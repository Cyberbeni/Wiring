import Foundation
import WebSocketKit

actor HomeAssistantWebSocket {
	private static let reconnectDelay: Double = 20

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

	func start() async {
		guard !isStarted else { return }
		isStarted = true
		await connect(isReconnect: false)
	}

	func connect(isReconnect: Bool) async {
		do {
			if isReconnect {
				try await Task.sleep(for: .seconds(Self.reconnectDelay), tolerance: .seconds(0.1))
				Log.debug("Attempting to reconnect.")
			}
			self.nextMessageId = 1
			_ = client.connect(
				scheme: config.scheme,
				host: config.host,
				port: config.port,
				path: config.path
			) { [weak self] webSocket in
				// Set callback without context switching, so auth_required message is not missed
				self?.webSocket = webSocket
				webSocket.onText { [weak self] webSocket, messageString in
					await self?.handleMessage(messageString, webSocket: webSocket)
				}
				_ = webSocket.onClose.always { [weak self] _ in
					Log.error("Connection closed...")
					Task { [weak self] in
						await self?.connect(isReconnect: true)
					}
				}
				Task { [weak self] in
					await self?.handleConnected(webSocket: webSocket)
				}
			}.always { result in
				Log.debug(".connect future: \(result)")
				guard case .success = result else {
					Task { [weak self] in
						await self?.connect(isReconnect: true)
					}
					return
				}
			}
		} catch {
			Log.error(error)
			Task { [weak self] in
				await self?.connect(isReconnect: true)
			}
		}
	}

	private func handleConnected(webSocket: WebSocket) {
		self.webSocket = webSocket
		Log.info("WebSocket connected")
	}

	// MARK: Receive message

	private func handleMessage(_ messageString: String, webSocket: WebSocket) async {
		self.webSocket = webSocket
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
				Log.info("WebSocket: Auth OK.")
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
			target: .init(entityId: "remote.broadlink_rm4_pro")
		)))
	}

	private func sendMessage(_ message: Message) async {
		do {
			Log.debug("Sending message: \(message)")
			let data = try encoder.encode(message)
			try await webSocket?.send(raw: data, opcode: .text)
		} catch {
			Log.error(error)
		}
	}

	// MARK: Shutdown

	func shutdown() {
		try? client.syncShutdown()
	}
}
