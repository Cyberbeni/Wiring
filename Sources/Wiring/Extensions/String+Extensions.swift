import Foundation

extension String {
	func toHomeAssistantAutodiscoveryTopic() -> String {
		replacing(" ", with: "_")
			.folding(options: .diacriticInsensitive, locale: .current)
	}

	func toUniqueId() -> String {
		replacing("/", with: "_")
	}
}
