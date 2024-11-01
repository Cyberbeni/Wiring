import Foundation

@MainActor class App {
	let generalConfig: GeneralConfig
	let presenceConfig: PresenceConfig?

	let mqttClient: MQTTClient
	var networkPresenceDetector: NetworkPresenceDetector?
	var espresensePresenceDetectors: [EspresensePresenceDetector] = []

	init() {
		let decoder = JSONDecoder()

		let generalConfigPath = "/config/config.general.json"
		do {
			let generalConfigData = try Data(contentsOf: URL(filePath: generalConfigPath))
			generalConfig = try decoder.decode(GeneralConfig.self, from: generalConfigData)
		} catch {
			print("General config not found or invalid at '\(generalConfigPath)'")
			exit(1)
		}
		let presenceConfigPath = "/config/config.presence.json"
		do {
			let presenceConfigData = try Data(contentsOf: URL(filePath: presenceConfigPath))
			presenceConfig = try decoder.decode(PresenceConfig.self, from: presenceConfigData)
		} catch {
			print("Presence config not found or invalid at '\(presenceConfigPath)'")
			presenceConfig = nil
		}

		mqttClient = MQTTClient(config: generalConfig.mqtt)
	}

	private func prepare() {
		if let presenceConfig {
			let ips = presenceConfig.entries.values.compactMap(\.ip)
			if !ips.isEmpty {
				do {
					networkPresenceDetector = try NetworkPresenceDetector(ips: Set(ips), pingInterval: 5)
				} catch {
					print("\(Self.self) failed to initialize NetworkPresenceDetector: \(error)")
				}
			}

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

		if let networkPresenceDetector {
			Task {
				while !Task.isCancelled {
					let ips = await networkPresenceDetector.getActiveIps()
					print("Active IPs: \(ips)")
					try await Task.sleep(for: .seconds(5), tolerance: .seconds(0.1))
				}
			}
		}

		Task {
			for detector in espresensePresenceDetectors {
				await detector.start()
			}
			await mqttClient.start()
		}
	}

	func shutdown() async {
		await mqttClient.shutdown()
	}
}
