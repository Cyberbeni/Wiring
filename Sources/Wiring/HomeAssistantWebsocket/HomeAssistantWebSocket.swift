import Foundation
import WebSocketKit

actor HomeAssistantWebSocket {
	private let client = WebSocketClient(eventLoopGroupProvider: .createNew)
	private let config: Config.WebSocket
	private let decoder = HomeAssistantWebSocketMessage.jsonDecoder()
	private let encoder = HomeAssistantWebSocketMessage.jsonEncoder()
	private var webSocket: WebSocket?

	private var isStarted = false
	private var runTask: Task<Void, Error>?

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
		// TODO: remove testing code
		// Task {
		//     await sendAuthMessage()
		// }
	}

	private func handleTextMessage(_ message: String) async {
		guard let data = message.data(using: .utf8) else {
			Log.error("WebSocket: Failed to parse message.")
			return
		}
		await handleMessage(data)
	}

	private func handleBinaryMessage(_ message: ByteBuffer) async {
		var message = message
		guard let data = message.readData(length: message.readableBytes) else {
			Log.error("WebSocket: Failed to parse message.")
			return
		}
		await handleMessage(data)
	}

	private func handleMessage(_ rawMessage: Data) async {
		do {
			let message = try decoder.decode(HomeAssistantWebSocketMessage.self, from: rawMessage)
			switch message {
			case .authRequired:
				await sendAuthMessage()
			case .auth:
				Log.error("WebSocket: Unexpected auth message.")
			case .authOk:
				Log.info("WebSocket: Auth OK.")
			case .authInvalid:
				Log.error("WebSocket: Auth invalid.")
			}
		} catch {
			Log.error(error)
		}
	}

	private func sendAuthMessage() async {
		do {
			let message = HomeAssistantWebSocketMessage.auth(.init(accessToken: config.accessToken))
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
