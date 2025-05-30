import Foundation
import MQTTNIO
import NIO
import NIOFoundationCompat

actor MQTTClient {
	private static let reconnectDelay: Double = 5

	private let mqttClient: MQTTNIO.MQTTClient

	private var isStarted = false
	private var isConnecting = false
	private var topicsByClientId: [UUID: Set<String>] = [:]
	private var onConnectMessages: [String: ByteBuffer] = [:]

	private let baseTopic: String
	private let clientId: String
	nonisolated var stateTopic: String { "\(baseTopic)/server/state" }

	private let messageEncoder = Mqtt.jsonEncoder()

	init(config: Config.Mqtt) {
		baseTopic = config.baseTopic
		let clientId = "Wiring - \(config.baseTopic)"
		self.clientId = clientId
		mqttClient = MQTTNIO.MQTTClient(
			host: config.host,
			port: config.port,
			identifier: clientId,
			eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
			configuration: MQTTNIO.MQTTClient.Configuration(
				version: .v5_0,
				userName: config.user,
				password: config.password
			)
		)
	}

	deinit {
		try? mqttClient.syncShutdownGracefully()
	}

	func start() async {
		guard !isStarted else { return }
		isStarted = true

		onConnectMessages[stateTopic] = ByteBuffer(string: Mqtt.Availability.online.rawValue)
		mqttClient.addPublishListener(named: clientId) { result in
			guard case let .failure(error) = result else { return }
			Log.error("Publish listener error: \(error)")
		}
		mqttClient.addCloseListener(named: clientId) { [weak self] _ in
			Log.error("Connection closed...")
			Task { [weak self] in
				await self?.connect(isReconnect: true)
			}
		}

		await connect(isReconnect: false)
	}

	func shutdown() async {
		try? await mqttClient.shutdown()
	}

	// MARK: - Before starting

	func setSubscriptions(clientId: UUID, topics: Set<String>, _ listener: @escaping (ByteBuffer) -> Void) {
		guard !isStarted else {
			Log.error("Adding subscriptions after already started")
			return
		}
		topicsByClientId[clientId] = topics
		let regexes = regexes(for: topics)
		mqttClient.addPublishListener(named: clientId.uuidString) { result in
			guard
				case let .success(msg) = result,
				regexes.contains(where: { msg.topicName.firstMatch(of: $0) != nil })
			else { return }
			listener(msg.payload)
		}
	}

	// MARK: - After starting

	func publish<T: RawRepresentable>(topic: String, rawMessage: T, retain: Bool) where T.RawValue == String {
		let payload = ByteBuffer(string: rawMessage.rawValue)
		if retain {
			onConnectMessages[topic] = payload
		}
		guard isStarted else { return }
		_ = mqttClient.publish(
			to: topic,
			payload: payload,
			qos: .atMostOnce,
			retain: retain
		).always { result in
			switch result {
			case .success:
				Log.debug("Message published to \(topic)")
			case let .failure(error):
				Log.error(error)
			}
		}
	}

	func publish(topic: String, message: some Encodable, retain: Bool) {
		do {
			var payload = ByteBuffer()
			try payload.writeJSONEncodable(message, encoder: messageEncoder)
			if retain {
				onConnectMessages[topic] = payload
			}
			guard isStarted else { return }
			_ = mqttClient.publish(
				to: topic,
				payload: payload,
				qos: .atMostOnce,
				retain: retain
			).always { result in
				switch result {
				case .success:
					Log.debug("Message published to \(topic)")
				case let .failure(error):
					Log.error(error)
				}
			}
		} catch {
			Log.error(error)
		}
	}
}

// MARK: - Private functions

private extension MQTTClient {
	func regexes(for topics: Set<String>) -> sending [Regex<AnyRegexOutput>] {
		topics.compactMap { string in
			do {
				return try Regex("^\(string)$"
					.replacingOccurrences(of: "/", with: "\\/")
					.replacingOccurrences(of: "+", with: "[^\\/]+")
					.replacingOccurrences(of: "#", with: ".+"))
					.repetitionBehavior(.possessive)
			} catch {
				Log.error("Failed to create regex from MQTT topic: \(string)")
				return nil
			}
		}
	}

	func publishOnConnectMessages() {
		for (topic, payload) in onConnectMessages {
			_ = mqttClient.publish(
				to: topic,
				payload: payload,
				qos: .atMostOnce,
				retain: true
			).always { result in
				switch result {
				case .success:
					Log.debug("Message published to \(topic)")
				case let .failure(error):
					Log.error(error)
				}
			}
		}
	}

	func connect(isReconnect: Bool) async {
		guard isStarted, !isConnecting else { return }
		isConnecting = true
		defer { isConnecting = false }

		do {
			if isReconnect {
				try await Task.sleep(for: .seconds(Self.reconnectDelay))
				Log.debug("Attempting to reconnect.")
			}
			try await mqttClient.connect(
				will: (topicName: stateTopic, payload: ByteBuffer(string: Mqtt.Availability.offline.rawValue), qos: .atMostOnce, retain: true)
			)
			let topicsToSubscribe = topicsByClientId.values.reduce(into: Set<String>()) { $0.formUnion($1) }
			if !topicsToSubscribe.isEmpty {
				_ = try await mqttClient.subscribe(to: topicsToSubscribe.map { topic in
					MQTTSubscribeInfo(topicFilter: topic, qos: .atMostOnce)
				})
			}
			Log.info("MQTT connected.")
			publishOnConnectMessages()
		} catch {
			Log.error(error)
			Task { [weak self] in
				await self?.connect(isReconnect: true)
			}
		}
	}
}
