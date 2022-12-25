//
//  ViewController.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2018-07-20.
//  Copyright © 2018 Aquis. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
	@IBOutlet var connectButton: UIButton?
	@IBOutlet var disconnectButton: UIButton?
	
	@IBOutlet var activityIndicator: UIActivityIndicatorView?
	@IBOutlet var statusLabel: UILabel?
	@IBOutlet var infoLabel: UILabel?
	
	var appearNotification: NSObjectProtocol?
	
	let session = URLSession(configuration: .default)
	
	var serverAddress: String? {
		get {
			UserDefaults.standard.string(forKey: "ServerAddress")
		}
		
		set {
			UserDefaults.standard.set(newValue, forKey: "ServerAddress")
		}
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		
		appearNotification = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
			self.checkCurrentConnection()
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
		
		checkCurrentConnection()
	}
	
	@objc func showSettings(gesture: UILongPressGestureRecognizer) {
		guard gesture.state == .began else {
			return
		}
		
		let controller = UIAlertController(title: "VPN Router Address", message: "Enter the address of the VPN router.", preferredStyle: .alert)
		controller.addTextField() { textField in
			textField.text = self.serverAddress
			
			textField.keyboardType = .numbersAndPunctuation
		}
		
		controller.addAction(UIAlertAction(title: "Save", style: .default, handler: { action in
			self.serverAddress = controller.textFields!.first!.text
		}))
		
		controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		present(controller, animated: true)
	}
	
	@IBAction func connectVPN() {
		switchVpn(.start)
	}
	
	@IBAction func disconnectVPN() {
		switchVpn(.stop)
	}
	
	private var checkingConnection = false
	
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
	
	private func switchVpn(_ action: VPNAction) {
		setStatus("Communicating with router…")
		
		func alert(message: String) {
			let alert = UIAlertController(title: "Country Switcher", message: message, preferredStyle: .alert)
			
			alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
			
			self.present(alert, animated: true, completion: nil)
		}
		
		vpnActionRequest(action) { success in
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
		}
	}
	
	private func testCountry(handler: @escaping (String?) -> ()) {
		let url = URL(string: "https://ipinfo.io/country")!
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
		
		let task = session.dataTask(with: request) { data, response, error in
			DispatchQueue.main.async {
				if let error = error {
					print("Could not get country code: \(error)")
				}
				
				guard let data = data else {
					handler(nil)
					return
				}
				
				guard let string = String(data: data, encoding: .utf8) else {
					handler(nil)
					return
				}
				
				let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
				
				handler(trimmedString)
			}
		}
		
		task.resume()
	}
	
	private enum VPNAction: String {
		case start
		case stop
		
		var targetCountry: String {
			switch self {
			case .start:
				return "GB"
				
			case .stop:
				return "US"
				
			}
		}
	}
	
	private func vpnActionRequest(_ action: VPNAction, handler: @escaping (Bool) -> ()) {
		guard let serverAddress else {
			let alert = UIAlertController(title: "No Server Address", message: "Hold down the Play button to set the server address.", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default))
			present(alert, animated: true)
			
			handler(false)
			return
		}
		
		let url = URL(string: "http://\(serverAddress)/lua/" + action.rawValue)!
		
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 120)
		
		let task = session.dataTask(with: request) { data, response, error in
			DispatchQueue.main.async {
				if let error = error {
					print("Could not negotiate with router: \(error)")
				}
				
				handler(true)
			}
		}
		
		task.resume()
	}
	
}

