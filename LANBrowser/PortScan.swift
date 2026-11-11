import Foundation

/// Which web ports the optional port scan tries. Off unless the user picks and confirms a preset.
enum PortScanPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case off, standard, common, custom
    var id: String { rawValue }

    static let defaultsKey = "portScanPreset"
    static let confirmedCountKey = "portScanConfirmedCount"

    static let standardPorts = [80, 443]
    static let commonPorts = [80, 81, 443, 1880, 3000, 3001, 5000, 5001, 7878, 8000, 8008, 8080, 8081, 8096, 8123, 8443, 8888, 8989, 9000, 9090, 9443, 32400]

    /// Scan prompts list the widest built-in scan, the user’s own list when it has ports,
    /// standard web ports, then Bonjour only.
    static func scanChoices(custom: PortList) -> [PortScanPreset] {
        custom.isEmpty ? [.common, .standard, .off] : [.common, .custom, .standard, .off]
    }

    /// Built-in presets carry their ports; Custom uses the list edited in Settings.
    func ports(custom: PortList) -> [Int] {
        switch self {
        case .off: return []
        case .standard: return Self.standardPorts
        case .common: return Self.commonPorts
        case .custom: return custom.ports
        }
    }

    var title: String {
        switch self {
        case .off: return "Off"
        case .standard: return "Standard Web"
        case .common: return "Common Web Apps"
        case .custom: return "Custom"
        }
    }

    func summary(custom: PortList) -> String {
        switch self {
        case .off: return "Bonjour only"
        case .standard: return "Ports 80 and 443"
        case .common, .custom: return PortList.countText(ports(custom: custom).count)
        }
    }

    /// The label shown in the scan prompts.
    func choiceLabel(custom: PortList) -> String {
        self == .off ? "Bonjour Only" : "\(title) (\(summary(custom: custom)))"
    }

    /// The last-scan line, which can’t know a custom list edited since that scan.
    var scannedSummary: String {
        switch self {
        case .off: return "Bonjour"
        case .standard: return "Bonjour + ports 80 and 443"
        case .common: return "Bonjour + \(PortList.countText(Self.commonPorts.count))"
        case .custom: return "Bonjour + custom ports"
        }
    }
}

/// One port or an inclusive run of ports in the custom scan list.
struct PortRange: Hashable, Comparable, Identifiable, Sendable {
    let lower: Int
    let upper: Int
    var id: String { "\(lower)-\(upper)" }

    static let valid = 1...65535

    init?(_ lower: Int, _ upper: Int) {
        guard Self.valid.contains(lower), Self.valid.contains(upper), lower <= upper else { return nil }
        self.lower = lower
        self.upper = upper
    }

    /// Accepts “8080”, “8000-8010”, “8000–8010” or “8000 to 8010”, with any spacing.
    init?(text: String) {
        let parts = text.lowercased()
            .replacingOccurrences(of: "to", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) }),
              let lower = Int(parts[0]), let upper = Int(parts.last!) else { return nil }
        self.init(lower, upper)
    }

    var count: Int { upper - lower + 1 }
    var label: String { lower == upper ? "\(lower)" : "\(lower) – \(upper)" }
    var text: String { lower == upper ? "\(lower)" : "\(lower)-\(upper)" }

    static func < (a: PortRange, b: PortRange) -> Bool { (a.lower, a.upper) < (b.lower, b.upper) }
}

/// The custom scan’s ports: sorted ranges with overlapping and adjacent entries combined.
struct PortList: Equatable, Sendable {
    static let limit = 1024
    static let defaultsKey = "customScanPorts"
    static let visitedKey = "customScanPortsVisited"
    static let common = PortList(ports: PortScanPreset.commonPorts)

    private(set) var ranges: [PortRange]

