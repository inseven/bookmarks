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

import Foundation

// TODO: Replace AsyncOperation with async await when adopting Swift 5.5 #130
//       https://github.com/inseven/bookmarks/issues/130
public class AsyncOperation<T> {

    var semaphore = DispatchSemaphore(value: 0)
    var result: Result<T, Error> = .failure(DatabaseError.unknown)

    init(_ operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) {
        operation { result in
            self.result = result
            self.semaphore.signal()
        }
    }

    func wait() throws -> T {
        semaphore.wait()  // TODO: Timeout
        switch self.result {
        case .failure(let error):
            throw error
        case .success(let value):
            return value
        }
    }

}
