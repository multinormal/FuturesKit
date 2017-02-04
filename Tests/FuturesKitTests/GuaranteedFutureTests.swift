//
//  GuaranteedFutureTests.swift
//  FuturesKit
//
//  Created by Chris Rose on 25/05/2016.
//  Copyright © 2016 Chris Rose. All rights reserved.
//

import XCTest
@testable import FuturesKit

private func failingFunction(_ expectation: XCTestExpectation) throws -> Int {
  expectation.fulfill()
  throw HeadDesk.ouch
}

private func nonfailingFunction(_ expectation: XCTestExpectation, valueToSucceedWith value: Int) -> Int {
  expectation.fulfill()
  return value
}

class GuaranteedFutureTests: XCTestCase {
  
  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}
  
  func testGuaranteedFutureCompletesWithSuccessfulFutureValue() {
    let expectation = self.expectation(description: "Should be fulfilled.")
    let expectedValue = 1
    let f = future {nonfailingFunction(expectation, valueToSucceedWith: expectedValue)}
    let unexpectedValue = 100
    let g = GuaranteedFuture(f: f, withFallbackValue: unexpectedValue)
    g.onSuccess {value in
      XCTAssertEqual(value, expectedValue)
      XCTAssertNotEqual(value, unexpectedValue)
    }
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  func testGuaranteedFutureCompletedWithFallbackValue() {
    let expectation = self.expectation(description: "Should be fulfilled.")
    let f = future {try failingFunction(expectation)}
    let expectedValue = 1
    let g = GuaranteedFuture(f: f, withFallbackValue: expectedValue)
    g.onSuccess {value in XCTAssertEqual(value, expectedValue)}
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }


// MARK: - Mapping function over a GuaranteedFuture
  
  func mapper(_ x: Int) -> String {return "\(x)"}
  
  /// Tests: func • <T,U>(f: T -> U, t: GuaranteedFuture<T>) -> GuaranteedFuture<U>
  func testMapNonThrowingFunctionOverGuaranteedFuture() {
    // Ensure we use the operator we intend to.
    func map<T,U>(_ f: @escaping (T) -> U, t: GuaranteedFuture<T>) -> GuaranteedFuture<U> {return f • t}
    
    let expectation = self.expectation(description: "Should be fulfilled.")
    let f = future {try failingFunction(expectation)}
    let expectedValue = 1
    let g = GuaranteedFuture(f: f, withFallbackValue: expectedValue)
    let h = map(self.mapper, t: g)
    h.onSuccess {value in XCTAssertEqual(value, self.mapper(expectedValue))}
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  /// Tests: func • <T,U>(f: T throws -> U, t: GuaranteedFuture<T>) -> Future<U>
  func testMapThrowingFunctionOverGuaranteedFuture() {
    // Ensure we use the operator we intend to.
    func map<T,U>(_ f: @escaping (T) throws -> U, t: GuaranteedFuture<T>) -> Future<U> {return f • t}
    
    let expectation = self.expectation(description: "Should be fulfilled.")
    let f = future {try failingFunction(expectation)}
    let expectedValue = 1
    let g = GuaranteedFuture(f: f, withFallbackValue: expectedValue)
    let h = map(self.mapper, t: g)
    h.onSuccess {value in
      XCTAssertEqual(value, self.mapper(expectedValue))
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  func mapperToFuture(_ x: Int) -> Future<String> {return futureFromValue(self.mapper(x))}
  
  /// Tests: func • <T,U>(f: T throws -> Future<U>, t: GuaranteedFuture<T>) -> Future<U>
  func testMapThrowingFunctionThatReturnsAFutureOverGuaranteedFuture() {
    // Ensure we use the operator we intend to.
    func map<T,U>(_ f: @escaping (T) throws -> Future<U>, t: GuaranteedFuture<T>) -> Future<U> {return f • t}
    
    let expectation = self.expectation(description: "Should be fulfilled.")
    let f = future {try failingFunction(expectation)}
    let expectedValue = 1
    let g = GuaranteedFuture(f: f, withFallbackValue: expectedValue)
    let h = map(self.mapperToFuture, t: g)
    h.onSuccess {value in
      XCTAssertEqual(value, self.mapper(expectedValue))
    }.onError {_ in
      XCTFail()
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }

// MARK: - Mapping a function that produces a GuaranteedFuture, over a SequenceType
  
  func mapperToGuaranteedFuture(_ x: Int) -> GuaranteedFuture<String> {
    return GuaranteedFuture(f: self.mapperToFuture(x), withFallbackValue: "WRONG!")
  }
  
  func mapperToGuaranteedFutureThatCanThrow(_ x: Int) throws -> GuaranteedFuture<String> {
    return GuaranteedFuture(f: self.mapperToFuture(x), withFallbackValue: "WRONG!")
  }
  
  func mapperToGuaranteedFutureThatDoesThrow(_ x: Int) throws -> GuaranteedFuture<String> {
    throw HeadDesk.ouch
  }
  
  /// Tests: func • <S:SequenceType, T>(f: S.Generator.Element -> GuaranteedFuture<T>, s: S) -> GuaranteedFuture<[T]>
  func testMappingFunctionThatReturnsAGuaranteedFutureOverSequenceType() {
    // Ensure we use the operator we intend to.
    func map<S:Sequence, T>(_ f: (S.Iterator.Element) -> GuaranteedFuture<T>, s: S) -> GuaranteedFuture<[T]> {
      return f • s
    }
    
    let expectation = self.expectation(description: "Should be fulfilled.")
    let s = [1,2,3,4,5]
    let expectedValue = s.map(self.mapper)
    let h = map(self.mapperToGuaranteedFuture, s: s)
    h.onSuccess {value in
      XCTAssertEqual(value, expectedValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  /// Tests: func • <S:SequenceType, T>(f: S.Generator.Element throws -> GuaranteedFuture<T>, s: S) -> Future<[T]>
  func testMappingFunctionThatCanThrowThatReturnsAGuaranteedFutureOverSequenceType() {
    // Ensure we use the operator we intend to.
    func map<S:Sequence, T>(_ f: @escaping (S.Iterator.Element) throws -> GuaranteedFuture<T>, s: S) -> Future<[T]> {
      return f • s
    }
    
    let expectation = self.expectation(description: "Should be fulfilled.")
    let s = [1,2,3,4,5]
    let expectedValue = s.map(self.mapper)
    let h = map(self.mapperToGuaranteedFutureThatCanThrow, s: s)
    h.onSuccess {value in
      XCTAssertEqual(value, expectedValue)
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  /// Tests: func • <S:SequenceType, T>(f: S.Generator.Element throws -> GuaranteedFuture<T>, s: S) -> Future<[T]>
  func testMappingFunctionThatCanAndDoesThrowThatReturnsAGuaranteedFutureOverSequenceType() {
    // Ensure we use the operator we intend to.
    func map<S:Sequence, T>(_ f: @escaping (S.Iterator.Element) throws -> GuaranteedFuture<T>, s: S) -> Future<[T]> {
      return f • s
    }
    
    let expectation = self.expectation(description: "Should be fulfilled.")
    let s = [1,2,3,4,5]
    let h = map(self.mapperToGuaranteedFutureThatDoesThrow, s: s)
    h.onSuccess {_ in
      XCTFail()
    }.onError {_ in
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }


// MARK: - Combining GuaranteedFutures into a GuaranteedFuture of a tuple
  
  /// Tests: func • <T,U>(t: GuaranteedFuture<T>, u: GuaranteedFuture<U>) -> GuaranteedFuture<(T, U)>
  func testMakeTwoTupleFromGuaranteedFutures() {
    let expectedValue1 = 1
    let expectedValue2 = 2
    XCTAssertNotEqual(expectedValue1, expectedValue2)
    let expectation1 = expectation(description: "Should be fulfilled.")
    let expectation2 = expectation(description: "Should be fulfilled.")
    let f1 = future {nonfailingFunction(expectation1, valueToSucceedWith: expectedValue1)}
    let f2 = future {nonfailingFunction(expectation2, valueToSucceedWith: expectedValue2)}
    let unexpectedValue1 = 100
    let unexpectedValue2 = 200
    let g1 = GuaranteedFuture(f: f1, withFallbackValue: unexpectedValue1)
    let g2 = GuaranteedFuture(f: f2, withFallbackValue: unexpectedValue2)
    let tuple = g1 • g2
    tuple.onSuccess {
      XCTAssertEqual($0.0, expectedValue1)
      XCTAssertEqual($0.1, expectedValue2)
    }
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  /// Tests: func • <S,T,U>(s: GuaranteedFuture<S>, tu: GuaranteedFuture<(T, U)>) -> GuaranteedFuture<(S,T,U)>
  func testMakeThreeTupleFromGuaranteedFutures() {
    let expectedValue1 = 1
    let expectedValue2 = 2
    let expectedValue3 = 3
    XCTAssertNotEqual(expectedValue1, expectedValue2)
    XCTAssertNotEqual(expectedValue2, expectedValue3)
    XCTAssertNotEqual(expectedValue1, expectedValue3)
    let expectation1 = expectation(description: "Should be fulfilled.")
    let expectation2 = expectation(description: "Should be fulfilled.")
    let expectation3 = expectation(description: "Should be fulfilled.")
    let f1 = future {nonfailingFunction(expectation1, valueToSucceedWith: expectedValue1)}
    let f2 = future {nonfailingFunction(expectation2, valueToSucceedWith: expectedValue2)}
    let f3 = future {nonfailingFunction(expectation3, valueToSucceedWith: expectedValue3)}
    let unexpectedValue1 = 100
    let unexpectedValue2 = 200
    let unexpectedValue3 = 300
    let g1 = GuaranteedFuture(f: f1, withFallbackValue: unexpectedValue1)
    let g2 = GuaranteedFuture(f: f2, withFallbackValue: unexpectedValue2)
    let g3 = GuaranteedFuture(f: f3, withFallbackValue: unexpectedValue3)
    let tuple = g1 • g2 • g3
    tuple.onSuccess {
      XCTAssertEqual($0.0, expectedValue1)
      XCTAssertEqual($0.1, expectedValue2)
      XCTAssertEqual($0.2, expectedValue3)
    }
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  /// Tests: func • <S,T,U,V>(s: GuaranteedFuture<S>, tu: GuaranteedFuture<(T, U, V)>) -> GuaranteedFuture<(S,T,U,V)>
  func testMakeFourTupleFromGuaranteedFutures() {
    let expectedValue1 = 1
    let expectedValue2 = 2
    let expectedValue3 = 3
    let expectedValue4 = 4
    XCTAssertNotEqual(expectedValue1, expectedValue2)
    XCTAssertNotEqual(expectedValue2, expectedValue3)
    XCTAssertNotEqual(expectedValue1, expectedValue3)
    XCTAssertNotEqual(expectedValue1, expectedValue4)
    let expectation1 = expectation(description: "Should be fulfilled.")
    let expectation2 = expectation(description: "Should be fulfilled.")
    let expectation3 = expectation(description: "Should be fulfilled.")
    let expectation4 = expectation(description: "Should be fulfilled.")
    let f1 = future {nonfailingFunction(expectation1, valueToSucceedWith: expectedValue1)}
    let f2 = future {nonfailingFunction(expectation2, valueToSucceedWith: expectedValue2)}
    let f3 = future {nonfailingFunction(expectation3, valueToSucceedWith: expectedValue3)}
    let f4 = future {nonfailingFunction(expectation4, valueToSucceedWith: expectedValue4)}
    let unexpectedValue1 = 100
    let unexpectedValue2 = 200
    let unexpectedValue3 = 300
    let unexpectedValue4 = 400
    let g1 = GuaranteedFuture(f: f1, withFallbackValue: unexpectedValue1)
    let g2 = GuaranteedFuture(f: f2, withFallbackValue: unexpectedValue2)
    let g3 = GuaranteedFuture(f: f3, withFallbackValue: unexpectedValue3)
    let g4 = GuaranteedFuture(f: f4, withFallbackValue: unexpectedValue4)
    let tuple = g1 • g2 • g3 • g4
    tuple.onSuccess {
      XCTAssertEqual($0.0, expectedValue1)
      XCTAssertEqual($0.1, expectedValue2)
      XCTAssertEqual($0.2, expectedValue3)
      XCTAssertEqual($0.3, expectedValue4)
    }
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
// MARK: - Combining GuaranteedFutures and Futures into a tuple
  
  /// Tests: func • <T,U>(t: Future<T>, u: GuaranteedFuture<U>) -> Future<(T, U)>
  func testMakeTupleOfFutureAndGuaranteedFuture() {
    let expectedValue1 = 1
    let expectedValue2 = 2
    XCTAssertNotEqual(expectedValue1, expectedValue2)
    let expectation1 = expectation(description: "Should be fulfilled.")
    let expectation2 = expectation(description: "Should be fulfilled.")
    let f1 = future {nonfailingFunction(expectation1, valueToSucceedWith: expectedValue1)}
    let f2 = future {nonfailingFunction(expectation2, valueToSucceedWith: expectedValue2)}
    let unexpectedValue1 = 100
    let g1 = GuaranteedFuture(f: f1, withFallbackValue: unexpectedValue1)
    let tuple = g1 • f2
    tuple.onSuccess {
      XCTAssertEqual($0.0, expectedValue1)
      XCTAssertEqual($0.1, expectedValue2)
    }.onError {_ in
      XCTFail()
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  /// Tests: func • <T,U>(t: GuaranteedFuture<T>, u: Future<U>) -> Future<(T, U)>
  func testMakeTupleOfGuaranteedFutureAndFuture() {
    let expectedValue1 = 1
    let expectedValue2 = 2
    XCTAssertNotEqual(expectedValue1, expectedValue2)
    let expectation1 = expectation(description: "Should be fulfilled.")
    let expectation2 = expectation(description: "Should be fulfilled.")
    let f1 = future {nonfailingFunction(expectation1, valueToSucceedWith: expectedValue1)}
    let f2 = future {nonfailingFunction(expectation2, valueToSucceedWith: expectedValue2)}
    let unexpectedValue1 = 100
    let g1 = GuaranteedFuture(f: f1, withFallbackValue: unexpectedValue1)
    let tuple = f2 • g1
    tuple.onSuccess {
      XCTAssertEqual($0.0, expectedValue2)
      XCTAssertEqual($0.1, expectedValue1)
    }.onError {_ in
      XCTFail()
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
}
