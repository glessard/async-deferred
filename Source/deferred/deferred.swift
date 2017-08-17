//
//  deferred.swift
//  async-deferred
//
//  Created by Guillaume Lessard on 2015-07-09.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import Dispatch

#if SWIFT_PACKAGE
  import Atomics
#endif

/// The possible states of a `Deferred`.
///
/// Must be a top-level type because Deferred is generic.

public enum DeferredState { case waiting, executing, determined }

/// An asynchronous computation.
///
/// A `Deferred` starts out undetermined, in the `.waiting` state.
/// It may then enter the `.executing` state, and will eventually become `.determined`.
/// Once it is `.determined`, it is ready to supply a result.
///
/// The `result` property will return the result, blocking until it becomes determined.
/// If the result is ready when `result` is called, it will return immediately.
///
/// A closure supplied to the `notify` method will be called after the `Deferred` has become determined.

open class Deferred<Value>
{
  fileprivate let queue: DispatchQueue

  private var resulto: Result<Value>?
  private var waiters: AtomicMutablePointer<Waiter<Value>>
  private var stateid: AtomicInt32

  deinit
  {
    if let w = waiters.load(order: .acquire), w != Waiter.invalid
    {
      deallocateWaiters(w)
    }
  }

  // MARK: designated initializers

  internal init(queue: DispatchQueue)
  {
    resulto = nil
    waiters = AtomicMutablePointer(nil)
    stateid = AtomicInt32(0)

    self.queue = queue
  }

  /// Initialize to an already determined state
  ///
  /// - parameter queue:  the dispatch queue upon which to execute future notifications for this `Deferred`
  /// - parameter result: the result of this `Deferred`

  public init(queue: DispatchQueue, result: Result<Value>)
  {
    resulto = result
    waiters = AtomicMutablePointer(Waiter.invalid)
    stateid = AtomicInt32(2)

    self.queue = queue
  }

  // MARK: initialize with a closure

  /// Initialize with a computation task to be performed in the background
  ///
  /// - parameter qos:  the Quality-of-Service class at which the computation (and notifications) should be performed; defaults to the current QoS.
  /// - parameter task: the computation to be performed

  public convenience init(qos: DispatchQoS = DispatchQoS.current ?? .default, task: @escaping () throws -> Value)
  {
    let queue = DispatchQueue.global(qos: qos.qosClass)
    self.init(queue: queue, task: task)
  }

  /// Initialize with a computation task to be performed on the specified queue
  ///
  /// - parameter queue: the `DispatchQueue` on which the computation (and notifications) will be executed
  /// - parameter qos:   the Quality-of-Service class at which the computation should be performed; defaults to the QOS class of `queue`
  /// - parameter task:  the computation to be performed

  public convenience init(queue: DispatchQueue, qos: DispatchQoS? = nil, task: @escaping () throws -> Value)
  {
    self.init(queue: queue)

    stateid.store(1)

    queue.async(qos: qos) {
      let result = Result { try task() }
      self.determine(result) // an error here means this `Deferred` has been canceled.
    }
  }

  // MARK: initialize with a result, value or error

  /// Initialize to an already determined state
  ///
  /// - parameter qos:    the Quality-of-Service class at which the notifications should be performed.
  /// - parameter result: the result of this `Deferred`

  public convenience init(qos: DispatchQoS = DispatchQoS.current ?? .default, result: Result<Value>)
  {
    let queue = DispatchQueue.global(qos: qos.qosClass)
    self.init(queue: queue, result: result)
  }

  /// Initialize to an already determined state, with a queue at the current quality-of-service class.
  ///
  /// - parameter result: the result of this `Deferred`

  public convenience init(_ result: Result<Value>)
  {
    self.init(result: result)
  }

  /// Initialize to an already determined state, with a queue at the current quality-of-service class.
  ///
  /// - parameter value: the value of this `Deferred`'s `Result`

  public convenience init(value: Value)
  {
    self.init(result: Result.value(value))
  }

  /// Initialize to an already determined state, with a queue at the current quality-of-service class.
  ///
  /// - parameter error: the error state of this `Deferred`'s `Result`

