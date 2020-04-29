import Foundation

/// ゲームの状態です。
public struct State {
    /// リバーシ盤の状態です。
    public var board: Board
    
    /// 現在のターンを表します。ゲームが終了したときは `nil` になります。
    public var turn: Disk?
    
    /// プレイヤーのモードです。
    public var playerModes: [PlayerMode]
    
    /// ゲームのフェーズです。
    public var phase: AnyPhase
    
    public init(board: Board, turn: Disk?, playerModes: [PlayerMode], phase: AnyPhase) {
        precondition(playerModes.count == Disk.sides.count)
        
        self.board = board
        self.turn = turn
        self.playerModes = playerModes
        self.phase = phase
    }
}
