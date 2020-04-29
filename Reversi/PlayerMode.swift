import Foundation

public enum PlayerMode: Hashable {
    case manual
    case computer
}

extension Array where Element == PlayerMode {
    public subscript(_ disk: Disk) -> PlayerMode {
        get {
            return self[disk.index]
        }
        set {
            self[disk.index] = newValue
        }
    }
}

extension Disk {
    fileprivate var index: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }
}
