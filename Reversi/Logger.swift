import Foundation

/// フェーズとアクションに関するログ出力を行うミドルウェアです。
public class Logger: Middleware, Dispatcher {
    private let game: Game
    private let next: Dispatcher
    private var depth = 0
    
    public init(game: Game, next: Dispatcher) {
        self.game = game
        self.next = next
    }
    
    public static func extend(game: Game, next: Dispatcher) -> Dispatcher {
        return Logger(game: game, next: next)
    }

    private var indent: String {
        return String(repeating: " ", count: depth * 2)
    }
    
    public func dispatch(_ actionish: Actionish) {
        guard actionish.isAction else {
            next.dispatch(actionish)
            return
        }
        
        print("\(indent)Phase: \(game.state.phase), Action: \(actionish)")
        do {
            depth += 1; defer { depth -= 1 }
            next.dispatch(actionish)
        }
        print("\(indent)----> Phase: \(game.state.phase)")
    }
}
