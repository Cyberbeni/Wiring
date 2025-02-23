extension String {
	func toHomeAssistantAutodiscoveryTopic() -> String {
		replacingOccurrences(of: " ", with: "_")
			.folding(options: .diacriticInsensitive, locale: .current)
	}

	func toUniqueId() -> String {
		replacingOccurrences(of: "/", with: "_")
	}
}
