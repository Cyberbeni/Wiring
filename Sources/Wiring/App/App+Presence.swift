extension App {
	func setupPresenceDetectors() async {
		guard let presenceConfig else { return }
		let mqttConfig = generalConfig.mqtt

		presenceDetectorAggregators = presenceConfig.entries.reduce(into: [:]) { result, entry in
			result[entry.key] = PresenceDetectorAggregator(
				mqttClient: mqttClient,
				mqttConfig: mqttConfig,
				presenceConfig: presenceConfig,
				person: entry.key
			)
		}

		blePresenceDetectors = presenceConfig.entries.compactMap { person, config in
			guard let device = config.espresenseDevice,
			      let aggregator = presenceDetectorAggregators[person]
			else { return nil }
			return BlePresenceDetector(
				mqttClient: mqttClient,
				presenceConfig: presenceConfig,
				topic: "\(presenceConfig.espresenseDevicesBaseTopic)/\(device)",
				presenceDetectorAggregator: aggregator
			)
		}
		for detector in blePresenceDetectors {
			await detector.start()
		}

		for person in presenceConfig.entries.keys {
			let name = "Presence \(person)"
			let stateTopic = "\(mqttConfig.baseTopic)/presence/\(person)"
			let config = Mqtt.BinarySensor(
				availabilityTopic: mqttClient.stateTopic,
				device: .init(
					identifiers: stateTopic,
					name: nil
				),
				deviceClass: .presence,
				name: name,
				objectId: name,
				stateTopic: stateTopic,
				uniqueId: stateTopic.replacingOccurrences(of: "/", with: "_")
			)
			await mqttClient.setOnConnectMessage(
				topic: "\(mqttConfig.homeAssistantBaseTopic)/binary_sensor/\(mqttConfig.baseTopic)-presence/\(person)/config",
				message: config
			)
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
			Log.error("Failed to initialize NetworkPresenceDetector: \(error)")
			return
		}

		Task {
			while !Task.isCancelled {
				let activeIps = await networkPresenceDetector.getActiveIps()
				for (person, ip) in ips {
					await presenceDetectorAggregators[person]?.setNetworkPresence(activeIps.contains(ip))
				}
				try await Task.sleep(for: .seconds(presenceConfig.arpInterval.seconds), tolerance: .seconds(0.1))
			}
		}
	}
}
