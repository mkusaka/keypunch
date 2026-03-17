// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeypunchKeyboardShortcuts",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "KeypunchKeyboardShortcuts",
            targets: ["KeypunchKeyboardShortcuts"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            from: "2.4.0"
        ),
    ],
    targets: [
        .target(
            name: "KeypunchKeyboardShortcuts",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
    ]
)
