//
//  ProcessRunner.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let output: String
    public let timedOut: Bool

    public var succeeded: Bool { exitCode == 0 && !timedOut }
}

public enum ProcessRunnerError: LocalizedError, Sendable {
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let reason): "Couldn't start the build: \(reason)"
        }
    }
}

/// Runs a command, streaming its output as it arrives, with a hard timeout and
/// cancellation that waits for the process to actually be gone before returning.
public struct ProcessRunner: Sendable {
    public init() {}

    public func run(
        executable: URL,
        arguments: [String],
        workingDirectory: URL,
        timeout: Duration,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardInput = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        // Keeps SwiftPM from drawing an ANSI progress bar into the log.
        environment["TERM"] = "dumb"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let collector = OutputCollector(onChunk: onOutput)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            collector.ingest(data)
        }

        let state = RunState()
        process.terminationHandler = { finished in
            state.finish(exitCode: finished.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            throw ProcessRunnerError.launchFailed(error.localizedDescription)
        }
        state.launched(pid: process.processIdentifier)

        let timeoutTask = Task {
            try await Task.sleep(for: timeout)
            state.markTimedOut()
            state.stop()
        }

        await withTaskCancellationHandler {
            await state.waitUntilFinished()
        } onCancel: {
            state.stop()
        }
        timeoutTask.cancel()

        // The parent is gone, but signalled descendants may still be winding down.
        // Detached so that it still runs when this task is the one being cancelled.
        await Task.detached { await state.waitForDescendantsToExit(timeout: .seconds(3)) }.value

        pipe.fileHandleForReading.readabilityHandler = nil
        if let remainder = try? pipe.fileHandleForReading.readToEnd(), !remainder.isEmpty {
            collector.ingest(remainder)
        }
        try? pipe.fileHandleForReading.close()

        let output = collector.finish()
        try Task.checkCancellation()

        return ProcessResult(
            exitCode: state.exitCode,
            output: output,
            timedOut: state.didTimeOut
        )
    }
}

// MARK: - Lifetime

/// Tracks one running child process. Signals escalate SIGINT -> SIGTERM -> SIGKILL:
/// SwiftPM handles SIGINT as "cancel this build and clean up", which is the polite
/// door to knock on first.
private final class RunState: @unchecked Sendable {
    private let lock = NSLock()
    private var pid: pid_t = 0
    private var known: Set<pid_t> = []
    private var finished = false
    private var stopping = false
    private var status: Int32 = -1
    private var timedOut = false
    private var continuation: CheckedContinuation<Void, Never>?

    var exitCode: Int32 { lock.withLock { status } }
    var didTimeOut: Bool { lock.withLock { timedOut } }

    func launched(pid: pid_t) {
        lock.withLock { self.pid = pid }
    }

    func markTimedOut() {
        lock.withLock { timedOut = true }
    }

    func finish(exitCode: Int32) {
        lock.lock()
        finished = true
        status = exitCode
        let waiter = continuation
        continuation = nil
        lock.unlock()
        waiter?.resume()
    }

    func waitUntilFinished() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if finished {
                lock.unlock()
                continuation.resume()
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func stop() {
        lock.lock()
        guard !finished, !stopping, pid > 0 else { lock.unlock(); return }
        stopping = true
        lock.unlock()

        Task.detached { [self] in
            signal(SIGINT)
            try? await Task.sleep(for: .seconds(2))
            guard !isFinished else { return }
            signal(SIGTERM)
            try? await Task.sleep(for: .seconds(2))
            guard !isFinished else { return }
            signal(SIGKILL)
        }
    }

    private var isFinished: Bool { lock.withLock { finished } }

    /// Waits for anything we signalled to actually exit. No-op when nothing was stopped.
    func waitForDescendantsToExit(timeout: Duration) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            let stillAlive = lock.withLock { known.filter { kill($0, 0) == 0 } }
            if stillAlive.isEmpty { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Signals the child and everything it spawned.
    ///
    /// Process groups aren't enough here: `swift build` starts swift-driver and
    /// swift-frontend children that SwiftPM puts into groups of their own, so
    /// `kill(-pgid)` leaves compilers running after the parent is gone. The tree
    /// is re-read and remembered on every round, because once the parent dies its
    /// children are reparented to launchd and can no longer be found from our pid.
    private func signal(_ code: Int32) {
        lock.lock()
        let root = pid
        let alive = !finished && pid > 0
        if alive {
            known.formUnion(ProcessTree.descendants(of: root))
        }
        let targets = alive ? [root] + known.sorted() : []
        lock.unlock()

        for target in targets {
            _ = kill(target, code)
        }
    }
}

// MARK: - Output

/// Accumulates process output and hands out whole, valid UTF-8 chunks. A read can
/// land mid-character, so incomplete trailing bytes are held back for the next read.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()
    private var text = ""
    private let onChunk: @Sendable (String) -> Void

    init(onChunk: @escaping @Sendable (String) -> Void) {
        self.onChunk = onChunk
    }

    func ingest(_ data: Data) {
        lock.lock()
        pending.append(data)
        let chunk = Self.takeDecodable(&pending)
        if !chunk.isEmpty { text += chunk }
        lock.unlock()
        if !chunk.isEmpty { onChunk(chunk) }
    }

    func finish() -> String {
        lock.lock()
        defer { lock.unlock() }
        if !pending.isEmpty {
            text += String(decoding: pending, as: UTF8.self)
            pending = Data()
        }
        return text
    }

    private static func takeDecodable(_ buffer: inout Data) -> String {
        guard !buffer.isEmpty else { return "" }
        for dropped in 0...min(3, buffer.count) {
            let candidate = buffer.prefix(buffer.count - dropped)
            if let decoded = String(data: candidate, encoding: .utf8) {
                buffer = Data(buffer.dropFirst(buffer.count - dropped))
                return decoded
            }
        }
        // Not valid UTF-8 at all — don't let the buffer grow without bound.
        if buffer.count > 64 * 1024 {
            let decoded = String(decoding: buffer, as: UTF8.self)
            buffer = Data()
            return decoded
        }
        return ""
    }
}


// MARK: - Process tree

private enum ProcessTree {
    /// Every descendant of `root`, from one snapshot of the process table.
    static func descendants(of root: pid_t) -> [pid_t] {
        guard let table = snapshot() else { return [] }

        var childrenByParent: [pid_t: [pid_t]] = [:]
        for entry in table {
            childrenByParent[entry.kp_eproc.e_ppid, default: []].append(entry.kp_proc.p_pid)
        }

        var found: [pid_t] = []
        var frontier = [root]
        while let next = frontier.popLast() {
            for child in childrenByParent[next] ?? [] where !found.contains(child) {
                found.append(child)
                frontier.append(child)
            }
        }
        return found
    }

    private static func snapshot() -> [kinfo_proc]? {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&name, 4, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        // The table can grow between sizing and reading, so ask for headroom.
        let capacity = size / MemoryLayout<kinfo_proc>.stride + 32
        var table = [kinfo_proc](repeating: kinfo_proc(), count: capacity)
        size = capacity * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&name, 4, &table, &size, nil, 0) == 0 else { return nil }

        return Array(table.prefix(size / MemoryLayout<kinfo_proc>.stride))
    }
}
