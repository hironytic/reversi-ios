import Foundation

/// フェーズとアクションに関するログ出力を行うミドルウェアです。
public class Logger: Middleware, Dispatcher {
    private let game: Game
    private let next: Dispatcher
    
    public init(game: Game, next: Dispatcher) {
        self.game = game
        self.next = next
    }
    
    public static func extend(game: Game, next: Dispatcher) -> Dispatcher {
        return Logger(game: game, next: next)
    }

    public func dispatch(_ actionish: Actionish) {
        print("(Phase: \(game.state.phase),\n Action: \(actionish))")
        next.dispatch(actionish)
        print("  --> Phase: \(game.state.phase)")
    }
}
