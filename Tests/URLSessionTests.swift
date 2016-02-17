//
//  CallbackTests.swift
//  deferred
//
//  Created by Guillaume Lessard on 09/02/2016.
//  Copyright © 2016 Guillaume Lessard. All rights reserved.
//

import XCTest

import deferred

let imagePath = "http://localhost:9973/image.jpg"
let notFoundPath = "http://localhost:9973/404"

class URLSessionTests: XCTestCase
{
#if _runtime(_ObjC)

  func testData_OK()
  {
    let url = NSURL(string: imagePath)!
    let request = NSURLRequest(URL: url)
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let result = session.deferredDataTask(request)

    let e = expectationWithDescription("Image download")

    result.map {
      (data, response) throws -> NSData in
      guard (200..<300).contains(response.statusCode) else
      {
        throw URLSessionError.ServerStatus(response.statusCode)
      }

      return data
    }.map {
      data -> Bool in
#if os(OSX) || os(Linux)
      let im = NSImage(data: data)
#else
      let im = UIImage(data: data)
#endif
      if let im = im
      {
        return (im.size.width == 200.0) && (im.size.height == 200.0)
      }
      return false
    }.notify {
      result in
      switch result
      {
      case .Value(let success):
        if success { e.fulfill() }
      case .Error(let error):
        print(error)
        XCTFail()
      }
    }

    waitForExpectationsWithTimeout(1.0) { _ in session.invalidateAndCancel() }
  }

  func testData_Cancellation()
  {
    let url = NSURL(string: imagePath)!
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let deferred = session.deferredDataTask(url)
    let canceled = deferred.cancel()
    XCTAssert(canceled)

    if let error = deferred.error
    {
      let e = error as NSError
      XCTAssert(e.domain == NSURLErrorDomain)
      XCTAssert(e.code == NSURLErrorCancelled)
    }
    else
    {
      XCTFail()
    }

    session.invalidateAndCancel()
  }

  func testData_DoubleCancellation()
  {
    let deferred: DeferredURLSessionTask<(NSData, NSHTTPURLResponse)> = {
      let url = NSURL(string: imagePath)!
      let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
      defer { session.invalidateAndCancel() }

      return session.deferredDataTask(url)
    }()

    _ = deferred.error
    // Nope: XCTAssertNil(deferred.task)

    let canceled = deferred.cancel()
    XCTAssert(canceled == false)
  }
  
  func testData_SuspendCancel()
  {
    let url = NSURL(string: imagePath)!
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let deferred = session.deferredDataTask(url)
    deferred.task?.suspend()
    let canceled = deferred.cancel()
    XCTAssert(canceled)

    if let error = deferred.error
    {
      XCTAssertFalse(error is DeferredError)
      let e = error as NSError
      XCTAssert(e.domain == NSURLErrorDomain)
      XCTAssert(e.code == NSURLErrorCancelled)
    }
    else
    {
      XCTFail()
    }

    session.invalidateAndCancel()
  }

  func testData_NotFound()
  {
    let url = NSURL(string: notFoundPath)!
    let request = NSURLRequest(URL: url)
    let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

    let deferred = session.deferredDataTask(request)

    if let (data, response) = deferred.value
    {
      XCTAssert(data.length > 0)
      XCTAssert(response.statusCode == 404)
    }
    else
    {
      XCTFail()
    }

    session.invalidateAndCancel()
  }

  func testDownload_OK()
  {
    let url = NSURL(string: imagePath)!
    let request = NSURLRequest(URL: url)
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let result = session.deferredDownloadTask(request)

    let e = expectationWithDescription("Image download")

    result.map {
      (url, file, response) throws -> NSData in
      guard (200..<300).contains(response.statusCode) else
      {
        throw URLSessionError.ServerStatus(response.statusCode)
      }
      defer { file.closeFile() }

      return file.readDataToEndOfFile()
    }.map {
      data -> Bool in
#if os(OSX) || os(Linux)
      let im = NSImage(data: data)
#else
      let im = UIImage(data: data)
#endif
      if let im = im
      {
        return (im.size.width == 200.0) && (im.size.height == 200.0)
      }
      return false
    }.notify {
      result in
      switch result
      {
      case .Value(let success):
        if success { e.fulfill() }
      case .Error(let error):
        print(error)
        XCTFail()
      }
    }

    waitForExpectationsWithTimeout(1.0) { _ in session.invalidateAndCancel() }
  }

