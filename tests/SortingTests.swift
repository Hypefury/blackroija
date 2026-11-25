// Which section the window puts a session in, given what its log, the app,
// GitHub and Haiku say. Each case is a session that was once shown in the
// wrong place (the commit that fixed it is in its name), or one that must
// keep showing where it does. All sessions, PRs and logs here are made up.

import Foundation

struct Case {
    let name: String
    // A made-up session log, written into a scratch folder; when set, what
    // the window reads from it replaces the five facts below.
    var log: ((FakeLog) -> Void)? = nil
    var activity: Activity = .idle
    var commandRunning = false
    var agentRunning = false
    var question: String? = nil
    var stopped: String? = nil
    // What the desktop app says about the last reply.
    var appStatus: AppStatus? = nil
    var needsAction: String? = nil
    // Haiku's answer for the last reply; nil while it's still being read.
    var effort: Effort? = nil
    // An "Allow / Deny" prompt nobody answered, for this tool.
    var prompt: String? = nil
    // PR number -> "open", "merged", "failing" or "conflicts".
    var prs: [Int: String] = [:]
    let expected: String
}

// MARK: - Fake session logs

let scratch = NSTemporaryDirectory() + "blackroija-tests-\(ProcessInfo.processInfo.processIdentifier)"

/// A session log in the shape the desktop app writes, plus the files its
/// background jobs write to.
final class FakeLog {
    let id: String
    let path: String
    var subagents: String { "\(scratch)/\(id)/subagents" }
    private var lines: [String] = []
    private var counter = 0
    // How old the log looks; a turn that hasn't moved for 15 minutes stopped.
    var minutesOld: Double = 0

    init(_ id: String) {
        self.id = id
        path = "\(scratch)/\(id).jsonl"
        try? FileManager.default.createDirectory(atPath: subagents, withIntermediateDirectories: true)
    }

    private func add(_ object: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: object, options: .withoutEscapingSlashes)
        lines.append(String(decoding: data, as: UTF8.self))
    }

    private func uuid() -> String { counter += 1; return "\(id)-\(counter)" }

    func you(_ text: String) {
        add(["type": "user", "uuid": uuid(), "message": ["role": "user", "content": text]])
    }

    /// Claude calls a tool; the turn goes on.
    func toolCall(_ name: String = "Bash", input: [String: Any] = [:]) {
        add(["type": "assistant", "uuid": uuid(), "message": [
            "role": "assistant", "stop_reason": "tool_use",
            "content": [["type": "tool_use", "id": uuid(), "name": name, "input": input]]]])
    }

    func toolResult(_ text: String, _ result: [String: Any] = [:]) {
        add(["type": "user", "uuid": uuid(), "toolUseResult": result,
             "message": ["role": "user", "content": [["type": "tool_result", "content": text]]]])
    }

    func apiRequest() { add(["type": "api-request"]) }

    /// Claude's closing reply: its turn ends.
    func reply(_ text: String) {
        apiRequest()
        add(["type": "assistant", "uuid": uuid(), "message": [
            "role": "assistant", "stop_reason": "end_turn", "content": [["type": "text", "text": text]]]])
    }

    /// A command started in the background, writing to its output file.
    func startCommand(_ task: String, outputMinutesOld: Double = 0) {
        toolCall()
        let file = "\(scratch)/\(id)-\(task).output"
        touch(file, minutesOld: outputMinutesOld)
        toolResult("Command running in background. Output is being written to: \(file)", ["backgroundTaskId": task])
    }

    /// A helper agent started in the background, writing to its own log.
    func startAgent(_ agent: String, logMinutesOld: Double = 0) {
        toolCall("Agent")
        toolResult("Async agent launched successfully.", ["isAsync": true, "agentId": agent])
        agentWrites(agent, minutesOld: logMinutesOld)
    }

    func agentWrites(_ agent: String, minutesOld: Double = 0) {
        touch("\(subagents)/agent-\(agent).jsonl", minutesOld: minutesOld)
    }

    /// The agent's own record, which says whether it runs in the background.
    func agentRecord(_ agent: String, finished: Bool) {
        let meta: [String: Any] = ["requestShape": "background", "finished": finished]
        FileManager.default.createFile(atPath: "\(subagents)/agent-\(agent).meta.json",
                                       contents: try! JSONSerialization.data(withJSONObject: meta))
    }

    /// The notice a finished background job sends, which wakes the session.
    func finished(_ task: String, extra: String = "") {
        you("<task-notification><task-id>\(task)</task-id><status>completed</status>\(extra)</task-notification>")
    }

    /// A big tool result, like a few screenshots, that pushes what came
    /// before it out of the part of the log the window reads.
    func bigResult() {
        toolCall("Read")
        toolResult(String(repeating: "x", count: 700 * 1024))
    }

    func write() {
        FileManager.default.createFile(atPath: path, contents: Data(lines.joined(separator: "\n").utf8))
        try? FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-minutesOld * 60)],
                                               ofItemAtPath: path)
    }

    private func touch(_ file: String, minutesOld: Double) {
        FileManager.default.createFile(atPath: file, contents: Data("…".utf8))
        try? FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-minutesOld * 60)],
                                               ofItemAtPath: file)
    }
}

