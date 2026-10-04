// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PanePeek",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "PanePeek", targets: ["PanePeek"])
    ],
    targets: [
        .executableTarget(name: "PanePeek")
    ]
)
