import SwiftUI
import UIKit

// Explicit wrapper name avoids the SDK’s same-named State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

extension HostDevice {
    /// The Mac reports the iPad idiom when it runs the iPad app, so check for it first.
    @MainActor static var current: HostDevice {
        if ProcessInfo.processInfo.isiOSAppOnMac { return .mac }
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
    }
}

struct SiteIcon: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "network").font(.title3).foregroundStyle(.tint)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

struct LocalNetworkCard: View {
    let turnOn: () -> Void
    let notNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Find devices on this network", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            Text("Lists web apps such as Plex and Home Assistant, and shows which bookmarks are reachable. You’ll be asked to allow Local Network access. Nothing is sent outside your network.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Not Now", action: notNow)
                Button("Turn On", action: turnOn).buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }
}

struct DiscoveredSection: View {
    @ObservedObject var network: LocalNetwork
    /// Web servers already bookmarked are left out, matched by host name or IP plus port.
    let bookmarked: Set<String>
    let label: (DiscoveredService) -> String
    let open: (DiscoveredService) -> Void
    /// The open action that isn’t the default, e.g. “Open in Current Tab”.
    let alternateOpen: (title: String, action: (DiscoveredService) -> Void)
    let save: (DiscoveredService) -> Void
    let rename: (DiscoveredService) -> Void
    @Binding var choosingScan: Bool
    @ViewState private var expanded = true
    @Environment(\.openURL) private var openURL

