import NIOCore
import WSClient

actor HomeAssistantWebSocket {
	private static let reconnectDelay: Double = 5

	private let config: Config.HomeAssistant
	private let decoder = Message.jsonDecoder()
	private let encoder = Message.jsonEncoder()

	private var subscriptions: [String: nonisolated(nonsending)(_ state: String) async -> Void] = [:]

	private var runTask: Task<Void, Never>?
	private var outboundWriter: WebSocketOutboundWriter?
	private var nextMessageId: Message.ID = 1
	private var eventHandlers: [Message.ID: nonisolated(nonsending)(HomeAssistantWebSocket.Message.EventWrapper.Event) async -> Void] = [:]

	init(config: Config.HomeAssistant) {
		self.config = config
	}

	func start() async {
		guard runTask == nil else { return }

		runTask = Task {
			await run()
		}
	}

	func addSubscription(entityId: String, callback: nonisolated(nonsending) @escaping (_ state: String) async -> Void) {
		guard runTask == nil else {
			Log.error("Adding subscriptions after already started")
			return
		}
		if let existingCallback = subscriptions[entityId] {
			subscriptions[entityId] = { state in
				await existingCallback(state)
				await callback(state)
			}
		} else {
			subscriptions[entityId] = callback
		}
	}

	private func run() async {
		let client = WebSocketClient(
			url: "\(config.baseAddress.appendingSlashIfNeeded())websocket",
			logger: .init(label: "HomeAssistantWebSocket"),
		) { [weak self] inboundStream, outboundWriter, _ in
			await self?.handleConnected(outboundWriter)
			for try await message in inboundStream.messages(maxSize: 1 << 14) {
				switch message {
				case let .text(messageString):
					await self?.handleMessage(messageString)
				case let .binary(buffer):
					await self?.handleMessage(buffer)
				}
			}
		}

		do {
			while !Task.isCancelled {
				nextMessageId = 1
				eventHandlers.removeAll()
				do {
					if let closeFrame = try await client.run() {
						Log.info("WebSocket close frame: \(closeFrame)")
					}
				} catch {
					Log.error(error)
				}
				Log.error("Connection closed...")
				try await Task.sleep(for: .seconds(Self.reconnectDelay), tolerance: .seconds(0.1))
				Log.debug("Attempting to reconnect.")
			}
		} catch {
			Log.error(error)
		}
	}

	private func handleConnected(_ outboundWriter: WebSocketOutboundWriter) {
		self.outboundWriter = outboundWriter
		Log.info("WebSocket connected")
	}

	// MARK: Receive message

	private func handleMessage(_ messageString: String) async {
		Log.debug("Received message: \(messageString)")
		guard let messageData = messageString.data(using: .utf8) else {
			Log.error("Message is not UTF8.")
			return
		}
		await handleMessage(messageData)
	}

	private func handleMessage(_ buffer: ByteBuffer) async {
		Log.debug("Received message: \(String(buffer: buffer))")
		await handleMessage(Data(buffer: buffer))
	}

	private func handleMessage(_ messageData: Data) async {
		do {
			let message = try decoder.decode(Message.self, from: messageData)
			switch message {
			case .authRequired:
				await sendAuthMessage()
			case .authOk:
				Log.info("Auth OK.")
				await subscribeToStates()
			case .authInvalid:
				Log.error("Auth invalid.")
			case let .event(eventWrapper):
				await eventHandlers[eventWrapper.id]?(eventWrapper.event)
			case let .result(result):
				if !result.success {
					if let error = result.error {
						Log.error("Received failure, request ID: \(result.id ?? 0), error: \(error)")
					} else {
						Log.error("Received failure, request ID: \(result.id ?? 0)")
					}
				}
			case .auth,
			     .callService,
			     .renderTemplate:
				Log.error("Unexpected message type.")
			}
		} catch {
			Log.error(error)
		}
	}

	// MARK: Send message

	private func sendAuthMessage() async {
		await sendMessage(.auth(.init(accessToken: config.accessToken)))
	}

	private func subscribeToStates() async {
		for entityId in subscriptions.keys {
			let id = nextMessageId
			nextMessageId += 1
			eventHandlers[id] = { [weak self] event in
				await self?.handleEvent(event, for: entityId)
			}
			await sendMessage(.renderTemplate(.init(
				id: id,
				template: "{{ states('\(entityId)') }}",
			)))
		}
	}

	private func handleEvent(_ event: HomeAssistantWebSocket.Message.EventWrapper.Event, for entityId: String) async {
		await subscriptions[entityId]?(event.result)
	}

	func callService(_ serviceCall: some HomeAssistantServiceCall) async {
		let id = nextMessageId
		nextMessageId += 1
		await sendMessage(.callService(.init(
			id: id,
			domain: serviceCall.domain,
			service: serviceCall.service,
			serviceData: serviceCall.serviceData.asDictionary(),
			target: .init(entityId: serviceCall.entityId),
		)))
	}

	private func sendMessage(_ message: Message) async {
		do {
			Log.debug("Sending message: \(message)")
			let data = try encoder.encode(message)
			try await outboundWriter?.write(.text(String(decoding: data, as: UTF8.self)))
		} catch {
			Log.error(error)
		}
	}

	// MARK: Shutdown

	func shutdown() async {
		if let runTask {
			runTask.cancel()
			_ = await runTask.result
		}
	}
}
