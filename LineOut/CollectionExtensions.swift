//
//  CollectionExtensions.swift
//  LineOut
//
//  Created by Peter Wunder on 04.07.19.
//  Copyright © 2019 Peter Wunder. All rights reserved.
//

import Foundation

extension Collection where Element: Numeric {
	/// Returns the total sum of all elements in the array
	var total: Element { return reduce(0, +) }
}

extension Collection where Element: BinaryFloatingPoint {
	/// Returns the average of all elements in the array
	var average: Element {
		return isEmpty ? 0 : total / Element(count)
	}
}
