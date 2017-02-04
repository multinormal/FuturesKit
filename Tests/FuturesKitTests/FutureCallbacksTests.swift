//
//  FutureCallbacksTests.swift
//  TestBed
//
//  Created by Chris Rose on 28/07/2015.
//  Copyright © 2015 Chris Rose. All rights reserved.
//

import XCTest

@testable import FuturesKit

// MARK: Helper

func assertCallbacksProcessed<T>(_ f: Future<T>) {
  XCTAssertEqual(0, f.callbacksForUnitTesting.count)
}

// MARK: Tests

class FutureCallbacksTests: XCTestCase {

  enum HeadDesk : Error {case ouch}
  
  override func setUp() {super.setUp()}
  override func tearDown() {super.tearDown()}
  
  // MARK: Testing onSuccess
  
  func testSuccessCallbackIsCalledIfAddedBeforeFutureCompletes() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)

    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    let expectation = self.expectation(description: "Callback should be called.")
    f.onSuccess {actualValue in
      XCTAssertEqual(value, actualValue)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  func testSuccessCallbackIsCalledIfAddedAfterFutureCompletes() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    semaphore.signal() // Let makeValue complete immediately.
    let expectation = self.expectation(description: "Callback should be called.")
    f.onSuccess {actualValue in
      XCTAssertEqual(value, actualValue)
      expectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  func testSuccessCalbackIsCalledIfAddedBeforeAndAfterFutureCompletes() {
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let f = future {makeValue()}
    let beforeExpectation = expectation(description: "Before Callback should be called.")
    f.onSuccess {actualValue in
      XCTAssertEqual(value, actualValue)
      beforeExpectation.fulfill()
    }.onError {_ in
      XCTFail()
    }.end()
    
    semaphore.signal() // Let makeValue complete now.
    
    let afterExpectation = expectation(description: "After Callback should be called.")
    f.onSuccess {actualValue in
      XCTAssertEqual(value, actualValue)
      afterExpectation.fulfill()
    }.end()
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  func testMultipleOnSuccessCallbacksAreCalled() {
    let indices = 0 ... 100
    let value = 1
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      return value
    }
    
    let expectations = indices.map {expectation(description: "Expectation \($0)")}
    
    let f = future {makeValue()}
    for i in indices {
      f.onSuccess {actualValue in
        XCTAssertEqual(value, actualValue)
        expectations[i].fulfill()
      }.end()
    }
    f.onError {_ in XCTFail()}.end()
    
    semaphore.signal() // Let makeValue complete now.
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  // MARK: Testing onError
  
  func testErrorCallbackIsCalledIfAddedBeforeFutureCompletes() {
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
    let errorExpectation = self.expectation(description: "Error should be Ouch.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: errorExpectation.fulfill()
      default: XCTFail()
      }
      expectation.fulfill()
    }.end()
    
    semaphore.signal() // Callback added, so now let makeValue complete.
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  func testErrorCallbackIsCalledIfAddedAfterFutureCompletes() {
    let shouldFail = true
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return 0
    }
    
    let f = future {try makeValue()}
    semaphore.signal() // Callback added, so now let makeValue complete.
    let expectation = self.expectation(description: "Callback should be called.")
    let errorExpectation = self.expectation(description: "Error should be Ouch.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: errorExpectation.fulfill()
      default: XCTFail()
      }
      expectation.fulfill()
    }.end()
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  func testErrorCallbackIsCalledIfAddedBeforeAndAfterFutureCompletes() {
    let shouldFail = true
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return 0
    }
    
    let f = future {try makeValue()}
    let beforeExpectation = expectation(description: "Before Callback should be called.")
    let beforeErrorExpectation = expectation(description: "Error should be Ouch.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: beforeErrorExpectation.fulfill()
      default: XCTFail()
      }
      beforeExpectation.fulfill()
    }.end()
    
    semaphore.signal() // Let makeValue complete now.
    
    let afterExpectation = expectation(description: "After Callback should be called.")
    let afterErrorExpectation = expectation(description: "Error should be Ouch.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {error in
      switch error as? HeadDesk {
      case .ouch?: afterErrorExpectation.fulfill()
      default: XCTFail()
      }
      afterExpectation.fulfill()
    }.end()
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  func testMultipleOnErrorCallbacksAreCalled() {
    let indices = 0 ... 100
    let shouldFail = true
    let semaphore = DispatchSemaphore(value: 0)
    
    func makeValue() throws -> Int {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      if shouldFail {throw HeadDesk.ouch}
      XCTFail() // Should never get here.
      return 0
    }
    
    let expectations = indices.map {expectation(description: "Expectation \($0)")}
    let errorExpectations = indices.map  {expectation(description: "Error expectation \($0)")}
    
    let f = future {try makeValue()}
    for i in indices {
      f.onError {error in
        switch error as? HeadDesk {
        case .ouch?: errorExpectations[i].fulfill()
        default: XCTFail()
        }
        expectations[i].fulfill()
      }.end()
    }
    f.onSuccess {_ in XCTFail()}.end()
    
    semaphore.signal() // Let makeValue complete now.
    
    waitForExpectations(timeout: 1) {error in
      XCTAssertNil(error)
    }
    
    assertCallbacksProcessed(f)
  }
  
  // MARK: Testing onError with NSError-throwing methods.
  
  func testErrorCallbackIsCalledIfAnNSErrorOccurs() {
    let semaphore = DispatchSemaphore(value: 0)
    
    let nonExistingFilename = "/this/does/not/exist"
    guard !FileManager.default.fileExists(atPath: nonExistingFilename) else {
      XCTFail()
      return
    }
    
    func wasFileDeleted() throws -> Bool {
      let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
      try FileManager.default.removeItem(atPath: nonExistingFilename)
      XCTFail() // We should not get here.
      return true
    }
    
    let f = future {try wasFileDeleted()}
    let expectation = self.expectation(description: "There should be an error.")
    f.onSuccess {_ in
      XCTFail()
    }.onError {_ in
      expectation.fulfill()
    }.end()
    
    semaphore.signal() // Let the future complete.
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
  func testResultHandlerWithResult() {
    enum ET: Error {case e}
    
    let valueResult: Result<Void> = Result.value(())
    let errorResult: Result<Void> = Result.error(ET.e)
    
    let successExpectation = expectation(description: "Success callback should be called.")
    let successCallback = Callback.success(context: .background) {successExpectation.fulfill()}
    
    let failureExpectation = expectation(description: "Failure callback should be called.")
    let failureCallback: Callback<Void> = Callback.failure {_ in failureExpectation.fulfill()}
    
    let valueSuccessResultHandler = valueResult.resultHandlerFor(successCallback)
    let errorFailureResultHandler = errorResult.resultHandlerFor(failureCallback)
    let valueFailureResultHandler = valueResult.resultHandlerFor(failureCallback)
    let errorSuccessResultHandler = errorResult.resultHandlerFor(successCallback)
    
    XCTAssertNotNil(valueSuccessResultHandler)
    XCTAssertNotNil(errorFailureResultHandler)
    XCTAssertNil(valueFailureResultHandler)
    XCTAssertNil(errorSuccessResultHandler)
    
    let allCallbacks = [valueSuccessResultHandler, errorFailureResultHandler, valueFailureResultHandler, errorSuccessResultHandler]
    allCallbacks.forEach {$0?()}
    waitForExpectations(timeout: 1) {error in XCTAssertNil(error)}
  }
  
}
