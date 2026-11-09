# AI measurement tools

Standalone benchmarks for the system move selector. They are **not** part of
the app or the widget test suite, and their numbers are host measurements —
never frame-budget claims.

## Correctness and timing tests

The regression suite (including the exhaustive 3×3 optimality sweep and the
deterministic 6×6 / 9×9 / 11×11 strength tests) runs with the normal suite:

```
flutter test
```

The exploratory timing test is skipped by default. Run it explicitly with:

```
flutter test --run-skipped test/features/game/domain/ai/system_move_selector_timing_test.dart
```

## Benchmarks

- `ai_bench.dart` — selection latency per level and board size (p50/p95/max),
  mirroring the timing test workload.
- `ai_async_bench.dart` — event-loop gaps of the synchronous search versus
  `selectMoveAsync` (`timerGap` shows the longest block).

Generated JavaScript goes to the git-ignored `tool/build/` directory.

### Dart VM (native-like)

```
dart run tool/ai_bench.dart
dart run tool/ai_async_bench.dart
```

### dart2js (web build output)

```
dart compile js -O2 -o tool/build/ai_bench.js tool/ai_bench.dart
node tool/build/ai_bench.js

dart compile js -O2 -o tool/build/ai_async_bench.js tool/ai_async_bench.dart
node tool/run_async_bench.js
```

Node needs a `self` global for dart2js timer code; `run_async_bench.js` adds it.

### Headless Edge / Chromium

`run_edge_cdp.js` opens `ai_async_bench.html` in headless Edge with remote
debugging, waits for the benchmark to finish, and prints the page output. It
requires Node 22+ (global `WebSocket`) and Edge at the default Windows path.

```
dart compile js -O2 -o tool/build/ai_async_bench.js tool/ai_async_bench.dart
node tool/run_edge_cdp.js
```

For the synchronous latency benchmark, open `ai_bench.html` the same way or
run its compiled output in Node. `flutter test --platform chrome` hung at
`loading` on the development machine, so browser numbers were collected with
the Edge CDP runner instead.

Web measurements vary substantially with machine load; compare runs only on
the same machine and do not turn them into frame-budget assertions.
