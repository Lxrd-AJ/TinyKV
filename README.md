# TinyKV

A pure Swift, Actor-isolated, embedded Key-Value store. 

TinyKV is a ground-up implementation of Redis in modern Swift, inspired by the "Build your own Redis in C/C++" paradigm. It bridges the gap between low-level systems architecture and high-performance Swift, serving as both a robust datastore and a learning project.

You can use TinyKV as either an:
* **In-process KV cache** directly embedded within your Swift applications
* **Client-Server KV store** for a standalone, network-addressable datastore

## 🏗 Architecture & Stack

TinyKV is designed around high-performance principles, making use of modern Swift concurrency and networking:

### 1. Networking: SwiftNIO
Replaces raw POSIX sockets (`epoll`/`kqueue`) with an industry-standard, high-performance, non-blocking I/O framework. Features a Reactor Pattern / Event-Driven architecture utilizing `EventLoopGroup`, `ChannelHandler` pipelines, and robust backpressure handling.

### 2. Concurrency: Single-Actor Engine
Redis operates strictly on a single-threaded execution model to ensure atomic operations without the overhead of locks or mutexes. TinyKV achieves this using Swift's Actor isolation. 

### 3. Parsing: Swift Enumerations & RESP Protocol
Instead of C-style byte array iteration and `strcmp`, TinyKV leverages type-safe pattern matching with Swift Associated Value Enums to parse the RESP (REdis Serialization Protocol) cleanly and safely.

### 4. Memory Management: ARC + ByteBuffer
While Swift uses ARC for object lifecycles, TinyKV minimizes allocations to maintain Redis-like speeds. It relies heavily on SwiftNIO's `ByteBuffer` to perform zero-copy slicing of memory references, avoiding unnecessary copying of `Data` or `String` structures during core data ingestion.

## 🚀 Future Roadmap

### Optional Persistent Storage Engine (LSM-Tree)
Extending TinyKV from an in-memory cache to a robust, on-disk storage engine comparable to RocksDB or LevelDB. 
* **Write-Ahead Logging (WAL) & MemTables:** Moving from simple Swift Dictionaries to in-memory SkipLists paired with append-only WALs for crash durability.
* **SSTables & Compaction:** Serializing immutable MemTables to disk as Sorted String Tables (SSTables) and utilizing background Swift Actors to merge and compact these files.
* **Read Optimizations:** Implementing Bloom Filters and LRU Block Caches to prevent disk I/O bottlenecks during the read path.
* **Range Queries:** Unlocking fast `SCAN_RANGE` queries by leveraging the inherently sorted nature of LSM-trees.
* The user can choose to have either in-memory only or disk based persistence

### AI Vector Search & Embedding
Modern generative AI workloads require high-performance datastores. TinyKV plans to support native vector search directly within the datastore, mimicking the capabilities of the RediSearch module. 

Future plans include:
* **SIMD-Accelerated Vector Math & Specialized Indexing:** Implementing HNSW and utilizing Apple's `Accelerate` framework, MLX, or `simd` types for parallelized vector distance calculations (cosine similarity, dot product).
* **Native AI Commands:** Extending the parsing engine to support commands like `FT.SEARCH` and custom commands such as `AI.SET user:1 "Text to embed"`, utilizing the local Neural Engine/GPU to generate and index vectors natively—removing massive network and processing bottlenecks for local AI agents.

## 📄 License

This project is licensed under the terms of the license found in the [LICENSE](LICENSE) file.
