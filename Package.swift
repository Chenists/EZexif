// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FilmExif",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FilmExif",
            path: "Sources/FilmExif"
        )
    ]
)
