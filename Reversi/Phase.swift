import Foundation

/// フェーズの種別を表します。
public struct PhaseKind: Hashable, CustomStringConvertible {
    private let rawValue: String
    
    init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        return rawValue
    }
}

/// ゲームのフェーズを表します。
public protocol Phase: Reducer, Hashable, CustomStringConvertible {
    /// フェーズ種別です。
    var kind: PhaseKind { get }
    
    /// 別のフェーズからこのフェーズに遷移するときに呼ばれます。
    /// 必要に応じてサンクを返すことができます。
    /// - Parameters:
    ///   - previousPhase: 以前のフェーズが渡されます。
    func onEnter(previousPhase: AnyPhase) -> Thunk?
    
    /// このフェーズから別のフェーズに遷移するときに呼ばれます。
    /// 必要に応じてサンクを返すことができます。
    /// - Parameters:
    ///   - state: 現在の状態です。
    ///   - nextPhase: 次のフェーズが渡されます。
    func onExit(nextPhase: AnyPhase) -> Thunk?
}

extension Phase {
    public func onEnter(previousPhase: AnyPhase) -> Thunk? { nil }
    public func onExit(nextPhase: AnyPhase) -> Thunk? { nil }
    public func reduce(state: State, action: Action) -> State { state }
    public var description: String {
        return kind.description
    }
}

/// `Phase` のtype erasureです。
public struct AnyPhase: Phase, CustomStringConvertible {
    private class AnyPhaseBox {
        func isEqual(to other: AnyPhaseBox) -> Bool { fatalError() }
        func hash(into hasher: inout Hasher) { fatalError() }
        
        func reduce(state: State, action: Action) -> State { fatalError() }
        
        var kind: PhaseKind { fatalError() }
        
        func onEnter(previousPhase: AnyPhase) -> Thunk? { fatalError() }
        func onExit(nextPhase: AnyPhase) -> Thunk? { fatalError() }
        
        var description: String { fatalError() }
        var typelessBase: Any { fatalError() }
    }
    
    private class PhaseBox<P: Phase>: AnyPhaseBox {
        private let base: P
        init(_ base: P) {
            self.base = base
        }
        
        override func isEqual(to other: AnyPhaseBox) -> Bool {
            if let other = other as? PhaseBox<P> {
                return base == other.base
            } else {
                return false
            }
        }
        
        override func hash(into hasher: inout Hasher) {
            base.hash(into: &hasher)
        }
        
        override func reduce(state: State, action: Action) -> State {
            return base.reduce(state: state, action: action)
        }
        
        override var kind: PhaseKind {
            return base.kind
        }

        override func onEnter(previousPhase: AnyPhase) -> Thunk? {
            return base.onEnter(previousPhase: previousPhase)
        }
        
        override func onExit(nextPhase: AnyPhase) -> Thunk? {
            return base.onExit(nextPhase: nextPhase)
        }
        
        override var description: String {
            return base.description
        }
        
        override var typelessBase: Any {
            return base
        }
    }
        
    private let box: AnyPhaseBox
    
    public init(_ base: AnyPhase) {
        box = base.box
    }
    
    public init<P: Phase>(_ base: P) {
        box = PhaseBox(base)
    }
    
    public static func == (lhs: AnyPhase, rhs: AnyPhase) -> Bool {
        return lhs.box.isEqual(to: rhs.box)
    }
    
    public func hash(into hasher: inout Hasher) {
        box.hash(into: &hasher)
    }

    public func reduce(state: State, action: Action) -> State {
        return box.reduce(state: state, action: action)
    }
    
    public var kind: PhaseKind { box.kind }

    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return box.onEnter(previousPhase: previousPhase)
    }
    
    public func onExit(nextPhase: AnyPhase) -> Thunk? {
        return box.onExit(nextPhase: nextPhase)
    }
    
    public var description: String {
        return box.description
    }
    
    public var base: Any {
        return box.typelessBase
    }
}
