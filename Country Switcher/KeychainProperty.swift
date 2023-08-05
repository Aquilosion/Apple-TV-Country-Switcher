//
//  KeychainProperty.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2023-06-10.
//  Copyright © 2023 Aquis. All rights reserved.
//

import Foundation
import Security

@propertyWrapper
struct Keychain {
	static let serviceName = "io.aquis.CountrySwitcher"
	
	var key: String
	
	var wrappedValue: String? {
		get {
			""
		}
		
		set {
			if let password = newValue {
				writePassword(password)
			}
		}
	}
	
	var projectedValue: Data? {
		let passwordQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
											kSecAttrService as String: Self.serviceName,
											kSecAttrAccount as String: key,
											kSecReturnPersistentRef as String: true]
		
		var result: AnyObject?
		let status3 = SecItemCopyMatching(passwordQuery as CFDictionary, &result)
		guard status3 == errSecSuccess, let passwordRef = result as? Data else {
			fatalError("Error retrieving password reference from Keychain: \(status3)")
		}

		return passwordRef
	}
	
	init(key: String) {
		self.key = key
	}
	
	private func writePassword(_ password: String) {
		var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
									kSecAttrService as String: Self.serviceName,
									kSecAttrAccount as String: key,
									kSecValueData as String: password.data(using: .utf8)!]
		
		let status = SecItemAdd(query as CFDictionary, nil)
		guard status == errSecSuccess else {
			fatalError("Error adding password to Keychain: \(status)")
		}
	}
}
