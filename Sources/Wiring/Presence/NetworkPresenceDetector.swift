import Foundation

actor NetworkPresenceDetector {
	private let ips: Set<String>
	private let pingProcesses: [Process]

	// "? (1.1.1.1) at 11:11:11:11:11:11 [ether] on eno1" -- connected
	// "? (1.1.1.1) at <incomplete> on eno1" -- recently disconnected
	private let ipRegex = /^\? \((?<ip>(?:\d{1,3}\.){3}\d{1,3})\) at (?:[\da-fA-F]{2}:){5}[\da-fA-F]{2}/
		.anchorsMatchLineEndings()
		.repetitionBehavior(.possessive)

	init(ips: Set<String>, pingInterval: Double) throws {
		self.ips = ips
		pingProcesses = try ips.map { ip in
			let ping = Process([
				"ping",
				"-i\(pingInterval)", // seconds between sending each packet
				ip, // <destination>
			])
			ping.setIO()
			ping.terminationHandler = { ping in
				Log.error("`ping` terminated with exit code: \(ping.terminationStatus)")
			}
			try ping.run()
			return ping
		}
	}

	deinit {
		pingProcesses.forEach { $0.terminate() }
	}

	func getActiveIps() -> Set<String> {
		do {
			let arp = Process([
				"arp",
				"-a", // display (all) hosts in alternative (BSD) style -- macOS/BusyBox doesn't support Linux style
				"-n", // don't resolve names -- macOS/BusyBox doesn't support the long option name `--numeric`
			])
			let arpOutput = Pipe()
			arp.setIO(standardOutput: arpOutput)
			try arp.run()
			arp.waitUntilExit()
			guard arp.terminationStatus == 0 else {
				Log.error("`arp` terminated with exit code: \(arp.terminationStatus)")
				return []
			}

			let arpOutputText = String(decoding: arpOutput.fileHandleForReading.availableData, as: UTF8.self)
			let matches = arpOutputText.matches(of: ipRegex)
			var activeIps = matches.reduce(into: Set<String>(minimumCapacity: matches.count)) { results, match in
				results.insert(String(match.ip))
			}
			activeIps.formIntersection(ips)
			return activeIps
		} catch {
			Log.error(error)
			return []
		}
	}
}
