import Foundation
#if canImport(SwiftGlibc)
	@preconcurrency import SwiftGlibc
#endif

// Make sure print() output is instant
setlinebuf(stdout)

let decoder = JSONDecoder()

let generalConfigPath = "/config/config.general.json"
let generalConfig: GeneralConfig
do {
	let generalConfigData = try Data(contentsOf: URL(filePath: generalConfigPath))
	generalConfig = try decoder.decode(GeneralConfig.self, from: generalConfigData)
} catch {
	print("General config not found or invalid at '\(generalConfigPath)'")
	exit(1)
}
let presenceConfigPath = "/config/config.presence.json"
let presenceConfig: PresenceConfig?
do {
	let presenceConfigData = try Data(contentsOf: URL(filePath: presenceConfigPath))
	presenceConfig = try decoder.decode(PresenceConfig.self, from: presenceConfigData)
} catch {
	print("Presence config not found or invalid at '\(presenceConfigPath)'")
	presenceConfig = nil
}

let a = try NetworkPresenceDetector(ips: ["192.168.1.40"], pingInterval: 5)
Task {
	while !Task.isCancelled {
		let ips = await a.getActiveIps()
		print("Active IPs: \(ips)")
		try await Task.sleep(for: .seconds(5), tolerance: .seconds(0.1))
	}
}

let mqttClient = MQTTClient(config: generalConfig.mqtt)
Task {
	await mqttClient.start()
}

let signalHandlers = [
	SIGINT, // ctrl+C in interactive mode
	SIGTERM, // docker container stop container_name
].map { signalName in
	// https://github.com/swift-server/swift-service-lifecycle/blob/24c800fb494fbee6e42bc156dc94232dc08971af/Sources/UnixSignals/UnixSignalsSequence.swift#L80-L85
	#if canImport(Darwin)
		signal(signalName, SIG_IGN)
	#endif
	let signalSource = DispatchSource.makeSignalSource(signal: signalName, queue: .main)
	signalSource.setEventHandler {
		print("Terminating...")
		Task {
			await mqttClient.shutdown()
			print("Successfully teared down everything.")
			exit(0)
		}
	}
	signalSource.resume()
	return signalSource
}

RunLoop.main.run()
