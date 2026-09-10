import SwiftUI
import AppKit
import CoreText
@main struct RenderIcon {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        CTFontManagerRegisterFontsForURL(root.appending(path: "ios/EnTil/Resources/Fraunces.ttf") as CFURL, .process, nil)
        let content = ZStack {
            Color.ink
            Circle().fill(Color.violet).frame(width: 850).offset(y: 310)
            VStack(spacing: 0) {
                Text("En til?").font(.editorial(210)).foregroundStyle(Color.cream).rotationEffect(.degrees(-5))
                CharacterView(index: 0, size: 480)
            }
        }.frame(width: 1024, height: 1024).clipped()
        let renderer = ImageRenderer(content: content); renderer.scale = 1; renderer.isOpaque = true
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: root.appending(path: "ios/EnTil/Assets.xcassets/AppIcon.appiconset/icon.png"))
    }
}