  public convenience init(error: Error)
  {
    self.init(result: Result.error(error))
  }

  // MARK: fileprivate methods

  /// Change the state of this `Deferred` from `.waiting` to `.executing`

  fileprivate func beginExecution()
  {
    if stateid.load() == 0 { stateid.store(1) }
  }

  /// Set the `Result` of this `Deferred`, change its state to `DeferredState.determined`,
  /// enqueue all notifications on the DispatchQueue, then return `true`.
  /// Note that a `Deferred` can only be determined once. On subsequent calls, `determine` will fail and return `false`.
  /// This operation is lock-free and thread-safe.
  ///
  /// - parameter result: the intended `Result` to determine this `Deferred`
  /// - returns: whether the call succesfully changed the state of this `Deferred`.

  @discardableResult
  fileprivate func determine(_ result: Result<Value>) -> Bool
  {
    var current: Int32 = 0
    while !stateid.loadCAS(current: &current, future: 2, orderSwap: .relaxed, orderLoad: .relaxed)
    { // keep trying if another thread hasn't succeeded yet
      if current == 2
      { // another thread succeeded ahead of this one
        return false
      }
    }

    resulto = result

    let waitQueue = waiters.swap(Waiter.invalid, order: .acqrel)
    // precondition(waitQueue != Waiter.invalid)
    notifyWaiters(queue, waitQueue, result)

    // precondition(waiters.load() == Waiter.invalid, "waiters.pointer has incorrect value \(String(describing: waiters.load()))")

    // The result is now available for the world
    return true
  }

  // MARK: public interface

  /// Enqueue a closure to be performed asynchronously as a notification after this `Deferred` becomes determined.
  /// This operation is lock-free and thread-safe.
  /// Multiple threads can call this method at once; they will succeed in turn.
  /// If one or more thread enters a race to enqueue with `determine()`, as soon as `determine()` succeeds
  /// all current and subsequent attempts to enqueue will result in immediate dispatch of the task.
  ///
  /// - parameter qos:  the Quality-of-Service class at which this notification should execute; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter task: the closure to be executed as a notification

  open func notify(qos: DispatchQoS? = nil, task: @escaping (Result<Value>) -> Void)
  {
    var waitQueue = waiters.load(order: .acquire)
    if waitQueue != Waiter.invalid
    {
      let waiter = UnsafeMutablePointer<Waiter<Value>>.allocate(capacity: 1)
      waiter.initialize(to: Waiter(qos, task))

      repeat {
        waiter.pointee.next = waitQueue
        if waiters.loadCAS(current: &waitQueue, future: waiter, type: .weak, orderSwap: .acqrel, orderLoad: .acquire)
        { // waiter is now enqueued; it will be deallocated at a later time by WaitQueue.notifyAll()
          return
        }
      } while waitQueue != Waiter.invalid

      // this Deferred has become determined; clean up
      waiter.deinitialize(count: 1)
      waiter.deallocate(capacity: 1)
    }

    // this Deferred is determined
    let result = resulto!

    queue.async(qos: qos, execute: { task(result) })
  }

  /// Query the current state of this `Deferred`
  ///
  /// - returns: a `DeferredState` (`.waiting`, `.executing` or `.determined`)

  public var state: DeferredState {
    if stateid.load() == 0 { return .waiting }
    if waiters.load(order: .relaxed) == Waiter.invalid  { return .determined }
    return .executing
  }

  /// Query whether this `Deferred` has been determined.
  ///
  /// - returns: wheither this `Deferred` has been determined.

  public var isDetermined: Bool {
    return waiters.load(order: .relaxed) == Waiter.invalid
  }

  /// Attempt to cancel the current operation, and report on whether cancellation happened successfully.
  /// A successful cancellation will result in a `Deferred` equivalent as if it had been initialized as follows:
  /// ```
  /// Deferred<Value>(error: DeferredError.canceled(reason))
  /// ```
  ///
  /// - parameter reason: a `String` detailing the reason for the attempted cancellation.
  /// - returns: whether the cancellation was performed successfully.

  @discardableResult
  open func cancel(_ reason: String = "") -> Bool
  {
    return determine(Result.error(DeferredError.canceled(reason)))
  }

