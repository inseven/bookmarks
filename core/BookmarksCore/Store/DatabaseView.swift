// Copyright (c) 2020-2021 InSeven Limited
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Combine
import Foundation


class EventSubscription<Target: Subscriber>: Subscription, DatabaseObserver
where Target.Input == Void {

    func databaseDidUpdate(database: Database) {
        _ = target?.receive()
    }


    var target: Target?

    // This subscription doesn't respond to demand, since it'll
    // simply emit events according to its underlying UIControl
    // instance, but we still have to implement this method
    // in order to conform to the Subscription protocol:
    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        // When our subscription was cancelled, we'll release
        // the reference to our target to prevent any
        // additional events from being sent to it:
        target = nil
    }

}


struct EventPublisher: Publisher {
    // Declaring that our publisher doesn't emit any values,
    // and that it can never fail:
    typealias Output = Void
    typealias Failure = Never

    fileprivate var database: Database

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = EventSubscription<S>()
        subscription.target = subscriber
        subscriber.receive(subscription: subscription)
        database.add(observer: subscription)
    }
}


public class DatabaseView: ObservableObject {

    var database: Database
    var publisher: EventPublisher
    var cancellable: AnyCancellable?

    // TODO: We should be debouncing the search field too.
    public var filter: String = "" {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            print(filter)
            self.update()
        }
    }

    public init(database: Database) {
        self.database = database
        self.publisher = EventPublisher(database: database)
        self.cancellable = self.publisher.debounce(for: .seconds(1), scheduler: DispatchQueue.main).sink { _ in
            self.update()
        }
        self.update()
    }

    func update() {
        database.items(filter: self.filter) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.items = items
                    self.objectWillChange.send()
                case .failure(let error):
                    print("Failed to load data with error \(error)")
                }
            }
        }
    }

    public var items: [Item] = []

}

