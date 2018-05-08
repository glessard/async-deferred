//
//  nsurlsession.swift
//  deferred
//
//  Created by Guillaume Lessard on 10/02/2016.
//  Copyright © 2016 Guillaume Lessard. All rights reserved.
//

import Dispatch

import Foundation
//import struct Foundation.Data
//import class  Foundation.FileHandle
//import struct Foundation.URL
//import struct Foundation.URLError
//import struct Foundation.URLRequest
//import class  Foundation.URLSession
//import class  Foundation.URLSessionTask
//import class  Foundation.URLSessionDownloadTask
//import let    Foundation.NSURLSessionDownloadTaskResumeData
//import class  Foundation.URLSessionUploadTask
//import class  Foundation.URLResponse
//import class  Foundation.HTTPURLResponse

public enum URLSessionError: Error
{
  case ServerStatus(Int)
  case InterruptedDownload(URLError, Data)
  case InvalidState
}

class DeferredURLSessionTask<Value>: Transfer<Value>
{
  public let urlSessionTask: URLSessionTask

  init(source: TBD<Value>, task: URLSessionTask)
  {
    urlSessionTask = task
    super.init(queue: source.queue, source: source)
  }

  @discardableResult
  public override func cancel(_ reason: String = "") -> Bool
  {
    guard !self.isDetermined else { return false }

    // try to propagate the cancellation upstream
    urlSessionTask.cancel()
    return true
  }

  public override func enqueue(queue: DispatchQueue? = nil, boostQoS: Bool = true, task: @escaping (Determined<Value>) -> Void)
  {
    if state == .waiting
    {
      beginExecution()
    }
    super.enqueue(queue: queue, boostQoS: boostQoS, task: task)
  }

  public override func beginExecution()
  {
    urlSessionTask.resume()
    super.beginExecution()
  }
}

public extension URLSession
{
  private func dataCompletion(_ tbd: TBD<(Data, HTTPURLResponse)>) -> (Data?, URLResponse?, Error?) -> Void
  {
    return {
      [weak tbd] (data: Data?, response: URLResponse?, error: Error?) in
      guard let tbd = tbd else { return }

      if let error = error
      {
        tbd.determine(error)
        return
      }

      if let d = data, let r = response as? HTTPURLResponse
      {
        tbd.determine( (d,r) )
        return
      }
      // Probably an impossible situation
      tbd.determine(URLSessionError.InvalidState)
    }
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with request: URLRequest) -> Deferred<(Data, HTTPURLResponse)>
  {
    guard let scheme = request.url?.scheme, scheme == "http" || scheme == "https"
    else {
      let e = DeferredError.invalid(
        "deferred does not support url scheme \"\(request.url?.scheme! ?? "unknown")\""
      )
      return Deferred(error: e)
    }

    let tbd = TBD<(Data, HTTPURLResponse)>(qos: qos)
    let task = dataTask(with: request, completionHandler: dataCompletion(tbd))
    return DeferredURLSessionTask(source: tbd, task: task)
  }

  public func deferredDataTask(qos: DispatchQoS = .current,
                               with url: URL) -> Deferred<(Data, HTTPURLResponse)>
  {
    return deferredDataTask(qos: qos, with: URLRequest(url: url))
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromData bodyData: Data) -> Deferred<(Data, HTTPURLResponse)>
  {
    guard let scheme = request.url?.scheme, scheme == "http" || scheme == "https"
      else {
        let e = DeferredError.invalid(
          "deferred does not support url scheme \"\(request.url?.scheme! ?? "unknown")\""
        )
        return Deferred(error: e)
    }

    let tbd = TBD<(Data, HTTPURLResponse)>(qos: qos)
    let task = uploadTask(with: request, from: bodyData, completionHandler: dataCompletion(tbd))
    return DeferredURLSessionTask(source: tbd, task: task)
  }

