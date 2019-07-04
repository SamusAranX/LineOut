//
//  ViewController.swift
//  LineOut
//
//  Created by Peter Wunder on 17.06.19.
//  Copyright © 2019 Peter Wunder. All rights reserved.
//

import Cocoa
import AVFoundation

import AMCoreAudio
import AudioKit

class ViewController: NSViewController {

	@IBOutlet weak var inputDeviceMenu: NSPopUpButton!
	@IBOutlet weak var outputDeviceMenu: NSPopUpButton!
	@IBOutlet weak var levelIndicatorLeftChannel: NSLevelIndicator!
	@IBOutlet weak var levelIndicatorRightChannel: NSLevelIndicator!

	var inputDevices: [AudioDevice] = []
	var outputDevices: [AudioDevice] = []

	var amplitudeTracker: AKAmplitudeTracker?

	var displayLink: DisplayLink!

	override func viewDidLoad() {
		super.viewDidLoad()

		self.levelIndicatorLeftChannel.scaleUnitSquare(to: NSSize(width: -1, height: 1))

		self.populateDeviceLists()

		NotificationCenter.defaultCenter.subscribe(self, eventType: AudioHardwareEvent.self)

		self.displayLink = DisplayLink()
		self.displayLink.delegate = self
		self.displayLink.start()
	}

	override func viewWillDisappear() {
		print("stop displaylink")
		self.displayLink.stop()
	}

	var _lastDate: Date?
	private func updateMeters() {
		guard let amplitudeTracker = self.amplitudeTracker else {
			return
		}

		let leftAmplitudeClamped = min(amplitudeTracker.leftAmplitude, 1)
		let leftAmplitudeRemapped = (leftAmplitudeClamped * self.levelIndicatorLeftChannel.maxValue).rounded(.up)
		let leftAmplitude = Int(leftAmplitudeRemapped)
		self.levelIndicatorLeftChannel.integerValue = leftAmplitude

		let rightAmplitudeClamped = min(amplitudeTracker.rightAmplitude, 1)
		let rightAmplitudeRemapped = (rightAmplitudeClamped * self.levelIndicatorRightChannel.maxValue).rounded(.up)
		let rightAmplitude = Int(rightAmplitudeRemapped)
		self.levelIndicatorRightChannel.integerValue = rightAmplitude
	}

	func populateDeviceLists() {
		let selectedInputTag = self.inputDeviceMenu.selectedTag()
		let selectedOutputTag = self.outputDeviceMenu.selectedTag()

		self.inputDeviceMenu.removeAllItems()
		self.outputDeviceMenu.removeAllItems()

		self.inputDevices = AudioDevice.allInputDevices()
		self.outputDevices = AudioDevice.allOutputDevices()

		print(self.inputDevices)
		print(self.outputDevices)

		if self.inputDevices.count > 0 {
			for device in self.inputDevices {
				self.inputDeviceMenu.addItem(withTitle: device.name)
				if let defaultInput = AudioDevice.defaultInputDevice(), defaultInput.id == device.id {
					self.inputDeviceMenu.lastItem!.image = NSImage(named: "defaultInput")!
				}
				self.inputDeviceMenu.lastItem!.tag = Int(device.id)
			}

			if !self.inputDeviceMenu.selectItem(withTag: selectedInputTag) {
				self.inputDeviceMenu.selectItem(at: 0)
			}

			self.inputDeviceMenu.isEnabled = true
		} else {
			self.inputDeviceMenu.addItem(withTitle: "No input devices available")
			self.inputDeviceMenu.isEnabled = false
		}

		if self.outputDevices.count > 0 {
			for device in self.outputDevices {
				self.outputDeviceMenu.addItem(withTitle: device.name)
				if let defaultOutput = AudioDevice.defaultOutputDevice(), defaultOutput.id == device.id {
					self.outputDeviceMenu.lastItem!.image = NSImage(named: "defaultOutput")!
				}
				self.outputDeviceMenu.lastItem!.tag = Int(device.id)
			}

			if !self.outputDeviceMenu.selectItem(withTag: selectedOutputTag) {
				self.outputDeviceMenu.selectItem(at: 0)
			}

//			self.outputDeviceMenu.isEnabled = true
		} else {
			self.outputDeviceMenu.addItem(withTitle: "No output devices available")
//			self.outputDeviceMenu.isEnabled = false
		}
	}

	@IBAction func toggleButtonPressed(_ sender: NSButton) {
		if !AudioKit.engine.isRunning {
			sender.state = startListening() ? .on : .off
		} else {
			stopListening()
			sender.state = .off
		}

		print(AudioKit.engine.isRunning)
	}

	func startListening() -> Bool {
		guard !AudioKit.engine.isRunning else {
			return false
		}

		do {
			let selectedInputID = self.inputDeviceMenu.selectedTag()
			guard let selectedInputDevice = self.inputDevices.first(where: {$0.id == selectedInputID}) else {
				fatalError("no input device found")
			}

//			let selectedOutputID = self.outputDeviceMenu.selectedTag()
//			guard let selectedOutputDevice = self.outputDevices.first(where: {$0.id == selectedOutputID}) else {
//				fatalError("no output device found")
//			}

			try AudioKit.setInputDevice(selectedInputDevice.toAKDevice())
//			try AudioKit.setOutputDevice(selectedOutputDevice.toAKDevice())

			guard let micNode = AKMicrophone() else {
				fatalError("fuck")
			}

			self.amplitudeTracker = AKAmplitudeTracker(micNode)

			AudioKit.output = self.amplitudeTracker!

			AKSettings.bufferLength = .shortest
			try AudioKit.start()

			micNode.start()

			return true
		} catch {
			print("Can't start")
			print(error.localizedDescription)
		}

		return false
	}

	func stopListening() {
		guard AudioKit.engine.isRunning else {
			return
		}

		do {
			try AudioKit.stop()
			AudioKit.disconnectAllInputs()
		} catch {
			print("Can't stop")
			print(error.localizedDescription)
		}
	}

}

extension ViewController: EventSubscriber {

	func eventReceiver(_ event: Event) {
		switch event {
		case let event as AudioHardwareEvent:
			switch event {
			case .deviceListChanged(_, _):
				DispatchQueue.main.async {
					self.populateDeviceLists()
				}
			default:
				break
			}
		default:
			break
		}
	}

}

extension ViewController: DisplayLinkDelegate {
	func vsync() {
		self.updateMeters()
	}
}
