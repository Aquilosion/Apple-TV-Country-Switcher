//
//  ViewController.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2018-07-20.
//  Copyright © 2018 Aquis. All rights reserved.
//

import UIKit
import NetworkExtension
import TunnelKitManager
import TunnelKitCore
import TunnelKitOpenVPNManager
import TunnelKitOpenVPNCore

class ViewController: UIViewController {
	@IBOutlet var connectButton: UIButton?
	@IBOutlet var disconnectButton: UIButton?
	
	@IBOutlet var activityIndicator: UIActivityIndicatorView?
	@IBOutlet var currentCountryLabel: UILabel?
	@IBOutlet var statusLabel: UILabel?
	@IBOutlet var infoLabel: UILabel?
	
	var appearNotification: NSObjectProtocol?
	var statusNotification: NSObjectProtocol?
	var failNotification: NSObjectProtocol?
	
	let session = URLSession(configuration: .default)
	
	@UserDefault(key: "Username")
	var username: String?
	
	@UserDefault(key: "Password")
	var password: Data?
	
	@UserDefault(key: "Configuration")
	var configuration: String?
	
	let vpn = NetworkExtensionVPN()
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		
		appearNotification = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) {[weak self] _ in
			Task {
				await self?.vpn.prepare()
			}
		}
		
		statusNotification = NotificationCenter.default.addObserver(forName: VPNNotification.didChangeStatus, object: nil, queue: .main) { [weak self] notification in
			guard let status = notification.userInfo?["Status"] as? VPNStatus else {
				return
			}
			
			let infoMessage: String?
			let statusMessage: String?
			
			switch status {
			case .connecting, .disconnecting:
				infoMessage = nil
				statusMessage = "Switching countries…"
				
			case .connected:
				infoMessage = "United Kingdom"
				statusMessage = nil
				
			case .disconnected:
				infoMessage = "United States"
				statusMessage = nil
			}
			
			self?.setStatus(statusMessage)
			self?.setInfoCountry(infoMessage)
		}
		
		failNotification = NotificationCenter.default.addObserver(forName: VPNNotification.didFail, object: nil, queue: .main) { notification in
			print("FAIL", notification)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let playPause = UILongPressGestureRecognizer(target: self, action: #selector(Self.showSettings))
		playPause.allowedPressTypes = [NSNumber(integerLiteral: UIPress.PressType.playPause.rawValue)]
		self.view.addGestureRecognizer(playPause)
		
		Task {
			await vpn.prepare()
		}
	}
	
	private func getSetting(title: String, message: String, answer: String? = nil) async throws -> String? {
		let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		controller.addTextField() { textField in
			textField.text = answer
		}
		
		let result = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
			controller.addAction(UIAlertAction(title: "Save", style: .default) { action in
				continuation.resume(returning: controller.textFields![0].text ?? "")
			})
			
			controller.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
				continuation.resume(returning: nil)
			})
			
			present(controller, animated: true)
		}
		
		return result
	}
	
	@objc func showSettings(gesture: UILongPressGestureRecognizer) {
		guard gesture.state == .began else {
			return
		}
		
		Task {
			do {
				let username = try await getSetting(
					title: "Username",
					message: "Enter VPN username.",
					answer: self.username
				)
				
				let password = try await getSetting(
					title: "Password",
					message: "Enter password for that account."
				)
				
				let configuration = try await getSetting(
					title: "OVPN Configuration",
					message: "Enter URL for OVPN configuration file."
				)
				
				if let username {
					self.username = username
				}
				
				if let password {
					self.password = try Keychain(group: "group.com.aquis.CountrySwitcher").set(password: password, for: "OpenVPN", context: "com.aquis.CountrySwitcher.OpenVPNExtension")
				}
				
				if let configuration {
					self.configuration = try String(contentsOf: URL(string: configuration)!)
				}
			} catch {
				
			}
		}
	}
	
	@IBAction func connectVPN() {
		Task {
			do {
				try await connectVPN()
			} catch {
				print(error)
			}
		}
	}
	
	@IBAction func disconnectVPN() {
		Task {
			do {
				try await disconnectVPN()
			} catch {
				print(error)
			}
		}
	}
	
	private func connectVPN() async throws {
		let configuration = try! OpenVPN.ConfigurationParser.parsed(fromContents: self.configuration!).configuration
		
		var providerConfiguration = OpenVPN.ProviderConfiguration(
			"Country Switcher VPN",
			appGroup: "group.com.aquis.CountrySwitcher",
			configuration: configuration
		)
		
		providerConfiguration.username = username
		
		var extra = NetworkExtensionExtra()
		
		guard let passwordReference = self.password else {
			print("No password set")
			return
		}
		
		extra.passwordReference = passwordReference
		
		try await vpn.reconnect(
			"com.aquis.CountrySwitcher.OpenVPNExtension",
			configuration: providerConfiguration,
			extra: extra,
			after: .seconds(2)
		)
	}
	
	private func disconnectVPN() async throws {
		await vpn.disconnect()
	}
	
	private func setStatus(_ status: String?) {
		if let status {
			statusLabel?.text = status
			statusLabel?.isHidden = false
			
			activityIndicator?.startAnimating()
			
			connectButton?.isEnabled = false
			disconnectButton?.isEnabled = false
		} else {
			statusLabel?.isHidden = true
			activityIndicator?.stopAnimating()
			
			connectButton?.isEnabled = true
			disconnectButton?.isEnabled = true
		}
	}
	
	private func setInfoCountry(_ message: String?) {
		if let message {
			infoLabel?.isHidden = false
			currentCountryLabel?.isHidden = false
			infoLabel?.text = message
		} else {
			infoLabel?.isHidden = true
			currentCountryLabel?.isHidden = true
		}
	}
}
