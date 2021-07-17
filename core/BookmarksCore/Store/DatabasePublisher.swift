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

class DatabaseSubscription<Target: Subscriber>: Subscription, DatabaseObserver where Target.Input == Void {

    var id = UUID()

    fileprivate var database: Database
    fileprivate var target: Target?

    init(database: Database) {
        self.database = database
        self.database.add(observer: self)
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        target = nil
        self.database.remove(observer: self)
    }

    func databaseDidUpdate(database: Database) {
        _ = target?.receive()
    }

}

struct DatabasePublisher: Publisher {

    typealias Output = Void
    typealias Failure = Never

    fileprivate var database: Database

    init(database: Database) {
        self.database = database
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = DatabaseSubscription<S>(database: database)
        subscription.target = subscriber
        subscriber.receive(subscription: subscription)
    }
    
}
