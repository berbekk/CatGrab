// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PieMenu",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PieMenuLib", targets: ["PieMenuLib"]),
        .executable(name: "PieMenu", targets: ["PieMenu"])
    ],
    targets: [
        .target(
            name: "PieMenuLib",
            path: "Sources/PieMenuLib",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .executableTarget(
            name: "PieMenu",
            dependencies: ["PieMenuLib"],
            path: "Sources/PieMenu",
            exclude: ["Info.plist", "Resources", "PieMenu.entitlements", "PrivacyInfo.xcprivacy"]
        ),
        .testTarget(
            name: "PieMenuLibTests",
            dependencies: ["PieMenuLib"],
            path: "Tests/PieMenuLibTests"
        )
    ]
)
