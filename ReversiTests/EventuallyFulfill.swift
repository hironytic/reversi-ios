import Foundation
import Combine
import XCTest

/// どこかのタイミングで結果的に指定したチェッカーを満たす状態になったら
/// その時点で指定された `expectation` を `fulfill()` する `Subscriber` です。
class EventuallyFulfill<Input, Failure: Error>: Subscriber, Cancellable {
    typealias Input = Input
    typealias Failure = Failure
    
    private var subscription: Subscription?
    private var expectation: XCTestExpectation?
    private var inputChecker: (Input) -> Bool
    private var errorChecker: (Failure) -> Bool
    private var isFulfilled = false
     
    public init(_ expectation: XCTestExpectation? = nil, inputChecker: @escaping (Input) -> Bool = { _ in false }, errorChecker: @escaping (Failure) -> Bool = { _ in false }) {
        self.expectation = expectation
        self.inputChecker = inputChecker
        self.errorChecker = errorChecker
    }

    public func reset(_ expectation: XCTestExpectation, inputChecker: @escaping (Input) -> Bool = { _ in false }, errorChecker: @escaping (Failure) -> Bool = { _ in false }) {
        self.expectation = expectation
        self.inputChecker = inputChecker
        self.errorChecker = errorChecker
        isFulfilled = false
    }
    
    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(.unlimited)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        if let expectation = expectation, !isFulfilled && inputChecker(input) {
            expectation.fulfill()
            isFulfilled = true
        }
        
        return .unlimited
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .failure(let error):
            if let expectation = expectation, !isFulfilled && errorChecker(error) {
                expectation.fulfill()
                isFulfilled = true
            }
            
        case .finished:
            break
        }
    }

    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}
