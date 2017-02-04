//
//  FutureMethodsTests.swift
//  TestBed
//
//  Created by Chris Rose on 28/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import XCTest

@testable import FuturesKit

func intToString(_ i: Int, context: ThreadContext) -> String {
  switch context {
  case .main:       XCTAssertTrue(Thread.isMainThread)
  case .background: XCTAssertFalse(Thread.isMainThread)
  }
  return "\(i)"
}

class FutureMethodsTests: XCTestCase {

  enum HeadDesk : Error {case ouch}
  
  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}
}

// MARK: - Testing map

extension FutureMethodsTests {
  func testMap() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f1 = future {makeValue()}
    
    let expected = intToString(value, context: .main)
    
    let f2 = {intToString($0, context: .background)} • f1
    let expectation = self.expectation(description: "Should be called.")
    f2.onSuccess {value in
      XCTAssertEqual(value, expected)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testMapWithFunctionThatThrows() {
    enum MapError: Error {case anError}
    func transformValue(_ v: Int) throws -> Int {throw MapError.anError}
    
    let value = 1
    let f1 = futureFromValue(value)
    let f2 = transformValue • f1
    let expectation = self.expectation(description: "The transformed future should fail.")
    f2.onSuccess {_ in
      XCTFail()
    }.onError {error in
      guard let error = error as? MapError else {
        XCTFail()
        return
      }
      XCTAssertEqual(error, MapError.anError)
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testMapPreservesOriginalFuture() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f1 = future {makeValue()}
    let expectation1 = expectation(description: "Callback on future 1 should be called.")
    f1.onSuccess {actualValue in
      XCTAssertEqual(actualValue, value)
      expectation1.fulfill()
    }.end()
    
    let expected = intToString(value, context: .main)
    
    let f2 = {intToString($0, context: .background)} • f1
    let expectation2 = expectation(description: "Callback on future 2 should be called.")
    f2.onSuccess {value in
      XCTAssertEqual(value, expected)
      expectation2.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }

  func testMapWithAFunctionThatReturnsAFuture() {
    // This tests what was flatMap.
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    func makeFutureValue(_ i: Int) -> Future<String> {
      return futureFromValue(intToString(i, context: .background))
    }
    
    let f1 = future {makeValue()}
    let f2 = makeFutureValue • f1
    let expectation = self.expectation(description: "Should be called.")
    let expected = intToString(value, context: .main)
    f2.onSuccess {value in
      XCTAssertEqual(value, expected)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
}

// MARK: - Testing flatMap

extension FutureMethodsTests {
}

// MARK: - Testing zip

extension FutureMethodsTests {
  func testZip() {
    let value1 = 1
    let value2 = "Hello"
    let semaphore1 = DispatchSemaphore(value: 0)
    let semaphore2 = DispatchSemaphore(value: 0)
    
    func makeValue1() -> Int {
      let _ = semaphore1.wait(timeout: DispatchTime.distantFuture)
      return value1
    }
    
    func makeValue2() -> String {
      let _ = semaphore2.wait(timeout: DispatchTime.distantFuture)
      return value2
    }
    
    // Make two futures.
    let f1 = future {makeValue1()}
    let f2 = future {makeValue2()}
    // Combine them.
    let f3 = f1 • f2
    
    // Ensure that the zipped future completes, the success callback is called,
    // and its values are correct.
    let expectation3 = expectation(description: "Should be called")
    f3.onSuccess {(actualValue1, actualValue2) in
      XCTAssertEqual(value1, actualValue1)
      XCTAssertEqual(value2, actualValue2)
      expectation3.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    // Ensure that future 1 completes, the success callback is called,
    // and its values are correct.
    let expectation1 = expectation(description: "Should be called")
    f1.onSuccess {actualValue in
      XCTAssertEqual(value1, actualValue)
      expectation1.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    // Ensure that future 2 completes, the success callback is called,
    // and its values are correct.
    let expectation2 = expectation(description: "Should be called")
    f2.onSuccess {actualValue in
      XCTAssertEqual(value2, actualValue)
      expectation2.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore1.signal() // Let the first future complete.
    semaphore2.signal() // Let the second future complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testZipWithThree() {
    let actual1 = 1
    let actual2 = "Hello"
    let actual3 = [1,2,3]
    let f1 = futureFromValue(actual1)
    let f2 = futureFromValue(actual2)
    let f3 = futureFromValue(actual3)
    let f123 = f1 • f2 • f3
    let expectation = self.expectation(description: "Should be fulfilled.")
    f123.onError {_ in
      XCTFail()
    }.onSuccess {(v1, v2, v3) in
      XCTAssertEqual(actual1, v1)
      XCTAssertEqual(actual2, v2)
      XCTAssertEqual(actual3, v3)
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
}

// MARK: - Testing Filter

extension FutureMethodsTests {
  func testFilterWhenOriginalSucceedsAndPredicateIsFalse() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    let expectation = self.expectation(description: "Should be called.")
    let errorExpectation = self.expectation(description: "Should be Ouch.")
    let f2 = {$0 != value} •? f // False by definition.
    f2.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? FutureErrorType<Int> {
      case .valueDidNotSatisfyPredicate(let actualValue)?:
        XCTAssertEqual(actualValue, value)
        errorExpectation.fulfill()
      default: XCTFail()
      }
      expectation.fulfill()
    }.end()
    
    semaphore.signal() // Let the future complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testFilterWhenOriginalSucceedsAndPredicateIsTrue() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    let expectation = self.expectation(description: "Should be called.")
    let f2 = {$0 == value} •? f // True by definition.
    f2.onSuccess {actualValue in
      XCTAssertEqual(actualValue, value)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Let the future complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  
  func testFilterWhenOriginalFailsAndPredicateIsFalse() {
    let value = 1
    let shouldFail = true
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return value
    }
    
    let f = future {try makeValue()}
    let expectation = self.expectation(description: "Should be called.")
    let errorExpectation = self.expectation(description: "Should be Ouch.")
    let f2 = {$0 != value} •? f // False by definition.
    f2.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: errorExpectation.fulfill()
      default: XCTFail()
      }
      expectation.fulfill()
    }.end()
    
    semaphore.signal() // Let the future complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testFilterWhenOriginalFailsAndPredicateIsTrue() {
    let value = 1
    let shouldFail = true
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return value
    }
    
    let f = future {try makeValue()}
    let expectation = self.expectation(description: "Should be called.")
    let errorExpectation = self.expectation(description: "Should be Ouch.")
    let f2 = {$0 != value} •? f // False by definition.
    f2.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: errorExpectation.fulfill()
      default: XCTFail()
      }
      expectation.fulfill()
    }.end()
    
    semaphore.signal() // Let the future complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testFilterWithAFunctionThatThrows() {
    enum FilterError : Error {case anError}
    func predicate(_ value: Int) throws -> Bool {throw FilterError.anError}
    let value = 1
    let f1 = futureFromValue(value)
    let f2 = predicate •? f1
    let expectation = self.expectation(description: "Should fail.")
    f2.onSuccess {_ in
      XCTFail()
    }.onError {error in
      guard let error = error as? FilterError else {
        XCTFail()
        return
      }
      XCTAssertEqual(error, FilterError.anError)
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
}

// MARK: - Testing combining futures
// NOTE: Was a test of combineWith

extension FutureMethodsTests {
  func testCombiningFutures() {
    let value1 = 1
    let value2 = "2"
    let expectedValue = value1 + Int(value2)!
    let semaphore1 = DispatchSemaphore(value: 0)
    let semaphore2 = DispatchSemaphore(value: 0)
    
    func makeValue1() -> Int {
      let _ = semaphore1.wait(timeout: DispatchTime.distantFuture)
      return value1
    }
    
    func makeValue2() -> String {
      let _ = semaphore2.wait(timeout: DispatchTime.distantFuture)
      return value2
    }
    
    func combiner(_ i: Int, s: String) -> Int {
      guard let asInt = Int(s) else {
        XCTFail()
        return -1
      }
      return i + asInt
    }
    
    let f1 = future {makeValue1()}
    let f2 = future {makeValue2()}
    let f3 = combiner • f1 • f2 // This used to be the call to combineWith.
    let expectation = self.expectation(description: "Should be called.")
    f3.onSuccess {actualValue in
      XCTAssertEqual(actualValue, expectedValue)
      expectation.fulfill()
    }.end()
    
    semaphore1.signal() // Let the future complete.
    semaphore2.signal() // Let the future complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
}

// MARK: - Demonstrate a race condition

extension FutureMethodsTests {
  // NOTE: This is not a test of desired behaviour, but demonstrates a race condition under a particular misuse of filter.
  func testDemonstrateRaceConditionInUsingFilterAsAnAlternativeToInvalidationTokens() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    class Invalidator {
      var valid = true
    }
    
    let invalidator = Invalidator()
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let originalFuture = future {makeValue()}
    let expectation = self.expectation(description: "Should be called.")
    originalFuture.onSuccess {actualValue in
      XCTAssertEqual(actualValue, value)
      invalidator.valid = false // Becomes invalid.
      expectation.fulfill()
    }.onError {_ in
      XCTFail() // The original future should not fail.
    }.end()
    
    semaphore.signal() // Let the future complete.
    func isValid(_: Int) -> Bool {
      let valid = invalidator.valid
      XCTAssertTrue(valid)
      return valid
    }
    let invalidatableFuture = isValid • originalFuture
    let expectation2 = self.expectation(description: "In the race condition we should incorrectly fulfill this expectation.")
    invalidatableFuture.onSuccess {_ in
      expectation2.fulfill()
      XCTAssertFalse(invalidator.valid)
      // Using the future's value here would represent an error since the condition is not valid.
      // This occurs due to the race condition.
    }.onError {_ in
      XCTFail()
    }.end()
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
}