// MARK: - Sorting one session

let repo = "Example/app"

func section(_ c: Case, index: Int) -> String {
    var transcript: TranscriptState
    if let build = c.log {
        let log = FakeLog("session\(index)")
        build(log)
        log.write()
        transcript = TranscriptReader.parse(path: log.path, cliSessionId: log.id).0
    } else {
        transcript = TranscriptState(activity: c.activity,
                                     reply: c.activity == .idle ? LastReply(id: "r1", text: "made up") : nil,
                                     commandRunning: c.commandRunning, agentRunning: c.agentRunning,
                                     question: c.question, stopped: c.stopped)
    }
    let state = classify(
        transcript,
        askAppStatus: { c.appStatus },
        needsAction: c.needsAction,
        askGrade: {
            guard let reply = transcript.reply else { return .none }
            return c.effort.map { .graded(Grade(replyId: reply.id, need: "", effort: $0)) } ?? .grading
        },
        prompt: c.prompt)
    var problems: [String: String] = [:]
    let prs = c.prs.sorted { $0.key < $1.key }.map { number, state in
        let pr = SessionPR(number: number, repo: repo, state: state == "merged" ? "MERGED" : "OPEN")
        if state == "failing" || state == "conflicts" { problems[pr.key] = state }
        return pr
    }
    let session = Session(
        id: "s\(index)", title: "Made-up session", project: "app",
        activity: state.activity, lastActivity: Date(), prs: prs, grade: state.grade,
        question: state.question, appStatus: state.appStatus,
        stopped: state.question == nil ? transcript.stopped : nil,
        commandRunning: transcript.commandRunning)
    let g = arrange([session], now: Date(), problems: problems)
    if !g.stuck.isEmpty { return "Stuck" }
    if !g.answer.isEmpty || !g.needsYou.isEmpty { return "Needs you" }
    if !g.working.isEmpty { return "Working" }
    if !g.quiet.isEmpty { return "Waiting" }
    return "hidden"
}

// MARK: - Cases

