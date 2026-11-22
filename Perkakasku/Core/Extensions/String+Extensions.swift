import Foundation

struct JSONStats: Sendable, Equatable {
    let rootType: String
    let depth: Int
    let nodeCount: Int
    let keyCount: Int
    let inputBytes: Int
    let outputBytes: Int
    let lines: Int
}

struct DiffLine: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case context, add, remove
    }
    let id = UUID()
    let kind: Kind
    let text: String
}

extension String {
    /// Trimmed word count.
    var wordCount: Int {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    /// Character count.
    var characterCount: Int { count }

    /// Character count excluding whitespace.
    var charactersWithoutSpacesCount: Int {
        filter { !$0.isWhitespace }.count
    }

    /// Paragraph count (split on blank lines).
    var paragraphCount: Int {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let paragraphs = trimmed.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return paragraphs.isEmpty ? 1 : paragraphs.count
    }

    /// Approximate sentence count.
    var sentenceCount: Int {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let sentences = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return max(sentences.isEmpty ? 1 : sentences.count, 0)
    }

    /// Estimated reading minutes at 200 WPM.
    var estimatedReadingMinutes: Int {
        let w = wordCount
        return w == 0 ? 0 : max(1, Int(ceil(Double(w) / 200.0)))
    }

    /// Pretty-print JSON if valid, otherwise return the input.
    var formattedJSON: String {
        (try? processJSON(indent: 2, sortKeys: false, minify: false).output) ?? self
    }

    /// Whether the string is valid JSON.
    var isValidJSON: Bool {
        guard let data = data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    func processJSON(indent: Int = 2, sortKeys: Bool = false, minify: Bool = false) throws -> (output: String, stats: JSONStats) {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "PerkakaskuJSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please enter JSON text first."])
        }
        guard let inputData = data(using: .utf8) else {
            throw NSError(domain: "PerkakaskuJSON", code: 2, userInfo: [NSLocalizedDescriptionKey: "Input text is not valid UTF-8."])
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: inputData, options: [.fragmentsAllowed])
        } catch let nsErr as NSError {
            let debugDesc = (nsErr.userInfo["NSDebugDescription"] as? String) ?? nsErr.localizedDescription
            throw NSError(domain: "PerkakaskuJSON", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON: \(debugDesc)"])
        }

        var writeOpts: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        if sortKeys {
            writeOpts.insert(.sortedKeys)
        }
        if !minify {
            writeOpts.insert(.prettyPrinted)
        }

        var outputData = try JSONSerialization.data(withJSONObject: object, options: writeOpts)
        var outString = String(data: outputData, encoding: .utf8) ?? ""
        if !minify && indent == 4 {
            outString = outString
                .components(separatedBy: "\n")
                .map { line in
                    let leadingSpaces = line.prefix(while: { $0 == " " }).count
                    let doubled = String(repeating: " ", count: leadingSpaces * 2)
                    return doubled + line.dropFirst(leadingSpaces)
                }
                .joined(separator: "\n")
            outputData = outString.data(using: .utf8) ?? outputData
        }

        let structure = Self.inspectJSONStructure(object)
        let stats = JSONStats(
            rootType: structure.rootType,
            depth: structure.depth,
            nodeCount: structure.nodeCount,
            keyCount: structure.keyCount,
            inputBytes: inputData.count,
            outputBytes: outputData.count,
            lines: outString.components(separatedBy: "\n").count
        )
        return (outString, stats)
    }

    private static func inspectJSONStructure(_ root: Any) -> (rootType: String, depth: Int, nodeCount: Int, keyCount: Int) {
        let rootType: String
        if root is [Any] { rootType = "array" }
        else if root is [String: Any] { rootType = "object" }
        else if root is NSNull { rootType = "null" }
        else if root is String { rootType = "string" }
        else if root is Bool { rootType = "boolean" }
        else { rootType = "number" }

        var maxDepth = 0
        var nodes = 0
        var keys = 0
        var stack: [(Any, Int)] = [(root, 1)]

        while let (val, depth) = stack.popLast() {
            maxDepth = Swift.max(maxDepth, depth)
            nodes += 1
            if let arr = val as? [Any] {
                for item in arr {
                    stack.append((item, depth + 1))
                }
            } else if let dict = val as? [String: Any] {
                keys += dict.count
                for (_, v) in dict {
                    stack.append((v, depth + 1))
                }
            }
        }
        return (rootType, maxDepth, nodes, keys)
    }

    static func computeLineDiff(left: String, right: String) -> [DiffLine] {
        let leftLines = left.components(separatedBy: "\n")
        let rightLines = right.components(separatedBy: "\n")
        let diff = rightLines.difference(from: leftLines)

        var removedIndices = Set<Int>()
        var insertedMap: [Int: String] = [:]
        for change in diff {
            switch change {
            case .remove(let offset, _, _):
                removedIndices.insert(offset)
            case .insert(let offset, let element, _):
                insertedMap[offset] = element
            }
        }

        var result: [DiffLine] = []
        var li = 0
        var ri = 0
        while li < leftLines.count || ri < rightLines.count {
            if li < leftLines.count, removedIndices.contains(li) {
                result.append(DiffLine(kind: .remove, text: leftLines[li]))
                li += 1
            } else if ri < rightLines.count, let inserted = insertedMap[ri] {
                result.append(DiffLine(kind: .add, text: inserted))
                ri += 1
            } else {
                if li < leftLines.count {
                    result.append(DiffLine(kind: .context, text: leftLines[li]))
                    li += 1
                }
                if ri < rightLines.count {
                    ri += 1
                }
            }
            if result.count >= 250 { break }
        }
        return result
    }
}
