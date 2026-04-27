extension App {
	func setupHomeAssistantWebSocket() async {
		guard let config = generalConfig.homeAssistant else { return }
		homeAssistantWebSocket = HomeAssistantWebSocket(config: config)
	}
}
