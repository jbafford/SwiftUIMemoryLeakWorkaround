// swift-tools-version:5.9

import PackageDescription


let package = Package(name: "SwiftUIMemoryLeakWorkaround",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
	],
	products: [
		.library(name: "SwiftUIMemoryLeakWorkaround", targets: ["SwiftUIMemoryLeakWorkaround"])
	],
	targets: [
		.target(name: "SwiftUIMemoryLeakWorkaround", path: "Source")
	],
	swiftLanguageVersions: [.v5]
)
