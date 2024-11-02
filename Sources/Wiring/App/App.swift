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

	func run() async {
		prepare()

		for detector in espresensePresenceDetectors {
			await detector.start()
		}
		await startNetworkPresenceDetection()
		await mqttClient.start()
	}

	func shutdown() async {
		await mqttClient.shutdown()
	}
}
