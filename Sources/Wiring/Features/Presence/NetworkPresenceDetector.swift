import Subprocess

actor NetworkPresenceDetector {
	private let presenceConfig: Config.Presence
	private let ips: [String: String]
	private let presenceDetectorAggregators: [String: PresenceDetectorAggregator]

	private let pingProcesses: [Task<Void, any Error>]

	private var runTask: Task<Void, any Error>?

	// NOTE: we could read /proc/net/arp directly on Linux:
	// https://github.com/ecki/net-tools/blob/c91448fb4dcb79e494dc3fe98b4ab747e45cb651/arp.c#L552
	// Parse "Flags" and check if the bit with value 2 is set.

	// "? (1.1.1.1) at 11:11:11:11:11:11 [ether] on eno1" -- connected
	// "? (1.1.1.1) at <incomplete> on eno1" -- recently disconnected
	private let ipRegex = /^\? \((?<ip>(?:\d{1,3}\.){3}\d{1,3})\) at (?:[\da-fA-F]{2}:){5}[\da-fA-F]{2}/
		.anchorsMatchLineEndings()
		.repetitionBehavior(.possessive)

	init(presenceConfig: Config.Presence, ips: [String: String], presenceDetectorAggregators: [String: PresenceDetectorAggregator]) {
		self.presenceConfig = presenceConfig
		self.ips = ips
		self.presenceDetectorAggregators = presenceDetectorAggregators
		pingProcesses = ips.values.map { ip in
			Task.detached {
				let ping = try await run(
					.name("ping"),
					arguments: [
						"-i\(presenceConfig.pingInterval.seconds)", // seconds between sending each packet
						ip, // <destination>
					],
					output: .discarded,
				)
				Log.error("`ping` terminated with exit code: \(ping.terminationStatus)")
			}
		}
	}

	deinit {
		runTask?.cancel()
		pingProcesses.forEach { $0.cancel() }
	}

	func start() {
		guard runTask == nil else { return }

		runTask = Task {
			while !Task.isCancelled {
				await doIt()
				try await Task.sleep(for: .seconds(presenceConfig.arpInterval.seconds))
			}
		}
	}

	private func doIt() async {
		do {
			let arp = try await run(
				.name("arp"),
				arguments: [
					"-a", // display (all) hosts in alternative (BSD) style -- macOS/BusyBox doesn't support Linux style
					"-n", // don't resolve names -- macOS/BusyBox doesn't support the long option name `--numeric`
				],
				output: .string(limit: .max),
			)
			guard arp.terminationStatus == .exited(0) else {
				Log.error("`arp` terminated with exit code: \(arp.terminationStatus)")
				return
			}

			let arpOutputText = arp.standardOutput ?? ""
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
