// swift-tools-version:4.0

import PackageDescription

#if swift(>=4.0)

let package = Package(
  name: "deferred",
  products: [
    .library(name: "deferred", type: .static, targets: ["deferred"]),
  ],
  dependencies: [
    .package(url: "https://github.com/glessard/syncprint.git", from: "2.3.0"),
    .package(url: "https://github.com/glessard/swift-atomics.git", from: "4.0.0"),
  ],
  targets: [
    .target(name: "deferred", dependencies: ["CAtomics"]),
    .testTarget(name: "deferredTests", dependencies: ["deferred", "syncprint"]),
  ],
  swiftLanguageVersions: [3,4]
)

#else

let package = Package(
  name: "deferred",
  targets: [
    Target(name: "deferred"),
  ],
  dependencies: [
    .Package(url: "https://github.com/glessard/syncprint.git", majorVersion: 2, minor: 3),
    .Package(url: "https://github.com/glessard/swift-atomics.git", majorVersion: 4, minor: 0),
  ]
)

#endif
