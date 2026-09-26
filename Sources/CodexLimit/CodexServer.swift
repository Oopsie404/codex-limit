import Darwin
import Foundation

enum CodexServer {
    static func read(completion: @escaping (Usage?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            completion(request())
        }
    }

    private static func executable() -> URL? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .filter { !$0.isEmpty }
            .map { String($0) + "/codex" }
        for path in paths + ["/Applications/ChatGPT.app/Contents/Resources/codex"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private static func request() -> Usage? {
        guard let executable = executable() else { return nil }
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }

        defer {
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
            if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGTERM) }
        }

        let initialize = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-limit","version":"0.1.3"},"capabilities":{}}}
        """
        guard send(initialize, to: input.fileHandleForWriting) else { return nil }

        let deadline = Date().addingTimeInterval(12)
        var buffer = Data()
        var initialized = false
        let fd = output.fileHandleForReading.fileDescriptor

        while Date() < deadline {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
            let remaining = max(1, Int32(deadline.timeIntervalSinceNow * 1_000))
            let ready = Darwin.poll(&descriptor, 1, remaining)
            if ready == 0 { break }
            if ready < 0 {
                if errno == EINTR { continue }
                break
            }

            var chunk = [UInt8](repeating: 0, count: 4_096)
            let count = Darwin.read(fd, &chunk, chunk.count)
            if count <= 0 { break }
            buffer.append(contentsOf: chunk[..<count])
            if buffer.count > 1_048_576 { break }

            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let id = (json["id"] as? NSNumber)?.intValue else { continue }
                if id == 1 && !initialized {
                    guard json["error"] == nil, json["result"] != nil,
                          send("{\"jsonrpc\":\"2.0\",\"method\":\"initialized\"}",
                               to: input.fileHandleForWriting),
                          send("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"account/rateLimits/read\",\"params\":{\"excludeResetCreditDetails\":true}}",
                               to: input.fileHandleForWriting) else { return nil }
                    initialized = true
                } else if id == 2 && initialized {
                    return Usage(response: json)
                }
            }
        }
        return nil
    }

    private static func send(_ message: String, to handle: FileHandle) -> Bool {
        guard let data = (message + "\n").data(using: .utf8) else { return false }
        do {
            try handle.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }
}
