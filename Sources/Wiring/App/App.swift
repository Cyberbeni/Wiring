import Foundation

@MainActor class App {
	let generalConfig: Config.General
	let presenceConfig: Config.Presence?
	let coverConfig: Config.Cover?

	let mqttClient: MQTTClient
	let stateStore: StateStore
	var homeAssistantRestApi: HomeAssistantRestApi?

	var presenceDetectorAggregators: [String: PresenceDetectorAggregator] = [:]
	var blePresenceDetectors: [BlePresenceDetector] = []
	var networkPresenceDetector: NetworkPresenceDetector?
	var coverControllers: [CoverController] = []

	init() {
		let decoder = Config.jsonDecoder()
		#if DEBUG
			let configDir = "./test_config"
		#else
			let configDir = "/config"
		#endif

		let generalConfigPath = "\(configDir)/config.general.json"
		do {
			let configData = try Data(contentsOf: URL(filePath: generalConfigPath))
			generalConfig = try decoder.decode(Config.General.self, from: configData)
		} catch {
			Log.info("General config not found or invalid at '\(generalConfigPath)' - \(error)")
			exit(1)
		}
		Log.enableDebugLogging = generalConfig.enableDebugLogging
		let presenceConfigPath = "\(configDir)/config.presence.json"
		do {
			let configData = try Data(contentsOf: URL(filePath: presenceConfigPath))
			presenceConfig = try decoder.decode(Config.Presence.self, from: configData)
		} catch {
			Log.info("Presence config not found or invalid at '\(presenceConfigPath)' - \(error)")
			presenceConfig = nil
		}
		let coverConfigPath = "\(configDir)/config.cover.json"
		do {
			let configData = try Data(contentsOf: URL(filePath: coverConfigPath))
			coverConfig = try decoder.decode(Config.Cover.self, from: configData)
		} catch {
			Log.info("Cover config not found or invalid at '\(coverConfigPath)' - \(error)")
			coverConfig = nil
		}

		stateStore = StateStore(configDir: configDir)
		mqttClient = MQTTClient(config: generalConfig.mqtt)
	}

	func run() async {
		// general
		setupHomeAssistantRestApi()
		await setupServerState()
		// features
		await setupPresenceDetectors()
		await setupCovers()

		await mqttClient.start()

		await startPresenceDetectors()
	}

	func shutdown() async {
		await stateStore.saveNow()
		await mqttClient.shutdown()
	}
}
