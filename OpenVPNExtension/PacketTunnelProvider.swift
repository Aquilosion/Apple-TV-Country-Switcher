//
//  PacketTunnelProvider.swift
//  OpenVPNExtension
//
//  Created by Robert Pugh on 2024-04-01.
//  Copyright © 2024 Aquis. All rights reserved.
//

import Foundation
import TunnelKitOpenVPNAppExtension

class PacketTunnelProvider: OpenVPNTunnelProvider {
	override func startTunnel(options: [String: NSObject]? = nil) async throws {
		dataCountInterval = 3
		try await super.startTunnel(options: options)
	}
}
