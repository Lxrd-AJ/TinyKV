# AGENTS: A Redis Implementation in Swift
A learning project to implement Redis in Swift, inspired by "Build your own Redis in C/C++".

## Project Overview
This repository contains a ground-up implementation of Redis in Swift. The goal is to translate the C/C++ networking and memory management paradigms from "Build your own Redis in C/C++" into modern, high-performance Swift. This bridges the gap between low-level systems architecture (I/O bounds, multiplexing).

## Architectural Guidance, Decisions & Stack
As the user progresses through the implementation, they will encounter key architectural decisions that shape the design of the Redis server. Below are some major components and patterns that you can expect to implement:

### 1. Networking: SwiftNIO
* **Pattern:** Reactor Pattern / Event-Driven.
* **Why:** Replaces raw POSIX sockets (`epoll`/`kqueue`) with an industry-standard, high-performance, non-blocking I/O framework.
* **Key Concepts:** `EventLoopGroup`, `ChannelHandler` pipelines, Backpressure.

### 2. Concurrency: Single-Actor Engine
* **Pattern:** Actor Isolation.
* **Why:** Redis operates strictly on a single-threaded execution model to ensure atomic operations without the overhead of locks or mutexes.

### 3. Parsing: Swift Enumerations & RESP Protocol
* **Pattern:** Associated Value Enums.
* **Why:** Replaces C-style byte array iteration and `strcmp` with type-safe pattern matching.
* **Example Implementation:** ```swift
    enum RESPValue {
        case simpleString(String)
        case error(String)
        case integer(Int64)
        case bulkString(Data?)
        case array([RESPValue])
    }
    ```

### 4. Memory Management: ARC + ByteBuffer
* **Pattern:** Zero-Copy Slicing.
* **Why:** While using ARC for general object lifetimes, the core data ingestion must avoid unnecessary allocations to maintain Redis-like speeds.
* **Example Implementation:** Utilizing SwiftNIO's `ByteBuffer` to slice memory references instead of copying `Data` or `String` structures whenever possible.

### 5. AI Vector Search & Embedding (Future Work)
* **Pattern:** SIMD-Accelerated Vector Math & specialized index structures (e.g., HNSW).
* **Why:** To support modern generative AI workloads directly within the datastore, mimicking the capabilities of the RediSearch module (e.g., vector embeddings, cosine similarity, dot product).
* **Example Implementation:** Utilizing Apple's `Accelerate` framework, MLX or `simd` types in Swift for high-performance, parallelized vector distance calculations during nearest-neighbor queries. This will require extending the parsing engine to support commands like `FT.SEARCH`.
* Some future usecases:
    * `AI.SET user:1 "Text to embed"` and TinyKV would use the local Neural Engine/GPU to generate and index the vector natively, removing a massive network/processing bottleneck for local AI agents.

### 6. Persistent Storage Engine (Future Work)
* **Pattern:** Log-Structured Merge-tree (LSM-tree) & Cooperative Actor System.
* **Why:** To extend TinyKV from an in-memory cache to a persistent, on-disk storage engine comparable to RocksDB/LevelDB/LanceDB/[Valkey](https://valkey.io/topics/data-types/). This involves moving beyond single-actor in-memory hash tables to handle datasets larger than RAM with crash-resistant durability.
* **Key Concepts:** Write-Ahead Logging (WAL) with SwiftNIO's `NonBlockingFileIO`, MemTables (Swift-based SkipList), immutable SSTables on disk, and background Actors for compaction and flushing. Also includes Bloom Filters and an LRU Block Cache to optimize read paths.
* The user can choose to have either in-memory only or disk based persistence

### 7. The De Facto Engine for AI & Monoliths (Future Work)
* **Pattern:** MVCC, Foreign Language Bindings, and Hybrid Search.
* **Why:** To mature from a simple KV store into an enterprise-grade, embeddable database capable of powering production monolithic servers and local LLM agents.
* **Key Concepts:** 
    * **Monolithic Needs:** Multi-Version Concurrency Control (MVCC) for ACID transactions, Point-in-Time Recovery (PITR) snapshots, and Column Families for logical partitioning.
    * **Local AI Specifics:** Zero-copy embedding generation (via `MLX`/`llama.cpp`), hybrid search combining HNSW vector indices within SSTables alongside metadata filtering.
    * **Ecosystem:** Exposing a C-API and Python bindings (`pytinykv`) to allow the Python AI ecosystem to natively embed the Swift storage engine.

## Coding guidelines
* When writing tests, prefer a newline after `@Test` annotations for better readability.