    private var services: [DiscoveredService] {
        network.services.filter { !ServiceCatalog.isBookmarked($0, bookmarked: bookmarked) }
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                scanStatus
                if network.accessDenied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local Network access is off for LAN Browser.").font(.subheadline)
                        if HostDevice.current == .mac {
                            Text("Turn it on in System Settings › Privacy & Security › Local Network.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                        }
                    }
                }
                ForEach(services) { service in
                    HStack(spacing: 12) {
                        Button { open(service) } label: {
                            HStack(spacing: 12) {
                                SiteIcon(data: service.faviconPNG)
                                    .overlay(alignment: .bottomTrailing) {
                                        StatusDot(state: network.serviceStatus[service.id])
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(service.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        if service.foundBy == .portScan {
                                            Text("port scan").font(.caption2).foregroundStyle(.secondary)
                                                .padding(.horizontal, 6).padding(.vertical, 1)
                                                .background(.quaternary, in: Capsule())
                                        }
                                    }
                                    Text(label(service)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button("Add to Bookmarks", systemImage: "plus.circle") { save(service) }
                            .labelStyle(.iconOnly).buttonStyle(.borderless).font(.title3)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Remove", systemImage: "minus.circle", role: .destructive) { network.remove(service) }
                    }
                    .contextMenu {
                        Button(alternateOpen.title, systemImage: "plus.square.on.square") { alternateOpen.action(service) }
                        Button("Rename Device…", systemImage: "character.cursor.ibeam") { rename(service) }
                        Button("Remove from List", systemImage: "minus.circle", role: .destructive) { network.remove(service) }
                    }
                }
            } label: {
                HStack {
                    Label("On This Network", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    if network.isSearching && !services.isEmpty { ProgressView().controlSize(.small) }
                    if !services.isEmpty { Text("\(services.count)").foregroundStyle(.secondary) }
                    Button { choosingScan = true } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(network.isSearching)
                    .accessibilityLabel("Scan Again")
                }
            }
        } footer: {
            Text("Web apps found by the last scan, except ones already in your bookmarks. The circular arrow, or a pull down, asks which scan to run. Tap + to save one as a bookmark; swipe left to remove it from this list.")
        }
        .animation(.default, value: services.map(\.id))
        .modifier(ScanChoiceDialog(network: network, isPresented: $choosingScan))
    }

    @ViewBuilder private var scanStatus: some View {
        if network.isSearching {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    if let progress = network.portScanProgress {
                        Text("\(progress.phase) · \(progress.done.formatted()) of \(progress.total.formatted())")
                            .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    } else {
                        Text(services.isEmpty ? "Looking for web apps…" : "Scanning…").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel") { network.stopScanning() }.buttonStyle(.borderless)
                }
                if let progress = network.portScanProgress, progress.total > 0 {
                    ProgressView(value: Double(progress.done), total: Double(progress.total))
                }
            }
        } else if let lastScan = network.lastScan {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scanned \(lastScan.formatted(.relative(presentation: .named))) · \(lastScan.formatted(date: .omitted, time: .shortened)) · \((network.lastScanPorts ?? .off).scannedSummary)")
                    .font(.caption).foregroundStyle(.secondary)
                if network.networkChanged {
                    Label("You’ve changed networks since this scan. Scan again to update.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if network.services.isEmpty {
                    Text("No web apps were found.").font(.subheadline).foregroundStyle(.secondary)
                } else if services.isEmpty {
                    Text("Everything found is already in your bookmarks.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } else {
            HStack {
                Text("Not scanned yet.").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("Scan") { choosingScan = true }.buttonStyle(.borderless)
            }
        }
    }
}

/// The scan button asks which scan to run, then starts it.
struct ScanChoiceDialog: ViewModifier {
    @ObservedObject var network: LocalNetwork
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.confirmationDialog("Scan Again", isPresented: $isPresented, titleVisibility: .visible) {
            ForEach(PortScanPreset.scanChoices(custom: network.customPorts)) { preset in
                Button(preset.choiceLabel(custom: network.customPorts)) { network.startChosenScan(preset) }
            }
        } message: {
            Text("Choose what this scan looks for.")
        }
    }
}

/// Asked once Local Network Features is turned on, in place of scanning automatically.
struct FirstScanSheet: View {
    @ObservedObject var network: LocalNetwork
    /// The chosen scan, or nil for No Scan; it starts once the sheet has closed.
    let choose: (PortScanPreset?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 44)).foregroundStyle(.tint)
                Text("Scan This Network?").font(.title.bold())
                Text("LAN Browser can look for web apps on this network now. Bonjour finds devices that announce themselves. A port scan also checks every address on this network for web pages, which can take several minutes.")
                ForEach(PortScanPreset.scanChoices(custom: network.customPorts)) { preset in
                    Button { choose(preset) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset == .off ? "Bonjour Only" : preset.title).font(.headline)
                            Text(detail(preset)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }
                Button { choose(nil) } label: {
                    Text("No Scan").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                Text("You can scan later from the circular arrow on On This Network. Change the Custom scan’s ports in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .interactiveDismissDisabled()
    }

    private func detail(_ preset: PortScanPreset) -> String {
        guard preset != .off else { return "Devices that announce themselves. The quickest scan." }
        let summary = preset.summary(custom: network.customPorts)
        guard let plan = network.plan(for: preset) else { return summary }
        return "\(summary) on \(plan.addressCount.formatted()) addresses · up to \(plan.durationText)"
    }
}

/// Presents the first-scan question while `active`; the sheet can only be closed by answering it.
/// The answer is applied after the sheet finishes closing, so starting a scan doesn’t stall the animation.
private struct FirstScanPrompt: ViewModifier {
    @ObservedObject var network: LocalNetwork
    let active: Bool
    @ViewState private var answer: PortScanPreset??

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { network.askingFirstScan && active && answer == nil }, set: { _ in }), onDismiss: {
            // Also called when the sheet is hidden for another screen; then the question stays open.
            guard let choice = answer else { return }
            answer = nil
            network.answerFirstScan(choice)
        }) {
            FirstScanSheet(network: network) { answer = .some($0) }
        }
    }
}

extension View {
    func firstScanPrompt(_ network: LocalNetwork, active: Bool = true) -> some View {
        modifier(FirstScanPrompt(network: network, active: active))
    }
}

/// Settings editor for the Custom scan: one row per port or range, combined as they’re added.
struct CustomPortsView: View {
    @ObservedObject var network: LocalNetwork
    @ViewState private var entry = ""
    @ViewState private var problem: String?
    @ViewState private var editing: PortRange?
    @ViewState private var editText = ""
    @ViewState private var confirmingReset = false
    @ViewState private var confirmingRemoveAll = false

    private var list: PortList { network.customPorts }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Port or range, such as 8000-8010", text: $entry)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .buttonStyle(.borderless)
                        .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .onChange(of: entry) { _, _ in problem = nil }
            } header: { Text("Add Ports") } footer: {
                if let problem {
                    Text(problem).foregroundStyle(.red)
                } else {
                    Text("Enter one port, such as 8080, or a range, such as 8000-8010. Overlapping and neighboring entries are combined.")
                }
            }

            Section {
                if list.isEmpty {
                    Text("No ports yet. Add one above, or reset to the Common Web Apps ports.").foregroundStyle(.secondary)
                }
                ForEach(list.ranges) { range in
                    Button { edit(range) } label: {
                        HStack {
                            Text(range.label).monospacedDigit().foregroundStyle(.primary)
                            Spacer()
                            Text(PortList.countText(range.count)).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint("Edits this entry")
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { edit(range) }
                        Button("Delete", systemImage: "trash", role: .destructive) { network.customPorts = list.removing(range) }
                    }
                }
                .onDelete { offsets in
                    var updated = list
                    for range in offsets.map({ list.ranges[$0] }) { updated = updated.removing(range) }
                    network.customPorts = updated
                }
            } header: { Text("Ports") } footer: { Text(totalText) }
        }
        .navigationTitle("Custom Scan Ports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Reset to Common Web Apps", systemImage: "arrow.counterclockwise") { confirmingReset = true }
                    Button("Remove All Ports", systemImage: "trash", role: .destructive) { confirmingRemoveAll = true }
                        .disabled(list.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton().disabled(list.isEmpty) }
        }
        .alert("Edit Ports", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }), presenting: editing) { range in
            TextField("8000-8010", text: $editText)
                .keyboardType(.numbersAndPunctuation)
            Button("Save") { save(range) }
            Button("Delete", role: .destructive) { network.customPorts = list.removing(range) }
            Button("Cancel", role: .cancel) {}
        } message: { range in
            Text("Change \(range.label) to another port or range.")
        }
        .confirmationDialog("Reset to Common Web Apps?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset Ports", role: .destructive) { network.customPorts = .common; problem = nil }
        } message: {
            Text("Your custom list is replaced with the \(PortScanPreset.commonPorts.count) Common Web Apps ports.")
        }
        .confirmationDialog("Remove all ports?", isPresented: $confirmingRemoveAll, titleVisibility: .visible) {
            Button("Remove All Ports", role: .destructive) { network.customPorts = PortList(); problem = nil }
        } message: {
            Text("Custom is hidden from the scan choices until you add a port.")
        }
    }

    private var totalText: String {
        var text = "\(PortList.countText(list.count)) of \(PortList.limit.formatted())."
        if let plan = network.plan(for: .custom) {
            text += " On this network, a Custom scan makes \(plan.connectionCount.formatted()) connections (\(plan.addressCount.formatted()) addresses × \(PortList.countText(plan.ports.count))), which can take up to \(plan.durationText)."
        }
        return text + " Choose Custom from the circular arrow on On This Network to run it. Editing ports never starts a scan."
    }

    private func add() {
        let text = entry.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if let message = list.problem(adding: text) {
            problem = message
        } else if let range = PortRange(text: text), let updated = list.adding(range) {
            network.customPorts = updated
            entry = ""
        }
    }

    private func edit(_ range: PortRange) {
        editText = range.text
        editing = range
    }

    private func save(_ range: PortRange) {
        if let message = list.problem(adding: editText, replacing: range) {
            problem = message
        } else if let updated = PortRange(text: editText).flatMap({ list.adding($0, replacing: range) }) {
            network.customPorts = updated
            problem = nil
        }
    }
}

