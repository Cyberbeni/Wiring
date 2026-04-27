extension HomeAssistantWebSocket {
	enum Api {}
}

protocol DictionaryEncodable {
	func asDictionary() -> [String: String]
}
