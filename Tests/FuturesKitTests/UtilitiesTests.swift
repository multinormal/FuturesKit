//
//  UtilitiesTests.swift
//  TestBed
//
//  Created by Chris Rose on 28/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import XCTest

@testable import FuturesKit

class UtilitiesTests: XCTestCase {

  enum HeadDesk: Error {case ouch}
  
  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}
}

// MARK: - Testing Flatten

extension UtilitiesTests {
  func testFlattenWhereBothFuturesComplete() {
    let value = 1
    let semaphore1 = DispatchSemaphore(value: 0)
    let semaphore2 = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore1.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    func makeFuture() throws -> Future<Int> {
      let _ = semaphore2.wait(timeout: DispatchTime.distantFuture)
      return future {try makeValue()}
    }
    
    let f = future {try makeFuture()}
    let flattenedFuture = flatten(f)
    let expectation = self.expectation(description: "Should be called.")
    flattenedFuture.onSuccess {actualValue in
      XCTAssertEqual(actualValue, value)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore1.signal() // Let the first future complete.
    semaphore2.signal() // Let the second future complete.
    
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testFlattenWhereInnerFutureFails() {
    let value = 1
    let shouldFail = true
    let semaphore1 = DispatchSemaphore(value: 0)
    let semaphore2 = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore1.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return value
    }
    
    func makeFuture() throws -> Future<Int> {
      let _ = semaphore2.wait(timeout: DispatchTime.distantFuture)
      return future {try makeValue()}
    }
    
    let f = future {try makeFuture()}
    let flattenedFuture = flatten(f)
    let expectation = self.expectation(description: "Should be called.")
    flattenedFuture.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.end()
    
    semaphore1.signal() // Let the first future complete.
    semaphore2.signal() // Let the second future complete.
    
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testFlattenWhereOuterFutureFails() {
    let value = 1
    let shouldFail = true
    let semaphore1 = DispatchSemaphore(value: 0)
    let semaphore2 = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      XCTFail() // Should never get called because the outer future should fail.
      let _ = semaphore1.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    func makeFuture() throws -> Future<Int> {
      let _ = semaphore2.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return future {try makeValue()}
    }
    
    let f = future {try makeFuture()}
    let flattenedFuture = flatten(f)
    let expectation = self.expectation(description: "Should be called.")
    flattenedFuture.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.end()
    
    semaphore1.signal() // Let the first future complete.
    semaphore2.signal() // Let the second future complete.
    
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testFlattenWhereBothFuturesFail() {
    let value = 1
    let shouldFail = true
    let semaphore1 = DispatchSemaphore(value: 0)
    let semaphore2 = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore1.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return value
    }
    
    func makeFuture() throws -> Future<Int> {
      let _ = semaphore2.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return future {try makeValue()}
    }
    
    let f = future {try makeFuture()}
    let flattenedFuture = flatten(f)
    let expectation = self.expectation(description: "Should be called.")
    flattenedFuture.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.end()
    
    semaphore1.signal() // Let the first future complete.
    semaphore2.signal() // Let the second future complete.
    
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
}

// MARK: - Testing Reduce
// NOTE: We no longer implement our own reduce, rather we use the built-in
// reduce and use the lift function to convert the reducer to operate on
// Futures rather than the raw types.

extension UtilitiesTests {
  func testReduceWhenAllFuturesComplete() {
    let indices = 0...10
    let semaphores = indices.map {_ in DispatchSemaphore(value: 0)}
    
    func makeValue(_ i: Int) throws -> Int {
      let semaphore = semaphores[i]
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return i
    }
    
    func makeFuture(_ i: Int) -> Future<Int> {
      return future {try makeValue(i)}
    }
    
    func combiner(_ accumulated: String, next: Int) -> String {
      return "\(accumulated)\(next)"
    }
    
    let futures = indices.map {i in makeFuture(i)}
    let reducedFuture = futures.reduce(futureFromValue(""), lift(combiner))
    let expectation = self.expectation(description: "Should be called.")
    reducedFuture.onSuccess {actualValue in
      let expectedValue = indices.reduce("", combiner)
      XCTAssertEqual(actualValue, expectedValue)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    // Let the futures complete.
    for semaphore in semaphores {semaphore.signal()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testReduceWhenAllOneFutureFails() {
    let indices = 0...10
    let semaphores = indices.map {_ in DispatchSemaphore(value: 0)}
    
    func makeValue(_ i: Int) throws -> Int {
      let semaphore = semaphores[i]
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if i == 3 {throw HeadDesk.ouch}
      return i
    }
    
    func makeFuture(_ i: Int) -> Future<Int> {
      return future {try makeValue(i)}
    }
    
    func combiner(_ accumulated: String, next: Int) -> String {
      return "\(accumulated)\(next)"
    }
    
    let futures = indices.map {i in makeFuture(i)}
    let reducedFuture = futures.reduce(futureFromValue(""), lift(combiner))
    let expectation = self.expectation(description: "Should be called.")
    reducedFuture.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.end()
    
    // Let the futures complete.
    for semaphore in semaphores {semaphore.signal()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testReduceWhenFunctionThrows() {
    enum ReduceError : Error {case reduceError}
    func reducer(_ prev: Int, next: Int) throws -> Int {throw ReduceError.reduceError}
    let values = [1,2,3,4,5].map {futureFromValue($0)}
    let f = values.reduce(futureFromValue(0), lift(reducer))
    let expectation = self.expectation(description: "Should fail.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      guard let error = error as? ReduceError else {
        XCTFail()
        return
      }
      XCTAssertEqual(error, ReduceError.reduceError)
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
}


// MARK: - Testing sequencing a list of Futures
// These test that we can use the traverse function and Future.identityTransform
// to convert [Future<T>] to Future<[T]>. The traverse and sequence functions
// were originally separate, but sequence can be written in terms of traverse and
// and Future.identityTransform.

extension UtilitiesTests {
  func testSequenceWhenAllFuturesSucceed() {
    let indices = 0...10
    let semaphores = indices.map {_ in DispatchSemaphore(value: 0)}
    
    func makeValue(_ i: Int) throws -> Int {
      let semaphore = semaphores[i]
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return i
    }
    
    func makeFuture(_ i: Int) -> Future<Int> {
      return future {try makeValue(i)}
    }
    
    let futures = indices.map {i in makeFuture(i)}
    let sequencedFuture = Future.identityTransform • futures
    let expectation = self.expectation(description: "Should be called.")
    sequencedFuture.onSuccess {actualValue in
      let expectedValue = Array(indices)
      XCTAssertEqual(actualValue, expectedValue)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    // Let the futures complete.
    for semaphore in semaphores {semaphore.signal()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testSequenceWhenOneFutureFails() {
    let indices = 0...10
    let semaphores = indices.map {_ in DispatchSemaphore(value: 0)}
    
    func makeValue(_ i: Int) throws -> Int {
      let semaphore = semaphores[i]
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if i == 3 {throw HeadDesk.ouch}
      return i
    }
    
    func makeFuture(_ i: Int) -> Future<Int> {
      return future {try makeValue(i)}
    }
    
    let futures = indices.map {i in makeFuture(i)}
    let sequencedFuture = Future.identityTransform • futures
    let expectation = self.expectation(description: "Should be called.")
    sequencedFuture.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.onSuccess {_ in
      XCTFail()
    }.end()
    
    // Let the futures complete.
    for semaphore in semaphores {semaphore.signal()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
}

// MARK: - Testing Traverse

extension UtilitiesTests {
  func testTraverseWhenAllFuturesSucceed() {
    let indices = 0...10
    let semaphores = indices.map {_ in DispatchSemaphore(value: 0)}
    
    func makeValue(_ i: Int) throws -> Int {
      let semaphore = semaphores[i]
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return i
    }
    
    func makeFuture(_ i: Int) -> Future<Int> {
      return future {try makeValue(i)}
    }
    
    let traversedFuture = makeFuture • indices
    let expectation = self.expectation(description: "Should be called.")
    traversedFuture.onSuccess {actualValue in
      let expectedValue = Array(indices)
      XCTAssertEqual(actualValue, expectedValue)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    // Let the futures complete.
    for semaphore in semaphores {semaphore.signal()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testTraverseWhenOneFutureFails() {
    let indices = 0...10
    let semaphores = indices.map {_ in DispatchSemaphore(value: 0)}
    
    func makeValue(_ i: Int) throws -> Int {
      let semaphore = semaphores[i]
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if i == 3 {throw HeadDesk.ouch}
      return i
    }
    
    func makeFuture(_ i: Int) -> Future<Int> {
      return future {try makeValue(i)}
    }
    
    let traversedFuture = makeFuture • indices
    let expectation = self.expectation(description: "Should be called.")
    traversedFuture.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.end()
    
    // Let the futures complete.
    for semaphore in semaphores {semaphore.signal()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testTraverseWithFunctionThatThrows() {
    enum TraverseError : Error {case anError}
    func mapper(_ v: Int) throws -> Future<Int> {throw TraverseError.anError}
    let values = [1,2,3,4,5]
    let f = mapper • values
    let expectation = self.expectation(description: "Should fail.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      guard let error = error as? TraverseError else {
        XCTFail()
        return
      }
      XCTAssertEqual(error, TraverseError.anError)
      expectation.fulfill()
    }.end()
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
}

// MARK: - Testing await

extension UtilitiesTests {
  
  func testAwaitWhenFutureSucceeds() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future(makeValue)
    let expectation = self.expectation(description: "Should succeed.")
    f.onSuccess {_ in
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    let backgroundQueue = DispatchQueue(label: "com.multinormal.AwaitUnitTest.\(UUID().uuidString)", attributes: DispatchQueue.Attributes.concurrent)
    backgroundQueue.async {
      XCTAssertFalse(Thread.isMainThread)
      do {
        let actual = try await(f)
        XCTAssertEqual(actual, value)
      } catch {
        XCTFail()
      }
    }
    semaphore.signal()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
  func testAwaitWhenFutureFails() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      throw HeadDesk.ouch
    }
    
    let f = future(makeValue)
    let expectation = self.expectation(description: "Future should fail.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: expectation.fulfill()
      default: XCTFail()
      }
    }.end()
    let awaitCorrectlyThrewExpectation = self.expectation(description: "Await should throw because the future should fail.")
    let backgroundQueue = DispatchQueue(label: "com.multinormal.AwaitUnitTest.\(UUID().uuidString)", attributes: DispatchQueue.Attributes.concurrent)
    backgroundQueue.async {
      XCTAssertFalse(Thread.isMainThread)
      do {
        let _ = try await(f)
        XCTFail() // Should throw an error because the future should fail.
      } catch {
        awaitCorrectlyThrewExpectation.fulfill()
      }
    }
    semaphore.signal()
    waitForExpectations(timeout: 1) {XCTAssertNil($0)}
  }
  
}
