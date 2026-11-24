// Sends each made-up reply in tests/grading-examples.json to Haiku, with the
// same instructions and flags the app uses, a few times, and reports the
// ones that come back with the wrong effort. Uses your Claude usage.

import Foundation

struct Example: Decodable {
    let name: String
    let reply: String
    // The efforts that are right for it; usually one.
    let expected: [String]
}

@main
enum GradingTests {
    static func main() {
        let args = CommandLine.arguments
        let runs = args.count > 2 ? Int(args[2]) ?? 3 : 3
        guard args.count > 1, let data = FileManager.default.contents(atPath: args[1]),
              let examples = try? JSONDecoder().decode([Example].self, from: data)
        else { print("usage: grading-tests <examples.json> [runs]"); exit(2) }
        let filter = ProcessInfo.processInfo.environment["ONLY"]
        let chosen = examples.filter { filter == nil || $0.name.localizedCaseInsensitiveContains(filter!) }

        // Every call for every example, a few at a time.
        let jobs = chosen.indices.flatMap { i in (0..<runs).map { _ in i } }
        var answers = Array(repeating: [String](), count: chosen.count)
        let lock = NSLock()
        let limit = DispatchSemaphore(value: 6)
        let group = DispatchGroup()
        for i in jobs {
            limit.wait()
            group.enter()
            DispatchQueue.global().async {
                let result = Grader.grade(LastReply(id: "test", text: chosen[i].reply))
                let answer = switch result {
                case .success(let g): g.effort.rawValue + (g.need.isEmpty ? "" : " (\(g.need))")
                case .failure(let e): "error: \(e.localizedDescription)"
                }
                lock.lock(); answers[i].append(answer); lock.unlock()
                limit.signal()
                group.leave()
            }
        }
        group.wait()

        var failed = 0
        for (i, e) in chosen.enumerated() {
            let wrong = answers[i].filter { a in !e.expected.contains { a == $0 || a.hasPrefix($0 + " (") } }
            if wrong.isEmpty {
                print("ok    \(e.name)")
            } else {
                failed += 1
                print("FAIL  \(e.name): \(wrong.count) of \(runs) wrong, should be \(e.expected.joined(separator: " or "))")
                for a in answers[i] { print("        \(a)") }
            }
        }
        print("\(chosen.count - failed) of \(chosen.count) passed, \(runs) runs each")
        exit(failed == 0 ? 0 : 1)
    }
}
