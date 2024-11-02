import Foundation

@MainActor class App {
	let generalConfig: Config.General
	let presenceConfig: Config.Presence?

	let mqttClient: MQTTClient
	var espresensePresenceDetectors: [EspresensePresenceDetector] = []

	init() {
		let decoder = JSONDecoder()

		let generalConfigPath = "/config/config.general.json"
		do {
			let generalConfigData = try Data(contentsOf: URL(filePath: generalConfigPath))
			generalConfig = try decoder.decode(Config.General.self, from: generalConfigData)
		} catch {
			print("General config not found or invalid at '\(generalConfigPath)'")
			exit(1)
		}
		let presenceConfigPath = "/config/config.presence.json"
		do {
			let presenceConfigData = try Data(contentsOf: URL(filePath: presenceConfigPath))
			presenceConfig = try decoder.decode(Config.Presence.self, from: presenceConfigData)
		} catch {
			print("Presence config not found or invalid at '\(presenceConfigPath)'")
			presenceConfig = nil
		}

		mqttClient = MQTTClient(config: generalConfig.mqtt)
	}

	private func prepare() {
		if let presenceConfig {
			let espresenseDevices = presenceConfig.entries.values.compactMap(\.espresenseDevice)
			if !espresenseDevices.isEmpty {
				espresensePresenceDetectors = espresenseDevices.map { device in
					EspresensePresenceDetector(mqttClient: mqttClient, topic: "\(presenceConfig.espresenseDevicesBaseTopic)/\(device)")
				}
			}
		}
	}

	func run() {
		prepare()

		runNetworkPresenceDetection()

		Task {
			for detector in espresensePresenceDetectors {
				await detector.start()
			}
			await mqttClient.start()
		}
	}

	func runNetworkPresenceDetection() {
		guard let presenceConfig else { return }
		let ips = presenceConfig.entries.reduce(into: [String: String]()) { result, entry in
			guard let ip = entry.value.ip else { return }
			result[entry.key] = ip
		}
		guard !ips.isEmpty else { return }
		let networkPresenceDetector: NetworkPresenceDetector
		do {
			networkPresenceDetector = try NetworkPresenceDetector(ips: Set(ips.values), pingInterval: presenceConfig.pingInterval.seconds)
		} catch {
			print("\(Self.self) failed to initialize NetworkPresenceDetector: \(error)")
			return
		}
		let arpInterval = presenceConfig.arpInterval
		Task {
			while !Task.isCancelled {
				let activeIps = await networkPresenceDetector.getActiveIps()
				print("WiFi - Active people: \(ips.filter{ activeIps.contains($0.value) }.keys )")
				try await Task.sleep(for: .seconds(arpInterval.seconds), tolerance: .seconds(0.1))
			}
		}
	}

	func shutdown() async {
		await mqttClient.shutdown()
	}
}
