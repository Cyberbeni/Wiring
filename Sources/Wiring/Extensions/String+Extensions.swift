import Utf8Proc

extension String {
	func toHomeAssistantAutodiscoveryTopic() -> String {
		String(
			replacing(" ", with: "_")
				.utf8proc_decomposedStringWithCompatibilityMapping
				.unicodeScalars
				.filter { !$0.properties.isDiacritic },
		)
	}

	func toUniqueId() -> String {
		replacing("/", with: "_")
	}
}
