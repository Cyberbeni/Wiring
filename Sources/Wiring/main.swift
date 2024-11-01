import Foundation
#if canImport(SwiftGlibc)
	@preconcurrency import SwiftGlibc
#endif

// Make sure print() output is instant
setlinebuf(stdout)

let a = try NetworkPresenceDetector(ips: ["192.168.1.40"], pingInterval: 5)
Task {
	while !Task.isCancelled {
		let ips = await a.getActiveIps()
		print("Active IPs: \(ips)")
		try await Task.sleep(for: .seconds(5), tolerance: .seconds(0.1))
	}
}

let mqttClient = MQTTClient(host: "localhost", port: 1883, user: nil, password: nil)
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
