import Foundation
import MQTTNIO
import NIO

actor MQTTClient {
	private static let reconnectDelay: Double = 5
	private static let clientId = "Wiring"

	private let mqttClient: MQTTNIO.MQTTClient

	private var isStarted = false
	private var isConnecting = false
	private var topicsByClientId: [UUID: Set<String>] = [:]

	private let rootTopic: String
	private var stateTopic: String { "\(rootTopic)/server/state" }
	private let onlineState = #"{"state":"online"}"#
	private let offlineState = #"{"state":"offline"}"#

	init(config: MqttConfig) {
		self.rootTopic = config.rootTopic
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

	// TODO: pass Codable instead
	// https://swiftinit.org/docs/swift-nio/niocore/bytebuffer.writejsonencodable(_:encoder:)
	func publish(topic: String, message: String, retain: Bool) {
		guard isStarted else {
			print("\(Self.self) error: Trying to publish before starting")
			return
		}
		_ = mqttClient.publish(
			to: topic,
			payload: ByteBuffer(string: message),
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
				will: (topicName: stateTopic, payload: ByteBuffer(string: offlineState), qos: .atMostOnce, retain: true)
			)
			let topicsToSubscribe = topicsByClientId.values.reduce(into: Set<String>()) { $0.formUnion($1) }
			if !topicsToSubscribe.isEmpty {
				_ = try await mqttClient.subscribe(to: topicsToSubscribe.map { topic in
					MQTTSubscribeInfo(topicFilter: topic, qos: .atMostOnce)
				})
			}
			print("\(Self.self) connected.")
			publish(topic: stateTopic, message: onlineState, retain: true)
		} catch {
			print("\(Self.self) connection error: \(error)")
			Task { [weak self] in
				await self?.connect(isReconnect: true)
			}
		}
	}
}
