import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3 else { fatalError("Expected render SOURCE OUTPUT or bookmark VOLUME OUTPUT.") }
let destination = URL(fileURLWithPath: arguments[2])
switch arguments[0] {
case "render":
    guard let artwork = NSImage(contentsOfFile: arguments[1]) else { fatalError("Unreadable DMG artwork.") }
    let size = NSSize(width: 760, height: 450)
    let representations = [1, 2].map { scale -> NSBitmapImageRep in
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 760 * scale, pixelsHigh: 450 * scale,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render DMG artwork.") }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        artwork.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
    guard let tiff = NSBitmapImageRep.representationOfImageReps(in: representations, using: .tiff, properties: [:]) else {
        fatalError("Cannot encode DMG artwork.")
    }
    try tiff.write(to: destination, options: .atomic)
case "verify":
    guard let background = NSImage(contentsOf: destination), background.size == NSSize(width: 760, height: 450),
          Set(background.representations.map { $0.pixelsWide }) == Set([760, 1520]),
          Set(background.representations.map { $0.pixelsHigh }) == Set([450, 900]) else {
        fatalError("The DMG artwork has invalid dimensions or scale representations.")
    }
    let volume = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let store = try Data(contentsOf: volume.appendingPathComponent(".DS_Store"))
    guard let marker = store.range(of: Data("pBBkblob".utf8)), marker.upperBound + 4 <= store.count else {
        fatalError("The DMG background bookmark is missing.")
    }
    let length = store[marker.upperBound..<marker.upperBound + 4].reduce(0) { ($0 << 8) | Int($1) }
    let start = marker.upperBound + 4
    guard length > 0, start + length <= store.count else { fatalError("The DMG bookmark is truncated.") }
    var stale = false
    let resolved = try URL(resolvingBookmarkData: store.subdata(in: start..<start + length),
                           options: [.withoutUI, .withoutMounting], relativeTo: volume, bookmarkDataIsStale: &stale)
    guard resolved.standardizedFileURL == destination.standardizedFileURL else {
        fatalError("The DMG background bookmark does not resolve inside the mounted volume.")
    }
case "bookmark":
    let volume = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let background = volume.appendingPathComponent(".background/installer.tiff")
    let bookmark = try background.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: volume)
    try bookmark.write(to: destination, options: .atomic)
default:
    fatalError("Unknown DMG artwork operation.")
}
