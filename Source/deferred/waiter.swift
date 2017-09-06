//
//  waiter.swift
//  async-deferred
//
//  Created by Guillaume Lessard on 2015-07-13.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import Dispatch

struct Waiter<T>
{
  private let qos: DispatchQoS?
  private let handler: (Deferred<T>) -> Void
  var next: UnsafeMutablePointer<Waiter<T>>? = nil

  init(_ qos: DispatchQoS? = nil, _ handler: @escaping (Deferred<T>) -> Void)
  {
    self.qos = qos
    self.handler = handler
  }

  fileprivate func notify(_ queue: DispatchQueue, _ result: Deferred<T>)
  {
    queue.async(qos: qos) { [ handler = self.handler ] in handler(result) }
  }
}

func notifyWaiters<T>(_ queue: DispatchQueue, _ tail: UnsafeMutablePointer<Waiter<T>>?, _ deferred: Deferred<T>)
{
  var head = reverseList(tail)
  while let current = head
  {
    head = current.pointee.next

    current.pointee.notify(queue, deferred)

    current.deinitialize(count: 1)
    current.deallocate(capacity: 1)
  }
}

func deallocateWaiters<T>(_ tail: UnsafeMutablePointer<Waiter<T>>?)
{
  var waiter = tail
  while let current = waiter
  {
    waiter = current.pointee.next

    current.deinitialize(count: 1)
    current.deallocate(capacity: 1)
  }
}

private func reverseList<T>(_ tail: UnsafeMutablePointer<Waiter<T>>?) -> UnsafeMutablePointer<Waiter<T>>?
{
  if tail != nil && tail!.pointee.next != nil
  {
    var head: UnsafeMutablePointer<Waiter<T>>? = nil
    var current = tail
    while let element = current
    {
      current = element.pointee.next

      element.pointee.next = head
      head = element
    }
    return head
  }
  return tail
}
