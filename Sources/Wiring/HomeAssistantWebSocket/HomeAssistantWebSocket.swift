import Foundation
import WebSocketKit

actor HomeAssistantWebSocket {
	private let client = WebSocketClient(eventLoopGroupProvider: .createNew)
	private let config: Config.WebSocket
	private let decoder = Message.jsonDecoder()
	private let encoder = Message.jsonEncoder()

	private var isStarted = false
	private var webSocket: WebSocket?
	private var nextMessageId: Message.ID = 1

	init(config: Config.WebSocket) {
		self.config = config
	}

	func start() {
		guard !isStarted else { return }
		isStarted = true
		_ = client.connect(
			scheme: config.scheme,
			host: config.host,
			port: config.port,
			path: config.path
		) { [weak self] webSocket in
			Task {
				await self?.setWebSocket(webSocket)
			}
		}
	}

	private func setWebSocket(_ webSocket: WebSocket) {
		self.webSocket = webSocket
		webSocket.onText { [weak self] _, string in
			await self?.handleTextMessage(string)
		}
		webSocket.onBinary { [weak self] _, bytes in
			await self?.handleBinaryMessage(bytes)
		}
		Log.info("WebSocket connected")
		// TODO: check what happens on HA restart
		Task {
			await sendAuthMessage()
			// TODO: remove testing code
			await sendRemoteCommand()
		}
	}

	private func handleTextMessage(_ message: String) async {
		guard let data = message.data(using: .utf8) else {
			Log.error("Failed to parse message.")
			return
		}
		await handleMessage(data)
	}

	private func handleBinaryMessage(_ message: ByteBuffer) async {
		var message = message
		guard let data = message.readData(length: message.readableBytes) else {
			Log.error("Failed to parse message.")
			return
		}
		await handleMessage(data)
	}

	private func handleMessage(_ rawMessage: Data) async {
		do {
			let message = try decoder.decode(Message.self, from: rawMessage)
			Log.debug("Received message: \(message)")
			switch message {
			case .authRequired:
				await sendAuthMessage()
			case .auth:
				Log.error("Unexpected auth message.")
			case .authOk:
				Log.info("WebSocket: Auth OK.")
			case .authInvalid:
				Log.error("Auth invalid.")
			case .callService:
				Log.error("Unexpected callService message.")
			case let .result(result):
				if !result.success {
					Log.error("callService failed: \(result.id ?? 0)")
				}
			}
		} catch {
			Log.error(error)
		}
	}

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
				"command": "open", // open / close / stop
			],
			target: .init(entityId: "remote.broadlink_rm4_pro")
		)))
	}

	private func sendMessage(_ message: Message) async {
		do {
			Log.debug("Sending message: \(message)")
			let data = try encoder.encode(message)
			let text = String(decoding: data, as: UTF8.self)
			try await webSocket?.send(text)
		} catch {
			Log.error(error)
		}
	}

	func shutdown() {
		try? client.syncShutdown()
	}
}
