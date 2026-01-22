// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PomodoroAuto",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "PomodoroAuto", targets: ["PomodoroAuto"])
    ],
    targets: [
        .executableTarget(
            name: "PomodoroAuto",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PomodoroAutoTests",
            dependencies: ["PomodoroAuto"],
            path: "Tests"
        )
    ]
)