    init(_ ranges: [PortRange] = []) {
        var merged: [PortRange] = []
        for range in ranges.sorted() {
            if let last = merged.last, range.lower <= last.upper + 1 {
                merged[merged.count - 1] = PortRange(last.lower, max(last.upper, range.upper))!
            } else {
                merged.append(range)
            }
        }
        self.ranges = merged
    }

    init(ports: [Int]) {
        self.init(ports.compactMap { PortRange($0, $0) })
    }

    /// Reads the saved form, such as “80,443,8000-8100”; an empty string is an empty list.
    init?(text: String) {
        let items = text.split(separator: ",").map(String.init)
        var ranges: [PortRange] = []
        for item in items {
            guard let range = PortRange(text: item) else { return nil }
            ranges.append(range)
        }
        self.init(ranges)
    }

    var text: String { ranges.map(\.text).joined(separator: ",") }
    var count: Int { ranges.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { ranges.isEmpty }
    var ports: [Int] { ranges.flatMap { Array($0.lower...$0.upper) } }

    static func countText(_ count: Int) -> String { count == 1 ? "1 port" : "\(count.formatted()) ports" }

    /// The list with `range` added, or with `original` replaced by it; nil past the port limit.
    func adding(_ range: PortRange, replacing original: PortRange? = nil) -> PortList? {
        let result = PortList(ranges.filter { $0 != original } + [range])
        return result.count <= Self.limit ? result : nil
    }

    func removing(_ range: PortRange) -> PortList {
        PortList(ranges.filter { $0 != range })
    }

    /// The message shown when an entry can’t be added, or nil when it can.
    func problem(adding text: String, replacing original: PortRange? = nil) -> String? {
        guard let range = PortRange(text: text) else {
            return "Enter a port from 1 to 65535, such as 8080, or a range, such as 8000-8010."
        }
        guard adding(range, replacing: original) != nil else {
            let total = PortList(ranges.filter { $0 != original } + [range]).count
            return "That would make \(total.formatted()) ports. A custom scan can include up to \(Self.limit.formatted())."
        }
        return nil
    }
}

/// A block of IPv4 addresses, such as the network this device is on.
struct IPv4Range: Equatable, Sendable {
    let network: UInt32
    let prefix: Int

    static let maxAddresses = 1024

    init?(cidr: String) {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let prefix = Int(parts[1]), (0...32).contains(prefix),
              let address = IPv4Range.number(String(parts[0])) else { return nil }
        self.prefix = prefix
        network = address & IPv4Range.mask(prefix)
    }

    var count: Int { prefix >= 31 ? 0 : (1 << (32 - prefix)) - 2 }
    var first: UInt32 { network + 1 }
    var last: UInt32 { network + UInt32((1 << (32 - prefix)) - 2) }
    var cidr: String { "\(IPv4Range.string(network))/\(prefix)" }
    var description: String { "\(IPv4Range.string(first)) – \(IPv4Range.string(last))" }

    /// Every usable address, leaving out the network and broadcast addresses and this device itself.
    func hosts(excluding excluded: String? = nil) -> [String] {
        guard count > 0 else { return [] }
        let skip = excluded.flatMap(IPv4Range.number)
        return (first...last).filter { $0 != skip }.map(IPv4Range.string)
    }

    /// This device’s whole network when it has at most 1,024 addresses, otherwise the /24 around it.
    static func scanRange(network: String, deviceIP: String) -> IPv4Range? {
        guard let range = IPv4Range(cidr: network), range.count > 0 else { return nil }
        if range.count <= maxAddresses { return range }
        return IPv4Range(cidr: "\(deviceIP)/24")
    }

    static func mask(_ prefix: Int) -> UInt32 { prefix == 0 ? 0 : UInt32.max << UInt32(32 - prefix) }