  /// Get this `Deferred`'s value if it has been determined, `nil` otherwise.
  /// (This call does not block)
  ///
  /// - returns: this `Deferred`'s value, or `nil`

  public func peek() -> Result<Value>?
  {
    if waiters.load(order: .acquire) == Waiter.invalid
    {
      return resulto
    }
    return nil
  }

  /// Get this `Deferred`'s value as a `Result`, blocking if necessary until it becomes determined.
  ///
  /// - returns: this `Deferred`'s determined result

  public var result: Result<Value> {
    if waiters.load(order: .acquire) != Waiter.invalid
    {
      let s = DispatchSemaphore(value: 0)
      self.notify(qos: DispatchQoS.current) { _ in s.signal() }
      s.wait()
    }

    // this Deferred is determined
    return resulto!
  }

  /// Get this `Deferred` value, blocking if necessary until it becomes determined.
  /// If the `Deferred` is determined by a `Result` in the `.error` state, return nil.
  /// In either case, this property will block until `Deferred` is determined.
  ///
  /// - returns: this `Deferred`'s determined value, or `nil`

  public var value: Value? {
    if case let .value(v) = result { return v }
    return nil
  }

  /// Get this `Deferred` value, blocking if necessary until it becomes determined.
  /// If the `Deferred` is determined by a `Result` in the `.error` state, return nil.
  /// In either case, this property will block until `Deferred` is determined.
  ///
  /// - returns: this `Deferred`'s determined value, or `nil`

  public var error: Error? {
    if case let .error(e) = result { return e }
    return nil
  }

  /// Get the quality-of-service class of this `Deferred`'s queue
  /// - returns: the quality-of-service class of this `Deferred`'s queue

  public var qos: DispatchQoS { return self.queue.qos }

  /// Set the queue to be used for future notifications
  /// - parameter queue: the queue to be used by the returned `Deferred`
  /// - returns: a new `Deferred` whose notifications will execute on `queue`

  public func notifying(on queue: DispatchQueue) -> Deferred
  {
    if waiters.load(order: .acquire) == Waiter.invalid
    {
      return Deferred(queue: queue, result: resulto!)
    }

    let deferred = Deferred(queue: queue)
    self.notify(qos: queue.qos, task: { deferred.determine($0) })
    return deferred
  }

  /// Set the quality-of-service to use for future notifications.
  /// The returned `Deferred` will issue notifications on a concurrent queue at the specified quality-of-service class.
  /// - parameter qos: the quality-of-service class to be used by the returned `Deferred`
  /// - returns: a new `Deferred` whose notifications will run at quality-of-service `qos`

  public func notifying(at qos: DispatchQoS, serially: Bool = false) -> Deferred
  {
    let queue = DispatchQueue(label: "deferred", qos: qos, attributes: serially ? [] : .concurrent)
    return notifying(on: queue)
  }
}


/// A mapped `Deferred`

internal final class Mapped<Value>: Deferred<Value>
{
  /// Initialize with a `Deferred` source and a transform to be computed in the background
  /// This constructor is used by `map`
  ///
  /// - parameter queue:     the `DispatchQueue` onto which the computation should be enqueued
  /// - parameter qos:       the QOS class at which to execute the transform; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter source:    the `Deferred` whose value should be used as the input for the transform
  /// - parameter transform: the transform to be applied to `source.value` and whose result is represented by this `Deferred`

  init<U>(qos: DispatchQoS?, source: Deferred<U>, transform: @escaping (U) throws -> Value)
  {
    super.init(queue: source.queue)

    source.notify(qos: qos) {
      result in
      if self.isDetermined { return }
      self.beginExecution()
      let transformed = result.map(transform)
      self.determine(transformed) // an error here means this `Deferred` has been canceled.
    }
  }

  /// Initialize with a `Deferred` source and a transform to be computed in the background
  /// This constructor is used by the version of `map` that uses a transform to a `Result`.
  ///
  /// - parameter queue:     the `DispatchQueue` onto which the computation should be enqueued
  /// - parameter qos:       the QOS class at which to execute the transform; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter source:    the `Deferred` whose value should be used as the input for the transform
  /// - parameter transform: the transform to be applied to `source.value` and whose result is represented by this `Deferred`

