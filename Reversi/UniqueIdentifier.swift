import Foundation

private var lastIdentifier = 0

/// 一意のID
public struct UniqueIdentifier: Hashable {
    private let rawValue: Int
    public init() {
        lastIdentifier += 1 // ここでオーバーフローしたらごめんね
        self.rawValue = lastIdentifier
    }
}
