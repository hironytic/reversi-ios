import Foundation
import Combine

/// アクションに応じて状態を変更する `reduce` メソッドを持ちます。
/// `reduce` メソッドでは、変更したStateを返す以外の方法で
/// 状態を変更してはいけません。また、非同期処理の呼び出しなど
/// 副作用のあることを行ってはいけません。
public protocol Reducer {
    /// アクションに応じて状態を変更します。
    /// - Parameters:
    ///   - state: 変更前の状態です。
    ///   - action: 状態変更を要求するアクションです。
    /// - Returns: 変更後の状態を返します。
    static func reduce(state: State, action: Action) -> State
}

/// アクションをディスパッチするメソッドを持ちます。
public protocol Dispatcher {
    /// アクションらしきものをディスパッチします。
    /// - Parameter actionish: アクションらしきもの
    func dispatch(_ actionish: Actionish)
}

/// アクションのディスパッチを遅延実行させるための関数です。
/// サンクの中では非同期処理の呼び出しなど副作用のある
/// 動作を行っても構いません。
public typealias Thunk = (Dispatcher, State) -> Void

/// ディスパッチ処理を必要に応じて拡張するためのものです。
public protocol Middleware {
    static func extend(game: Game, next: Dispatcher) -> Dispatcher
}

public class Store: Dispatcher {
    /// 状態を保持するものです。
    public let stateHolder: CurrentValueSubject<State, Never>
    
    /// 状態を変更するものです。
    private let reducer: Reducer.Type

    public init(initialState: State, reducer: Reducer.Type) {
        stateHolder = CurrentValueSubject(initialState)
        self.reducer = reducer
    }

    /// アクションらしきものをディスパッチします。
    /// - Parameter actionish: アクションらしきもの
    public func dispatch(_ actionish: Actionish) {
        switch actionish {
        case .action(let action):
            dispatch(action: action)
            
        case .thunk(let thunk):
            dispatch(thunk: thunk)
        }
    }

    /// アクションをディスパッチします。
    /// - Parameter action: ディスパッチ対象のアクション
    public func dispatch(action: Action) {
        var state = stateHolder.value
        state = reducer.reduce(state: state, action: action)

        // ループ用サンクは取り出しておく
        let thunks = state._loops
        state._loops = []
        
        stateHolder.value = state
        
        for thunk in thunks {
            dispatch(thunk: thunk)
        }
    }

    /// サンクを用いてアクションをディスパッチします。
    /// - Parameter thunk: サンク
    public func dispatch(thunk: Thunk) {
        thunk(self, stateHolder.value)
    }
}
