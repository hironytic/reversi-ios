import Foundation

extension Array {
    public subscript(_ disk: Disk) -> Element {
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
