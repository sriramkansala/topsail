// swift-tools-version: 5.9
import PackageDescription

// The koi pond's renderer. It is a package of its own so that it is always compiled with
// optimisation: it colours every pixel of the pond twelve times a second, which takes about a
// millisecond optimised and over a hundred in an unoptimised debug build of the app. Its art lives
// in the app's resources (Topsail/Pond/Art), so the package has no bundle of its own to sign.
let package = Package(
    name: "PondKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PondKit", targets: ["PondKit"]),
    ],
    targets: [
        .target(
            name: "PondKit",
            swiftSettings: [.unsafeFlags(["-O"])]
        ),
    ]
)
