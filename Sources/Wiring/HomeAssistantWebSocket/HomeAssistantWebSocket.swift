import Foundation
import WSClient

actor HomeAssistantWebSocket {
	private static let reconnectDelay: Double = 5

	private let config: Config.HomeAssistant
	private let decoder = Message.jsonDecoder()
	private let encoder = Message.jsonEncoder()

	private var runTask: Task<Void, Never>?
	private var outboundWriter: WebSocketOutboundWriter?
	private var nextMessageId: Message.ID = 1

	init(config: Config.HomeAssistant) {
		self.config = config
	}

	func start() async {
		guard runTask == nil else { return }

		runTask = Task {
			await run()
		}
	}

	private func run() async {
		guard let url = URL(string: "websocket", relativeTo: config.baseAddress) else {
			Log.error("Unable to create URL.")
			return
		}
		let client = WebSocketClient(
			url: url.absoluteString,
			logger: .init(label: "HomeAssistantWebSocket"),
		) { [weak self] inboundStream, outboundWriter, context in
			await self?.handleConnected(outboundWriter)
			for try await message in inboundStream.messages(maxSize: 1 << 14) {
				switch message {
				case let .text(messageString):
					await self?.handleMessage(messageString)
				case .binary:
					Log.error("Binary WebSocket messages are not handled.")
				}
			}
		}

		do {
			while !Task.isCancelled {
				nextMessageId = 1
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
		do {
			let message = try decoder.decode(Message.self, from: messageData)
			switch message {
			case .authRequired:
				await sendAuthMessage()
			case .auth:
				Log.error("Unexpected auth message.")
			case .authOk:
				Log.info("Auth OK.")
				// TODO: remove testing send remote
				await sendRemoteCommand()
			case .authInvalid:
				Log.error("Auth invalid.")
			case .callService:
				Log.error("Unexpected callService message.")
			case let .result(result):
				if !result.success {
					if let error = result.error {
						Log.error("Received failure, request ID: \(result.id ?? 0), error: \(error)")
					} else {
						Log.error("Received failure, request ID: \(result.id ?? 0)")
					}
				}
			}
		} catch {
			Log.error(error)
		}
	}

	// MARK: Send message

	private func sendAuthMessage() async {
		await sendMessage(.auth(.init(accessToken: config.accessToken)))
	}

	// TODO: accept inputs
	func sendRemoteCommand() async {
		let id = nextMessageId
		nextMessageId += 1
		await sendMessage(.callService(.init(
			id: id,
			domain: "remote",
			service: "send_command",
			serviceData: [
				"device": "homekit/blind/emelet",
				"command": "close", // open / close / stop
			],
			target: .init(entityId: "remote.broadlink_rm4_pro"),
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
