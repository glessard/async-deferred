//
//  DeferredCombinationTests.swift
//  deferred
//
//  Created by Guillaume Lessard on 30/01/2017.
//  Copyright © 2017 Guillaume Lessard. All rights reserved.
//

import XCTest
import Dispatch

import deferred

class DeferredCombinationTests: XCTestCase
{
  func testReduce()
  {
    let count = 9
    let inputs = (0..<count).map { i in Deferred(value: nzRandom() & 0x003f_fffe + 1) } + [Deferred(value: 0)]

    let e = expectation(description: "reduce")
    let c = reduce(AnySequence(inputs), initial: 0) {
      a, i throws -> Int in
      if i > 0 { return a+i }
      throw TestError(a)
    }
    c.onResult { _ in e.fulfill() }

    XCTAssert(c.value == nil)
    XCTAssert(c.error != nil)
    if let error = c.error as? TestError
    {
      XCTAssert(error.error >= 9)
    }

    waitForExpectations(timeout: 1.0)
  }

  func testReduceCancel()
  {
    let count = 10

    let d = (0..<count).map {
      i -> Deferred<Int> in
      let e = expectation(description: String(describing: i))
      return Deferred {
        usleep(numericCast(i+1)*10_000)
        e.fulfill()
        return i
      }
    }

    let cancel1 = Int(nzRandom() % numericCast(count))
    let cancel2 = Int(nzRandom() % numericCast(count))
    d[cancel1].cancel(String(cancel1))
    d[cancel2].cancel(String(cancel2))

    let c = reduce(d, initial: 0, combine: { a, b in return a+b })

    waitForExpectations(timeout: 1.0)

    XCTAssert(c.value == nil)
    XCTAssert(c.error as? DeferredError == DeferredError.canceled(String(min(cancel1, cancel2))))
  }

  func testCombineArray1()
  {
    let count = 10

    let inputs = (0..<count).map { i in Deferred(value: nzRandom()) }
    let combined = combine(AnySequence(inputs))
    if let values = combined.value
    {
      XCTAssert(values.count == count)
      for (a,b) in zip(inputs, values)
      {
        XCTAssert(a.value == b)
      }
    }
    XCTAssert(combined.error == nil)

    let combined1 = combine([Deferred<Int>]())
    XCTAssert(combined1.value?.count == 0)
  }

  func testCombineArray2()
  {
    let count = 10
    let e = (0..<count).map { i in expectation(description: String(describing: i)) }

    let d = Deferred.inParallel(count: count) {
      i -> Int in
      usleep(numericCast(i+1)*10_000)
      e[i].fulfill()
      return i
    }

    // If any one is in error, the combined whole will be in error.
    // The first error encountered will be passed on.

    let cancel1 = Int(nzRandom() % numericCast(count))
    let cancel2 = Int(nzRandom() % numericCast(count))

    d[cancel1].cancel(String(cancel1))
    d[cancel2].cancel(String(cancel2))

    let c = combine(d)

    waitForExpectations(timeout: 1.0)

    XCTAssert(c.value == nil)
    XCTAssert(c.error as? DeferredError == DeferredError.canceled(String(min(cancel1,cancel2))))
  }

  func testCombine2()
  {
    let v1 = Int(nzRandom())
    let v2 = UInt64(nzRandom())

    let d1 = Deferred(value: v1)
    let d2 = Deferred(value: v2)
    let d3 = d1.delay(.milliseconds(10))
    let d4 = d2.delay(.milliseconds(20))

    let c = combine(d3,d4).value
    XCTAssert(c?.0 == v1)
    XCTAssert(c?.1 == v2)
  }

  func testCombine3()
  {
    let v1 = Int(nzRandom())
    let v2 = UInt64(nzRandom())
    let v3 = String(nzRandom())

    let d1 = Deferred(value: v1)
    let d2 = Deferred(value: v2)
    let d3 = Deferred(value: v3)
    // let d4 = Deferred { v3 }                        // infers Deferred<()->String> rather than Deferred<String>
    // let d5 = Deferred { () -> String in v3 }        // infers Deferred<()->String> rather than Deferred<String>
    // let d6 = Deferred { _ in v3 }                   // infers Deferred<String> as expected
    // let d7 = Deferred { () throws -> String in v3 } // infers Deferred<String> as expected

    let c = combine(d1,d2,d3.delay(seconds: 0.001)).value
    XCTAssert(c?.0 == v1)
    XCTAssert(c?.1 == v2)
    XCTAssert(c?.2 == v3)
  }

  func testCombine4()
  {
    let v1 = Int(nzRandom())
    let v2 = UInt64(nzRandom())
    let v3 = String(nzRandom())
    let v4 = sin(Double(v2))

    let d1 = Deferred(value: v1)
    let d2 = Deferred(value: v2)
    let d3 = Deferred(value: v3)
    let d4 = Deferred(value: v4)

    let c = combine(d1,d2,d3,d4.delay(.milliseconds(1))).value
    XCTAssert(c?.0 == v1)
    XCTAssert(c?.1 == v2)
    XCTAssert(c?.2 == v3)
    XCTAssert(c?.3 == v4)
  }
}

class DeferredCombinationTimedTests: XCTestCase
{
  let loopTestCount = 5_000

  func testPerformanceReduce()
  {
    let iterations = loopTestCount

    measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {
      let inputs = (1...iterations).map { Deferred(value: $0) }
      self.startMeasuring()
      let c = reduce(inputs, initial: 0, combine: +)
      let v = try? c.get()
      XCTAssert(v == (iterations*(iterations+1)/2))
      self.stopMeasuring()
    }
  }

  func testPerformanceABAProneReduce()
  {
    let iterations = loopTestCount / 10

    measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {
      let inputs = (1...iterations).map {Deferred(value: $0) }
      self.startMeasuring()
      let accumulator = Deferred(value: 0)
      let c = inputs.reduce(accumulator) {
        (accumulator, deferred) in
        accumulator.flatMap {
          u in deferred.map { t in u+t }
        }
      }
      let v = try? c.get()
      XCTAssert(v == (iterations*(iterations+1)/2))
      self.stopMeasuring()
    }
  }

  func testPerformanceCombine()
  {
    let iterations = loopTestCount

    measureMetrics(XCTestCase.defaultPerformanceMetrics, automaticallyStartMeasuring: false) {
      let inputs = (1...iterations).map { Deferred(value: $0) }
      self.startMeasuring()
      let c = combine(inputs)
      let v = try? c.get()
      XCTAssert(v?.count == iterations)
      self.stopMeasuring()
    }
  }
}
