//
//  deferred-combine.swift
//  async-deferred
//
//  Created by Guillaume Lessard on 06/11/2015.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import Dispatch

// combine two or more Deferred objects into one.

/// Combine an array of `Deferred`s into a new `Deferred` whose value is an array.
/// The combined `Deferred` will become determined after every input `Deferred` is determined.
///
/// If any of the elements resolves to an error, the combined `Deferred` will contain that error.
/// The combined `Deferred` will use the queue from the first element of the input array (unless the input array is empty.)
///
/// - parameter deferreds: an array of `Deferred`
/// - returns: a new `Deferred`

public func combine<Value>(qos: DispatchQoS = DispatchQoS.current ?? .default,
                           _ deferreds: [Deferred<Value>]) -> Deferred<[Value]>
{
  var combined = [Value]()
  combined.reserveCapacity(deferreds.count)

  let reduced = reduce(qos: qos, deferreds, initial: (), combine: { _, value in combined.append(value) })
  return reduced.map { _ in combined }
}

/// Combine a Sequence of `Deferred`s into a new `Deferred` whose value is an array.
/// The combined `Deferred` will become determined after every input `Deferred` has become determined.
///
/// If any of the elements resolves to an error, the combined `Deferred` will contain that error.
/// The combined `Deferred` will use the concurrent queue at the current qos class.
///
/// - parameter deferreds: an array of `Deferred`
/// - returns: a new `Deferred`

public func combine<Value, S: Sequence>(qos: DispatchQoS = DispatchQoS.current ?? .default,
                                        _ deferreds: S) -> Deferred<[Value]>
  where S.Iterator.Element == Deferred<Value>
{
  var combined = [Value]()

  let reduced = reduce(qos: qos, deferreds, initial: (), combine: { _, value in combined.append(value) })
  return reduced.map { _ in combined }
}

/// Returns the result of repeatedly calling `combine` with an
/// accumulated value initialized to `initial` and each element of
/// `deferreds`, in turn. That is, return a deferred version of
/// `combine(combine(...combine(combine(initial, deferreds[0].value),
/// deferreds[1].value),...deferreds[count-2].value), deferreds[count-1].value)`.
///
/// If any of the elements resolves to an error, the resulting `Deferred` will contain that error.
/// If the reducing function throws an error, the resulting `Deferred` will contain that error.
/// The combined `Deferred` will use the qos from the first element of the input array (unless the input array is empty.)
///
/// - parameter qos: the Quality-of-Service at which the `reduce` operation and its notifications should occur; defaults to the current QoS
/// - parameter deferreds: an array of `Deferred`
/// - parameter combine: a reducing function
/// - returns: a new `Deferred`

public func reduce<T, U>(qos: DispatchQoS = DispatchQoS.current ?? .default, _ deferreds: [Deferred<T>],
                         initial: U, combine: @escaping (U,T) throws -> U) -> Deferred<U>
{
  guard deferreds.isEmpty == false
    else { return Deferred(qos: qos, result: Result.value(initial)) }

  let queue = DispatchQueue(label: "reduce-collection", qos: qos)
  let accumulator = Deferred(queue: queue, result: Result.value(initial))

  let reduced = deferreds.reduce(accumulator) {
    (accumulator, deferred) in
    accumulator.flatMap {
      u in deferred.notifying(on: queue).map { t in try combine(u,t) }
    }
  }

  return reduced
}

/// Returns the result of repeatedly calling `combine` with an
/// accumulated value initialized to `initial` and each element of
/// `deferreds`, in turn. That is, return a deferred version of
/// `combine(combine(...combine(combine(initial, deferreds[0].value),
/// deferreds[1].value),...deferreds[count-2].value), deferreds[count-1].value)`.
/// (Never mind that you can't index a Sequence.)
///
/// If any of the elements resolves to an error, the resulting `Deferred` will contain that error.
/// If the reducing function throws an error, the resulting `Deferred` will contain that error.
/// The combined `Deferred` will use a serial queue at the current qos class.
///
/// - parameter deferreds: an array of `Deferred`
/// - parameter combine: a reducing function
/// - returns: a new `Deferred`

public func reduce<S: Sequence, T, U>(qos: DispatchQoS = DispatchQoS.current ?? .default, _ deferreds: S,
                                      initial: U, combine: @escaping (U,T) throws -> U) -> Deferred<U>
  where S.Iterator.Element == Deferred<T>
{
  let queue = DispatchQueue(label: "reduce-sequence", qos: qos)
  let accumulator = Deferred(queue: queue, result: Result.value(initial))

  // We iterate on a background thread because S could block on next()
  let reduced = Deferred<Deferred<U>>(queue: queue) {
    deferreds.reduce(accumulator) {
      (accumulator, deferred) in
      accumulator.flatMap {
        u in deferred.notifying(on: queue).map { t in try combine(u,t) }
      }
    }
  }

  return reduced.flatMap { $0 }
}

/// Combine two `Deferred` into one.
/// The returned `Deferred` will become determined after both inputs are determined.
/// If either of the elements resolves to an error, the combined `Deferred` will be an error.
/// The combined `Deferred` will use the queue from the first input, `d1`.
///
/// - parameter d1: a `Deferred`
/// - parameter d2: a second `Deferred` to combine with `d1`
/// - returns: a new `Deferred` whose value shall be a tuple of `d1.value` and `d2.value`

