//
//  Promise.swift
//  FuturesKit
//
//  Created by Chris Rose on 23/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import Foundation

// MARK: - Value Type: Promise

public struct Promise<T> {
  public let future = Future<T>()
  public init() {}
}

// MARK: Keeping and Breaking Promise

extension Promise {
  public func keptWithValue(_ value: T) {self.future.setResult(.value(value))}
  public func brokenWithError(_ error: Error) {self.future.setResult(.error(error))}
}

// MARK: - Functions to help unit testing

internal func keptOrBrokenForPromise<T>(_ promise: Promise<T>) -> Bool {
  return promise.future.resultForUnitTesting != nil
}
