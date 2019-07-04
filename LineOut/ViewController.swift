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
	@IBOutlet weak var levelIndicatorLeftChannel: NSLevelIndicator!
	@IBOutlet weak var levelIndicatorRightChannel: NSLevelIndicator!

	var inputDevices: [AudioDevice] = []

	var amplitudeTracker: AKAmplitudeTracker?
	let maxAmplitudes = 8
	var amplitudesL: [Double] = []
	var amplitudesR: [Double] = []

	var displayLink: DisplayLink!

	override func viewDidLoad() {
		super.viewDidLoad()

		self.levelIndicatorLeftChannel.scaleUnitSquare(to: NSSize(width: -1, height: 1))

		self.populateInputDeviceList()

		NotificationCenter.defaultCenter.subscribe(self, eventType: AudioHardwareEvent.self)
	}

	override func viewDidAppear() {
		self.displayLink = DisplayLink()
		self.displayLink.delegate = self
		self.displayLink.start()
	}

	override func viewWillDisappear() {
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

		var leftAmplitudeClamped = min(amplitudesL.average, 1)
		var rightAmplitudeClamped = min(amplitudesR.average, 1)

		let scalar = 0.1
		leftAmplitudeClamped = ((1+scalar)*leftAmplitudeClamped) / (scalar + leftAmplitudeClamped)
		rightAmplitudeClamped = ((1+scalar)*rightAmplitudeClamped) / (scalar + rightAmplitudeClamped)

		let leftAmplitudeRemapped = (leftAmplitudeClamped * self.levelIndicatorLeftChannel.maxValue).rounded(.up)
		let leftAmplitude = Int(leftAmplitudeRemapped)
		self.levelIndicatorLeftChannel.integerValue = leftAmplitude

		let rightAmplitudeRemapped = (rightAmplitudeClamped * self.levelIndicatorRightChannel.maxValue).rounded(.up)
		let rightAmplitude = Int(rightAmplitudeRemapped)
		self.levelIndicatorRightChannel.integerValue = rightAmplitude
	}

	func populateInputDeviceList() {
		let selectedInputTag = self.inputDeviceMenu.selectedTag()

		self.inputDeviceMenu.removeAllItems()
		self.inputDevices = AudioDevice.allInputDevices()

		print(self.inputDevices)

		if self.inputDevices.count > 0 {
			for device in self.inputDevices {
				guard device.transportType != .aggregate else {
					continue
				}

				self.inputDeviceMenu.addItem(withTitle: device.name)
				if let defaultInput = AudioDevice.defaultInputDevice(), defaultInput.id == device.id {
					self.inputDeviceMenu.lastItem!.image = NSImage(named: "defaultInput")!
				} else {
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
	}

	@IBAction func selectedInputDeviceChanged(_ sender: NSPopUpButton) {
		if AudioKit.engine.isRunning {
			restartListening()
		}
	}

	@IBAction func toggleButtonPressed(_ sender: NSButton) {
		if !AudioKit.engine.isRunning && sender.state == .on {
			sender.state = startListening() ? .on : .off
		} else {
			stopListening()
			sender.state = .off
		}

		print(AudioKit.engine.isRunning)
	}

	func restartListening() -> Bool {
		stopListening()
		RunLoop.current.run(until: .init(timeIntervalSinceNow: 0.1))
		return startListening()
	}

	func startListening() -> Bool {
		guard !AudioKit.engine.isRunning else {
			return false
		}

		self.amplitudesL = []
		self.amplitudesR = []

		do {
			let selectedInputID = self.inputDeviceMenu.selectedTag()
			guard let selectedInputDevice = self.inputDevices.first(where: {$0.id == selectedInputID}) else {
				fatalError("no input device found")
			}

			try AudioKit.setInputDevice(selectedInputDevice.toAKDevice())

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
			fatalError(error.localizedDescription)
		}

		return false
	}

	func stopListening() {
		guard AudioKit.engine.isRunning else {
			print("engine is not running")
			return
		}

		print("engine is running. will stop")
		do {
			try AudioKit.stop()
			AudioKit.disconnectAllInputs()
			print("engine shut down")
		} catch {
			print("Can't stop")
			fatalError(error.localizedDescription)
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
					self.populateInputDeviceList()
				}
			case .defaultOutputDeviceChanged(_):
				guard AudioKit.engine.isRunning else {
					return
				}

				DispatchQueue.main.async {
					self.restartListening()
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
