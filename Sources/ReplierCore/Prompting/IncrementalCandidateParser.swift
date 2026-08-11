public struct PartialCandidate: Sendable, Equatable {
    public let label: ReplyCandidate.Label
    public var text: String
    public var isComplete: Bool

    public init(label: ReplyCandidate.Label, text: String, isComplete: Bool) {
        self.label = label
        self.text = text
        self.isComplete = isComplete
    }
}

/// Incrementally parses the sentinel-delimited streaming reply format:
/// ```
/// <<<short>>>
/// (short body)
/// <<<long>>>
/// (long body)
/// ```
/// Network deltas can split a sentinel line at any position, so lines are buffered until
/// a terminating newline (or `finish()`) arrives before being classified.
public struct IncrementalCandidateParser: Sendable {
    private var lineBuffer = ""
    private var candidates: [PartialCandidate] = []
    private var rawLines: [[String]] = []
    private var seenLabels: Set<ReplyCandidate.Label> = []
    private var openIndex: Int?

    public init() {}

    public mutating func feed(_ delta: String) -> [PartialCandidate] {
        lineBuffer += delta
        while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
            let rawLine = String(lineBuffer[lineBuffer.startIndex..<newlineIndex])
            lineBuffer.removeSubrange(lineBuffer.startIndex...newlineIndex)
            process(rawLine)
        }
        return candidates
    }

    public mutating func finish() -> [PartialCandidate] {
        if !lineBuffer.isEmpty {
            let rawLine = lineBuffer
            lineBuffer = ""
            process(rawLine)
        }
        closeOpenCandidate()
        return candidates
    }

    private mutating func process(_ rawLine: String) {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        if let label = sentinelLabel(in: line), !seenLabels.contains(label) {
            closeOpenCandidate()
            seenLabels.insert(label)
            candidates.append(PartialCandidate(label: label, text: "", isComplete: false))
            rawLines.append([])
            openIndex = candidates.count - 1
            return
        }

        guard let index = openIndex else { return }
        rawLines[index].append(line)
        candidates[index].text = rawLines[index].joined(separator: "\n")
    }

    private func sentinelLabel(in line: String) -> ReplyCandidate.Label? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("<<<"), trimmed.hasSuffix(">>>"), trimmed.count > 6 else { return nil }
        return ReplyCandidate.Label(rawValue: String(trimmed.dropFirst(3).dropLast(3)))
    }

    private mutating func closeOpenCandidate() {
        guard let index = openIndex else { return }
        candidates[index].text = candidates[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        candidates[index].isComplete = true
        openIndex = nil
    }
}
