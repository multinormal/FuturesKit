//
//  Future.swift
//  FuturesKit
//
//  Created by Chris Rose on 23/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import Foundation

// MARK: - Reference Types for Mutable State: ResultBox and CallbacksBox

private final class ResultBox<T> {
  var result: Result<T>? {
    didSet {
      // Assure that once we have a value, we don't replace it with another one.
      assert(oldValue == nil)
      if oldValue != nil {self.result = oldValue}
    }
  }
}

private final class CallbacksBox<T> {
  var callbacks: [Callback<T>] = []

  func add(_ callback: Callback<T>) {
    objc_sync_enter(self)
    defer {objc_sync_exit(self)}
    self.callbacks.append(callback)
  }
  
  func process(_ result: Result<T>) {
    objc_sync_enter(self)
    defer {objc_sync_exit(self)}
    let resultHandlers = self.callbacks.flatMap {result.resultHandlerFor($0)}
    resultHandlers.forEach {$0()}
    self.callbacks = []
  }
}

// MARK: - Value Type Enumerations: Result, ThreadContext, and Callback

internal enum Result<T> {
  case value(T)
  case error(Error) // Do not call this None, because Optional.None == nil, and type inference can confuse them!
}

internal enum ThreadContext {
  case main         // Must be executed on the main thread.
  case background   // Must be executed on a background thread.
  
  var queue: DispatchQueue {get {
    switch self {
    case .main:       return DispatchQueue.main
    case .background: return DispatchQueue(label: "com.multinormal.ThreadContext.\(UUID().uuidString)", attributes: DispatchQueue.Attributes.concurrent)
    }
    }
  }
  
  func assertCorrectThread() {
    switch self {
    case .main: assert(Thread.isMainThread)
    case .background: assert(!Thread.isMainThread)
    }
  }
}

internal enum Callback<T> {
  case success(context: ThreadContext, f: (T) -> ())
  case failure(f: (Error) -> ())
}

// MARK: - Value Type: Future
// Future is implemented as a struct that wraps reference types containing
// mutable state. Modelling Future as a value type maps onto the functional
// programming design of this framework, and may alleviate clients from
// memory management issues such as reference cycles.

public struct Future<T> {
  fileprivate let resultBox = ResultBox<T>()
  fileprivate let callbacksBox = CallbacksBox<T>()
  
  // MARK: Initializers
  
  // Init for completion by a Promise.
  internal init() {}
  
  // Init using a value.
  fileprivate init(value: T) {
    self.resultBox.result = .value(value)
    let _ = self.onSuccess {_ in}
  }
  
  // Init using a function (that might throw).
  fileprivate init(f: @escaping () throws -> T) {
    ThreadContext.background.queue.async {[mySelf = self] in
      assert(!Thread.isMainThread)
      do {
        let value = try f()
        mySelf.resultBox.result = .value(value)
        let _ = mySelf.onSuccess {_ in}
      }
      catch let error {
        mySelf.resultBox.result = .error(error)
        let _ = mySelf.onError {_ in}
      }
      assert(self.resultBox.result != nil, "Result must have a value before this block returns.")
    }
  }
}

// MARK: Providing a Result to Future

internal extension Future {
  func setResult(_ result: Result<T>) {
    self.resultBox.result = result
    let _ = self.onSuccess {_ in}
  }
}

// MARK: Adding Callbacks

private extension Future {
  func addCallback(_ callback: Callback<T>) -> Future<T> { // Allows chained calls.
    self.callbacksBox.add(callback)
    guard let result = self.resultBox.result else {return self}
    self.callbacksBox.process(result)
    return self
  }
}

// MARK: Adding Success Callbacks on a Background Thread for Implementing Methods and Utilities

internal extension Future {
  func onSuccessOnBackgroundThread(_ f: @escaping (T) -> ()) -> Future<T> { // Allows chained calls.
    return self.addCallback(.success(context: .background, f: f))
  }
}

// MARK: Adding Success and Error Callbacks

public extension Future {
  func onSuccess(_ f: @escaping (T) -> ()) -> Future<T> { // Allows chained calls.
    return self.addCallback(.success(context: .main, f: f))
  }
  
  func onError(_ f: @escaping (Error) -> ()) -> Future<T> { // Allows chained calls.
    return self.addCallback(.failure(f: f))
  }
}

// MARK: Closing a chain of callbacks.

public extension Future {
  func end() {}
}

// MARK: Making Futures

public func future<T>(_ f: @escaping () throws -> T)  -> Future<T> {return Future(f: f)}
public func futureFromValue<T>(_ value: T)            -> Future<T> {return Future(value: value)}

// MARK: - Making a ResultHandler from a Result and a Callback

internal typealias ResultHandler = (() -> ())

internal extension Result {
  func resultHandlerFor(_ callback: Callback<T>) -> ResultHandler? {
    switch (self, callback) {
    case (.value(let value), .success(let context, let f)):
      return {
        context.queue.async {
          context.assertCorrectThread()
          f(value)
        }
      }
    case (.error(let error), .failure(let f)):
      return {
        ThreadContext.main.queue.async {
          assert(Thread.isMainThread)
          f(error)
        }
      }
    default: return nil
    }
  }
}

// MARK: - Functions to Help Unit Testing

internal extension Future {
  var resultForUnitTesting: Result<T>? {return self.resultBox.result}
}

internal extension Future {
  var callbacksForUnitTesting: [Callback<T>] {return self.callbacksBox.callbacks}
}
