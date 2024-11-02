extension App {
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

		let mqttConfig = generalConfig.mqtt
		let arpInterval = presenceConfig.arpInterval

		Task {
			for person in ips.keys {
				let name = "Presence WiFi \(person)"
				let stateTopic = "\(mqttConfig.baseTopic)/presence/\(person)"
				let config = Mqtt.BinarySensor(
					availabilityTopic: mqttClient.stateTopic,
					deviceClass: .presence,
					stateTopic: stateTopic,
					name: name,
					device: .init(
						name: name,
						identifiers: stateTopic
					)
				)
				await mqttClient.publish(topic: "\(mqttConfig.homeAssistantBaseTopic)/binary_sensor/\(mqttConfig.baseTopic)-presence/\(person)/config", message: config, retain: true)
			}
			while !Task.isCancelled {
				let activeIps = await networkPresenceDetector.getActiveIps()
				for (person, ip) in ips {
					await mqttClient.publish(topic: "\(mqttConfig.baseTopic)/presence/\(person)", rawMessage: activeIps.contains(ip) ? Mqtt.BinarySensor.Payload.on : .off, retain: false)
				}
				try await Task.sleep(for: .seconds(arpInterval.seconds), tolerance: .seconds(0.1))
			}
		}
	}
}
