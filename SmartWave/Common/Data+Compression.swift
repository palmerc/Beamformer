//
//  Data+Compression.swift
//  Data+Compression
//
//  Created by Lee Morgan on 7/17/15.
//  Copyright © 2015 Lee Morgan. All rights reserved.
//

import Foundation
import Compression

/** Available Compression Algorithms

 - Compression.LZ4   : Fast compression
 - Compression.ZLIB  : Balanced between speed and compression
 - Compression.LZMA  : High compression
 - Compression.LZFSE : Apple-specific high performance compression. Faster and better compression than ZLIB, but slower than LZ4 and does not compress as well as LZMA.
 */
enum Compression {

    /// Fast compression
    case lz4

    /// Balanced between speed and compression
    case zlib

    /// High compression
    case lzma

    /// Apple-specific high performance compression. Faster and better compression than ZLIB, but slower than LZ4 and does not compress as well as LZMA.
    case lzfse
}

extension Data {


    /// Returns a NSData object initialized by decompressing the data from the file specified by `path`. Attempts to determine the appropriate decompression algorithm using the path's extension.
    ///
    /// This method is equivalent to `NSData(contentsOfArchive:usingCompression:)` with `nil compression`
    ///
    ///     let data = NSData(contentsOfArchive: absolutePathToFile)
    ///
    /// - Parameter path: The absolute path of the file from which to read data
    /// - Returns: A NSData object initialized by decompressing the data from the file specified by `path`. Returns `nil` if decompression fails.
    init?(contentsOfArchive path: String) {
        self.init(contentsOfArchive: path, usedCompression: nil)
    }


    /// Returns a NSData object initialized by decompressing the data from the file specified by `path` using the given `compression` algorithm.
    ///
    ///     let data = NSData(contentsOfArchive: absolutePathToFile, usedCompression: Compression.LZFSE)
    ///
    /// - Parameter path: The absolute path of the file from which to read data
    /// - Parameter usedCompression: Algorithm to use during decompression. If compression is nil, attempts to determine the appropriate decompression algorithm using the path's extension
    /// - Returns: A NSData object initialized by decompressing the data from the file specified by `path` using the given `compression` algorithm. Returns `nil` if decompression fails.
    init?(contentsOfArchive path: String, usedCompression: Compression?) {

        // read in the compressed data from disk
        guard let compressedData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        // if compression is set use it
        let compression: Compression
        if usedCompression != nil {
            compression = usedCompression!
        }
        else {
            // otherwise, attempt to use the file extension to determine the compression algorithm
            switch (path as NSString).pathExtension.lowercased() {
            case "lz4"  :	compression = Compression.lz4
            case "zlib" :	compression = Compression.zlib
            case "lzma" :	compression = Compression.lzma
            case "lzfse":	compression = Compression.lzfse
            default:		return nil
            }
        }

        // finally, attempt to uncompress the data and initalize self
        if let uncompressedData = compressedData.uncompressedDataUsingCompression(compression) {
            self.init(Array(uncompressedData))
        }
        else {
            return nil
        }
    }


    /// Returns a NSData object created by compressing the receiver using the given compression algorithm.
    ///
    ///     let compressedData = someData.compressedDataUsingCompression(Compression.LZFSE)
    ///
    /// - Parameter compression: Algorithm to use during compression
    /// - Returns: A NSData object created by encoding the receiver's contents using the provided compression algorithm. Returns nil if compression fails or if the receiver's length is 0.
    func compressedDataUsingCompression(_ compression: Compression) -> Data? {
        return self.dataUsingCompression(compression, operation: .encode)
    }

    /// Returns a NSData object by uncompressing the receiver using the given compression algorithm.
    ///
    ///     let uncompressedData = someCompressedData.uncompressedDataUsingCompression(Compression.LZFSE)
    ///
    /// - Parameter compression: Algorithm to use during decompression
    /// - Returns: A NSData object created by decoding the receiver's contents using the provided compression algorithm. Returns nil if decompression fails or if the receiver's length is 0.
    func uncompressedDataUsingCompression(_ compression: Compression) -> Data? {
        return self.dataUsingCompression(compression, operation: .decode)
    }


    fileprivate enum CompressionOperation {
        case encode
        case decode
    }

    fileprivate func dataUsingCompression(_ compression: Compression, operation: CompressionOperation) -> Data? {

        guard self.count > 0 else {
            return nil
        }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        var stream = streamPtr.pointee
        var status : compression_status
        var op : compression_stream_operation
        var flags : Int32
        var algorithm : compression_algorithm

        switch compression {
        case .lz4:
            algorithm = COMPRESSION_LZ4
        case .lzfse:
            algorithm = COMPRESSION_LZFSE
        case .lzma:
            algorithm = COMPRESSION_LZMA
        case .zlib:
            algorithm = COMPRESSION_ZLIB
        }

        switch operation {
        case .encode:
            op = COMPRESSION_STREAM_ENCODE
            flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
        case .decode:
            op = COMPRESSION_STREAM_DECODE
            flags = 0
        }

        status = compression_stream_init(&stream, op, algorithm)
        guard status != COMPRESSION_STATUS_ERROR else {
            // an error occurred
            return nil
        }

        // setup the stream's source
        var outputData: Data?

        withUnsafeBytes {
            (bytes: UnsafePointer<UInt8>) -> Void in
            stream.src_ptr = bytes
            stream.src_size = count

            // setup the stream's output buffer
            // we use a temporary buffer to store the data as it's compressed
            let dstBufferSize: size_t = 4096
            let dstBufferPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)

            stream.dst_ptr = dstBufferPtr
            stream.dst_size = dstBufferSize
            // and we stroe the output in a mutable data object

            repeat {
                status = compression_stream_process(&stream, flags)

                switch status.rawValue {
                case COMPRESSION_STATUS_OK.rawValue:
                    // Going to call _process at least once more, so prepare for that
                    if stream.dst_size == 0 {
                        // Output buffer full...

                        // Write out to mutableData
                        outputData?.append(dstBufferPtr, count: dstBufferSize)

                        // Re-use dstBuffer
                        stream.dst_ptr = dstBufferPtr
                        stream.dst_size = dstBufferSize
                    }

                case COMPRESSION_STATUS_END.rawValue:
                    // We are done, just write out the output buffer if there's anything in it
                    if stream.dst_ptr > dstBufferPtr {
                        outputData?.append(dstBufferPtr, count: stream.dst_ptr - dstBufferPtr)
                    }

                case COMPRESSION_STATUS_ERROR.rawValue:
                    outputData = nil

                default:
                    break
                }
                
            } while status == COMPRESSION_STATUS_OK
            
            compression_stream_destroy(&stream)
        }
        
        return outputData
    }
    
}
