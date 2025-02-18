extension App {
	func setupCovers() async {
		guard
			let coverConfig,
			let homeAssistantRestApi
		else { return }
		let mqttConfig = generalConfig.mqtt

		for (name, config) in coverConfig.entries {
			let initialState = await stateStore.getCoverState(name: name)?.asInitialState ?? State.Cover(
				currentPosition: 0,
				targetPosition: 0,
				controlTriggeDate: nil
			)
			coverControllers.append(CoverController(
				name: name,
				baseTopic: mqttConfig.baseTopic,
				config: config,
				stateStore: stateStore,
				mqttClient: mqttClient,
				homeAssistantRestApi: homeAssistantRestApi,
				state: initialState
			))
			let stateTopic = CoverController.stateTopic(baseTopic: mqttConfig.baseTopic, name: name)
			let commandTopic = CoverController.commandTopic(baseTopic: mqttConfig.baseTopic, name: name)
			let setPositionTopic = CoverController.setPositionTopic(baseTopic: mqttConfig.baseTopic, name: name)
			let stateMessage = initialState.stateMqttMessage
			await mqttClient.publish(
				topic: stateTopic,
				message: stateMessage,
				retain: true
			)
			let mqttAutodiscoveryMessage = Mqtt.Cover(
				availabilityTopic: mqttClient.stateTopic,
				commandTopic: commandTopic,
				device: .init(identifiers: stateTopic, name: name, viaDevice: mqttClient.stateTopic),
				deviceClass: config.deviceClass,
				name: .explicitNone,
				platform: .cover,
				positionTemplate: "{{ value_json.targetPosition }}",
				positionTopic: stateTopic,
				// Not setting this or setting it to "{{ position }}" or "{{ position | int }}" sometimes results in "{}" being sent, especially
				// when setting to around 70-80%, HA Core 2025.1.4
				setPositionTemplate: "{{ position | float }}",
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
	}
}
