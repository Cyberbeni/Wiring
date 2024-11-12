import Foundation

@MainActor class App {
	let generalConfig: Config.General
	let presenceConfig: Config.Presence?

	let mqttClient: MQTTClient

	var presenceDetectorAggregators: [String: PresenceDetectorAggregator] = [:]
	var blePresenceDetectors: [BlePresenceDetector] = []
	var networkPresenceDetector: NetworkPresenceDetector?

	init() {
		let decoder = Config.jsonDecoder()
		#if DEBUG
			let configDir = "./test_config"
		#else
			let configDir = "/config"
		#endif

		let generalConfigPath = "\(configDir)/config.general.json"
		do {
			let generalConfigData = try Data(contentsOf: URL(filePath: generalConfigPath))
			generalConfig = try decoder.decode(Config.General.self, from: generalConfigData)
		} catch {
			Log.info("General config not found or invalid at '\(generalConfigPath)' - \(error)")
			exit(1)
		}
		Log.enableDebugLogging = generalConfig.enableDebugLogging
		let presenceConfigPath = "\(configDir)/config.presence.json"
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
		await setupServerState()
		await setupPresenceDetectors()
		await mqttClient.start()

		await runPresenceDetectors()
	}

	func shutdown() async {
		await mqttClient.shutdown()
	}
}
