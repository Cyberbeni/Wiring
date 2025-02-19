import Foundation

protocol HomeAssistantServiceCall {
	associatedtype ServiceData: Encodable

	var domain: String { get }
	var service: String { get }
	var serviceData: ServiceData { get }
}
