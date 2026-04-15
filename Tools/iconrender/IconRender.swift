// Rasterizes the canonical brand PNG to all macOS iconset sizes and packages
// AppIcon.icns via iconutil. Run via:
//   swift run -c release AirplaneIconRender <output-icns-path>
//
// Source of truth: branding/airplane-ai.png (pre-designed full app-icon artwork,
// light background included). The tool rescales that single master to every
// iconset spec Apple requires, preserving color and sharp edges via high-quality
// Lanczos interpolation through CoreImage.
import Foundation
import AppKit

@main
struct IconRenderMain {
    static func main() throws {
        let args = CommandLine.arguments.dropFirst()
        let outArg = args.first ?? "Sources/AirplaneAI/Resources/AppIcon.icns"
        let outURL = URL(fileURLWithPath: outArg)

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sourcePNG = repoRoot.appendingPathComponent("branding/airplane-ai.png")
        guard FileManager.default.fileExists(atPath: sourcePNG.path) else {
            throw NSError(domain: "IconRender", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Missing \(sourcePNG.path)"])
        }
        guard let master = NSImage(contentsOf: sourcePNG) else {
            throw NSError(domain: "IconRender", code: -11,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot decode \(sourcePNG.path)"])
        }

        let buildDir = outURL.deletingLastPathComponent().appendingPathComponent(".iconrender-tmp", isDirectory: true)
        let iconset = buildDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try? FileManager.default.removeItem(at: buildDir)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        let specs: [(pt: Int, name: String)] = [
            (16,   "icon_16x16.png"),
            (32,   "icon_16x16@2x.png"),
            (32,   "icon_32x32.png"),
            (64,   "icon_32x32@2x.png"),
            (128,  "icon_128x128.png"),
            (256,  "icon_128x128@2x.png"),
            (256,  "icon_256x256.png"),
            (512,  "icon_256x256@2x.png"),
            (512,  "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        for spec in specs {
            try rescale(master: master, to: spec.pt,
                        outURL: iconset.appendingPathComponent(spec.name))
        }

        let proc = Process()
        proc.launchPath = "/usr/bin/iconutil"
        proc.arguments = ["-c", "icns", "-o", outURL.path, iconset.path]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "IconRender", code: Int(proc.terminationStatus))
        }
        FileHandle.standardOutput.write("→ wrote \(outURL.path)\n".data(using: .utf8)!)
        try? FileManager.default.removeItem(at: buildDir)
    }

    static func rescale(master: NSImage, to pt: Int, outURL: URL) throws {
        let size = NSSize(width: pt, height: pt)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pt, pixelsHigh: pt,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 32
        )
        rep?.size = size
        guard let rep else {
            throw NSError(domain: "IconRender", code: -2)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        master.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconRender", code: -3)
        }
        try png.write(to: outURL)
    }
}
