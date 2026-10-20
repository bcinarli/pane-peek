import AVFoundation
import Darwin
import Foundation
import UniformTypeIdentifiers
import PanePeekCore

// Immutable ownership and offset-based reads keep delegate work independent of the main actor.
final class ScopedVideoSource: NSObject, @unchecked Sendable, AVAssetResourceLoaderDelegate {
    static let chunkSize = 64 * 1024
    let url = URL(string: "panepeek-video://" + UUID().uuidString)!
    let queue = DispatchQueue(label: "com.bcinarli.PanePeek.video-source", qos: .userInitiated)
    private let handle: FileHandle
    private let access: DirectoryAccess?
    private let length: Int64
    private let contentType: String

    init(item: DirectoryEntry, access: DirectoryAccess?) throws {
        try Task.checkCancellation()
        guard item.url.isFileURL else { throw VideoPreview.Failure.nonLocal }
        guard !item.isSymbolicLink else { throw VideoPreview.Failure.symbolicLink }
        let descriptor = Darwin.open(item.url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        if descriptor < 0, errno == ELOOP { throw VideoPreview.Failure.symbolicLink }
        guard descriptor >= 0 else { throw Self.posixError() }
        handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0 else { throw Self.posixError() }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else { throw VideoPreview.Failure.nonRegularFile }
        guard attributes.st_size >= 0 else { throw VideoPreview.Failure.unsupported }
        length = attributes.st_size
        contentType = UTType(filenameExtension: item.url.pathExtension)?.identifier ?? UTType.movie.identifier
        self.access = access
        super.init()
        try Task.checkCancellation()
    }

    /// Read a bounded range from the opened file, independently of subsequent path replacements.
    func read(offset: Int64, maximumLength: Int) throws -> Data {
        guard offset >= 0, maximumLength >= 0 else { throw POSIXError(.EINVAL) }
        guard offset < length, maximumLength > 0 else { return Data() }
        let count = min(Self.chunkSize, maximumLength, Int(length - offset))
        var data = Data(count: count)
        let received = data.withUnsafeMutableBytes { bytes in
            var result: Int
            repeat { result = pread(handle.fileDescriptor, bytes.baseAddress!, count, offset) } while result < 0 && errno == EINTR
            return result
        }
        guard received >= 0 else { throw Self.posixError() }
        data.count = received
        return data
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest) -> Bool {
        guard !request.isCancelled, !request.isFinished else { return true }
        guard request.request.url == url else {
            request.finishLoading(with: VideoPreview.Failure.nonLocal)
            return true
        }
        if let info = request.contentInformationRequest {
            guard info.allowedContentTypes?.contains(contentType) != false else {
                request.finishLoading(with: VideoPreview.Failure.unsupported)
                return true
            }
            info.contentType = contentType
            info.contentLength = length
            info.isByteRangeAccessSupported = true
            info.isEntireLengthAvailableOnDemand = true
        }
        respond(to: request)
        return true
    }

    private func respond(to request: AVAssetResourceLoadingRequest) {
        guard !request.isCancelled, !request.isFinished else { return }
        guard let data = request.dataRequest else { request.finishLoading(); return }
        do {
            guard data.requestedOffset >= 0, data.requestedLength >= 0 else { throw POSIXError(.EINVAL) }
            let end: Int64
            if data.requestsAllDataToEndOfResource {
                end = length
            } else {
                let sum = data.requestedOffset.addingReportingOverflow(Int64(data.requestedLength))
                guard !sum.overflow else { throw POSIXError(.EINVAL) }
                end = min(length, sum.partialValue)
            }
            let offset = max(data.currentOffset, data.requestedOffset)
            guard offset < end else { request.finishLoading(); return }
            let bytes = try read(offset: offset, maximumLength: Int(min(Int64(Self.chunkSize), end - offset)))
            guard !request.isCancelled, !request.isFinished else { return }
            guard !bytes.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            data.respond(with: bytes)
            // Yield between chunks so cancelled requests do not keep reading a long movie.
            queue.async { self.respond(to: request) }
        } catch {
            if !request.isCancelled, !request.isFinished { request.finishLoading(with: error) }
        }
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}
