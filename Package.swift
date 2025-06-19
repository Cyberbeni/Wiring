// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Wiring",
	products: [
		.executable(
			name: "Wiring",
			targets: ["Wiring"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/Cyberbeni/CBLogging", from: "1.2.0"),
		.package(url: "https://github.com/swift-server-community/mqtt-nio", from: "2.11.0"),
		.package(url: "https://github.com/apple/swift-nio", from: "2.76.1"),
		// Plugins:
		.package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.55.5"),
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
			]
		),
	]
)
