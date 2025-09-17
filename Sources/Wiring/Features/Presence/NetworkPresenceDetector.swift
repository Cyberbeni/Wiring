import Foundation

actor NetworkPresenceDetector {
	private let presenceConfig: Config.Presence
	private let ips: [String: String]
	private let presenceDetectorAggregators: [String: PresenceDetectorAggregator]

	private let pingProcesses: [Process]

	private var isStarted = false

	// NOTE: we could read /proc/net/arp directly on Linux: https://github.com/ecki/net-tools/blob/c91448fb4dcb79e494dc3fe98b4ab747e45cb651/arp.c#L552
	// Parse "Flags" and check if the bit with value 2 is set.

	// "? (1.1.1.1) at 11:11:11:11:11:11 [ether] on eno1" -- connected
	// "? (1.1.1.1) at <incomplete> on eno1" -- recently disconnected
	private let ipRegex = /^\? \((?<ip>(?:\d{1,3}\.){3}\d{1,3})\) at (?:[\da-fA-F]{2}:){5}[\da-fA-F]{2}/
		.anchorsMatchLineEndings()
		.repetitionBehavior(.possessive)

	init(presenceConfig: Config.Presence, ips: [String: String], presenceDetectorAggregators: [String: PresenceDetectorAggregator]) throws {
		self.presenceConfig = presenceConfig
		self.ips = ips
		self.presenceDetectorAggregators = presenceDetectorAggregators
		pingProcesses = try ips.values.map { ip in
			let ping = Process([
				"ping",
				"-i\(presenceConfig.pingInterval.seconds)", // seconds between sending each packet
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

	func start() {
		guard !isStarted else { return }
		isStarted = true

		Task {
			while !Task.isCancelled {
				await doIt()
				try await Task.sleep(for: .seconds(presenceConfig.arpInterval.seconds))
			}
		}
	}

	private func doIt() async {
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
				return
			}

			let arpOutputText = String(decoding: arpOutput.fileHandleForReading.availableData, as: UTF8.self)
			let matches = arpOutputText.matches(of: ipRegex)
			let activeIps = matches.reduce(into: Set<String>(minimumCapacity: matches.count)) { results, match in
				results.insert(String(match.ip))
			}
			for (person, ip) in ips {
				await presenceDetectorAggregators[person]?.setNetworkPresence(activeIps.contains(ip))
			}
		} catch {
			Log.error(error)
		}
	}
}