let cases: [Case] = [
    // From what the app, GitHub and Haiku say.
    Case(name: "Waits on its own background test run while another of its PRs fails (7ab74d5)",
         commandRunning: true, effort: .waiting, prs: [101: "open", 102: "failing"],
         expected: "Waiting"),
    Case(name: "Idle, asks nothing, with a PR failing its checks",
         effort: .nothing, prs: [101: "failing"],
         expected: "Stuck"),
    Case(name: "Idle, waits on nothing it runs, with a PR failing its checks",
         effort: .waiting, prs: [101: "failing"],
         expected: "Stuck"),
    Case(name: "Asks you to test something while its PR fails: on you, not stuck (1fef257)",
         effort: .handsOn, prs: [101: "failing"],
         expected: "Needs you"),
    Case(name: "Ready for review while its PR fails: on you, not stuck (1fef257)",
         appStatus: .reviewReady("Test it on your phone"), prs: [101: "failing"],
         expected: "Needs you"),
    Case(name: "Done, with a PR that only has merge conflicts (9160529)",
         appStatus: .finished, prs: [101: "conflicts"],
         expected: "Needs you"),
    Case(name: "Waiting, with a PR that only has merge conflicts (9160529)",
         effort: .waiting, prs: [101: "conflicts"],
         expected: "Waiting"),
    Case(name: "Background command running and the reply asks nothing: a test run",
         commandRunning: true, effort: .nothing,
         expected: "Working"),
    Case(name: "Background command running but the reply asks you to run a command (41fd4a7)",
         commandRunning: true, effort: .handsOn,
         expected: "Needs you"),
    Case(name: "PR up for review while its own background command still watches the checks and review bot",
         commandRunning: true, effort: .review, prs: [101: "open"],
         expected: "Waiting"),
    Case(name: "PR up for review and nothing runs for it: on you",
         effort: .review, prs: [101: "open"],
         expected: "Needs you"),
    Case(name: "Background command running and the reply only waits on CI",
         commandRunning: true, effort: .waiting,
         expected: "Waiting"),
    Case(name: "Helper agent working and the reply asks nothing",
         agentRunning: true, effort: .nothing,
         expected: "Working"),
    Case(name: "Helper agent working and the reply only waits",
         agentRunning: true, effort: .waiting, prs: [101: "conflicts"],
         expected: "Working"),
    Case(name: "Helper agent working but the reply asks you something (a2b2f54)",
         agentRunning: true, effort: .reply,
         expected: "Needs you"),
    Case(name: "Helper agent working but the app says it's blocked on you",
         agentRunning: true, appStatus: .blocked("Pick a name"),
         expected: "Needs you"),
    Case(name: "Helper agent working, ready for review with nothing for you to do (18f7467)",
         agentRunning: true, appStatus: .reviewReady("PR open"), needsAction: "",
         expected: "Working"),
    Case(name: "Unanswered Allow / Deny prompt while a helper agent works (509e4d8)",
         agentRunning: true, effort: .waiting, prompt: "Bash",
         expected: "Needs you"),
    Case(name: "Done and asks nothing: it waits for you to archive it",
         effort: .nothing,
         expected: "Needs you"),
    Case(name: "The app says it finished: you check it and archive it (a3f9016)",
         appStatus: .finished,
         expected: "Needs you"),
    Case(name: "Turn stopped without finishing",
         stopped: "Stopped mid-turn",
         expected: "Stuck"),
    Case(name: "Working session",
         activity: .working,
         expected: "Working"),

    // From a made-up session log.
    Case(name: "Log: helper agent restarted by a message after its first finished notice (61151ee)",
         log: { l in
             l.you("Fix the flaky test"); l.startAgent("a1"); l.finished("a1")
             l.toolCall("SendMessage"); l.toolResult("Agent resumed.", ["resumedAgentId": "a1"])
             l.reply("I sent the helper agent a follow-up and will report back when it's done.")
         },
         effort: .waiting, prs: [101: "conflicts"],
         expected: "Working"),
    Case(name: "Log: helper agent's finished notice says it may resume on its own (ec9d523)",
         log: { l in
             l.you("Rebase the PR"); l.startAgent("a1")
             l.finished("a1", extra: "<note>Stopped with background work of its own still running; it may resume on its own and notify again.</note>")
             l.reply("The rebase is still running in the helper agent.")
         },
         effort: .nothing,
         expected: "Working"),
    Case(name: "Log: a helper's finished notice after the last reply starts no new turn (eccac78)",
         log: { l in
             l.you("Check the status line"); l.startAgent("a1", logMinutesOld: 30)
             l.reply("Two questions: should the line say 'idle' or 'waiting'? And should I run the checks now?")
             l.finished("a1")
         },
         effort: .reply,
         expected: "Needs you"),
    Case(name: "Log: helper agent's start is outside the part read, a message is queued for it (18f7467)",
         log: { l in
             l.you("Review the PR"); l.startAgent("a1"); l.bigResult()
             l.toolCall("SendMessage"); l.toolResult("Message queued for delivery to a1 at its next tool round.")
             l.reply("The helper agent is still reviewing; I'll report back.")
         },
         appStatus: .reviewReady("PR open"), needsAction: "", prs: [101: "conflicts"],
         expected: "Working"),
    Case(name: "Log: big screenshots pushed the helper agent's start out, its record says it runs (25287e4)",
         log: { l in
             l.you("Re-check the page"); l.startAgent("a1"); l.agentRecord("a1", finished: false)
             l.bigResult(); l.bigResult()
             l.reply("A helper agent is re-checking the page in the background.")
         },
         effort: .nothing,
         expected: "Working"),
    Case(name: "Log: helper agent's record says finished: not running",
         log: { l in
             l.you("Re-check the page"); l.startAgent("a1"); l.agentRecord("a1", finished: true)
             l.bigResult(); l.bigResult()
             l.reply("Done: the page looks right. Archive this when you've checked it.")
         },
         effort: .nothing,
         expected: "Needs you"),
    Case(name: "Log: background test run still writing, reply only waits on it (7ab74d5)",
         log: { l in
             l.you("Merge both"); l.startCommand("b1")
             l.reply("The full browser tests are running (about 10 minutes). After they pass I'll merge.")
         },
         effort: .waiting, prs: [101: "open", 102: "failing"],
         expected: "Waiting"),
    Case(name: "Log: background command whose output stopped 20 minutes ago doesn't count",
         log: { l in
             l.you("Start the dev server"); l.startCommand("b1", outputMinutesOld: 20)
             l.reply("The dev server is up. Open the page and tell me if the button shows.")
         },
         effort: .handsOn,
         expected: "Needs you"),
    Case(name: "Log: background command that sent its finished notice doesn't count",
         log: { l in
             l.you("Run the tests"); l.startCommand("b1"); l.finished("b1")
             l.reply("All tests pass. Say merge and I'll merge it.")
         },
         effort: .click,
         expected: "Needs you"),
    Case(name: "Log: a question card nobody answered",
         log: { l in
             l.you("Add the setting")
             l.toolCall("AskUserQuestion", input: ["questions": [["question": "Which default?"]]])
         },
         expected: "Needs you"),
    Case(name: "Log: turn hasn't moved for 20 minutes without a reply",
         log: { l in
             l.you("Fix it"); l.toolCall(); l.minutesOld = 20
         },
         expected: "Stuck"),
    Case(name: "Log: turn hasn't moved for 20 minutes, but its helper agent still writes",
         log: { l in
             l.you("Fix it"); l.startAgent("a1"); l.toolCall(); l.minutesOld = 20
         },
         expected: "Working"),
    Case(name: "Log: you pressed stop: it waits on you, nothing is broken",
         log: { l in
             l.you("Fix it"); l.toolCall(); l.you("[Request interrupted by user]"); l.minutesOld = 20
         },
         expected: "Needs you"),
]

