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
  private let queue: DispatchQueue?
  private let handler: (Determined<T>) -> Void
  var next: UnsafeMutablePointer<Waiter<T>>? = nil

  init(_ queue: DispatchQueue?, _ handler: @escaping (Determined<T>) -> Void)
  {
    self.queue = queue
    self.handler = handler
  }

  fileprivate func notify(_ queue: DispatchQueue, _ value: Determined<T>)
  {
    let q = self.queue ?? queue
    q.async { [handler = self.handler] in handler(value) }
  }
}

func notifyWaiters<T>(_ queue: DispatchQueue, _ tail: UnsafeMutablePointer<Waiter<T>>?, _ value: Determined<T>)
{
  var head = reverseList(tail)
  while let current = head
  {
    head = current.pointee.next

    current.pointee.notify(queue, value)

    current.deinitialize(count: 1)
#if swift(>=4.1)
    current.deallocate()
#else
    current.deallocate(capacity: 1)
#endif
  }
}

func deallocateWaiters<T>(_ tail: UnsafeMutablePointer<Waiter<T>>?)
{
  var waiter = tail
  while let current = waiter
  {
    waiter = current.pointee.next

    current.deinitialize(count: 1)
#if swift(>=4.1)
    current.deallocate()
#else
    current.deallocate(capacity: 1)
#endif
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
