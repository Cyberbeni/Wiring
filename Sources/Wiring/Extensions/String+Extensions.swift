extension String {
	func toHomeAssistantAutodiscoveryTopic() -> String {
		String(
			replacing(" ", with: "_")
				.decomposedStringWithCompatibilityMapping
				.unicodeScalars
				.filter { !$0.properties.isDiacritic },
		)
	}

	func toUniqueId() -> String {
		replacing("/", with: "_")
	}
}
