import Foundation

private var lastIdentifier: UInt = 0

/// 一意のID
public struct UniqueIdentifier: Hashable, CustomStringConvertible {
    private let rawValue: UInt
    public init() {
        lastIdentifier += 1 // ここでオーバーフローしたらごめんね
        self.init(rawValue: lastIdentifier)
    }
    
    private init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        return "ID=\(rawValue)"
    }
    
    public static let invalid = UniqueIdentifier(rawValue: 0)
}
