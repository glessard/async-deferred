//
//  deferred.swift
//  swiftiandispatch
//
//  Created by Guillaume Lessard on 2015-07-09.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import Dispatch

/**
  The states a Deferred can be in.

  Must be a top-level type because Deferred is generic.
*/

public enum DeferredState: Int32 { case Waiting = 0, Executing = 1, Determined = 3, Assigning = -1 }

/**
  The errors a Deferred can throw.

  Must be a top-level type because Deferred is generic.
*/

public enum DeferredError: ErrorType
{
  case AlreadyDetermined(String)
  case CannotDetermine(String)
}

/**
  An asynchronous computation.

  A `Deferred` starts out undetermined, in the `.Waiting` state. It may then enter the `.Executing` state,
  and will eventually become `.Determined`, and ready to supply a result.

  The `value` property will return the result, blocking until it becomes determined.
  If the result is ready when `value` is called, it will return immediately.
*/

public class Deferred<T>
{
  private var v: T! = nil

  private var currentState: Int32 = DeferredState.Waiting.rawValue
  private var waiters = UnsafeMutablePointer<Waiter>(nil)

  // MARK: Initializers

  private init() {}

  public init(value: T)
  {
    v = value
    currentState = DeferredState.Determined.rawValue
  }

  public init(queue: dispatch_queue_t, task: () -> T)
  {
    guard setState(.Executing) else { fatalError("Could not start task in \(__FUNCTION__)") }
    dispatch_async(queue) {
      try! self.setValue(task())
    }
  }

  public convenience init(qos: qos_class_t, task: () -> T)
  {
    self.init(queue: dispatch_get_global_queue(qos, 0), task: task)
  }

  public convenience init(_ task: () -> T)
  {
    self.init(queue: dispatch_get_global_queue(qos_class_self(), 0), task: task)
  }

  deinit
  {
    WaitQueue.dealloc(waiters)
  }

  // MARK: private methods

  private func setState(newState: DeferredState) -> Bool
  {
    switch newState
    {
    case .Waiting:
      return currentState == DeferredState.Waiting.rawValue

    case .Executing:
      return OSAtomicCompareAndSwap32Barrier(DeferredState.Waiting.rawValue, DeferredState.Executing.rawValue, &currentState)

    case .Assigning:
      return OSAtomicCompareAndSwap32Barrier(DeferredState.Executing.rawValue, DeferredState.Assigning.rawValue, &currentState)

    case .Determined:
      if OSAtomicCompareAndSwap32Barrier(DeferredState.Assigning.rawValue, DeferredState.Determined.rawValue, &currentState)
      {
        while true
        {
          let queue = waiters
          if CAS(queue, nil, &waiters)
          {
            // syncprint(syncread(&waiting))
            // syncprint("Queue tail is \(queue)")
            WaitQueue.notifyAll(queue)
            return true
          }
        }
      }
      return currentState == DeferredState.Determined.rawValue
    }
  }
  
  private func setValue(value: T) throws
  { // A very simple turnstile to ensure only one thread can succeed
    guard setState(.Assigning) else
    {
      if currentState == DeferredState.Determined.rawValue
      {
        throw DeferredError.AlreadyDetermined("Failed attempt to determine Deferred twice with \(__FUNCTION__)")
      }
      throw DeferredError.CannotDetermine("Deferred in wrong state at start of \(__FUNCTION__)")
    }

    v = value

    guard setState(.Determined) else
    { // We cannot know where to go from here. Happily getting here seems impossible.
      fatalError("Could not complete assignment of value in \(__FUNCTION__)")
    }

    // The result is now available for the world
  }

  // private var waiting: Int32 = 0

  private func enqueue(waiter: UnsafeMutablePointer<Waiter>) -> Bool
  {
    while true
    {
      let tail = waiters
      waiter.memory.prev = tail
      if syncread(&currentState) != DeferredState.Determined.rawValue
      {
        if CAS(tail, waiter, &waiters)
        { // waiter is now enqueued
          // OSAtomicIncrement32Barrier(&waiting)
          return true
        }
      }
      else
      { // This Deferred has become determined; bail
        return false
      }
    }
  }

  // MARK: public interface

  public var state: DeferredState { return DeferredState(rawValue: currentState)! }

  public var isDetermined: Bool { return currentState == DeferredState.Determined.rawValue }

  public func peek() -> T?
  {
    if currentState != DeferredState.Determined.rawValue
    {
      return nil
    }
    return v
  }

  public var value: T {
    if currentState != DeferredState.Determined.rawValue
    {
      let thread = mach_thread_self()
      let waiter = UnsafeMutablePointer<Waiter>.alloc(1)
      waiter.initialize(Waiter(.Thread(thread)))

      if enqueue(waiter)
      { // waiter will be deallocated after the thread is woken
        let kr = thread_suspend(thread)
        guard kr == KERN_SUCCESS else { fatalError("Thread suspension failed with code \(kr)") }
      }
      else
      {
        waiter.destroy(1)
        waiter.dealloc(1)
      }
    }

    return v
  }

  public func notify(queue: dispatch_queue_t, task: (T) -> Void)
  {
    let block = { task(self.v) } // This cannot be [weak self]

    if currentState != DeferredState.Determined.rawValue
    {
      let waiter = UnsafeMutablePointer<Waiter>.alloc(1)
      waiter.initialize(Waiter(.Dispatch(queue, block)))

      if enqueue(waiter)
      { // waiter will be deallocated after the block is dispatched to GCD
        return
      }
      else
      { // Deferred has a value now
        waiter.destroy(1)
        waiter.dealloc(1)
      }
    }

    dispatch_async(queue, block)
  }
}

/**
  A Deferred to be determined (TBD) manually.
*/

public class TBD<T>: Deferred<T>
{
  override public init() { super.init() }

  public func determine(value: T) throws
  {
    super.setState(.Executing)
    try super.setValue(value)
  }

  public func beginExecution()
  {
    super.setState(.Executing)
  }
}
