extension App {
	func setupCovers() async {
		guard
			let coverConfig,
			let homeAssistantRestApi
		else { return }
		let mqttConfig = generalConfig.mqtt

		await createControllers(
			configs: coverConfig.entries,
			coverConfig: coverConfig,
			mqttConfig: mqttConfig,
			homeAssistantRestApi: homeAssistantRestApi
		)

		for controller in coverControllers {
			await controller.start()
		}
	}

	@discardableResult
	private func createControllers(
		configs: [String: Config.Cover.CoverItem]?,
		coverConfig: Config.Cover,
		mqttConfig: Config.Mqtt,
		homeAssistantRestApi: HomeAssistantRestApi
	) async -> [CoverController] {
		guard let configs, !configs.isEmpty else { return [] }
		var coverControllers: [CoverController] = []
		for (name, config) in configs {
			let children = await createControllers(
				configs: config.children,
				coverConfig: coverConfig,
				mqttConfig: mqttConfig,
				homeAssistantRestApi: homeAssistantRestApi
			)
			let initialState = await stateStore.getCoverState(name: name)?.asInitialState ?? State.Cover(
				currentPosition: 0,
				targetPosition: 0,
				controlTriggeDate: nil
			)
			coverControllers.append(CoverController(
				name: name,
				baseTopic: mqttConfig.baseTopic,
				remoteEntityId: coverConfig.remoteEntityId,
				remoteDevice: config.remoteDevice,
				deviceClass: config.deviceClass,
				openSmallDuration: config.openSmallDuration,
				openLargeDuration: config.openLargeDuration,
				closeSmallDuration: config.closeSmallDuration,
				closeLargeDuration: config.closeLargeDuration,
				stateStore: stateStore,
				mqttClient: mqttClient,
				homeAssistantRestApi: homeAssistantRestApi,
				state: initialState,
				children: children
			))
			let stateTopic = CoverController.stateTopic(baseTopic: mqttConfig.baseTopic, name: name)
			let commandTopic = CoverController.commandTopic(baseTopic: mqttConfig.baseTopic, name: name)
			let setPositionTopic = CoverController.setPositionTopic(baseTopic: mqttConfig.baseTopic, name: name)
			await mqttClient.publish(
				topic: stateTopic,
				message: initialState.stateMqttMessage,
				retain: true
			)
			let mqttAutodiscoveryMessage = Mqtt.Cover(
				availabilityTopic: mqttClient.stateTopic,
				commandTopic: commandTopic,
				device: .init(
					identifiers: stateTopic,
					name: name,
					viaDevice: mqttClient.stateTopic
				),
				deviceClass: config.deviceClass,
				name: .explicitNone,
				platform: .cover,
				positionTemplate: "{{ value_json.target_position }}",
				positionTopic: stateTopic,
				setPositionTopic: setPositionTopic,
				stateTopic: stateTopic,
				uniqueId: stateTopic.toUniqueId(),
				valueTemplate: "{{ value_json.state }}"
			)
			await mqttClient.publish(
				topic: "\(mqttConfig.homeAssistantBaseTopic)/cover/\(mqttConfig.baseTopic)/\(name)/config",
				message: mqttAutodiscoveryMessage,
				retain: true
			)
		}
		self.coverControllers.append(contentsOf: coverControllers)
		return coverControllers
	}
}
