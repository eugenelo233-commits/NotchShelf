// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NotchShelf", platforms: [.macOS(.v14)], products: [.executable(name: "NotchShelf", targets: ["NotchShelf"])], targets: [.executableTarget(name: "NotchShelf")])
