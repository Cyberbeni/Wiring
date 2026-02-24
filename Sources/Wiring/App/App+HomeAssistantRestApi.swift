extension App {
	func setupHomeAssistantRestApi() {
		guard let config = generalConfig.homeAssistant else { return }
		homeAssistantRestApi = HomeAssistantRestApi(config: config)
	}
}
