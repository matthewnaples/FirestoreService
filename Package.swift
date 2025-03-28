// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FirestoreService",
    platforms: [.iOS(.v13),.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FirestoreService",
            targets: ["FirestoreService"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from:"11.6.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "FirestoreService",
            dependencies: [.product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                           .product(name: "FirebaseFirestoreCombine-Community", package: "firebase-ios-sdk")
            ]),
        .testTarget(
            name: "FirestoreServiceTests",
            dependencies: ["FirestoreService"]),
    ]
)
