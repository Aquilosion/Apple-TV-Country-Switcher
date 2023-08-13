//
//  ViewController.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2018-07-20.
//  Copyright © 2018 Aquis. All rights reserved.
//

import UIKit
import NetworkExtension

class ViewController: UIViewController {
	@IBOutlet var connectButton: UIButton?
	@IBOutlet var disconnectButton: UIButton?
	
	@IBOutlet var activityIndicator: UIActivityIndicatorView?
	@IBOutlet var statusLabel: UILabel?
	@IBOutlet var infoLabel: UILabel?
	
	var appearNotification: NSObjectProtocol?
	
	let session = URLSession(configuration: .default)
	
	@UserDefault(key: "ServerAddress")
	var serverAddress: String?
	
	@UserDefault(key: "Username")
	var username: String?
	
	
	@Keychain(key: "UserPassword")
	var password: String?
	
	@Keychain(key: "SharedSecret")
	var sharedSecret: String?
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		
		appearNotification = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
//			self.checkCurrentConnection()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let playPause = UILongPressGestureRecognizer(target: self, action: #selector(Self.showSettings))
		playPause.allowedPressTypes = [NSNumber(integerLiteral: UIPress.PressType.playPause.rawValue)]
		self.view.addGestureRecognizer(playPause)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
//		checkCurrentConnection()
	}
	
	private func getSetting(title: String, message: String, answer: String? = nil) async throws -> String {
		let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		controller.addTextField() { textField in
			textField.text = answer
		}
		
		let result = try await withCheckedThrowingContinuation { continuation in
			controller.addAction(UIAlertAction(title: "Save", style: .default) { action in
				continuation.resume(returning: controller.textFields![0].text ?? "")
			})
			
			controller.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
				continuation.resume(throwing: CancellationError())
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
				let serverAddress = try await getSetting(
					title: "Server Address",
					message: "Enter the address of the VPN server.",
					answer: self.serverAddress
				)
				
				let username = try await getSetting(
					title: "Username",
					message: "Enter VPN username.",
					answer: self.username
				)
				
				let password = try await getSetting(
					title: "Password",
					message: "Enter password for that account."
				)
				
				let sharedSecret = try await getSetting(
					title: "Shared Secret",
					message: "Enter shared secret."
				)
				
				self.serverAddress = serverAddress
				self.username = username
				self.password = password
				self.sharedSecret = sharedSecret
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
	/*	let manager = NEVPNManager.shared()
		
		try await manager.loadFromPreferences()
		
		let connection = NEVPNProtocolIPSec()
		
		connection.serverAddress = serverAddress
		
		connection.username = username
		connection.passwordReference = $password
		
		connection.authenticationMethod = .sharedSecret
		connection.sharedSecretReference = $sharedSecret
		
		connection.useExtendedAuthentication = true
		connection.disconnectOnSleep = false
		
		manager.isEnabled = true
		manager.protocolConfiguration = connection
		manager.isOnDemandEnabled = false
		manager.localizedDescription = serverAddress
		
		try await manager.saveToPreferences()
		
		print("Connecting…")
		
		try manager.connection.startVPNTunnel()
		
		print("Connected?")*/
		
		let prtcl = NEVPNProtocolIPSec()
		prtcl.username = username
		prtcl.passwordReference = $password
		prtcl.serverAddress = serverAddress
		prtcl.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret
		prtcl.sharedSecretReference = $sharedSecret
		prtcl.localIdentifier = "Test iOS device"
		prtcl.remoteIdentifier = serverAddress
		prtcl.useExtendedAuthentication = true
		prtcl.disconnectOnSleep = false
		
		let manager = NEVPNManager.shared()
		
		manager.isEnabled = true
		manager.protocolConfiguration = prtcl
		manager.isOnDemandEnabled = false
		manager.localizedDescription = "MyVPN Configuration"
		manager.saveToPreferences(completionHandler: { (error) in
			if (error != nil)
			{
				print("Error: ", error.debugDescription)
//				completion?(false)
			}
			else
			{
//				self.serverButton.setTitle(server.name, for: UIControlState.normal)
				print("VPN prefs saved")
//				completion?(true)
			}
		})
	}
	
	private func disconnectVPN() async throws {
		
	}
	
/*	private var checkingConnection = false
	
	private func checkCurrentConnection() {
		guard checkingConnection == false else {
			return
		}
		
		checkingConnection = true
		
		setStatus("Checking current connection…")
		
		testCountry() { country in
			self.checkingConnection = false
			
			if let country = country {
				self.setInfoCountry(country)
			} else {
				let alert = UIAlertController(title: "Country Switcher", message: "Your device currently doesn’t appear to have a connection.", preferredStyle: .alert)
				
				alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
				
				self.present(alert, animated: true, completion: nil)
			}
			
			self.setStatus(nil)
		}
	}
	
	private func setStatus(_ status: String?) {
		if let status = status {
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
	
	private func setInfoCountry(_ countryCode: String?) {
		infoLabel?.isHidden = false
		
		if let code = countryCode {
			let countryCodes = [
				"GB": "United Kingdom",
				"US": "United States"
			]
			
			infoLabel?.text = "Current country: \(countryCodes[code] ?? code)"
		} else {
			infoLabel?.text = "No internet connection."
		}
	}
	
	private func switchVpn(_ action: VPNAction) async {
		setStatus("Communicating with router…")
		
		func alert(message: String) {
			let alert = UIAlertController(title: "Country Switcher", message: message, preferredStyle: .alert)
			
			alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
			
			self.present(alert, animated: true, completion: nil)
		}
		
		/*vpnActionRequest(action) { success in
			if success {
				var attempts = 0
				
				func checkIfConnected() {
					attempts += 1
					
					self.setStatus("Waiting for VPN (\(attempts))…")
					
					self.testCountry() { country in
						if country == action.targetCountry {
							self.setStatus(nil)
							
							self.setInfoCountry(country)
						} else {
							if attempts < 20 {
								Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
									checkIfConnected()
								}
							} else {
								self.setStatus(nil)
								
								alert(message: "Could not switch country, try restarting the router.")
							}
						}
					}
				}
				
				checkIfConnected()
			} else {
				self.setStatus(nil)
				alert(message: "Failed to communicate with router.")
			}
		}*/
	}
	
	private func testCountry() async throws -> String {
		let url = URL(string: "https://ipinfo.io/country")!
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
		
		enum CountryError: Error {
			case invalidResponse
		}
		
		let (data, _) = try await session.data(for: request)
		
		guard let string = String(data: data, encoding: .utf8) else {
			throw CountryError.invalidResponse
		}
		
		let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
		
		return trimmedString
	}*/
}

