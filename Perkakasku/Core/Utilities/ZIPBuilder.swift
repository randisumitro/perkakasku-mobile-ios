import Foundation
import zlib

/// Minimal standards-compliant Store (method 0) ZIP archive builder using system zlib CRC32.
/// Avoids third-party dependencies while producing archives compatible with macOS, iOS Files, and Windows.
enum ZIPBuilder {
    struct Entry: Sendable {
        let fileName: String
        let data: Data
    }

    enum ZIPError: LocalizedError, Sendable {
        case emptyEntries
        case invalidFileName

        var errorDescription: String? {
            switch self {
            case .emptyEntries: return "No files provided to archive."
            case .invalidFileName: return "Invalid archive file name."
            }
        }
    }

    static func buildArchive(entries: [Entry]) throws -> Data {
        guard !entries.isEmpty else { throw ZIPError.emptyEntries }

        var output = Data()
        var centralDirectory = Data()
        let (dosTime, dosDate) = currentDOSTimeAndDate()

        for entry in entries {
            guard let nameData = entry.fileName.data(using: .utf8), !nameData.isEmpty else {
                throw ZIPError.invalidFileName
            }
            let crc = crc32Checksum(for: entry.data)
            let size = UInt32(clamping: entry.data.count)
            let nameLen = UInt16(clamping: nameData.count)
            let localHeaderOffset = UInt32(clamping: output.count)

            // Local file header (30 bytes + filename)
            output.appendLE(UInt32(0x04034B50))
            output.appendLE(UInt16(20))          // version needed: 2.0
            output.appendLE(UInt16(0x0800))      // UTF-8 filename flag
            output.appendLE(UInt16(0))           // compression method: 0 (store)
            output.appendLE(dosTime)
            output.appendLE(dosDate)
            output.appendLE(crc)
            output.appendLE(size)
            output.appendLE(size)
            output.appendLE(nameLen)
            output.appendLE(UInt16(0))           // extra field length
            output.append(nameData)
            output.append(entry.data)

            // Central directory file header (46 bytes + filename)
            centralDirectory.appendLE(UInt32(0x02014B50))
            centralDirectory.appendLE(UInt16(20)) // version made by
            centralDirectory.appendLE(UInt16(20)) // version needed
            centralDirectory.appendLE(UInt16(0x0800))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(dosTime)
            centralDirectory.appendLE(dosDate)
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(nameLen)
            centralDirectory.appendLE(UInt16(0))  // extra len
            centralDirectory.appendLE(UInt16(0))  // comment len
            centralDirectory.appendLE(UInt16(0))  // disk number
            centralDirectory.appendLE(UInt16(0))  // internal attrs
            centralDirectory.appendLE(UInt32(0))  // external attrs
            centralDirectory.appendLE(localHeaderOffset)
            centralDirectory.append(nameData)
        }

        let cdOffset = UInt32(clamping: output.count)
        let cdSize = UInt32(clamping: centralDirectory.count)
        let count = UInt16(clamping: entries.count)
        output.append(centralDirectory)

        // End of central directory record (22 bytes)
        output.appendLE(UInt32(0x06054B50))
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(0))
        output.appendLE(count)
        output.appendLE(count)
        output.appendLE(cdSize)
        output.appendLE(cdOffset)
        output.appendLE(UInt16(0))

        return output
    }

    private static func crc32Checksum(for data: Data) -> UInt32 {
        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
                return 0
            }
            return UInt32(zlib.crc32(0, ptr, uInt(data.count)))
        }
    }

    private static func currentDOSTimeAndDate() -> (UInt16, UInt16) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let year = max(1980, comps.year ?? 2026) - 1980
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = (comps.second ?? 0) / 2
        let dosTime = UInt16((hour << 11) | (minute << 5) | second)
        let dosDate = UInt16((year << 9) | (month << 5) | day)
        return (dosTime, dosDate)
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
