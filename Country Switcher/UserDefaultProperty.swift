//
//  UserDefaultProperty.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2023-06-10.
//  Copyright © 2023 Aquis. All rights reserved.
//

import Foundation

@propertyWrapper
struct UserDefault<T> {
	var key: String
	
	var wrappedValue: T? {
		get {
			UserDefaults.standard.object(forKey: key) as? T
		}
		
		set {
			UserDefaults.standard.set(newValue, forKey: key)
		}
	}
	
	init(key: String) {
		self.key = key
	}
}

protocol UserDefaultPropertyType { }

extension String: UserDefaultPropertyType { }
extension Data: UserDefaultPropertyType { }
