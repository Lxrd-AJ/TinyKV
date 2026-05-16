# GEMINI: A Redis Implementation in Swift
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
* **Example Implementation:** A single `RedisEngine` Actor that processes parsed commands sequentially. It allows the safe use of standard Swift `Dictionary` and `Array` for storage.

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

### 5. AI Vector Search (Future Work)
* **Pattern:** SIMD-Accelerated Vector Math & specialized index structures (e.g., HNSW).
* **Why:** To support modern generative AI workloads directly within the datastore, mimicking the capabilities of the RediSearch module (e.g., vector embeddings, cosine similarity, dot product).
* **Example Implementation:** Utilizing Apple's `Accelerate` framework, MLX or `simd` types in Swift for high-performance, parallelized vector distance calculations during nearest-neighbor queries. This will require extending the parsing engine to support commands like `FT.SEARCH`.

## Coding guidelines
* When writing tests, prefer a newline after `@Test` annotations for better readability.