  init<U>(qos: DispatchQoS?, source: Deferred<U>, transform: @escaping (U) -> Result<Value>)
  {
    super.init(queue: source.queue)

    source.notify(qos: qos) {
      result in
      if self.isDetermined { return }
      self.beginExecution()
      let transformed = result.flatMap(transform)
      self.determine(transformed) // an error here means this `Deferred` has been canceled.
    }
  }
}

internal final class Bind<Value>: Deferred<Value>
{
  /// Initialize with a `Deferred` source and a transform to be computed in the background
  /// This constructor is used by `flatMap`
  ///
  /// - parameter queue:     the `DispatchQueue` onto which the computation should be enqueued
  /// - parameter qos:       the QOS class at which to execute the transform; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter source:    the `Deferred` whose value should be used as the input for the transform
  /// - parameter transform: the transform to be applied to `source.value` and whose result is represented by this `Deferred`

  init<U>(qos: DispatchQoS?, source: Deferred<U>, transform: @escaping (U) -> Deferred<Value>)
  {
    super.init(queue: source.queue)

    source.notify(qos: qos) {
      result in
      if self.isDetermined { return }
      self.beginExecution()
      switch result
      {
      case .value(let value):
        transform(value).notify(qos: qos) {
          transformed in
          self.determine(transformed) // an error here means this `Deferred` has been canceled.
        }

      case .error(let error):
        self.determine(Result.error(error)) // an error here means this `Deferred` has been canceled.
      }
    }
  }

  /// Initialize with a `Deferred` source and a transform to be computed in the background
  /// This constructor is used by `recover` -- flatMap for the `ErrorType` path.
  ///
  /// - parameter queue:     the `DispatchQueue` onto which the computation should be enqueued
  /// - parameter qos:       the QOS class at which to execute the transform; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter source:    the `Deferred` whose value should be used as the input for the transform
  /// - parameter transform: the transform to be applied to `source.value` and whose result is represented by this `Deferred`

  init(qos: DispatchQoS?, source: Deferred<Value>, transform: @escaping (Error) -> Deferred<Value>)
  {
    super.init(queue: source.queue)

    source.notify(qos: qos) {
      result in
      if self.isDetermined { return }
      self.beginExecution()
      switch result
      {
      case .value:
        self.determine(result)

      case .error(let error):
        transform(error).notify(qos: qos) {
          transformed in
          self.determine(transformed)
        }
      }
    }
  }
}

/// A `Deferred` that applies a `Deferred` transform onto its input

internal final class Applicator<Value>: Deferred<Value>
{
  /// Initialize with a `Deferred` source and a transform to be computed in the background
  /// This constructor is used by `apply`
  ///
  /// - parameter queue:     the `DispatchQueue` onto which the computation should be enqueued
  /// - parameter qos:       the QOS class at which to execute the transform; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter source:    the `Deferred` whose value should be used as the input for the transform
  /// - parameter transform: the transform to be applied to `source.value` and whose result is represented by this `Deferred`

  init<U>(qos: DispatchQoS?, source: Deferred<U>, transform: Deferred<(U) -> Result<Value>>)
  {
    super.init(queue: source.queue)

    source.notify(qos: qos) {
      result in
      if self.isDetermined { return }
      switch result
      {
      case .value:
        transform.notifying(on: self.queue).notify(qos: qos) {
          transform in
          if self.isDetermined { return }
          self.beginExecution()
          let transformed = result.apply(transform)
          self.determine(transformed) // an error here means this `Deferred` has been canceled.
        }

      case .error(let error):
        self.beginExecution()
        self.determine(Result.error(error)) // an error here means this `Deferred` has been canceled.
      }
    }
  }

  /// Initialize with a `Deferred` source and a transform to be computed in the background
  /// This constructor is used by `apply`
  ///
  /// - parameter queue:     the `DispatchQueue` onto which the computation should be enqueued
  /// - parameter qos:       the QOS class at which to execute the transform; defaults to the QOS class of this `Deferred`'s queue.
  /// - parameter source:    the `Deferred` whose value should be used as the input for the transform
  /// - parameter transform: the transform to be applied to `source.value` and whose result is represented by this `Deferred`

