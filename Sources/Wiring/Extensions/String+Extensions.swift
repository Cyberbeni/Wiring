extension String {
	func toHomeAssistantAutodiscoveryTopic() -> String {
		String(
			replacing(" ", with: "_")
				// https://help.perforce.com/sourcepro/sposd/HTML/i18n/normalization_forms.htm
				// NFKD
				.decomposedStringWithCompatibilityMapping
				.unicodeScalars
				// https://en.wikipedia.org/wiki/Combining_Diacritical_Marks
				.filter { $0.value < 0x300 || $0.value > 0x36F },
		)
	}

	func toUniqueId() -> String {
		replacing("/", with: "_")
	}
}
