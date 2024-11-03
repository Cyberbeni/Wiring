import Foundation

@MainActor class App {
	let generalConfig: Config.General
	let presenceConfig: Config.Presence?

	let mqttClient: MQTTClient

	var presenceDetectorAggregators: [String: PresenceDetectorAggregator] = [:]
	var espresensePresenceDetectors: [EspresensePresenceDetector] = []

	init() {
		let decoder = Config.jsonDecoder()

		let generalConfigPath = "/config/config.general.json"
		do {
			let generalConfigData = try Data(contentsOf: URL(filePath: generalConfigPath))
			generalConfig = try decoder.decode(Config.General.self, from: generalConfigData)
		} catch {
			Log.info("General config not found or invalid at '\(generalConfigPath)' - \(error)")
			exit(1)
		}
		Log.enableDebugLogging = generalConfig.enableDebugLogging
		let presenceConfigPath = "/config/config.presence.json"
		do {
			let presenceConfigData = try Data(contentsOf: URL(filePath: presenceConfigPath))
			presenceConfig = try decoder.decode(Config.Presence.self, from: presenceConfigData)
		} catch {
			Log.info("Presence config not found or invalid at '\(presenceConfigPath)' - \(error)")
			presenceConfig = nil
		}

		mqttClient = MQTTClient(config: generalConfig.mqtt)
	}

	func run() async {
		setupPresenceDetectors()
		await setupPresenceDetectionMqttDiscovery()
		for detector in espresensePresenceDetectors {
			await detector.start()
		}
		await mqttClient.start()

		runNetworkPresenceDetection()
	}

	func shutdown() async {
		await mqttClient.shutdown()
	}
}
