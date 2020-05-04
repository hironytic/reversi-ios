import Foundation
import Combine

public enum GameError: Error {
    case restore(data: String)
}

/// ゲームの状態を保持し、アクションをディスパッチすることでゲームを進めます。
public class Game: Dispatcher {
    private lazy var store: Store = { () -> Store in fatalError() }()

    /// 現在の状態
    public var state: State {
        store.stateHolder.value
    }
    
    /// 現在の状態が変更されたときのイベント発行者
    public lazy var statePublisher: AnyPublisher<State, Never> = { () -> AnyPublisher<State, Never> in fatalError() }()

    /// 状態を変更するもの
    public lazy var dispatcher: Dispatcher = { () -> Dispatcher in fatalError() }()
    
    /// 指定された状態で初期化します。
    public init(state: State = State(board: Board(),
                                     turn: .dark,
                                     playerModes: [.manual, .manual]),
                reducer: Reducer.Type = GameReducer.self,
                middlewares: [Middleware.Type] = []) {
        store = Store(rootDispatcher: self, initialState: state, reducer: reducer)
        statePublisher = store.stateHolder
            .eraseToAnyPublisher()
        dispatcher = middlewares.reversed().reduce(store) { (next, middleware) in
            return middleware.extend(game: self, next: next)
        }
    }
    
    /// 保存した状態で初期化します。
    /// - Parameter data: 保存状態のテキスト
    /// - Throws: 保存状態を復元できなければ `GameError.restore` を `throw` します。
    public convenience init(loading data: String) throws {
        // TODO:
        self.init()
    }
    
    /// アクションらしきものをディスパッチします。
    /// - Parameter actionish: アクションらしきもの
    public func dispatch(_ actionish: Actionish) {
        dispatcher.dispatch(actionish)
    }
}

public enum GameReducer: Reducer {
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
            state.boardUpdateRequest = wholeCellUpdateRequest(board: state.board)
            state.passNotificationRequest = nil
            state.resetConfirmationRequst = nil

        case .playerModeChanged(player: let disk, mode: let mode):
            state.playerModes[disk] = mode

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
                    state.loop { (dispatcher, _) in
                        dispatcher.dispatch(.changePhase(to: ResetPhase()))
                    }
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
    
    /// リバーシ盤の状態に合うように全セルの更新依頼を生成します。
    /// - Parameter board: リバーシ盤
    /// - Returns: 生成した更新依頼を返します。
    private static func wholeCellUpdateRequest(board: Board) -> DetailedRequest<BoardUpdate> {
        let cellChanges: [Board.CellChange] =
            (0 ..< board.height).flatMap { y in
                (0 ..< board.width).map { x in
                    Board.CellChange(x: x, y: y, disk: board.diskAt(x: x, y: y))
                }
            }

        return DetailedRequest(.withoutAnimation(cellChanges))
    }
}
