import Foundation

public struct CandidateParser: Sendable {
    private struct CandidateResponse: Decodable {
        let candidates: [ReplyCandidate]
    }

    public init() {}

    public func parse(_ modelOutput: String) throws -> [ReplyCandidate] {
        let unfenced = stripFences(modelOutput)

        guard let openIndex = unfenced.firstIndex(of: "{"),
              let closeIndex = unfenced.lastIndex(of: "}"),
              openIndex <= closeIndex
        else {
            throw CandidateParserError.noJSONFound
        }

        let jsonSlice = unfenced[openIndex...closeIndex]
        let data = Data(jsonSlice.utf8)

        let response: CandidateResponse
        do {
            response = try JSONDecoder().decode(CandidateResponse.self, from: data)
        } catch {
            throw CandidateParserError.malformed(error.localizedDescription)
        }

        guard response.candidates.count == 3 else {
            throw CandidateParserError.wrongCandidateCount(response.candidates.count)
        }

        return response.candidates
    }

    private func stripFences(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"),
              let firstNewline = trimmed.firstIndex(of: "\n")
        else {
            return input
        }

        let afterOpening = trimmed[trimmed.index(after: firstNewline)...]
        guard let closingRange = afterOpening.range(of: "```", options: .backwards) else {
            return input
        }

        return String(afterOpening[..<closingRange.lowerBound])
    }
}