  init<U>(qos: DispatchQoS?, source: Deferred<U>, transform: Deferred<(U) throws -> Value>)
  {
    super.init(queue: source.queue)

    source.notify(qos: qos) {
      result in
      if self.isDetermined { return }
      switch result
      {
      case .value:
        transform.notifying(on: self.queue).notify(qos: qos) {
          transform in
          if self.isDetermined { return }
          self.beginExecution()
          let transformed = result.apply(transform)
          self.determine(transformed) // an error here means this `Deferred` has been canceled.
        }

      case .error(let error):
        self.beginExecution()
        self.determine(Result.error(error)) // an error here means this `Deferred` has been canceled.
      }
    }
  }
}

/// A `Deferred` with a time-delay

internal final class Delayed<Value>: Deferred<Value>
{
  /// Initialize with a `Deferred` source and a time after which this `Deferred` may become determined.
  /// The determination could be delayed further if `source` has not become determined yet,
  /// but it will not happen earlier than the time referred to by `until`.
  /// This constructor is used by `delay`
  ///
  /// - parameter source: the `Deferred` whose value should be delayed
  /// - parameter until:  the target time until which the determination of this `Deferred` will be delayed

  init(source: Deferred<Value>, until time: DispatchTime)
  {
    super.init(queue: source.queue)

    source.notify {
      result in
      if self.isDetermined { return }

      if case .value = result, time > DispatchTime.now()
      {
        self.beginExecution()
        if time != .distantFuture
        { // enqueue block only if can get executed
          self.queue.asyncAfter(deadline: time) { self.determine(result) }
        }
      }
      else
      {
        self.determine(result) // an error here means this `Deferred` has been canceled.
      }
    }
  }
}

/// A `Deferred` to be determined (`TBD`) manually.

open class TBD<Value>: Deferred<Value>
{
  /// Initialize an undetermined `Deferred`, `TBD`.
  ///
  /// - parameter queue: the `DispatchQueue` on which the notifications will be executed

  public override init(queue: DispatchQueue)
  {
    super.init(queue: queue)
  }

  /// Initialize an undetermined `Deferred`, `TBD`.
  ///
  /// - parameter qos: the Quality-of-Service class at which the notifications should be performed; defaults to the current quality-of-service class.

  public convenience init(qos: DispatchQoS = DispatchQoS.current ?? .default)
  {
    let queue = DispatchQueue.global(qos: qos.qosClass)
    self.init(queue: queue)
  }

  /// Set the value of this `Deferred` and change its state to `DeferredState.determined`
  /// Note that a `Deferred` can only be determined once.
  ///
  /// - parameter value: the intended value for this `Deferred`
  /// - returns: whether the call succesfully changed the state of this `Deferred`.

  @discardableResult
  public func determine(_ value: Value) -> Bool
  {
    return determine(Result.value(value))
  }

  /// Set this `Deferred` to an error and change its state to `DeferredState.determined`
  /// Note that a `Deferred` can only be determined once. On subsequent calls, `determine` will throw an `AlreadyDetermined` error.
  ///
  /// - parameter error: the intended error for this `Deferred`
  /// - returns: whether the call succesfully changed the state of this `Deferred`.

  @discardableResult
  public func determine(_ error: Error) -> Bool
  {
    return determine(Result.error(error))
  }

  /// Set the `Result` of this `Deferred` and change its state to `DeferredState.determined`
  /// Note that a `Deferred` can only be determined once. On subsequent calls, `determine` will throw an `AlreadyDetermined` error.
  ///
  /// - parameter result: the intended `Result` for this `Deferred`
  /// - returns: whether the call succesfully changed the state of this `Deferred`.

  @discardableResult
  public override func determine(_ result: Result<Value>) -> Bool
  {
    return super.determine(result)
  }

  /// Change the state of this `TBD` from `.waiting` to `.executing`

  open override func beginExecution()
  {
    super.beginExecution()
  }
}
