import Foundation

actor StateStore {
	private static let saveDelay: Double = 60

	private let encoder = State.jsonEncoder()
	private let coverStateUrl: URL

	private var coverStates: [String: State.Cover]
	private var scheduleSaveTask: Task<Void, Error>?

	init(configDir: String) {
		let decoder = State.jsonDecoder()
		let coverStateUrl = URL(filePath: "\(configDir)/state.cover.json")
		self.coverStateUrl = coverStateUrl
		do {
			let stateData = try Data(contentsOf: coverStateUrl)
			coverStates = try decoder.decode([String: State.Cover].self, from: stateData)
		} catch {
			Log.info("Cover states not found or invalid at '\(coverStateUrl.absoluteString)' - \(error)")
			coverStates = [:]
		}
	}

	func getCoverState(name: String) -> State.Cover? {
		coverStates[name]
	}

	func setCoverState(name: String, state: State.Cover) {
		coverStates[name] = state
		scheduleSave()
	}

	private func scheduleSave() {
		guard scheduleSaveTask == nil else { return }
		scheduleSaveTask = Task { [weak self] in
			try await Task.sleep(for: .seconds(Self.saveDelay))
			await self?.saveNow()
		}
	}

	func saveNow() {
		scheduleSaveTask?.cancel()
		scheduleSaveTask = nil
		do {
			let data = try encoder.encode(coverStates)
			try data.write(to: coverStateUrl)
		} catch {
			Log.error(error)
		}
	}
}