    static func number(_ address: String) -> UInt32? {
        let octets = address.split(separator: ".", omittingEmptySubsequences: false).compactMap { UInt8($0) }
        guard octets.count == 4, address.split(separator: ".", omittingEmptySubsequences: false).count == 4 else { return nil }
        return octets.reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func string(_ number: UInt32) -> String {
        [24, 16, 8, 0].map { String((number >> UInt32($0)) & 0xFF) }.joined(separator: ".")
    }
}

/// What a port scan would do on the current network, shown to the user before it is allowed.
struct PortScanPlan: Identifiable, Equatable, Sendable {
    let preset: PortScanPreset
    let ports: [Int]
    let range: IPv4Range
    let deviceIP: String
    var id: String { "\(preset.rawValue)|\(range.cidr)" }

    /// Counted rather than listed, because prompts and Settings read it on every redraw.
    var addressCount: Int {
        guard let device = IPv4Range.number(deviceIP), range.count > 0, (range.first...range.last).contains(device) else { return range.count }
        return range.count - 1
    }
    var connectionCount: Int { addressCount * ports.count }

    /// The longest the connection phase can take if nothing answers: every batch waits for its timeout.
    var worstCaseSeconds: Double {
        (Double(connectionCount) / Double(PortScan.concurrentChecks)).rounded(.up) * PortScan.connectTimeout
    }

    var durationText: String {
        let minutes = Int((worstCaseSeconds / 60).rounded(.up))
        return minutes <= 1 ? "about a minute" : "about \(minutes.formatted()) minutes"
    }

    /// Every selected port is checked, even on hosts that silently drop 80 and 443.
    var targets: [(host: String, port: Int)] {
        range.hosts(excluding: deviceIP).flatMap { host in
            ports.map { (host: host, port: $0) }
        }
    }

    /// A scan needs (re)confirmation until one is confirmed, and again on a larger network.
    func needsConfirmation(confirmedCount: Int?) -> Bool {
        guard let confirmedCount, confirmedCount > 0 else { return true }
        return addressCount > confirmedCount
    }
}

/// An open port that answered as a web server.
struct WebFinding: Equatable, Sendable {
    let host: String
    let port: Int
    let url: URL
    let status: Int
    let title: String?
    let server: String?
    let location: String?

    var isRedirect: Bool { (300..<400).contains(status) }
}

enum PortScan {
    /// Connection checks in flight at once, and how long each waits for an answer.
    static let concurrentChecks = 128
    static let connectTimeout = 1.5

    /// Drops answers that aren’t useful pages: 400 Bad Request (the port isn’t a web UI),
    /// redirects to another page that was also found (such as HTTP → HTTPS on the same device),
    /// and the HTTP copy of a page the same device also serves over HTTPS.
    static func collapse(_ findings: [WebFinding]) -> [WebFinding] {
        let found = Set(findings.map { ServiceCatalog.deviceKey($0.url) })
        let useful = findings.filter { finding in
            guard finding.status != 400 else { return false }
            guard finding.isRedirect, let location = finding.location,
                  let target = URL(string: location, relativeTo: finding.url)?.absoluteURL else { return true }
            let targetKey = ServiceCatalog.deviceKey(target)
            return targetKey == ServiceCatalog.deviceKey(finding.url) || !found.contains(targetKey)
        }
        return useful.filter { finding in
            guard finding.url.scheme == "http" else { return true }
            return !useful.contains { other in
                other.host == finding.host && other.url.scheme == "https" && other.port == 443 && finding.port == 80
                    && other.title == finding.title && other.server == finding.server
            }
        }
    }

    /// The row title: the title of the page the redirects end on, else the device’s network
    /// name, else the server software, else the port.
    static func name(for finding: WebFinding, deviceName: String?) -> String {
        if let title = finding.title { return title }
        if let deviceName { return DeviceStore.endpointLabel(host: deviceName, port: finding.port) }
        return finding.server ?? "Web app on port \(finding.port)"
    }

    /// Ports that usually speak HTTPS are tried with TLS first, everything else with plain HTTP first.
    static func prefersHTTPS(port: Int) -> Bool { [443, 5001, 8443, 9443].contains(port) }
}
