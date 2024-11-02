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

	private let baseTopic: String
	private var stateTopic: String { "\(baseTopic)/server/state" }

	private let messageEncoder = JSONEncoder()

	init(config: MqttConfig) {
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
		isStarted = true

		mqttClient.addPublishListener(named: Self.clientId) { result in
			guard case let .failure(error) = result else { return }
			print("\(Self.self) publish listener error: \(error)")
		}
		mqttClient.addCloseListener(named: Self.clientId) { [weak self] _ in
			print("\(Self.self) connection closed...")
			Task { [weak self] in
				await self?.connect(isReconnect: true)
			}
		}

		await connect(isReconnect: false)
	}

	func shutdown() async {
		try? await mqttClient.shutdown()
	}

	func setSubscriptions(clientId: UUID, topics: Set<String>, _ listener: @escaping (Result<MQTTPublishInfo, Swift.Error>) -> Void) {
		guard !isStarted else {
			print("\(Self.self) error: Adding subscriptions after already started")
			return
		}
		topicsByClientId[clientId] = topics
		mqttClient.addPublishListener(named: clientId.uuidString, listener)
	}

	func publish<T: RawRepresentable>(topic: String, rawMessage: T, retain: Bool) where T.RawValue == String {
		guard isStarted else {
			print("\(Self.self) error: Trying to publish before starting")
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
				print("\(Self.self) message published to \(topic)")
			case let .failure(error):
				print("\(Self.self) publish error: \(error)")
			}
		}
	}

	func publish(topic: String, message: some Codable, retain: Bool) {
		guard isStarted else {
			print("\(Self.self) error: Trying to publish before starting")
			return
		}
		do {
			var payload = ByteBuffer()
			try payload.encodeJSONEncodable(message, encoder: messageEncoder)
			_ = mqttClient.publish(
				to: topic,
				payload: ByteBuffer(data: payloadData),
				qos: .atMostOnce,
				retain: retain
			).always { result in
				switch result {
				case .success:
					print("\(Self.self) message published to \(topic)")
				case let .failure(error):
					print("\(Self.self) publish error: \(error)")
				}
			}
		} catch {
			print("\(Self.self) publish error: \(error)")
		}
	}

	// MARK: - Private functions

	private func connect(isReconnect: Bool) async {
		guard isStarted, !isConnecting else { return }
		isConnecting = true
		defer { isConnecting = false }

		do {
			if isReconnect {
				try await Task.sleep(for: .seconds(Self.reconnectDelay), tolerance: .seconds(0.1))
				print("\(Self.self) attempting to reconnect.")
			}
			try await mqttClient.connect(
				will: (topicName: stateTopic, payload: ByteBuffer(string: MqttAvailability.offline.rawValue), qos: .atMostOnce, retain: true)
			)
			let topicsToSubscribe = topicsByClientId.values.reduce(into: Set<String>()) { $0.formUnion($1) }
			if !topicsToSubscribe.isEmpty {
				_ = try await mqttClient.subscribe(to: topicsToSubscribe.map { topic in
					MQTTSubscribeInfo(topicFilter: topic, qos: .atMostOnce)
				})
			}
			print("\(Self.self) connected.")
			// TODO: only make available when everything else is up to date?
			publish(topic: stateTopic, rawMessage: MqttAvailability.online, retain: true)
		} catch {
			print("\(Self.self) connection error: \(error)")
			Task { [weak self] in
				await self?.connect(isReconnect: true)
			}
		}
	}
}
