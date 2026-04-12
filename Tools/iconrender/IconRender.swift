// Renders the canonical AirplaneGlyph to PNGs at all required macOS icon sizes
// and builds AppIcon.icns via iconutil. Run via:
//   swift run -c release AirplaneIconRender <output-icns-path>
//
// This is the SSOT for the icon: the exact same glyph the About tab shows.
import SwiftUI
import AppKit

@main
@MainActor
struct IconRenderMain {
    static func main() throws {
        let outArg = CommandLine.arguments.dropFirst().first
            ?? "Sources/AirplaneAI/Resources/AppIcon.icns"
        let outURL = URL(fileURLWithPath: outArg)

        let buildDir = outURL.deletingLastPathComponent().appendingPathComponent(".iconrender-tmp", isDirectory: true)
        let iconset = buildDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try? FileManager.default.removeItem(at: buildDir)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        // All sizes Apple's iconutil wants for macOS AppIcon.icns.
        let specs: [(pt: CGFloat, name: String)] = [
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
            try render(size: spec.pt, to: iconset.appendingPathComponent(spec.name))
        }
        // Ask iconutil to package.
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

    @MainActor
    static func render(size: CGFloat, to url: URL) throws {
        let view = AppIconRenderable().frame(width: size, height: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = .init(width: size, height: size)
        guard let nsImage = renderer.nsImage else {
            throw NSError(domain: "IconRender", code: -1)
        }
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "IconRender", code: -2)
        }
        try png.write(to: url)
    }
}

// The icon body — must match AirplaneGlyph in the app exactly.
// White rounded-square background, accent-blue tinted circle, SF-Symbol airplane rotated -20°.
struct AppIconRenderable: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.22, style: .continuous)
                    .fill(Color.white)
                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.12))
                    .frame(width: s * 0.66, height: s * 0.66)
                Image(systemName: "airplane")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .frame(width: s * 0.44, height: s * 0.44)
                    .rotationEffect(.degrees(-20))
            }
            .frame(width: s, height: s)
        }
    }
}
