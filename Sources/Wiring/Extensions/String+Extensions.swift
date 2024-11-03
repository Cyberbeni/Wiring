extension String {
	func toUniqueId() -> String {
		replacingOccurrences(of: "/", with: "_")
	}
}
