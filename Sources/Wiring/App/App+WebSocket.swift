extension App {
	func setupWebSocket() async {
		guard let webSocketConfig = generalConfig.webSocket else { return }
		homeAssistantWebSocket = HomeAssistantWebSocket(config: webSocketConfig)
	}
}
