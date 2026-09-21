// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatGrab",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CatGrabLib", targets: ["CatGrabLib"]),
        .executable(name: "CatGrab", targets: ["CatGrab"])
    ],
    targets: [
        .target(
            name: "CatGrabLib",
            path: "Sources/CatGrabLib",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .executableTarget(
            name: "CatGrab",
            dependencies: ["CatGrabLib"],
            path: "Sources/CatGrab",
            exclude: ["Info.plist", "Resources", "CatGrab.entitlements", "PrivacyInfo.xcprivacy"]
        ),
        .testTarget(
            name: "CatGrabLibTests",
            dependencies: ["CatGrabLib"],
            path: "Tests/CatGrabLibTests"
        )
    ]
)
