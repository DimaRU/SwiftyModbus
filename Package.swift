// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftyModbus",
    products: [
        .library(name: "SwiftyModbusPromise", targets: ["SwiftyModbusPromise"]),
        .library(name: "SwiftyModbus", targets: ["SwiftyModbus"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.15.2"))
    ],
    targets: [
        .target(name: "SwiftyModbusPromise",
                dependencies: ["CModbus", "PromiseKit"]),
        .target(name: "SwiftyModbus",
                dependencies: ["CModbus"]),
        .systemLibrary(name: "CModbus",
                       path: "Sources/Libmodbus",
                       pkgConfig: "libmodbus",
                       providers: [
                        .apt(["libmodbus-dev"]),
                        .brew(["libmodbus"]),
                       ]),
        .testTarget(
            name: "SwiftyModbusTests",
            dependencies: ["SwiftyModbus"]),
    ]
)
