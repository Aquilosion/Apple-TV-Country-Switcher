//
//  UserDefaultProperty.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2023-06-10.
//  Copyright © 2023 Aquis. All rights reserved.
//

import Foundation

@propertyWrapper
struct UserDefault {
	var key: String
	
	var wrappedValue: String? {
		get {
			UserDefaults.standard.string(forKey: key)
		}
		
		set {
			UserDefaults.standard.set(newValue, forKey: key)
		}
	}
	
	init(key: String) {
		self.key = key
	}
}
