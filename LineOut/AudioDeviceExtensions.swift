//
//  AudioDeviceShim.swift
//  LineOut
//
//  Created by Peter Wunder on 29.06.19.
//  Copyright © 2019 Peter Wunder. All rights reserved.
//

import Cocoa

import AudioKit
import AMCoreAudio

extension AudioDevice {

	func toAKDevice() -> AKDevice {
		let deviceID = self.id
		return AKDevice(name: self.name, deviceID: deviceID)
	}

	var transportTypeIcon: NSImage {
		guard let transportType = self.transportType else {
			return NSImage(named: "transportUnknown")!
		}

		switch transportType {
		case .unknown:
			return NSImage(named: "transportUnknown")!
		case .aggregate:
			return NSImage(named: "transportAggregate")!
		case .airPlay:
			return NSImage(named: "transportAirPlay")!
		case .bluetooth, .bluetoothLE:
			return NSImage(named: "transportBluetooth")!
		case .builtIn:
			return NSImage(named: "transportBuiltIn14")!
		case .displayPort:
			return NSImage(named: "transportDisplayPort")!
		case .fireWire:
			return NSImage(named: "transportFireWire")!
		case .hdmi:
			return NSImage(named: "transportHDMI")!
		case .pci:
			return NSImage(named: "transportPCI")!
		case .thunderbolt:
			return NSImage(named: "transportThunderbolt")!
		case .usb:
			return NSImage(named: "transportUSB")!
		case .virtual:
			return NSImage(named: "transportVirtual")!
		default:
			return NSImage(named: "transportUnknown")!
		}
	}

}
