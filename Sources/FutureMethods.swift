//
//  FutureMethods.swift
//  FuturesKit
//
//  Created by Chris Rose on 23/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import Foundation

// MARK: - Error cases for Future

public enum FutureErrorType<T>: Error {
  case valueDidNotSatisfyPredicate(valueWas: T)
}

// MARK: - Precendence Group

precedencegroup FutureCompositionPrecedence {
  associativity: right
  higherThan: BitwiseShiftPrecedence
}

// MARK: - Operators

infix operator •: FutureCompositionPrecedence
infix operator •?: FutureCompositionPrecedence

// MARK: Mapping function over a Future

public func • <T,U>(f: @escaping (T) throws -> U, t: Future<T>) -> Future<U> {
  return t.map(f)
}

public func • <T,U>(f: @escaping (T) throws -> Future<U>, t: Future<T>) -> Future<U> {
  return t.map(f)
}

// MARK: Mapping a function that produces a Future, over a SequenceType

public func • <S:Sequence, T>(f: (S.Iterator.Element) throws -> Future<T>, s: S) -> Future<[T]> {
  return traverse(s, f: f)
}

// MARK: Combining Futures into a Future of a tuple

public func • <T,U>(t: Future<T>, u: Future<U>) -> Future<(T, U)> {return t.zip(u)}
public func • <S,T,U>(s: Future<S>, tu: Future<(T, U)>) -> Future<(S,T,U)> {
  let flatten: (S,(T, U)) -> (S,T,U) = {($0.0, $0.1.0, $0.1.1)}
  let stu = s.zip(tu)
  return flatten • stu
}

// MARK: Filtering a future using a predicate

public func •? <T>(p: @escaping (T) throws -> Bool, t: Future<T>) -> Future<T> {
  return t.filter(p)
}

// MARK: - Helper functions

private func traverse<S:Sequence, T>(_ s: S, f: (S.Iterator.Element) throws -> Future<T>) -> Future<[T]> {
  do {
    let allFutures = try s.map {try f($0)}
    let initialFuture: Future<[T]> = futureFromValue([])
    return allFutures.reduce(initialFuture) {prev, next in
      return {$0 + [$1]} • prev • next
    }
  } catch let error {
    let promise = Promise<[T]>()
    promise.brokenWithError(error)
    return promise.future
  }
}

extension Future {
  public static func identityTransform(_ t: Future<T>) -> Future<T> {
    return t
  } // Helps the type checker when performing [Future<T>] -> Future<[T]> using the • traverse operator.
}


// MARK: - Private methods on Futures

extension Future {
    
  fileprivate func map<U>(_ f: @escaping (T) throws -> U) -> Future<U> {
    let promise = Promise<U>()
    let _ = self.onSuccessOnBackgroundThread {value in
      do {
        let u = try f(value)
        promise.keptWithValue(u)
      } catch let error {
        promise.brokenWithError(error)
      }
    }.onError{error in
      promise.brokenWithError(error)
    }
    return promise.future
  }
  
  fileprivate func map<U>(_ f: @escaping (T) throws -> Future<U>) -> Future<U> {
    return flatten(self.map(f))
  }
  
  fileprivate func zip<U>(_ f2: Future<U>) -> Future<(T, U)> {
    let promise = Promise<(T, U)>()
    let _ = self.onSuccessOnBackgroundThread {value1 in
      let _ = f2.onSuccessOnBackgroundThread {value2 in
        promise.keptWithValue((value1, value2))
      }.onError {error in
        promise.brokenWithError(error)
      }
    }.onError {error in
      promise.brokenWithError(error)
    }
    return promise.future
  }
  
  fileprivate func filter(_ p: @escaping (T) throws -> Bool) -> Future<T> {
    let promise = Promise<T>()
    let _ = self.onSuccessOnBackgroundThread {value in
      do {
        if try p(value) {
          promise.keptWithValue(value)
        } else {
          promise.brokenWithError(FutureErrorType.valueDidNotSatisfyPredicate(valueWas: value))
        }
      } catch let error {
        promise.brokenWithError(error)
      }
    }.onError {error in
      promise.brokenWithError(error)
    }
    return promise.future
  }
  
}





