import Benchmark
import NIO
import Foundation
import TinyKVCommon

let benchmarks: @Sendable () -> Void = {
    let payloadSize = MAX_PAYLOAD_SIZE
    let repeatedString = String(repeating: "A", count: payloadSize)
    let unitsToUse: [BenchmarkMetric: BenchmarkUnits] = [
        .peakMemoryResident : BenchmarkUnits.giga,
    ]

    Benchmark("String Extraction", configuration: .init(metrics: [.mallocCountTotal, .wallClock, .peakMemoryResident], timeUnits: .milliseconds, units: unitsToUse)) { benchmark in
        var buffer = ByteBufferAllocator().buffer(capacity: payloadSize)
        buffer.writeString(repeatedString)
        
        benchmark.startMeasurement()
        let _ = buffer.readString(length: payloadSize)
        benchmark.stopMeasurement()
    }

    Benchmark("Slice Extraction", configuration: .init(metrics: [.mallocCountTotal, .wallClock, .peakMemoryResident], timeUnits: .milliseconds, units: unitsToUse)) { benchmark in
        var buffer = ByteBufferAllocator().buffer(capacity: payloadSize)
        buffer.writeString(repeatedString)
        
        benchmark.startMeasurement()
        let _ = buffer.readSlice(length: payloadSize)
        benchmark.stopMeasurement()
    }
}
