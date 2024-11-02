import Foundation
#if canImport(SwiftGlibc)
	@preconcurrency import SwiftGlibc
#endif

// Make sure print() output is instant
setlinebuf(stdout)

let app = App()
Task {
	await app.run()
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
		Log.info("Terminating...")
		Task {
			await app.shutdown()
			Log.info("Successfully teared down everything.")
			exit(0)
		}
	}
	signalSource.resume()
	return signalSource
}

RunLoop.main.run()
