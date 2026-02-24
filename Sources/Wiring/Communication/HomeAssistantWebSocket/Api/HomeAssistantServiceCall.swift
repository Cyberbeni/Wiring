protocol HomeAssistantServiceCall {
	associatedtype ServiceData: DictionaryEncodable

	var domain: String { get }
	var service: String { get }
	var serviceData: ServiceData { get }
	var entityId: String { get }
}
