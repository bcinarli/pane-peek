import Darwin
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers
import PanePeekCore

enum ImagePreview {
    static let maximumBytes = 32 * 1_048_576
    static let maximumPixels = 64_000_000
    static let maximumDimension = 2048

    static func supports(_ item: DirectoryEntry?) -> Bool {
        guard let item, !item.isDirectory, !item.isPackage else { return false }
        return UTType(filenameExtension: item.url.pathExtension)?.conforms(to: .image) == true
    }

    enum Failure: LocalizedError, Equatable {
        case tooLarge, dimensions, unsupported, nonRegularFile
        var errorDescription: String? {
            switch self {
            case .tooLarge: "Image preview is limited to files up to 32 MiB."
            case .dimensions: "This image is too large to preview."
            case .unsupported: "This image is damaged or its format is not supported."
            case .nonRegularFile: "No image preview for this file type."
            }
        }
    }

    private static let decoder = Decoder()

    /// Decode one fitted frame off the UI thread, bounding bytes, pixels and concurrent work.
    static func read(_ item: DirectoryEntry) async throws -> CGImage {
        try await decoder.read(item)
    }

    // ImageIO decoding cannot be interrupted mid-frame; serialise it across windows.
    private actor Decoder {
        func read(_ item: DirectoryEntry) throws -> CGImage {
            guard item.url.isFileURL, ImagePreview.supports(item) else { throw Failure.unsupported }
            try Task.checkCancellation()
            let descriptor = Darwin.open(item.url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
            guard descriptor >= 0 else { throw posixError() }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var attributes = stat()
            guard fstat(descriptor, &attributes) == 0 else { throw posixError() }
            guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw Failure.nonRegularFile }
            guard attributes.st_size <= ImagePreview.maximumBytes else { throw Failure.tooLarge }
            let data = try handle.read(upToCount: ImagePreview.maximumBytes + 1) ?? Data()
            try Task.checkCancellation()
            guard data.count <= ImagePreview.maximumBytes else { throw Failure.tooLarge }
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let identifier = CGImageSourceGetType(source), UTType(identifier as String)?.conforms(to: .image) == true,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
                  let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue else { throw Failure.unsupported }
            guard width > 0, height > 0, width <= ImagePreview.maximumPixels / height else { throw Failure.dimensions }
            try Task.checkCancellation()
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                           kCGImageSourceCreateThumbnailWithTransform: true,
                                           kCGImageSourceThumbnailMaxPixelSize: ImagePreview.maximumDimension,
                                           kCGImageSourceShouldCacheImmediately: true]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw Failure.unsupported }
            try Task.checkCancellation()
            return image
        }

        private func posixError() -> POSIXError {
            POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}

@MainActor @Observable final class ImagePreviewState {
    private(set) var selection: DetailsSelection?
    private(set) var image: CGImage?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var requestID = UUID()
    private let read: @Sendable (DirectoryEntry) async throws -> CGImage

    init(read: @escaping @Sendable (DirectoryEntry) async throws -> CGImage = ImagePreview.read) {
        self.read = read
    }

    func load(_ selection: DetailsSelection?) async {
        guard !Task.isCancelled else { return }
        let request = UUID()
        requestID = request
        self.selection = ImagePreview.supports(selection?.item) ? selection : nil
        image = nil
        errorMessage = nil
        isLoading = self.selection != nil
        defer { if requestID == request { isLoading = false } }
        guard let selection = self.selection else { return }
        do {
            let image = try await read(selection.item)
            guard requestID == request, !Task.isCancelled else { return }
            self.image = image
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Couldn’t preview this image. \(error.localizedDescription)"
        }
    }
}

struct ImagePreviewView: View {
    let image: CGImage
    let name: String

    var body: some View {
        GeometryReader { geometry in
            Image(image, scale: 1, label: Text("Read-only image preview of \(name)"))
                .resizable()
                .scaledToFit()
                .padding(12)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