/// Marks a local page opened despite an untrusted certificate; tapping shows the certificate.
struct CertificateStrip: View {
    let issue: CertificateIssue
    let show: () -> Void

    var body: some View {
        Button(action: show) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Certificate not trusted").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(issue.host).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityLabel("Certificate not trusted for \(issue.host). Show certificate.")
    }
}

/// The untrusted certificate in full, so it can be checked against the device.
struct CertificateDetailsView: View {
    let issue: CertificateIssue
    @ViewState private var copied = false

    var body: some View {
        List {
            Section {
                Label(issue.error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red).textSelection(.enabled)
                if let code = issue.errorCode { LabeledContent("Error code", value: String(code)) }
            } header: { Text("Problem") } footer: {
                Text("LAN Browser opened \(issue.host) anyway because it’s an address on your local network. Another device on your network could pretend to be it, so if it matters, compare the SHA-256 fingerprint below with the one the device shows in its own settings.")
            }
            ForEach(Array(issue.chain.enumerated()), id: \.offset) { index, certificate in
                Section(index == 0 ? "Server Certificate" : "Issuer \(index)") {
                    LabeledContent("Subject", value: certificate.subject)
                    if let commonName = certificate.commonName, commonName != certificate.subject {
                        LabeledContent("Common Name", value: commonName)
                    }
                    if let notBefore = certificate.notBefore {
                        LabeledContent("Valid From", value: notBefore.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let notAfter = certificate.notAfter {
                        LabeledContent("Valid Until", value: notAfter.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(notAfter < Date() ? .red : .primary)
                    }
                    if let key = certificate.key { LabeledContent("Key", value: key) }
                    if let serial = certificate.serialNumber {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Serial Number").font(.caption.weight(.semibold))
                            Text(serial).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SHA-256 Fingerprint").font(.caption.weight(.semibold))
                        Text(certificate.sha256).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            Section {
                Button(copied ? "Copied" : "Copy Certificate Details", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = issue.report
                    copied = true
                }
            }
        }
        .navigationTitle("Certificate")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A non-200 page’s first line: status, exact request, and quick ways to see more.
struct ResponseBanner: View {
    let response: PageResponse
    let details: () -> Void
    let diagnose: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: response.isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(response.statusCode >= 500 ? .red : response.isError ? .orange : .blue)
            VStack(alignment: .leading, spacing: 6) {
                Text("HTTP \(response.statusLine)").font(.subheadline.weight(.semibold).monospaced())
                Text("\(response.method) \(response.url)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                HStack(spacing: 8) {
                    Button("Details", action: details)
                    if response.isError { Button("Diagnose", action: diagnose) }
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            Spacer(minLength: 0)
            Button("Hide", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }
}

/// Every detail WebKit reports about the page’s response, verbatim.
struct ResponseDetailsView: View {
    let response: PageResponse
    @ViewState private var copied = false

    var body: some View {
        List {
            Section("Request") {
                LabeledContent("Method", value: response.method)
                Text(response.url).font(.callout.monospaced()).textSelection(.enabled)
            }
            Section {
                Text(response.statusLine).font(.body.monospaced()).textSelection(.enabled)
            } header: { Text("Status") } footer: {
                Text("The status code is exactly what the server sent. WebKit doesn’t pass on the server’s own reason phrase, and HTTP/2 doesn’t send one, so the phrase shown is the standard one for this code.")
            }
            Section {
                ForEach(Array(response.headers.enumerated()), id: \.offset) { _, header in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(header.name).font(.caption.weight(.semibold).monospaced())
                        Text(header.value).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            } header: { Text("Response Headers (\(response.headers.count))") } footer: {
                Text("Values are as received. iOS may normalize header names and doesn’t keep their original order, so they are sorted by name.")
            }
            Section {
                Button(copied ? "Copied" : "Copy Response Details", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = response.report
                    copied = true
                }
            }
        }
        .navigationTitle("HTTP \(response.statusCode)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatusDot: View {
    let state: Reachability?

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 1.5))
            .accessibilityLabel(label)
    }

    private var color: Color {
        switch state {
        case .reachable: return .green
        case .unreachable: return .red
        case .checking, nil: return .gray
        }
    }

    private var label: String {
        switch state {
        case .reachable: return "Reachable"
        case .unreachable: return "Not reachable"
        case .checking, nil: return "Checking"
        }
    }
}

struct DiagnosticsTarget: Identifiable {
    let id = UUID()
    let url: URL
}

/// Presented on its own (error screen, bookmark menu) with a Done button.
struct DiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    var body: some View {
        NavigationStack {
            DiagnosticsView(url: url)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct DiagnosticsView: View {
    @StateObject private var diagnostics: ConnectionDiagnostics
    @ViewState private var copied = false
    @Environment(\.openURL) private var openURL

    init(url: URL) {
        _diagnostics = StateObject(wrappedValue: ConnectionDiagnostics(url: url, device: .current))
    }

    var body: some View {
        List {
            Section {
                Text(diagnostics.url.absoluteString).font(.callout.monospaced()).textSelection(.enabled)
            }
            Section("Checks") {
                ForEach(diagnostics.steps) { step in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            icon(for: step.status).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.kind.title).font(.subheadline.weight(.semibold))
                                if !step.detail.isEmpty {
                                    Text(step.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                            }
                        }
                        if let advice = step.advice {
                            Text(advice).font(.callout).padding(.leading, 30)
                            // The advice names the System Settings path on a Mac, where this URL doesn’t reach it.
                            if step.kind == .permission && step.status == .failed && diagnostics.device != .mac {
                                Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                                    .padding(.leading, 30)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
            Section {
                Button(diagnostics.isRunning ? "Checking…" : "Retry Checks", systemImage: "arrow.clockwise") {
                    copied = false
                    Task { await diagnostics.run() }
                }
                .disabled(diagnostics.isRunning)
                Button(copied ? "Copied" : "Copy Report", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = diagnostics.report
                    copied = true
                }
                .disabled(diagnostics.isRunning)
            } footer: {
                Text("The report includes addresses on your network. Review it before posting it publicly.")
            }
        }
        .navigationTitle("Why Can’t I Connect?")
        .navigationBarTitleDisplayMode(.inline)
        .task { await diagnostics.run() }
    }

    @ViewBuilder private func icon(for status: DiagnosticStatus) -> some View {
        switch status {
        case .pending: Image(systemName: "circle").foregroundStyle(.tertiary).accessibilityLabel("Waiting")
        case .running: ProgressView().controlSize(.small)
        case .passed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Passed")
        case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityLabel("Warning")
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red).accessibilityLabel("Failed")
        case .skipped: Image(systemName: "minus.circle").foregroundStyle(.tertiary).accessibilityLabel("Skipped")
        }
    }
}
