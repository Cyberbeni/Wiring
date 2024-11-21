import WebSocketKit

actor HomeAssistantWebSocket {
	private let client = WebSocketClient(eventLoopGroupProvider: .createNew)
	private let config: Config.WebSocket
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
		Log.debug("WebSocket connected")
	}

	private func handleTextMessage(_ message: String) {
		Log.debug("WS string: \(message)")
		// {"type":"auth_required","ha_version":"2024.10.4"}
	}

	private func handleBinaryMessage(_ message: ByteBuffer) {
		Log.debug("WS binary: \(message)")
	}

	func shutdown() {
		try? client.syncShutdown()
	}
}
