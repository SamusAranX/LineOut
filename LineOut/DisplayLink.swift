//
//  DisplayLink.swift
//  LineOut
//
//  Created by Peter Wunder on 29.06.19.
//  Copyright © 2019 Peter Wunder. All rights reserved.
//

import Cocoa

protocol DisplayLinkDelegate: AnyObject {
	func vsync()
}

class DisplayLink {

	weak var delegate: DisplayLinkDelegate?

	var _displayLink: CVDisplayLink?
	var _displaySource: DispatchSourceUserDataAdd?

	init() {
		self.initDisplayLink()
	}

	private func initDisplayLink() {
		_displaySource = DispatchSource.makeUserDataAddSource(queue: DispatchQueue.main)
		_displaySource!.setEventHandler {[weak self] in
			if let delegate = self?.delegate {
				delegate.vsync()
			}
		}
		_displaySource!.resume()

		// Create a display link capable of being used with all active displays
		var cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink)

		assert(cvReturn == kCVReturnSuccess)

		cvReturn = CVDisplayLinkSetOutputCallback(_displayLink!, displayLinkCallback, Unmanaged.passUnretained(_displaySource!).toOpaque())

		assert(cvReturn == kCVReturnSuccess)

		cvReturn = CVDisplayLinkSetCurrentCGDisplay(_displayLink!, CGMainDisplayID () )

		assert(cvReturn == kCVReturnSuccess)
	}

	private let displayLinkCallback: CVDisplayLinkOutputCallback = {
		displayLink, now, outputTime, flagsIn, flagsOut, displayLinkContext in

		let source = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext!).takeUnretainedValue()
		source.add(data: 1)
		return kCVReturnSuccess
	}

	func start() {
		CVDisplayLinkStart(self._displayLink!)
	}

	func stop() {
		CVDisplayLinkStop(self._displayLink!)
	}

}
