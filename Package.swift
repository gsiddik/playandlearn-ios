// swift-tools-version:5.9
import PackageDescription

// Logika domain murni Swift (padanan modul :core Android); diuji tanpa Xcode project.
// Aplikasi iOS (SwiftUI) ditambahkan sebagai Xcode project pada Increment 3 di macOS.
let package = Package(
    name: "PlayAndLearnCore",
    products: [.library(name: "PlayAndLearnCore", targets: ["PlayAndLearnCore"])],
    targets: [
        .target(name: "PlayAndLearnCore"),
        .testTarget(name: "PlayAndLearnCoreTests", dependencies: ["PlayAndLearnCore"]),
    ]
)
