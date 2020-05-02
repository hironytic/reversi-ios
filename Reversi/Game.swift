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

public enum GameError: Error {
    case restore(data: String)
}

/// ゲームの状態を保持し、アクションをディスパッチすることでゲームを進めます。
public class Game: Dispatcher {
    private let store: Store

    /// 現在の状態の発行元
    public let statePublisher: AnyPublisher<State, Never>

    /// 新規ゲームの開始状態で初期化します。
    public convenience init() {
        let state = State(board: Board(),
                          turn: .dark,
                          playerModes: [.manual, .manual])
        self.init(state: state, reducer: MainReducer.self)
    }

    /// 保存した状態で初期化します。
    /// - Parameter data: 保存状態のテキスト
    /// - Throws: 保存状態を復元できなければ `GameError.restore` を `throw` します。
    public convenience init(loading data: String) throws {
        // TODO:
        self.init()
    }

    /// 指定された状態で初期化します。
    public init(state: State, reducer: Reducer.Type = MainReducer.self) {
        store = Store(initialState: state, reducer: reducer)
        statePublisher = store.stateHolder
            .eraseToAnyPublisher()
    }
    
    /// アクションらしきものをディスパッチします。
    /// - Parameter actionish: アクションらしきもの
    public func dispatch(_ actionish: Actionish) {
        store.dispatch(actionish)
    }
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

    private func outputLog(_ line: @autoclosure () -> String) {
//        print(line())
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
        
        outputLog("(Phase: \(stateHolder.value.phase), Action: \(action)) -> Phase: \(state.phase)")
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

public enum MainReducer: Reducer {
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        let currentPhase = state.phase
        var phaseChanged = false

        switch action {
        case .changePhase(nextPhase: let nextPhase):
            // フェーズの変更
            state.phase = nextPhase
            phaseChanged = true

        case .initializeStateWhenStarted:
            // ゲーム開始時の状態初期化
            state.thinking = false
            for disk in Disk.sides {
                state.diskCount[disk] = state.board.countDisks(of: disk)
            }
            state.boardUpdateRequest = nil
            state.passNotificationRequest = nil
            state.resetConfirmationRequst = nil
        
        case .setThinking(let thinking):
            state.thinking = thinking
            
        case .requestUpdateBoard(request: let request):
            state.boardUpdateRequest = request
            
        case .requestPassNotification(let doRequest):
            state.passNotificationRequest = doRequest ? Request() : nil
            
        case .reset:
            // リセットボタンが押されたらリセット確認依頼を出す
            state.resetConfirmationRequst = Request()
            
        case .resetConfirmed(let requestId, let execute):
            if let request = state.resetConfirmationRequst, request.requestId == requestId {
                state.resetConfirmationRequst = nil
                
                if execute {
                    // どのフェーズにいてもリセットの確認の結果、
                    // 実行することになったらリセット
                    state.phase = AnyPhase(ResetPhase())
                }
            }
            
        default:
            break
        }
        
        // フェーズが変わらなければ、フェーズにreduceさせる
        if !phaseChanged {
            state = currentPhase.reduce(state: state, action: action)
        }
        
        return state
    }
}
