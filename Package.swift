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
		.package(url: "https://github.com/swift-server-community/mqtt-nio", from: "2.11.0"),
		// Plugins:
		.package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.54.6"),
	],
	targets: [
		.executableTarget(
			name: "Wiring",
			dependencies: [
				.product(name: "MQTTNIO", package: "mqtt-nio"),
			],
			swiftSettings: [
				.unsafeFlags(["-warnings-as-errors"], .when(configuration: .release)),
			],
			linkerSettings: [
				.unsafeFlags(["-Xlinker", "-s"], .when(configuration: .release)),
			]
		),
	]
)
