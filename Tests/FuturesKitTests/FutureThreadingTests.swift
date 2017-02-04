//
//  FutureThreadingTests.swift
//  TestBed
//
//  Created by Chris Rose on 28/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import XCTest

@testable import FuturesKit

class FutureThreadingTests: XCTestCase {

  enum HeadDesk : Error {case ouch}
  
  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}
  
  // MARK: Test callbacks run on correct threads.
  
  func testSuccessCallbackRunsOnMainThread() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    let expectation = self.expectation(description: "Callback should be called.")
    f.onSuccess {_ in
      XCTAssertTrue(Thread.isMainThread)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testErrorCallbackRunsOnMainThread() {
    let shouldFail = true
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return 0
    }
    
    let f = future {try makeValue()}
    let expectation = self.expectation(description: "Callback should be called.")
    let errorExpectation = self.expectation(description: "Should be Ouch.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: errorExpectation.fulfill()
      default: XCTFail()
      }
      XCTAssertTrue(Thread.isMainThread)
      expectation.fulfill()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
  }
  
  func testOnSuccessOnBackgroundThreadRunsOnBackgroundThread() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    let expectation = self.expectation(description: "Callback should be called.")
    f.onSuccessOnBackgroundThread {_ in
      XCTAssertFalse(Thread.isMainThread)
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
