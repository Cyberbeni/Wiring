// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Wiring",
	platforms: [.macOS(.v26)],
	products: [
		.executable(
			name: "Wiring",
			targets: ["Wiring"],
		),
	],
	dependencies: [
		.package(url: "https://codeberg.org/Cyberbeni/CBLogging", from: "1.3.2"),
		.package(url: "https://github.com/swift-server-community/mqtt-nio", from: "2.13.0"),
		.package(url: "https://github.com/apple/swift-nio", from: "2.94.1"),
		// Plugins:
		.package(url: "https://codeberg.org/Cyberbeni/SwiftFormat-mirror", from: "0.59.1"),
	],
	targets: [
		.executableTarget(
			name: "Wiring",
			dependencies: [
				.product(name: "CBLogging", package: "CBLogging"),
				.product(name: "MQTTNIO", package: "mqtt-nio"),
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "NIOFoundationCompat", package: "swift-nio"),
			],
			swiftSettings: [
				.define("DEBUG", .when(configuration: .debug)),
				.unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
			],
			linkerSettings: [
				.unsafeFlags(["-Xlinker", "-s"], .when(configuration: .release)),
			],
		),
	],
)
