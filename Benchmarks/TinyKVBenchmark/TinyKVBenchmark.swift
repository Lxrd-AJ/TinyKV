import Benchmark
import NIO
import Foundation
import TinyKVCommon

let benchmarks: @Sendable () -> Void = {
    let payloadSize = 10_000_000
    let repeatedString = String(repeating: "A", count: payloadSize)

    Benchmark("String Extraction", configuration: .init(metrics: [.mallocCountTotal, .wallClock, .peakMemoryResident])) { benchmark in
        var buffer = ByteBufferAllocator().buffer(capacity: payloadSize)
        buffer.writeString(repeatedString)
        
        benchmark.startMeasurement()
        let _ = buffer.readString(length: payloadSize)
        benchmark.stopMeasurement()
    }

    Benchmark("Slice Extraction", configuration: .init(metrics: [.mallocCountTotal, .wallClock, .peakMemoryResident])) { benchmark in
        var buffer = ByteBufferAllocator().buffer(capacity: payloadSize)
        buffer.writeString(repeatedString)
        
        benchmark.startMeasurement()
        let _ = buffer.readSlice(length: payloadSize)
        benchmark.stopMeasurement()
    }
}
