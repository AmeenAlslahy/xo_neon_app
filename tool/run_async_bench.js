// Node shim for the dart2js async benchmark: dart2js timer code expects a
// `self` global, which Node does not provide.
// Run after: dart compile js -O2 -o tool/build/ai_async_bench.js tool/ai_async_bench.dart
globalThis.self = globalThis;
require('./build/ai_async_bench.js');
