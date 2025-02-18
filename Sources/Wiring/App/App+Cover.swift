extension App {
	func setupCovers() async {
		guard
			let coverConfig,
			let homeAssistantRestApi
		else { return }

		for (name, config) in coverConfig.entries {
			let initialState = await stateStore.getCoverState(name: name) ?? State.Cover(
				currentPosition: 0,
				targetPosition: 0,
				controlTriggeDate: nil
			)
			coverControllers.append(CoverController(
				name: name,
				config: config,
				stateStore: stateStore,
				mqttClient: mqttClient,
				homeAssistantRestApi: homeAssistantRestApi,
				state: initialState
			))
		}
	}
}
