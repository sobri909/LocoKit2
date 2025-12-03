//
//  Data+Compression.swift
//  LocoKit2
//
//  Created by Claude on 2025-12-03
//

import Foundation
import Compression

public enum GzipError: Error {
    case compressionFailed
    case decompressionFailed
    case invalidGzipHeader
    case corruptedData
    case checksumMismatch
}

extension Data {

    // MARK: - Gzip Compression

    /// Compresses data using gzip format (compatible with gunzip, zcat, etc.)
    public func gzipCompressed() throws -> Data {
        guard !isEmpty else { return Data() }

        // gzip header (10 bytes)
        var result = Data([
            0x1f, 0x8b,  // magic number
            0x08,        // compression method (deflate)
            0x00,        // flags
            0x00, 0x00, 0x00, 0x00,  // modification time (not set)
            0x00,        // extra flags
            0x03         // OS (Unix)
        ])

        // compress using streaming API
        guard let deflated = deflateCompress() else {
            throw GzipError.compressionFailed
        }
        result.append(deflated)

        // gzip trailer: CRC32 + original size (little endian)
        var crc = crc32Checksum().littleEndian
        var size = UInt32(truncatingIfNeeded: count).littleEndian
        result.append(Data(bytes: &crc, count: 4))
        result.append(Data(bytes: &size, count: 4))

        return result
    }

    /// Decompresses gzip-formatted data
    public func gzipDecompressed() throws -> Data {
        guard count >= 18 else {  // minimum: 10 header + 0 data + 8 trailer
            throw GzipError.invalidGzipHeader
        }

        // verify gzip magic number and compression method
        guard self[0] == 0x1f, self[1] == 0x8b, self[2] == 0x08 else {
            throw GzipError.invalidGzipHeader
        }

        // parse header to find start of compressed data
        var offset = 10
        let flags = self[3]

        if flags & 0x04 != 0 {  // FEXTRA
            guard count > offset + 2 else { throw GzipError.corruptedData }
            let extraLen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            offset += 2 + extraLen
        }
        if flags & 0x08 != 0 {  // FNAME (null-terminated)
            while offset < count && self[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 {  // FCOMMENT (null-terminated)
            while offset < count && self[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 {  // FHCRC
            offset += 2
        }

        guard offset < count - 8 else {
            throw GzipError.corruptedData
        }

        // extract footer values (little endian)
        let footerStart = count - 8
        let expectedCrc = UInt32(self[footerStart]) |
                         (UInt32(self[footerStart + 1]) << 8) |
                         (UInt32(self[footerStart + 2]) << 16) |
                         (UInt32(self[footerStart + 3]) << 24)
        let expectedSize = UInt32(self[footerStart + 4]) |
                          (UInt32(self[footerStart + 5]) << 8) |
                          (UInt32(self[footerStart + 6]) << 16) |
                          (UInt32(self[footerStart + 7]) << 24)

        // decompress
        let compressedData = self[offset..<footerStart]
        guard let inflated = Data(compressedData).deflateDecompress() else {
            throw GzipError.decompressionFailed
        }

        // validate size and checksum
        guard UInt32(truncatingIfNeeded: inflated.count) == expectedSize else {
            throw GzipError.checksumMismatch
        }
        guard inflated.crc32Checksum() == expectedCrc else {
            throw GzipError.checksumMismatch
        }

        return inflated
    }

    // MARK: - Deflate (streaming API)

    private func deflateCompress() -> Data? {
        return withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }
            return performCompression(
                operation: COMPRESSION_STREAM_ENCODE,
                source: sourcePtr,
                sourceSize: count
            )
        }
    }

    private func deflateDecompress() -> Data? {
        return withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourcePtr = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }
            return performCompression(
                operation: COMPRESSION_STREAM_DECODE,
                source: sourcePtr,
                sourceSize: count
            )
        }
    }

    private func performCompression(
        operation: compression_stream_operation,
        source: UnsafePointer<UInt8>,
        sourceSize: Int
    ) -> Data? {
        guard operation == COMPRESSION_STREAM_ENCODE || sourceSize > 0 else { return nil }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPtr.deallocate() }

        var stream = streamPtr.pointee
        let status = compression_stream_init(&stream, operation, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else { return nil }
        defer { compression_stream_destroy(&stream) }

        let bufferSize = 64 * 1024  // 64KB chunks
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        stream.src_ptr = source
        stream.src_size = sourceSize
        stream.dst_ptr = buffer
        stream.dst_size = bufferSize

        var result = Data()
        let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)

        while true {
            switch compression_stream_process(&stream, flags) {
            case COMPRESSION_STATUS_OK:
                guard stream.dst_size == 0 else { return nil }
                result.append(buffer, count: bufferSize)
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize

            case COMPRESSION_STATUS_END:
                result.append(buffer, count: bufferSize - stream.dst_size)
                return result

            default:
                return nil
            }
        }
    }

    // MARK: - CRC32

    private typealias Crc32FuncPtr = @convention(c) (UInt32, UnsafePointer<UInt8>, UInt32) -> UInt32

    private static let libzCrc32: Crc32FuncPtr = {
        let libz = dlopen("/usr/lib/libz.dylib", RTLD_NOW)!
        let sym = dlsym(libz, "crc32")!
        return unsafeBitCast(sym, to: Crc32FuncPtr.self)
    }()

    fileprivate func crc32Checksum() -> UInt32 {
        withUnsafeBytes { buffer -> UInt32 in
            guard let ptr = buffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return Self.libzCrc32(0, ptr, UInt32(count))
        }
    }
}
