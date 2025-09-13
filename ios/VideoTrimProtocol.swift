//
//  VideoTrimProtocol.swift
//  VideoTrim
//
//  Created by Duc Trung Mai on 9/11/25.
//

@objc public protocol VideoTrimProtocol {
  func emitEventToJS(eventName: String, body: [String: Any]?)
}
