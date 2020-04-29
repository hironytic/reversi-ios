import Foundation

/// ゲームの状態を進めるためのアクションです。
public enum Action {
    /// ゲームを開始するときにディスパッチするアクションです。
    case start
    
    /// ボードのセルが選択されたときにディスパッチするアクションです。
    case boardCellSelected(x: Int, y: Int)
    
    /// 黒・白のプレイヤーモードが変更されたときにディスパッチするアクションです。
    case playerModeChanged(player: Disk?, mode: PlayerMode)
    
    /// リセットボタンが押されたときにディスパッチするアクションです。
    case reset
    
    /// リセットの確認ができたときにディスパッチするアクションです。
    case executeReset
    
    /// 「パス」の表示を消したときにディスパッチするアクションです。
    case dismissPass
    
    /// ディスクをセットするアニメーションが終わったらディスパッチするアクションです。
    case diskAnimationCompleted
}
