# Benchmark subjects

The six files the numbers in the main README were measured on. Each stands alone,
so the app can be pointed at one directly in single-file mode.

| File | Shape | Why it's here |
|---|---|---|
| `Money.swift` | value type, throwing operator | the easy case — arithmetic and one error path |
| `BoundedStack.swift` | generic, stateful, mutating | state that has to be driven to be observed |
| `VersionParser.swift` | parsing, returns an optional | many wrong answers, one right one |
| `SlugMaker.swift` | pure string functions | easy to test, easy to get wrong |
| `RetryPolicy.swift` | protocol dependency | needs a fake written by hand |
| `Announcer.swift` | no observable behaviour | everything it does goes to stdout |

`Announcer` is deliberately untestable in any useful sense. It is here because a
generator with no verification will report a confident success on it, and the
point of this app is that it doesn't.

## Reproducing

Open one in the app, generate three times, and compare. Numbers will not match
exactly — the model is sampling — but the spread between *compiled* and *passed*
is stable.
