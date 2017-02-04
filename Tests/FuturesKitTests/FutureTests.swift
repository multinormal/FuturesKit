//
//  FutureTests.swift
//  TestBed
//
//  Created by Chris Rose on 28/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import XCTest

@testable import FuturesKit

class FutureTests: XCTestCase {

  enum HeadDesk : Error {case ouch}
  
  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}
  
  func testInitWithValue() {
    let value = 1
    let f = futureFromValue(value)
    
    XCTAssertTrue(f.resultForUnitTesting != nil)
    switch f.resultForUnitTesting! {
    case .error: XCTFail()
    case let .value(actualValue): XCTAssertEqual(value, actualValue)
    }
    
    XCTAssertEqual(0, f.callbacksForUnitTesting.count)
    // Because the future is created with a value, the callback(s) should be run
    // immediately, and doing so clears the list of callbacks.
  }
  
  func testInitWithFunctionThatCannotFail() {
    let value = 1
    let expectation = self.expectation(description: "")
    let threadExpectation = self.expectation(description: "Function should not be called on main thread.")
    
    func nonfailingFunction() -> Int {
      if Thread.isMainThread == false {
        threadExpectation.fulfill()
      }
      expectation.fulfill()
      return value
    }
    
    let f = future {nonfailingFunction()}
    waitForExpectations(timeout: 1) {_ in
      guard let result = f.resultForUnitTesting else {
        XCTFail()
        return
      }
      switch result {
      case .error: XCTFail()
      case let .value(actualValue): XCTAssertEqual(value, actualValue)
      }
      
      XCTAssertEqual(0, f.callbacksForUnitTesting.count)
      // Because the future's value is guaranteed to have been set now,
      // the callback(s) should have been run, and doing so clears the list of callbacks.
    }
  }
  
  func testInitWithFunctionThatCanFailButDoesNot() {
    let value = 1
    let expectation = self.expectation(description: "")
    let threadExpectation = self.expectation(description: "Function should not be called on main thread.")
    
    func nonfailingFunction() throws -> Int {
      if !Thread.isMainThread {threadExpectation.fulfill()}
      expectation.fulfill()
      return value
    }
    
    let f = future {try nonfailingFunction()}
    waitForExpectations(timeout: 1) {_ in
      guard let result = f.resultForUnitTesting else {
        XCTFail()
        return
      }
      switch result {
      case .error: XCTFail()
      case let .value(actualValue): XCTAssertEqual(value, actualValue)
      }
      
      XCTAssertEqual(0, f.callbacksForUnitTesting.count)
      // Because the future's value is guaranteed to have been set now,
      // the callback(s) should have been run, and doing so clears the list of callbacks.
    }
  }
  
  func testInitWithFunctionThatCanFailAndDoes() {
    let value = 1
    let shouldThrow = true
    let onErrorExpectation = expectation(description: "Should be fulfilled by an onError callback.")
    let failingFunctionWasCalledExpectation = expectation(description: "failingFunction() should be called.")
    let threadExpectation = expectation(description: "Function should not be called on main thread.")
    
    func failingFunction() throws -> Int {
      failingFunctionWasCalledExpectation.fulfill()
      if Thread.isMainThread == false {
        threadExpectation.fulfill()
      }
      if shouldThrow {throw HeadDesk.ouch}
      XCTFail() // We should never get here, because we should always throw.
      return value
    }
    
    let f = future {try failingFunction()}
    f.onError {error in
      switch error as? HeadDesk {
      case .ouch?: onErrorExpectation.fulfill()
      default: XCTFail()
      }
    }.end()
    
    waitForExpectations(timeout: 0.1) {_ in
      guard let result = f.resultForUnitTesting else {
        XCTFail()
        return
      }
      switch result {
      case .error: ()
      case .value: XCTFail()
      }
      
      assertCallbacksProcessed(f)
      // Because the future's value is guaranteed to have failed now,
      // the error callback(s) should have been run, and doing so clears the list of callbacks.
    }
  }
  
  func testThreadContextQueueReturnsCorrectQueue() {
    let mainExpectation = expectation(description: "Should be fulfilled on the main queue.")
    let backgroundExpectation = expectation(description: "Should NOT be fulfilled on the main queue.")
    
    ThreadContext.main.queue.async {
      XCTAssertTrue(Thread.isMainThread)
      mainExpectation.fulfill()
    }
    ThreadContext.background.queue.async {
      XCTAssertFalse(Thread.isMainThread)
      backgroundExpectation.fulfill()
    }
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  
  
}