@main
enum SortingTests {
    static func main() {
        defer { try? FileManager.default.removeItem(atPath: scratch) }
        var failed = 0
        for (i, c) in cases.enumerated() {
            let got = section(c, index: i)
            if got == c.expected {
                print("ok    \(c.name)")
            } else {
                failed += 1
                print("FAIL  \(c.name): shows under \(got), should be \(c.expected)")
            }
        }
        // A row's PR: the session's task was the second PR, stacked on an
        // older one that got closed.
        let closedBase = SessionPR(number: 201, repo: repo, state: "CLOSED")
        let ownMerged = SessionPR(number: 202, repo: repo, state: "MERGED", own: true)
        let ownOpen = SessionPR(number: 203, repo: repo, state: "OPEN", own: true)
        let rows: [(name: String, prs: [SessionPR], expected: [Int])] = [
            ("With no PR open, the row names the PR the session opened, not an older closed one it built on",
             [closedBase, ownMerged], [202]),
            ("With no PR open, the row names every PR the session opened",
             [ownMerged, closedBase, SessionPR(number: 205, repo: repo, state: "CLOSED", own: true)], [202, 205]),
            ("With no PR open and none the session opened, the row names the first one",
             [closedBase, SessionPR(number: 204, repo: repo, state: "MERGED")], [201]),
            ("An open PR hides the closed and merged ones",
             [closedBase, ownMerged, ownOpen], [203]),
        ]
        for row in rows {
            let got = prsToShow(row.prs).map(\.number)
            if got == row.expected {
                print("ok    \(row.name)")
            } else {
                failed += 1
                print("FAIL  \(row.name): names \(got), should be \(row.expected)")
            }
        }
        print("\(cases.count + rows.count - failed) of \(cases.count + rows.count) passed")
        try? FileManager.default.removeItem(atPath: scratch)
        exit(failed == 0 ? 0 : 1)
    }
}
