import Foundation
import NIO

public let PORT: Int = 6379

public struct Message {
    public let contents: String

    public init(contents: String) {
        self.contents = contents
    }
}