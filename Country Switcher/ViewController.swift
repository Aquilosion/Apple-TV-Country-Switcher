//
//  ViewController.swift
//  Country Switcher
//
//  Created by Robert Pugh on 2018-07-20.
//  Copyright © 2018 Aquis. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
	@IBOutlet var activityIndicator: UIActivityIndicatorView?
	@IBOutlet var statusLabel: UILabel?
	
	let session = URLSession(configuration: .default)
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		activityIndicator?.tintColor = .white
	}
	
	@IBAction func connectVPN() {
		switchVpn(.start)
	}
	
	@IBAction func disconnectVPN() {
		switchVpn(.stop)
	}
	
	private func setStatus(_ status: String?) {
		if let status = status {
			statusLabel?.text = status
			statusLabel?.isHidden = false
			activityIndicator?.startAnimating()
		} else {
			statusLabel?.isHidden = true
			activityIndicator?.stopAnimating()
		}
	}
	
	private func switchVpn(_ action: VPNAction) {
		setStatus("Communicating with router…")
		
		func alert(message: String) {
			let alert = UIAlertController(
				title: "VPN Action",
				message: message,
				preferredStyle: .alert
			)
			
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
							
							alert(message: "The country has successfully been switched!")
						} else {
							if attempts < 20 {
								Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
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
		let url = URL(string: "http://192.168.8.1:8081/lua/" + action.rawValue)!
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
		
		let task = session.dataTask(with: request) { data, response, error in
			DispatchQueue.main.async {
				if let error = error {
					print("Could not negotiate with router: \(error)")
				}
				
				guard let data = data else {
					handler(false)
					return
				}
				
				guard let string = String(data: data, encoding: .utf8) else {
					handler(false)
					return
				}
				
				handler(string == "Success")
			}
		}
		
		task.resume()
	}
	
}

