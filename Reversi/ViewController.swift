import UIKit
import Combine

class ViewController: UIViewController {
    @IBOutlet private var boardView: BoardView!
    
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!
    
    private var viewModel: ViewModel!
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.delegate = self

        viewModel = ViewModel(savedData: try? loadGame())
        bindViewModel(messageDiskSize: messageDiskSizeConstraint.constant)
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if viewHasAppeared { return }
        viewHasAppeared = true
        viewModel.viewDidFirstAppear()
    }
}

// MARK: Binding

extension ViewController {
    private func bindViewModel(messageDiskSize: CGFloat) {
        // メッセージ表示の中のディスクの表示
        let messageDiskSizeConstraint: NSLayoutConstraint = self.messageDiskSizeConstraint
        let messageDiskView: DiskView = self.messageDiskView
        viewModel.messageDiskViewDisk
            .sink { disk in
                if let disk = disk {
                    messageDiskSizeConstraint.constant = messageDiskSize
                    messageDiskView.disk = disk
                } else {
                    messageDiskSizeConstraint.constant = 0
                }
            }
            .store(in: &cancellables)

        // メッセージ表示の中のテキスト
        viewModel.messageLabelText
            .assign(to: \.text, on: messageLabel)
            .store(in: &cancellables)
        
        // プレイヤーモードの選択値
        for (viewModel, view) in zip(viewModel.playerControlSelectedIndices, playerControls) {
            viewModel
                .assign(to: \.selectedSegmentIndex, on: view)
                .store(in: &cancellables)
        }
        
        // ディスクカウント
        for (viewModel, view) in zip(viewModel.countLabelTexts, countLabels) {
            viewModel
                .assign(to: \.text, on: view)
                .store(in: &cancellables)
        }
        
        // ぐるぐる
        for (viewModel, view) in zip(viewModel.playerActivityIndicatorAnimateds, playerActivityIndicators) {
            viewModel
                .sink { isAnimated in
                    if isAnimated {
                        view.startAnimating()
                    } else {
                        view.stopAnimating()
                    }
                }
                .store(in: &cancellables)
        }
        
        // リバーシ盤表示の更新
        viewModel.boardViewUpdate
            .sink { [weak self] request in
                self?.handleBoardViewUpdateRequest(request)
            }
            .store(in: &cancellables)
        
        // リセット確認のアラート表示
        viewModel.showResetConfirmationAlert
            .sink { [weak self] request in
                self?.handleResetConfirmationAlertRequest(request)
            }
            .store(in: &cancellables)

        // 「パス」のアラート表示
        viewModel.showPassAlert
            .sink { [weak self] request in
                self?.handlePassAlertRequest(request)
            }
            .store(in: &cancellables)
        
        // セーブ
        viewModel.save
            .sink { [weak self] request in
                self?.handleSaveRequest(request)
            }
            .store(in: &cancellables)
    }
}

// MARK: Handling Request

extension ViewController {
    
    /// リバーシ盤の表示更新のリクエストをハンドリングします。
    /// - Parameter request: リクエスト
    private func handleBoardViewUpdateRequest(_ request: DetailedRequest<BoardUpdate>) {
        switch request.detail {
        case .withAnimation(let cellChange):
            boardView.setDisk(cellChange.disk, atX: cellChange.x, y: cellChange.y, animated: true) { [weak self] result in
                self?.viewModel.boardViewUpdateCompleted(requestId: request.requestId)
            }
            
        case .withoutAnimation(let cellChanges):
            for change in cellChanges {
                boardView.setDisk(change.disk, atX: change.x, y: change.y, animated: false)
            }
            viewModel.boardViewUpdateCompleted(requestId: request.requestId)
        }
    }
    
    /// リセット確認用アラート表示のリクエストをハンドリングします。
    /// - Parameter request: リクエスト
    private func handleResetConfirmationAlertRequest(_ request: Request) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.viewModel.resetConfirmed(requestId: request.requestId, doReset: false)
        })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.viewModel.resetConfirmed(requestId: request.requestId, doReset: true)
        })
        present(alertController, animated: true)
    }
        
    /// 「パス」用アラート表示リクエストをハンドリングします。
    /// - Parameter request: リクエスト
    private func handlePassAlertRequest(_ request: Request) {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.viewModel.passDismissed(requestId: request.requestId)
        })
        present(alertController, animated: true)
    }
    
    /// セーブリクエストをハンドリングします。
    /// - Parameter request: リクエスト
    private func handleSaveRequest(_ request: DetailedRequest<String>) {
        try? saveGame(data: request.detail)
        viewModel.saveCompleted(requestid: request.requestId)
    }
}

// MARK: Inputs

extension ViewController {
    /// リセットボタンが押された場合に呼ばれるハンドラーです。
    /// アラートを表示して、ゲームを初期化して良いか確認し、
    /// "OK" が選択された場合ゲームを初期化します。
    @IBAction func pressResetButton(_ sender: UIButton) {
        viewModel.pressResetButton()
    }
    
    /// プレイヤーのモードが変更された場合に呼ばれるハンドラーです。
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side = playerControls.firstIndex(of: sender)!
        viewModel.changePlayerControlSegment(side: side, selectedIndex: sender.selectedSegmentIndex)
    }
}

extension ViewController: BoardViewDelegate {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        viewModel.boardViewDidSelectCell(x: x, y: y)
    }
}

// MARK: Save and Load

extension ViewController {
    private var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }

    /// ゲームの状態をファイルに書き出し、保存します。
    func saveGame(data: String) throws {
        do {
            try data.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.write(path: path, cause: error)
        }
    }

    /// ゲームの状態をファイルから読み込み、復元します。
    func loadGame() throws -> String {
        let input: String
        do {
            input = try String(contentsOfFile: path, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
        return input
    }

    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}
