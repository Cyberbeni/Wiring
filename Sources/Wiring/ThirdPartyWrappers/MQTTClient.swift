import Foundation
import MQTTNIO
import NIO
import NIOFoundationCompat

actor MQTTClient {
	private static let reconnectDelay: Double = 5
	private static let clientId = "Wiring"

	private let mqttClient: MQTTNIO.MQTTClient

	private var isStarted = false
	private var isConnecting = false
	private var topicsByClientId: [UUID: Set<String>] = [:]
	private var onConnectMessages: [String: ByteBuffer] = [:]

	private let baseTopic: String
	nonisolated var stateTopic: String { "\(baseTopic)/server/state" }

	private let messageEncoder = Mqtt.jsonEncoder()

	init(config: Config.Mqtt) {
		baseTopic = config.baseTopic
		mqttClient = MQTTNIO.MQTTClient(
			host: config.host,
			port: config.port,
			identifier: Self.clientId,
			eventLoopGroupProvider: .createNew,
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
		setOnConnectMessage(topic: stateTopic, rawMessage: Mqtt.Availability.online)
		isStarted = true

		mqttClient.addPublishListener(named: Self.clientId) { result in
			guard case let .failure(error) = result else { return }
			Log.error("Publish listener error: \(error)")
		}
		mqttClient.addCloseListener(named: Self.clientId) { [weak self] _ in
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

	func setSubscriptions(clientId: UUID, topics: Set<String>, _ listener: @escaping (Result<MQTTPublishInfo, Swift.Error>) -> Void) {
		guard !isStarted else {
			Log.error("Adding subscriptions after already started")
			return
		}
		topicsByClientId[clientId] = topics
		mqttClient.addPublishListener(named: clientId.uuidString, listener)
	}

	func setOnConnectMessage<T: RawRepresentable>(topic: String, rawMessage: T) where T.RawValue == String {
		guard !isStarted else {
			Log.error("Trying to add onConnect message after starting")
			return
		}
		onConnectMessages[topic] = ByteBuffer(string: rawMessage.rawValue)
	}

	func setOnConnectMessage(topic: String, message: some Codable) {
		guard !isStarted else {
			Log.error("Trying to add onConnect message after starting")
			return
		}
		do {
			var payload = ByteBuffer()
			try payload.writeJSONEncodable(message, encoder: messageEncoder)
			onConnectMessages[topic] = payload
		} catch {
			Log.error(error)
		}
	}

	// MARK: - After starting

	func publish<T: RawRepresentable>(topic: String, rawMessage: T, retain: Bool) where T.RawValue == String {
		guard isStarted else {
			Log.error("Trying to publish before starting")
			return
		}
		_ = mqttClient.publish(
			to: topic,
			payload: ByteBuffer(string: rawMessage.rawValue),
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

	func publish(topic: String, message: some Codable, retain: Bool) {
		guard isStarted else {
			Log.error("Trying to publish before starting")
			return
		}
		do {
			var payload = ByteBuffer()
			try payload.writeJSONEncodable(message, encoder: messageEncoder)
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

	// MARK: - Private functions

	private func publishOnConnectMessages() {
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

	private func connect(isReconnect: Bool) async {
		guard isStarted, !isConnecting else { return }
		isConnecting = true
		defer { isConnecting = false }

		do {
			if isReconnect {
				try await Task.sleep(for: .seconds(Self.reconnectDelay), tolerance: .seconds(0.1))
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
