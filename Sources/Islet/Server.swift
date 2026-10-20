import Foundation
import Network

/// Tiny HTTP server on the local network.
///   GET  /            – page for the phone
///   POST /text        – body is the text to show (empty body hides it)
///   GET  /text?t=...  – same, handy for Shortcuts / curl
///   POST /clear       – hide
final class HTTPServer {
    let port: UInt16
    var onText: (String) -> Void = { _ in }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "islet.http")

    init(port: UInt16) { self.port = port }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.service = NWListener.Service(name: "Islet", type: "_http._tcp")
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            conn.start(queue: self.queue)
            self.receive(on: conn, buffer: Data())
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state { NSLog("Islet listener failed: \(error)") }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    private func receive(on conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = HTTPRequest(buffer) {
                self.respond(to: request, on: conn)
            } else if isComplete || error != nil || buffer.count > 1_000_000 {
                conn.cancel()
            } else {
                self.receive(on: conn, buffer: buffer)
            }
        }
    }

    private func respond(to req: HTTPRequest, on conn: NWConnection) {
        let comps = URLComponents(string: req.path)
        switch (req.method, comps?.path ?? req.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            send(conn, status: "200 OK", type: "text/html; charset=utf-8", body: Data(phonePage.utf8))
        case ("POST", "/text"), ("PUT", "/text"):
            deliver(String(decoding: req.body, as: UTF8.self))
            send(conn, status: "200 OK", body: Data("ok".utf8))
        case ("GET", "/text"):
            deliver(comps?.queryItems?.first { $0.name == "t" || $0.name == "text" }?.value ?? "")
            send(conn, status: "200 OK", body: Data("ok".utf8))
        case (_, "/clear"):
            deliver("")
            send(conn, status: "200 OK", body: Data("ok".utf8))
        case ("OPTIONS", _):
            send(conn, status: "204 No Content", body: Data())
        default:
            send(conn, status: "404 Not Found", body: Data("not found".utf8))
        }
    }

    private func deliver(_ text: String) {
        DispatchQueue.main.async { self.onText(text) }
    }

    private func send(_ conn: NWConnection, status: String, type: String = "text/plain; charset=utf-8", body: Data) {
        let head = "HTTP/1.1 \(status)\r\n" +
            "Content-Type: \(type)\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Access-Control-Allow-Origin: *\r\n" +
            "Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS\r\n" +
            "Access-Control-Allow-Headers: *\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in conn.cancel() })
    }
}

struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    /// Returns nil until the buffer holds the full headers and body.
    init?(_ data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: data[..<headerEnd.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return nil }
        var length = 0
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            if kv.count == 2, kv[0].lowercased() == "content-length" {
                length = Int(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyStart = headerEnd.upperBound
        guard data.count - bodyStart >= length else { return nil }
        method = String(parts[0]).uppercased()
        path = String(parts[1])
        body = data[bodyStart..<(bodyStart + length)]
    }
}

/// Best guess at the Mac's LAN IPv4 address (Wi-Fi / Ethernet).
func localIPAddress() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }
    var candidates: [(String, String)] = []
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let ifa = ptr.pointee
        guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
              (ifa.ifa_flags & UInt32(IFF_UP)) != 0, (ifa.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
            candidates.append((String(cString: ifa.ifa_name), String(cString: host)))
        }
    }
    return candidates.first { $0.0 == "en0" }?.1
        ?? candidates.first { $0.0.hasPrefix("en") }?.1
        ?? candidates.first?.1
}
