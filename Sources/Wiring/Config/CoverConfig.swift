import Foundation

extension Config {
	struct Cover: Decodable {
        let remoteEntityId: String
        let entries: [String: CoverItem]

        struct CoverItem: Decodable {
            let remoteDevice: String
            let openDuration: TimeInterval
            let closeDuration: TimeInterval
            let closedToOnePercentDuration: TimeInterval
            let onePercentToClosedDuration: TimeInterval
        }
    }
}