  func testDownload_Cancellation()
  {
    let url = NSURL(string: imagePath)!
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let deferred = session.deferredDownloadTask(url)
    let canceled = deferred.cancel()
    XCTAssert(canceled)

    if let error = deferred.error
    {
      let e = error as NSError
      XCTAssert(e.domain == NSURLErrorDomain)
      XCTAssert(e.code == NSURLErrorCancelled)
    }
    else
    {
      XCTFail()
    }

    session.invalidateAndCancel()
  }

  func testDownload_DoubleCancellation()
  {
    let deferred: DeferredURLSessionTask<(NSURL, NSFileHandle, NSHTTPURLResponse)> = {
      let url = NSURL(string: imagePath)!
      let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
      defer { session.invalidateAndCancel() }

      return session.deferredDownloadTask(url)
    }()

    _ = deferred.error
    // Nope: XCTAssertNil(deferred.task)

    let canceled = deferred.cancel()
    XCTAssert(canceled == false)
  }
  
  func testDownload_SuspendCancel()
  {
    let url = NSURL(string: imagePath)!
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let deferred = session.deferredDownloadTask(url)
    deferred.task?.suspend()
    let canceled = deferred.cancel()
    XCTAssert(canceled)

    if let error = deferred.error
    {
      XCTAssertFalse(error is DeferredError)
      let e = error as NSError
      XCTAssert(e.domain == NSURLErrorDomain)
      XCTAssert(e.code == NSURLErrorCancelled)
    }
    else
    {
      XCTFail()
    }

    session.invalidateAndCancel()
  }

  func testDownload_CancelAndResume()
  {
    let url = NSURL(string: "http://mirrors.axint.net/repos/gnu.org/gcc/gcc-2.8.0.tar.gz")!
    // let url = NSURL(string: "https://mirrors.axint.net/repos/gnu.org/gcc/gcc-2.8.0.tar.gz")!
    let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())

    let deferred = session.deferredDownloadTask(url)

    let converted = deferred.map { _ -> Result<NSData> in Result() }
    usleep(250_000)

    let canceled = deferred.cancel()
    XCTAssert(canceled)

    XCTAssert(deferred.error != nil)
    XCTAssert(converted.value == nil)

    let recovered = converted.recover {
      error in
      switch error
      {
      case URLSessionError.InterruptedDownload(let data):
        return Deferred(value: data)
      default:
        return Deferred(error: error)
      }
    }
    if let error = recovered.error
    { // give up
      XCTFail("Download operation failed and/or could not be resumed: \(error as NSError)")
      session.invalidateAndCancel()
      return
    }

    let firstLength = recovered.map { data in data.length }

    let resumed = recovered.flatMap { data in session.deferredDownloadTask(resumeData: data) }
    let finalLength = resumed.map {
      (url, handle, response) throws -> Int in
      defer { handle.closeFile() }

      var ptr = Optional<AnyObject>()
      try url.getResourceValue(&ptr, forKey: NSURLFileSizeKey)

      if let number = ptr as? NSNumber
      {
        return number.integerValue
      }
      if let error = Result<Void>().error { throw error }
      return -1
    }

    let e = expectationWithDescription("Large file download, paused and resumed")

    combine(firstLength, finalLength).onValue {
      (l1, l2) in
      // print(l2)
      XCTAssert(l2 > l1)
      e.fulfill()
    }

    waitForExpectationsWithTimeout(9.9) { _ in session.invalidateAndCancel() }
  }

  func testDownload_NotFound()
  {
    let url = NSURL(string: notFoundPath)!
    let request = NSURLRequest(URL: url)
    let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

    let deferred = session.deferredDownloadTask(request)

    if let (_, handle, response) = deferred.value
    {
      let data = handle.readDataToEndOfFile()
      handle.closeFile()
      XCTAssert(data.length > 0)
      XCTAssert(response.statusCode == 404)
    }
    else
    {
      XCTFail()
    }

    session.invalidateAndCancel()
  }

#endif
}
