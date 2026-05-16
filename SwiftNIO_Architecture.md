# SwiftNIO Architectural Overview

SwiftNIO is a cross-platform asynchronous event-driven network application framework. Its architecture is built around several core primitives that work together to handle non-blocking I/O.

## Core Concepts

1. **`EventLoopGroup` & `EventLoop`**:
   - An **EventLoop** is a single thread running an infinite loop, constantly checking for I/O events (like new connections or incoming data) using the system's kernel (like `kqueue` on macOS or `epoll` on Linux). 
   - An **EventLoopGroup** manages a pool of these loops (typically one per CPU core). When a new connection arrives, it assigns the connection to exactly one `EventLoop`.

2. **`Channel`**:
   - A `Channel` represents a network socket (a TCP connection, for example). 
   - **Crucial Rule:** A `Channel` is bound to a single `EventLoop` for its entire lifetime. This means all processing for a given connection happens on the exact same thread, avoiding the need for locks and mutexes.

3. **`ChannelPipeline`**:
   - Every `Channel` has one `ChannelPipeline`. Think of it as a conveyor belt that data rides on when moving between the Network and your Application.

4. **`ChannelHandler`**:
   - The building blocks on the pipeline. You write these to handle your specific protocol.
   - **Inbound Handlers:** Process data moving from the network to the application (parsing raw bytes into swift structs, handling connections). Events flow from **Head to Tail**.
   - **Outbound Handlers:** Process data moving from the application to the network (encoding swift structs back into raw bytes). Events flow from **Tail to Head**.

## Architecture Diagram

```mermaid
graph TD
    subgraph ELG [EventLoopGroup]
        direction TB
        EL1[EventLoop 1]
        EL2[EventLoop 2]
        ELN[EventLoop N...]
    end

    subgraph EL1_Scope [Managed by EventLoop 1]
        direction TB
        Channel1[Channel A<br/>e.g., Active Socket Connection]
        Channel2[Channel B]
    end

    EL1 -->|Manages I/O & Execution| Channel1
    EL1 -.->|Manages| Channel2

    subgraph Channel_Structure [Inside a single Channel]
        direction TB
        Pipeline[ChannelPipeline]
        
        subgraph Handlers [Pipeline Execution Order]
            direction TB
            Head((Pipeline Head))
            In1[Inbound Handler<br/>e.g. ByteToMessageDecoder]
            InOut[Inbound/Outbound Handler<br/>e.g. EchoHandler]
            Out1[Outbound Handler<br/>e.g. MessageToByteEncoder]
            Tail((Pipeline Tail))
        end
    end

    Channel1 ===>|Owns exactly one| Pipeline
    Pipeline --- Handlers

    %% Inbound Flow
    Network((Network Socket)) ===>|1. Network Read| Head
    Head -->|2. channelRead| In1
    In1 -->|3. channelRead| InOut
    InOut -.->|4. channelRead| Tail
    
    %% Outbound Flow
    App((Application)) ===>|1. Write| Tail
    Tail -->|2. write| InOut
    InOut -->|3. write| Out1
    Out1 -->|4. write| Head
    Head ===>|5. Network Write| Network

    classDef inbound fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#000;
    classDef outbound fill:#fce4ec,stroke:#880e4f,stroke-width:2px,color:#000;
    classDef core fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px,color:#000;
    classDef io fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#000;

    class In1 inbound;
    class Out1 outbound;
    class EL1,EL2,ELN,Channel1,Channel2,Pipeline core;
    class Network,App io;
```
