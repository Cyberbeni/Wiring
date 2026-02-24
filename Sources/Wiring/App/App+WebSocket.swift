extension App {
	func setupWebSocket() async {
		guard let config = generalConfig.homeAssistant else { return }
		homeAssistantWebSocket = HomeAssistantWebSocket(config: config)
	}
}
