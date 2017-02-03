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
  private let qos: DispatchQoS
  private let handler: (Result<T>) -> Void
  var next: UnsafeMutablePointer<Waiter<T>>? = nil

  init(_ qos: DispatchQoS, _ handler: @escaping (Result<T>) -> Void)
  {
    self.qos = qos
    self.handler = handler
  }

  fileprivate func notify(_ queue: DispatchQueue, _ result: Result<T>)
  {
    let closure = { [ handler = self.handler ] in handler(result) }

    if qos == .unspecified
    {
      queue.async(execute: closure)
    }
    else
    {
      queue.async(qos: qos, flags: [.enforceQoS], execute: closure)
    }
  }

  static var invalid: UnsafeMutablePointer<Waiter<T>>? {
    return UnsafeMutablePointer(bitPattern: 0x7)
  }
}

enum WaitQueue
{
  static func notifyAll<T>(_ queue: DispatchQueue, _ tail: UnsafeMutablePointer<Waiter<T>>?, _ result: Result<T>)
  {
    var head = reverseList(tail)
    while let current = head
    {
      head = current.pointee.next

      current.pointee.notify(queue, result)

      current.deinitialize(count: 1)
      current.deallocate(capacity: 1)
    }
  }

  static func dealloc<T>(_ tail: UnsafeMutablePointer<Waiter<T>>?)
  {
    var waiter = tail
    while let current = waiter
    {
      waiter = current.pointee.next

      current.deinitialize(count: 1)
      current.deallocate(capacity: 1)
    }
  }

  private static func reverseList<T>(_ tail: UnsafeMutablePointer<Waiter<T>>?) -> UnsafeMutablePointer<Waiter<T>>?
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
}