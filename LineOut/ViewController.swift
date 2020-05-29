//
//  ViewController.swift
//  LineOut
//
//  Created by Peter Wunder on 17.06.19.
//  Copyright © 2019 Peter Wunder. All rights reserved.
//

import Cocoa
import AVFoundation

import AudioKit

class ViewController: NSViewController {

	@IBOutlet weak var inputDeviceMenu: NSPopUpButton!
	@IBOutlet weak var levelIndicatorLeftChannel: NSLevelIndicator!
	@IBOutlet weak var levelIndicatorRightChannel: NSLevelIndicator!

	var inputDevices: [AKDevice]?

	var mic: AKMicrophone?
	var amplitudeTracker: AKAmplitudeTracker?
	var gain: AKBooster?

	let maxAmplitudes = 5
	var amplitudesL: [Double] = []
	var amplitudesR: [Double] = []

	var displayLink: DisplayLink!

	override func viewDidLoad() {
		super.viewDidLoad()

		self.levelIndicatorLeftChannel.scaleUnitSquare(to: NSSize(width: -1, height: 1))

		self.populateInputDeviceList()
	}

	override func viewDidAppear() {
		self.displayLink = DisplayLink()
		self.displayLink.delegate = self
		self.displayLink.start()
	}

	override func viewWillDisappear() {
		self.stopListening()
		self.displayLink.stop()
	}

	private func updateMeters() {
		guard let amplitudeTracker = self.amplitudeTracker else {
			return
		}

		amplitudesL.append(amplitudeTracker.leftAmplitude)
		amplitudesR.append(amplitudeTracker.rightAmplitude)
		amplitudesL = amplitudesL.suffix(self.maxAmplitudes)
		amplitudesR = amplitudesR.suffix(self.maxAmplitudes)

		let leftAmplitudeClamped = min(amplitudesL.average, 1)
		let rightAmplitudeClamped = min(amplitudesR.average, 1)

		let amplitudeL = (leftAmplitudeClamped * self.levelIndicatorLeftChannel.maxValue).rounded()
		let amplitudeR = (rightAmplitudeClamped * self.levelIndicatorRightChannel.maxValue).rounded()

		self.levelIndicatorLeftChannel.integerValue = Int(amplitudeL)
		self.levelIndicatorRightChannel.integerValue = Int(amplitudeR)
	}

	func resetMeters() {
		self.levelIndicatorLeftChannel.integerValue = 0
		self.levelIndicatorRightChannel.integerValue = 0
	}

	func populateInputDeviceList() {
		let selectedInputTag = self.inputDeviceMenu.selectedTag()

		self.inputDevices = AudioKit.inputDevices

		self.inputDeviceMenu.removeAllItems()

		guard let inputDevices = self.inputDevices else {
			self.inputDeviceMenu.addItem(withTitle: "No input devices available")
			self.inputDeviceMenu.lastItem!.tag = -1
			self.inputDeviceMenu.isEnabled = false
			return
		}

		for device in inputDevices {
			self.inputDeviceMenu.addItem(withTitle: "\(device.name) (\(device.deviceID))")
			self.inputDeviceMenu.lastItem!.tag = Int(device.deviceID)
		}

		if !self.inputDeviceMenu.selectItem(withTag: selectedInputTag) {
			self.inputDeviceMenu.selectItem(at: 0)
		}

		self.inputDeviceMenu.isEnabled = true
	}

	@IBAction func selectedInputDeviceChanged(_ sender: NSPopUpButton) {
		if AudioKit.engine.isRunning {
			restartListening()
		}
	}

	@IBAction func toggleButtonPressed(_ sender: NSButton) {
		if !AudioKit.engine.isRunning && sender.state == .on {
			startListening()
			sender.state = .on
		} else {
			stopListening()
			sender.state = .off
		}

		print("Engine running: \(AudioKit.engine.isRunning)")
	}

	func restartListening() {
		stopListening()
		RunLoop.current.run(until: .init(timeIntervalSinceNow: 0.05)) // avoids weird issues with macOS's audio system
		startListening()
	}

	func startListening() {
		guard !AudioKit.engine.isRunning else {
			print("AudioKit engine is already running!")
			return
		}

		self.amplitudesL = []
		self.amplitudesR = []

		do {
			let selectedInputID = self.inputDeviceMenu.selectedTag()
			guard let selectedInputDevice = self.inputDevices?.first(where: {$0.deviceID == selectedInputID}) else {
				fatalError("no input device found")
			}

			try AudioKit.setInputDevice(selectedInputDevice)

			self.mic = AKMicrophone()
			self.amplitudeTracker = AKAmplitudeTracker(self.mic)
			self.amplitudeTracker?.mode = .peak
			self.gain = AKBooster(self.amplitudeTracker, gain: 1) // hook this up to a slider later

			AKSettings.bufferLength = .medium

			AudioKit.output = self.gain!

			try AudioKit.start()
		} catch {
			fatalError(error.localizedDescription)
		}
	}

	func stopListening() {
		self.resetMeters()

		guard AudioKit.engine.isRunning else {
			print("engine is not running")
			return
		}

		print("engine is running. will stop")
		do {
			try AudioKit.stop()
			print("engine shut down")
		} catch {
			print("Can't stop")
			fatalError(error.localizedDescription)
		}
	}

}

extension ViewController: DisplayLinkDelegate {
	func vsync() {
		self.updateMeters()
	}
}