  public func deferredUploadTask(qos: DispatchQoS = .current,
                                 with request: URLRequest, fromFile fileURL: URL) -> Deferred<(Data, HTTPURLResponse)>
  {
    guard let scheme = request.url?.scheme, scheme == "http" || scheme == "https"
      else {
        let e = DeferredError.invalid(
          "deferred does not support url scheme \"\(request.url?.scheme! ?? "unknown")\""
        )
        return Deferred(error: e)
    }

    let tbd = TBD<(Data, HTTPURLResponse)>(qos: qos)
    let task = uploadTask(with: request, fromFile: fileURL, completionHandler: dataCompletion(tbd))
    return DeferredURLSessionTask(source: tbd, task: task)
  }
}

private class DeferredDownloadTask<Value>: DeferredURLSessionTask<Value>
{
  @discardableResult
  override func cancel(_ reason: String = "") -> Bool
  {
    guard !self.isDetermined else { return false }

    guard let task = urlSessionTask as? URLSessionDownloadTask
    else { return super.cancel(reason) }

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    // try to propagate the cancellation upstream
    task.cancel(byProducingResumeData: { _ in }) // Let the completion handler collect the data for resuming.
    return true
#else // swift-corelibs-foundation calls fatalError() when cancel(byProducingResumeData:) is called
    task.cancel()
    return true
#endif
  }
}

extension URLSession
{
  private func downloadCompletion(_ tbd: TBD<(URL, FileHandle, HTTPURLResponse)>) -> (URL?, URLResponse?, Error?) -> Void
  {
    return {
      [weak tbd] (location: URL?, response: URLResponse?, error: Error?) in
      guard let tbd = tbd else { return }

      if let error = error
      {
        if let error = error as? URLError, error.code == .cancelled
        {
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
          // rdar://29623544 and https://bugs.swift.org/browse/SR-3403
          let URLSessionDownloadTaskResumeData = NSURLSessionDownloadTaskResumeData
#endif
          if let data = error.userInfo[URLSessionDownloadTaskResumeData] as? Data
          { tbd.determine(URLSessionError.InterruptedDownload(error, data)) }
          else
          { tbd.determine(DeferredError.canceled(error.localizedDescription)) }
        }
        else
        { tbd.determine(error) }
        return
      }

      if let u = location, let r = response as? HTTPURLResponse
      {
        do {
          let f = try FileHandle(forReadingFrom: u)
          tbd.determine( (u,f,r) )
        }
        catch {
          // Likely an impossible situation
          tbd.determine(error)
        }
        return
      }
      // Probably an impossible situation
      tbd.determine(URLSessionError.InvalidState)
    }
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with request: URLRequest) -> Deferred<(URL, FileHandle, HTTPURLResponse)>
  {
    guard let scheme = request.url?.scheme, scheme == "http" || scheme == "https"
      else {
        let e = DeferredError.invalid(
          "deferred does not support url scheme \"\(request.url?.scheme! ?? "unknown")\""
        )
        return Deferred(error: e)
    }

    let tbd = TBD<(URL, FileHandle, HTTPURLResponse)>(qos: qos)
    let task = downloadTask(with: request, completionHandler: downloadCompletion(tbd))
    return DeferredDownloadTask(source: tbd, task: task)
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   with url: URL) -> Deferred<(URL, FileHandle, HTTPURLResponse)>
  {
    return deferredDownloadTask(qos: qos, with: URLRequest(url: url))
  }

  public func deferredDownloadTask(qos: DispatchQoS = .current,
                                   withResumeData data: Data) -> Deferred<(URL, FileHandle, HTTPURLResponse)>
  {
    let tbd = TBD<(URL, FileHandle, HTTPURLResponse)>(qos: qos)

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    let task = downloadTask(withResumeData: data, completionHandler: downloadCompletion(tbd))
    return DeferredDownloadTask(source: tbd, task: task)
#else // swift-corelibs-foundation calls fatalError() when downloadTask(withResumeData:) is called
    // let task = downloadTask(withResumeData: data, completionHandler: downloadCompletion(tbd))
    tbd.cancel(.invalid("swift-corelibs-foundation does not support \(#function)"))
    return DeferredDownloadTask(source: tbd, task: URLSessionDownloadTask())
#endif
  }
}