public func combine<T1,T2>(_ d1: Deferred<T1>, _ d2: Deferred<T2>) -> Deferred<(T1,T2)>
{
  return d1.flatMap { t1 in d2.map { t2 in (t1,t2) } }
}

/// Combine three `Deferred` into one.
/// The returned `Deferred` will become determined after all inputs are determined.
/// If any of the elements resolves to an error, the combined `Deferred` will be an error.
/// The combined `Deferred` will use the queue from the first input, `d1`.
///
/// - parameter d1: a `Deferred`
/// - parameter d2: a second `Deferred` to combine
/// - parameter d3: a third `Deferred` to combine
/// - returns: a new `Deferred` whose value shall be a tuple of the inputs's values

public func combine<T1,T2,T3>(_ d1: Deferred<T1>, _ d2: Deferred<T2>, _ d3: Deferred<T3>) -> Deferred<(T1,T2,T3)>
{
  return combine(d1,d2).flatMap { (t1,t2) in d3.map { t3 in (t1,t2,t3) } }
}

/// Combine four `Deferred` into one.
/// The returned `Deferred` will become determined after all inputs are determined.
/// If any of the elements resolves to an error, the combined `Deferred` will be an error.
/// The combined `Deferred` will use the queue from the first input, `d1`.
///
/// - parameter d1: a `Deferred`
/// - parameter d2: a second `Deferred` to combine
/// - parameter d3: a third `Deferred` to combine
/// - parameter d4: a fourth `Deferred` to combine
/// - returns: a new `Deferred` whose value shall be a tuple of the inputs's values

public func combine<T1,T2,T3,T4>(_ d1: Deferred<T1>, _ d2: Deferred<T2>, _ d3: Deferred<T3>, _ d4: Deferred<T4>) -> Deferred<(T1,T2,T3,T4)>
{
  return combine(d1,d2,d3).flatMap { (t1,t2,t3) in d4.map { t4 in (t1,t2,t3,t4) } }
}

/// Return the value of the first of an array of `Deferred`s to be determined.
/// Note that if the array is empty the resulting `Deferred` will resolve to a
/// `DeferredError.canceled` error.
/// Note also that if more than one element is already determined at the time
/// the function is called, the earliest one will be considered first; if this
/// biasing is a problem, consider shuffling the array first.
///
/// - parameter deferreds: an array of `Deferred`
/// - returns: a new `Deferred`

public func firstValue<Value, C: Collection>(qos: DispatchQoS = DispatchQoS.current ?? .default,
                                             _ deferreds: C, cancelOthers: Bool = false) -> Deferred<Value>
  where C.Iterator.Element: Deferred<Value>
{
  return firstDetermined(qos: qos, deferreds, cancelOthers: cancelOthers).flatMap { $0 }
}

public func firstValue<Value, S: Sequence>(qos: DispatchQoS = DispatchQoS.current ?? .default,
                                           _ deferreds: S, cancelOthers: Bool = false) -> Deferred<Value>
  where S.Iterator.Element: Deferred<Value>
{
  return firstDetermined(qos: qos, deferreds, cancelOthers: cancelOthers).flatMap { $0 }
}

/// Return the first of an array of `Deferred`s to become determined.
/// Note that if the array is empty the resulting `Deferred` will resolve to a
/// `DeferredError.canceled` error.
/// Note also that if more than one element is already determined at the time
/// the function is called, the earliest one will be considered first; if this
/// biasing is a problem, consider shuffling the array first.
///
/// - parameter deferreds: an array of `Deferred`
/// - returns: a new `Deferred`

public func firstDetermined<Value, C: Collection>(qos: DispatchQoS = DispatchQoS.current ?? .default,
                                                  _ deferreds: C, cancelOthers: Bool = false) -> Deferred<Deferred<Value>>
  where C.Iterator.Element: Deferred<Value>
{
  if deferreds.count == 0
  {
    let error = DeferredError.canceled("cannot find first determined from an empty set in \(#function)")
    return Deferred(qos: qos, result: Result.error(error))
  }

  let queue = DispatchQueue(label: "first-collection", qos: qos, attributes: .concurrent)
  let first = TBD<Deferred<Value>>(queue: queue)

  deferreds.forEach {
    deferred in
    deferred.notify { first.determine($0) }
    if cancelOthers { first.notify { _ in deferred.cancel() } }
  }

  return first
}

public func firstDetermined<Value, S: Sequence>(qos: DispatchQoS = DispatchQoS.current ?? .default,
                                                _ deferreds: S, cancelOthers: Bool = false) -> Deferred<Deferred<Value>>
  where S.Iterator.Element: Deferred<Value>
{
  let queue = DispatchQueue(label: "first-sequence", qos: qos, attributes: .concurrent)
  let first = TBD<Deferred<Value>>(queue: queue)

  // We iterate on a background thread because the sequence (type S) could block on next()
  queue.async {
    var subscribed = false
    deferreds.forEach {
      deferred in
      subscribed = true
      deferred.notify { first.determine($0) }
      if cancelOthers { first.notify { _ in deferred.cancel() } }
    }

    if !subscribed
    {
      first.cancel("cannot find first determined from an empty set in \(#function)")
    }
  }

  return first
}
