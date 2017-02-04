//
//  PromiseTests.swift
//  TestBed
//
//  Created by Chris Rose on 28/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import XCTest

@testable import FuturesKit

// Function to work with promises, ensuring that their future is eventually accessed.
// (Using promises without obtaining their future is an error.)
func withPromise<T>(_ f: (Promise<T>) -> ()) {
  let p = Promise<T>()
  f(p)
  // Get and use the promise.
  let f = p.future
  f.onSuccess {_ in}.end()
}

enum HeadDesk: Error {case ouch}

class PromiseTests: XCTestCase {

  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}

  func testKeptWithValue() {
    withPromise {(p: Promise<Int>) -> Void in
      let value = 1
      
      // Preconditions.
      XCTAssertFalse(keptOrBrokenForPromise(p))
      
      // Keep the promise.
      p.keptWithValue(value)
      
      // Postconditions.
      XCTAssertTrue(keptOrBrokenForPromise(p))
      let future = p.future
      guard let result = future.resultForUnitTesting else {
        XCTFail()
        return
      }
      let expectation = self.expectation(description: "Should be called.")
      switch result {
      case .value(let actualValue):
        XCTAssertEqual(actualValue, value)
        expectation.fulfill()
      case .error: XCTFail()
      }
      self.waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
    }    
  }
  
  func testKeptWithValueCallsSuccessCallback() {
    withPromise {(p: Promise<Int>) -> Void in
      let value = 1
      let expectation = self.expectation(description: "Should be called.")
      
      // Set callbacks.
      let future = p.future
      future.onSuccess {actualValue in
        XCTAssertEqual(actualValue, value)
        expectation.fulfill()
      }.onError {_ in
        XCTFail()
      }.end()
      
      // Keep the promise.
      p.keptWithValue(value)
      
      self.waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
    }
  }
  
  
  func testBroken() {
    withPromise {(p: Promise<Int>) -> Void in
      // Preconditions.
      XCTAssertFalse(keptOrBrokenForPromise(p))
      
      // Break the promise.
      p.brokenWithError(HeadDesk.ouch)
      
      // Postconditions.
      XCTAssertTrue(keptOrBrokenForPromise(p))
      let future = p.future
      guard let result = future.resultForUnitTesting else {
        XCTFail()
        return
      }
      let expectation = self.expectation(description: "Should be called.")
      let errorExpectation = self.expectation(description: "Should be Ouch.")
      switch result {
      case .value: XCTFail()
      case .error(HeadDesk.ouch):
        errorExpectation.fulfill()
        expectation.fulfill()
      default: XCTFail()
      }
      self.waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
    }
  }
  
  func testBrokenCallsErrorCallback() {
    withPromise {(p: Promise<Int>) -> Void in
      let expectation = self.expectation(description: "Should be called.")
      let errorExpectation = self.expectation(description: "Should be Ouch.")
      
      // Set a callback.
      let future = p.future
      future.onSuccess {_ in
        XCTFail()
      }.onError {error in
        switch error as? HeadDesk {
        case .ouch?: errorExpectation.fulfill()
        default: XCTFail()
        }
        expectation.fulfill()
      }.end()
      
      // Break the promise.
      p.brokenWithError(HeadDesk.ouch)
      
      self.waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
    }
  }
  
  func testFuture() {
    withPromise {(p: Promise<Int>) -> Void in
      let value = 1
      
      // Keep the promise and get the future.
      p.keptWithValue(value)
      let f = p.future
      f.onError {_ in XCTFail()}.end() // Only really here to quell compiler warning of unused f.
      
      let expectation = self.expectation(description: "Should be called.")
      f.onSuccess {_ in expectation.fulfill()}.end()
      self.waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
    }
  }
}
