//
//  determined.swift
//  deferred
//
//  Created by Guillaume Lessard on 9/26/17.
//  Copyright © 2017 Guillaume Lessard. All rights reserved.
//

public struct Determined<Value>
{
  private let state: State<Value>

  init(_ value: Value)
  {
    state = .value(value)
  }

  init(_ error: Error)
  {
    state = .error(error)
  }

  public func get() throws -> Value
  {
    switch state
    {
    case .value(let value): return value
    case .error(let error): throw error
    }
  }

  public var value: Value? {
    if case .value(let value) = state { return value }
    return nil
  }

  public var error: Error? {
    if case .error(let error) = state { return error }
    return nil
  }

  public var isValue: Bool {
    if case .value = state { return true }
    return false
  }

  public var isError: Bool {
    if case .error = state { return true }
    return false
  }
}

private enum State<Value>
{
  case value(Value)
  case error(Error)
}
