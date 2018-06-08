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

  init(value: Value)
  {
    state = .value(value)
  }

  init(error: Error)
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

#if swift (>=4.1)
extension Determined: Equatable where Value: Equatable
{
  public static func ==(lhs: Determined, rhs: Determined) -> Bool
  {
    switch (lhs.state, rhs.state)
    {
    case (.value(let lhv), .value(let rhv)):
      return lhv == rhv
    case (.error(let lhe), .error(let rhe)):
      return String(describing: lhe) == String(describing: rhe)
    default:
      return false
    }
  }
}
#endif

enum State<Value>
{
  case value(Value)
  case error(Error)
}
