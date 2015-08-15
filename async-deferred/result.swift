//
//  Result.swift
//  swiftiandispatch
//
//  Created by Guillaume Lessard on 2015-07-16.
//  Copyright © 2015 Guillaume Lessard. All rights reserved.
//

import Foundation

// A Result type, approximately like everyone else has done.

public enum Result<T>: CustomStringConvertible
{
  case Value(T)
  case Error(ErrorType)

  public init(value: T)
  {
    self = .Value(value)
  }

  public init(error: ErrorType)
  {
    self = .Error(error)
  }

  public init(@noescape task: () throws -> T)
  {
    do {
      let v = try task()
      self = .Value(v)
    }
    catch {
      self = .Error(error)
    }
  }


  public var value: T? {
    switch self
    {
    case .Value(let value): return value
    case .Error:            return nil
    }
  }

  public var error: ErrorType? {
    switch self
    {
    case .Value:            return nil
    case .Error(let error): return error
    }
  }

  public func asValue() throws -> T
  {
    switch self
    {
    case .Value(let value): return value
    case .Error(let error): throw error
    }
  }


  public var description: String {
    switch self
    {
    case .Value(let value): return "\(value)"
    case .Error(let error): return "Error: \(error)"
    }
  }


  public func map<U>(transform: (T) throws -> U) -> Result<U>
  {
    switch self
    {
    case .Value(let value): return Result<U> { try transform(value) }
    case .Error(let error): return .Error(error)
    }
  }

  public func flatMap<U>(transform: (T) -> Result<U>) -> Result<U>
  {
    switch self
    {
    case .Value(let value): return transform(value)
    case .Error(let error): return .Error(error)
    }
  }

  public func apply<U>(transform: Result<(T) throws -> U>) -> Result<U>
  {
    switch (self, transform)
    {
    case (.Value(let value), .Value(let transform)):
      return Result<U> { try transform(value) }

    case (.Value, .Error(let error)):
      return .Error(error)

    case (.Error(let error), _):
      return .Error(error)

    default: fatalError("The compiler made me do it.")
    }
  }
}

public func ?? <T> (possible: Result<T>, @autoclosure alternate: () -> T) -> T
{
  switch possible
  {
  case .Value(let value): return value
  case .Error:            return alternate()
  }
}