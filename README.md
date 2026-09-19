# SwiftTestLab

[![CI](https://github.com/ManjuiOS46/SwiftTestLab/actions/workflows/ci.yml/badge.svg)](https://github.com/ManjuiOS46/SwiftTestLab/actions/workflows/ci.yml)

A small macOS app that generates a unit test for **one** Swift file, then compiles
and runs it and shows you what happened. You decide whether to keep it.

The distinction it's built around: most test generators *produce* a test. This one
**verifies** it. Nothing is reported as a success until `swift build --build-tests`
and `swift test` have both actually run.

It is not an agent, and that is the design rather than a shortfall. It takes one
action, observes what happened, and stops. The loop is closed by you: you choose
the file, you see the prompt before it is sent, and you decide whether the result
is worth keeping. A tool that retries until something goes green optimises for
green — and a test that passes while asserting nothing is the exact failure this
app exists to catch.

One turn, verified, with a human holding the decision.

It works with Claude over the Anthropic API, or with an open model running on your
own machine through Ollama, LM Studio, llama.cpp or vLLM — no key, no cost, nothing
leaving the Mac.

---

## The loop

1. **Open something.** Either a **Swift Package** (a folder with a `Package.swift`
   at its root) or a **single Swift file**. An `.xcodeproj` is told it's out of
   scope by name, rather than just "unrecognised".
2. **Pick a file.** In package mode: everything under `Sources/`, minus existing
   tests, `*Tests.swift` and `.build/`.
3. **Review the prompt.** The system prompt and the exact message are shown in full
   before anything is sent. There is no path to a model that skips this screen.
4. **Generate.** One streamed request, so the test file appears as it's written.
5. **Verify.** The package is cloned to a scratch directory, the test is written
   *there*, and `swift build --build-tests` then `swift test --filter <Suite>` run
   against the copy. Your files are not touched. Output streams live.
6. **Decide.** Compiled or not, passed or not — with the compiler's actual
   complaints pulled out of the log, and the raw output a click away.
7. **Saved either way.** Every generated test is written to `SwiftTestLabTests/`
   beside the package (or beside the file) the moment it arrives, before the build
   runs. Pass or fail, the file is on disk and the app shows you its path. Nothing
   there is ever overwritten — a repeat generation becomes `-2`, `-3`.
8. **Accept.** Only on your click, and only after a diff, does it go into your
   actual test target.

---

## Models: hosted, or on your own machine

Both paths go through the same prompt, the same extraction and the same
verification. Only the transport differs.

| | Anthropic | Open model |
|---|---|---|
| Endpoint | `api.anthropic.com/v1/messages` | any OpenAI-compatible `/chat/completions` |
| Presets | Sonnet / Opus / Haiku, or type an ID | Ollama, LM Studio, llama.cpp, vLLM |
| Key | required, in the Keychain | none for `localhost`; Bearer token for remote gateways |
| Cost | per token | nothing |

Point Settings at a local runtime and press **Check**: the app asks the endpoint
what it has loaded, lists it, and picks a coding-tuned model if it can find one —
`qwen2.5-coder` beats a general chat model of the same size at this, noticeably.
When the endpoint is local, the prompt preview says so, and nothing leaves the Mac.

Reasoning models that emit a `<think>` scratchpad inline are handled: the
scratchpad is stripped, not written into your test file.

---

## The two ways in

**Package mode** is the fuller one. It reads your manifest, finds your test target,
detects whether your existing tests use Swift Testing or XCTest and instructs the
model to match, and can write an accepted test straight into `Tests/YourTests/`.

**Single-file mode** takes any `.swift` file on its own. SwiftPM can't build a loose
file, so verifying one means wrapping it in a throwaway package and building that.
The throwaway module takes its name from the file's own location, so the generated
test imports a name that exists in your project rather than one invented for the
scratch build: `Sources/PixiiCloneApp/Models.swift` is module `PixiiCloneApp`, and
a file in an Xcode project next to `LoginApp.xcodeproj` is module `LoginApp`.
Failing both, it uses the enclosing folder's name.
That works when the file stands on its own, and **fails honestly when it doesn't**:
a file that needs types from the rest of its project won't compile, and the
Problems list will say which symbol is missing. Accepting in this mode is a Save As,
because there's no test target to land in.

**SwiftUI works.** A platform-neutral SwiftUI file compiles and its logic runs —
there's a test that proves it. What doesn't work is **iOS-only API**
(`.navigationBarTrailing`, `UIViewController`, `UIApplication`): verification runs
`swift test` on macOS, and running iOS code needs a simulator, which is on the
deliberately-excluded list. The app checks for this before you spend a run on it and
says so. A view's `body` is also a thin subject for a unit test either way — the
logic behind the view is usually the better file to point at.

---

## Requirements

- macOS 14 or later
- Swift 6.2 or later (Xcode 26+). Not 6.0 or 6.1: the app uses `nonisolated
  deinit`, which was experimental before 6.2, and an older toolchain fails with
  an error that doesn't mention the version. The manifest declares 6.2 so
  SwiftPM says so plainly instead.
- An Anthropic API key, **or** a local model server — either is enough
- No third-party dependencies. `URLSession` and `Process`, nothing else.

## Build and run

```bash
swift run SwiftTestLab
```

That's enough to use it, though the app is then tied to that terminal. For a real
app with a Dock icon that outlives the shell:

```bash
./Scripts/make-app.sh
open SwiftTestLab.app
```

No `.xcodeproj` is needed for either path — clone and run. Tests:

```bash
swift test
```

## Your API key

Entered in Settings (`⌘,`), stored in the login Keychain, one item per provider so
switching between them doesn't lose the other. It is never written to disk in plain
text, never logged, and never included in an error message — API failures report
the status code and the server's message, nothing else. With no key set, the app
says exactly what's missing and the generate button stays disabled.

---

## How verification works

The generated test has to live inside a test target for SwiftPM to compile it, so
the package is copied to a temporary directory first (or invented, in single-file
mode) and the test is written into the copy. On APFS the copy is a clone, so it
costs almost nothing. `.build` and `.git` are left behind, which means the scratch
copy is **pristine**: the first verification of a given package is a cold build.
That's deliberate — a test proven against a clean build is worth the wait, and
SwiftPM's shared dependency cache means checkouts usually don't need refetching.

The scratch copy is deleted when the run ends, whether it passed, failed or was
cancelled.

**Cancelling** stops the build properly. `swift build` starts swift-driver and
swift-frontend children that SwiftPM puts into process groups of their own, so
signalling a process group isn't enough — the runner walks the real process tree
from the kernel's process table, escalates SIGINT → SIGTERM → SIGKILL, and waits
for everything it signalled to actually exit before returning. There's a test that
asks `ps`, not the app's own bookkeeping, whether anything survived.

**Failures are readable.** When a build fails SwiftPM prints the whole compiler
invocation, so the lines that say what's actually wrong sit buried in several
hundred flags. The app parses the diagnostics out and leads with them; the raw log
is still one click away.

## The system prompt

Built in [`SystemPrompt.swift`](Sources/SwiftTestLabKit/SystemPrompt.swift), and
shown to you in full before every run. It adapts to the framework the package
already uses — the sidebar shows which was detected and why. The rules:

1. Return one complete, compilable test file and nothing else.
2. Cover the happy path, boundary values and error paths.
3. Write fakes by implementing the protocol the subject depends on. No mocking frameworks.
4. Never force-unwrap, never `try!`, never index a collection directly — a trap
   takes down the whole suite, not one test.
5. Never invent an expected value. If the code doesn't say what a string or default
   should be, assert something derivable instead.
6. Assert the behaviour the code *should* have, not what it happens to do.
7. Test only what a test target can reach: public and internal declarations.

Plus framework mechanics, which turn out to matter as much as the rules: every
`@Test` whose body contains `try` must be declared `throws`, `#require` is for
unwrapping optionals only, and a fake that varies its answers has to be a class.
Smaller models get these wrong constantly, and each one is a compile error rather
than a bad test — cheap to catch, but only if you actually compile it.

---

## Assertions that cannot fail

A suite can compile, run, pass every test, and assert nothing. Pointed at a type
with no observable behaviour, `qwen3-coder:30b` produced this:

```swift
#expect(announcer.announce() == Void())            // comparing Void to Void
#expect(throws: Never.self) { try announcer.run() } // a non-throwing call doesn't throw
```

Both pass. Neither is a test.

Adding a rule to the system prompt forbidding exactly this **did not work** — the
second example is what the model wrote *after* being told not to. Measured over
three runs per condition on the same subject, there was no difference. So the app
checks for it instead of asking: a passing run that contains assertions which are
true by construction is reported as "Passed, but N assertions cannot fail", with
the line and the reason. It is a warning, not a block — you decide.

## Does it work?

Measured, not assumed. Six subjects, three runs each, against `qwen3-coder:30b`
running locally in Ollama — 18 generations in all:

| | count | rate |
|---|---|---|
| Produced something parseable as a test | 18 | 100% |
| Compiled | 14 | 78% |
| Compiled **and passed** | 10 | 56% |

Per subject:

| Subject | Shape | Compiled | Passed |
|---|---|---|---|
| `Money` | value type, throwing operator | 3/3 | 3/3 |
| `BoundedStack` | generic, stateful | 3/3 | 3/3 |
| `VersionParser` | parsing, optionals | 2/3 | 2/3 |
| `SlugMaker` | pure string functions | 3/3 | 1/3 |
| `RetryPolicy` | protocol dependency | 3/3 | 1/3 |
| `Announcer` | no observable behaviour | 0/3 | 0/3 |

**The gap between the columns is the whole argument.** `SlugMaker` compiled every
time and passed once: a test that builds tells you nothing about whether it is
right. Most failures are the model computing an expected value itself and getting
it wrong — precisely what rule 5 of the prompt exists to prevent, and it still
happens, which is why the test is run rather than trusted.

`Announcer` is the interesting one. It has no observable behaviour — everything it
does goes to stdout — and nothing usable was produced for it in three runs. A
generator without verification would have reported three successes.

### Assertions that cannot fail

The audit flagged none across those 18 runs. Re-running `Announcer` three more
times, one produced exactly what the audit exists for:

```swift
#expect(throws: Never.self) { announcer.announce("Hello") }
#expect(throws: Never.self) { announcer.warn("Something went wrong") }
```

`announce` is not declared `throws`. Neither assertion can fail. Both were caught.

So it is real but intermittent — roughly one run in six on a subject with nothing
to assert, and none at all on subjects that have something. Worth catching, not
worth quoting a rate for.

### What this is and isn't

Six subjects, one model, three runs each, all small and self-contained. Enough to
show the spread between *produced*, *compiled* and *passed* is real and wide.
Not enough to predict what a larger model does on a large codebase.

The six subjects are in `Benchmarks/Subjects/`. Open one in the app, generate
three times, and compare. The counts will not match exactly — the model samples —
but the spread between *compiled* and *passed* is stable.

---

## What it deliberately doesn't do

These are choices, not gaps:

- **No repair loop.** If the test fails, you get the output and the decision.
  This is the "not an agent" choice above, made concrete: the one place a tool
  like this could act on its own is the one place it doesn't.
- **No whole-project sweep, no planner, no work queue.** One file at a time. The
  value is in reading the result, and nobody reads two hundred generated tests.
- **No coverage measurement.** Coverage tells you lines executed. Running the test
  tells you it compiles, runs and asserts — a stronger claim, measured directly.
- **No Xcode projects, simulators or code signing.** SwiftPM only, so verification
  is one command with no scheme or device in the way.
- **It will not create a test target.** If a package has none, it says so up front
  instead of failing obscurely at build time.
- **It will never overwrite an existing test file** in package mode. The write uses
  `O_EXCL`, so the guarantee holds even against a race, and the run stops before the
  build — verifying against a sandbox where a human's test had been shadowed would
  be a meaningless green tick. (In single-file mode you name the path yourself in a
  save panel, so that panel's replace confirmation is the decision.)
- **A test that doesn't compile never reaches your test target**, however you feel
  about it. It is still saved to `SwiftTestLabTests/` so you can read it — those
  are two different places, and the app says which. One that compiles but fails,
  you may accept: that's a judgement call, and it leaves it to you.

---

## Layout

```
Sources/SwiftTestLabKit/   Inspection, providers, prompt, sandbox, verify, diagnostics, write
Sources/SwiftTestLab/      The SwiftUI app
Tests/SwiftTestLabKitTests/
```

The split keeps the logic testable without a UI, and lets the app be pointed at
itself. The integration tests build and run real packages — they're the only ones
that prove the central claim, so they earn their runtime.

---

## Tried and rejected: a vendored Swift Testing skill

One plausible reading of the failures here is that they are gaps in framework
knowledge rather than missing context — the model knows the code under test and
still writes Swift Testing wrongly. That reading is why this app's prompt carries a
framework-mechanics section and a worked example at all.

Vendoring curated Swift Testing reference documents into the prompt follows from
the same reading, so it was worth trying. It was measured and **did not help**, on
`qwen3-coder:30b` against a throwing subject with a protocol dependency, three runs
per condition:

| Prompt | Compiled | Passed |
|---|---|---|
| Mechanics section + vendored reference | 3/3 | 0/3 |
| Mechanics section only | 2/3 | 0/3 |
| Vendored reference only, mechanics removed | 1/3 | 0/3 |

The reference could not replace the hand-written section — it was worse at
producing code that compiles. A general reference teaches a framework; the
mechanics section targets the specific mistakes this task actually produces, which
were found by running it. Adding both costs around 7KB of prompt for no measured
gain, so it isn't shipped.

Small sample, one model, one subject — enough to decline, not enough to conclude a
stronger model wouldn't benefit.

## What I'd add next

In rough order of what I'd actually reach for:

- **A verified-failure view.** A failing test is a dead end by design. The honest
  next step isn't a repair loop, it's showing the failed assertion beside the line
  of source it disagrees with, so a human can tell in ten seconds whether the test
  is wrong or the code is. Given how the failures actually look, this is the single
  highest-value thing left.
- **A mutation check on passing tests.** A test that passes may still assert nothing
  useful. Flipping one operator in the subject and re-running would say whether the
  test detects the change — a real quality signal, and far cheaper than coverage.
- **Warm sandboxes, opt-in.** Cloning `.build` too would turn a 90-second first run
  into a 5-second one. Off by default because a warm build can hide a stale-artifact
  problem; as a switch you flip knowingly, worth having.
- **Model comparison on one file.** The plumbing for several providers is already
  there; running the same file through two models and showing both verified results
  side by side would make picking a local model an evidence-based decision.
- **Diff-scoped selection.** "Files changed on this branch" is a better file list
  than "all files", and it's a filter on what's there, not a project sweep.
- **Cost and token display.** Responses carry usage; showing what a run cost, and
  what the same run costs locally (nothing), would make the model picker mean more.

Each of those keeps the app small. The ones I'd still refuse are the sweep, the
queue and the retry loop — those change what it is.

## Developer flags

The app takes a package path on the command line, which is how its layout was
debugged without clicking through the UI by hand:

```bash
swift run SwiftTestLab /path/to/package --select-first
swift run SwiftTestLab /path/to/package --demo-run    # a finished run, no model call
swift run SwiftTestLab /path/to/package --dump-layout # records oversized views
```

They exist because a window that sizes itself from its content is very hard to
reason about by eye, and measuring it beat guessing every time.

## Licence

MIT. See [LICENSE](LICENSE).
