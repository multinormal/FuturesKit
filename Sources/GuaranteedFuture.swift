//
//  Guarantee.swift
//  FuturesKit
//
//  Created by Chris Rose on 24/05/2016.
//  Copyright © 2016 Chris Rose. All rights reserved.
//

import Foundation

/// GuaranteedFuture models a future that has a fallback value and cannot fail.
public struct GuaranteedFuture<T> {
  fileprivate let f: Future<T>
  fileprivate let fallbackValue: T
  
  /// Create a GuaranteedFuture, providing a fallback value.
  public init(f: Future<T>, withFallbackValue fallback: T) {
    let promise = Promise<T>()
    let _ = f.onSuccess {value in promise.keptWithValue(value)}
    let _ = f.onError {_ in promise.keptWithValue(fallback)}
    let _ = promise.future.onError {_ in assertionFailure()}
    self.f = promise.future
    self.fallbackValue = fallback
  }
  
  /// Add a callback to use the value when it is ready.
  public func onSuccess(_ f: @escaping (T) -> Void) {
    let _ = self.f.onSuccess(f)
  }
}

// MARK: - Mapping function over a GuaranteedFuture

/// Applying a function to the value of a GuaranteedFuture gives a GuaranteedFuture.
public func • <T,U>(f: @escaping (T) -> U, t: GuaranteedFuture<T>) -> GuaranteedFuture<U> {
  return GuaranteedFuture(f: f • t.f, withFallbackValue: f(t.fallbackValue))
}

/// Applying a function that can throw to GuaranteedFuture gives a Future.
public func • <T,U>(f: @escaping (T) throws -> U, t: GuaranteedFuture<T>) -> Future<U> {
  return f • t.f
}

/// Applying a function that returns a Future to a GuaranteedFuture gives a Future
/// since the Future can fail (or the function can throw).
public func • <T,U>(f: @escaping (T) throws -> Future<U>, t: GuaranteedFuture<T>) -> Future<U> {
  return f • t.f
}

// MARK: - Mapping a function that produces a GuaranteedFuture, over a SequenceType

/// Mapping a function that returns a GuaranteedFuture over a SequenceType gives
/// a GuaranteedFuture.
public func • <S:Sequence, T>(f: (S.Iterator.Element) -> GuaranteedFuture<T>, s: S) -> GuaranteedFuture<[T]> {
  let allGuaranteedFutures = s.map(f)
  let initialGuaranteedFuture: GuaranteedFuture<[T]> = GuaranteedFuture(f: futureFromValue([]), withFallbackValue: [])
  return allGuaranteedFutures.reduce(initialGuaranteedFuture) {prev, next in
    return {$0 + [$1]} • prev • next
  }
}

/// Mapping a function that can throw over a SequenceType gives a Future.
public func • <S:Sequence, T>(f: @escaping (S.Iterator.Element) throws -> GuaranteedFuture<T>, s: S) -> Future<[T]> {
  // A Function that converts the throwing function to a function that returns a Future.
  func toFuture(_ f: @escaping (S.Iterator.Element) throws -> GuaranteedFuture<T>) -> ((S.Iterator.Element) -> Future<T>) {
    return {(element: S.Iterator.Element) -> Future<T> in
      let promise = Promise<T>()
      let ft = future {try f(element)}
      let _ = ft.onSuccess {value in value.onSuccess {promise.keptWithValue($0)}}
      let _ = ft.onError {error in promise.brokenWithError(error)}
      return promise.future
    }
  }
  
  return toFuture(f) • s
}

// MARK: - Combining GuaranteedFutures into a GuaranteedFuture of a tuple

public func • <T,U>(t: GuaranteedFuture<T>, u: GuaranteedFuture<U>) -> GuaranteedFuture<(T, U)> {
  return GuaranteedFuture(f: t.f • u.f, withFallbackValue: (t.fallbackValue, u.fallbackValue))
}

public func • <S,T,U>(s: GuaranteedFuture<S>, tu: GuaranteedFuture<(T, U)>) -> GuaranteedFuture<(S,T,U)> {
  let fallback = (s.fallbackValue, tu.fallbackValue.0, tu.fallbackValue.1)
  return GuaranteedFuture(f: s.f • tu.f, withFallbackValue: fallback)
}

public func • <S,T,U,V>(s: GuaranteedFuture<S>, tu: GuaranteedFuture<(T, U, V)>) -> GuaranteedFuture<(S,T,U,V)> {
  let fallback = (s.fallbackValue, tu.fallbackValue.0, tu.fallbackValue.1, tu.fallbackValue.2)
  let flatten: (S, (T,U,V)) -> (S,T,U,V) = {($0.0, $0.1.0, $0.1.1, $0.1.2)}
  return GuaranteedFuture(f: flatten • s.f • tu.f, withFallbackValue: fallback)
}

// MARK: - Combining GuaranteedFutures and Futures into a tuple

public func • <T,U>(t: Future<T>, u: GuaranteedFuture<U>) -> Future<(T, U)> {return t • u.f}
public func • <T,U>(t: GuaranteedFuture<T>, u: Future<U>) -> Future<(T, U)> {return t.f • u}



