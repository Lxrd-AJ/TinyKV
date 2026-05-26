# TinyKV
A pure Swift, Actor-isolated, embedded Key-Value store

## Tiny TODOS
- [ ] Performance optimizations
    - [ ] Convert `KVStore` to use templates and make a KVStore protocol so that I can create a `KVStore<String, String>` or a `KVStore<String, ByteBuffer>` and benchmark the differences. From a quick test in 'Benchmarks/TinyKVBenchmark/TinyKVBenchmark.swift' it seems like using `ByteBuffer` is much faster than using `String` for large payloads, which makes sense since it avoids unnecessary copying and encoding/decoding overhead.