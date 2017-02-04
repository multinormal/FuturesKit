//
//  Utilities.swift
//  FuturesKit
//
//  Created by Chris Rose on 23/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import Foundation

// MARK: - Utility Functions

public func flatten<T>(_ future: Future<Future<T>>) -> Future<T> {
  let promise = Promise<T>()
  let _ = future.onSuccessOnBackgroundThread {futureValue in
    let _ = futureValue.onSuccessOnBackgroundThread {value in
      promise.keptWithValue(value)
    }.onError {error in
      promise.brokenWithError(error)
    }
  }.onError {error in
    promise.brokenWithError(error)
  }
  return promise.future
}

public func lift<S, T, U>(_ f: @escaping (S, T) throws -> U) -> (Future<S>, Future<T>) -> Future<U> {
  func lifted(_ s: Future<S>, t: Future<T>) -> Future<U> {return f • s • t}
  return lifted
}

public enum AwaitError : Error {
  case awaitCalledOnMainThread
  case noResult
}

public func await<T>(_ future: Future<T>) throws -> T {
  let semaphore = DispatchSemaphore(value: 0)
  var result: Result<T>? = nil
  let _ = future.onSuccessOnBackgroundThread {value in
    result = Result.value(value)
    semaphore.signal()
  }
  let _ = future.onError {error in
    result = Result.error(error)
    semaphore.signal()
  }
  let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
  guard let theResult = result else {
    throw AwaitError.noResult
  }
  switch theResult {
  case .value(let value): return value
  case .error(let error): throw error
  }
}
