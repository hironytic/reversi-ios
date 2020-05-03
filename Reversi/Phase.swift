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
    static func onEnter(previousPhase: AnyPhase) -> Thunk?
    
    /// このフェーズから別のフェーズに遷移するときに呼ばれます。
    /// 必要に応じてサンクを返すことができます。
    /// - Parameters:
    ///   - state: 現在の状態です。
    ///   - nextPhase: 次のフェーズが渡されます。
    static func onExit(nextPhase: AnyPhase) -> Thunk?
}

extension Phase {
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? { nil }
    public static func onExit(nextPhase: AnyPhase) -> Thunk? { nil }
    public static func reduce(state: State, action: Action) -> State { state }
    public var description: String {
        return kind.description
    }
    
    public static func thisPhase(of state: State) -> Self? {
        return state.phase.base as? Self
    }
}

/// `Phase` のtype erasureです。
public struct AnyPhase: Phase, CustomStringConvertible {
    private class AnyPhaseBox {
        func isEqual(to other: AnyPhaseBox) -> Bool { fatalError() }
        func hash(into hasher: inout Hasher) { fatalError() }
        
        class func reduce(state: State, action: Action) -> State { fatalError() }
        
        var kind: PhaseKind { fatalError() }
        
        class func onEnter(previousPhase: AnyPhase) -> Thunk? { fatalError() }
        class func onExit(nextPhase: AnyPhase) -> Thunk? { fatalError() }
        
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
        
        override class func reduce(state: State, action: Action) -> State {
            return P.reduce(state: state, action: action)
        }
        
        override var kind: PhaseKind {
            return base.kind
        }

        override class func onEnter(previousPhase: AnyPhase) -> Thunk? {
            return P.onEnter(previousPhase: previousPhase)
        }
        
        override class func onExit(nextPhase: AnyPhase) -> Thunk? {
            return P.onExit(nextPhase: nextPhase)
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

    public static func reduce(state: State, action: Action) -> State {
        preconditionFailure("This function should not be called.")
    }
    
    public var kind: PhaseKind { box.kind }

    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        preconditionFailure("This function should not be called.")
    }
    
    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        preconditionFailure("This function should not be called.")
    }
    
    public static var reduce: Reducer {
        preconditionFailure("This property should not be called.")
    }
    
    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return type(of: box).onEnter(previousPhase: previousPhase)
    }
    
    public func onExit(nextPhase: AnyPhase) -> Thunk? {
        return type(of: box).onExit(nextPhase: nextPhase)
    }
    
    public func reduce(state: State, action: Action) -> State {
        return type(of: box).reduce(state: state, action: action)
    }
    
    public var description: String {
        return box.description
    }
    
    public var base: Any {
        return box.typelessBase
    }
}
