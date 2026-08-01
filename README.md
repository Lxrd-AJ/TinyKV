# TinyKV

An embedded **KV and vector datastore** for local-first apps.

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

