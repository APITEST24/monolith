import Foundation
import Network
import Security

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var loading = false
    @Published var note: String?
    @Published var showSettings = false
    @Published var online = true
    @Published var bundleFilter = "all"

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "disciplina.baseURL") }
    }

    private let cacheURL: URL
    private let queueURL: URL
    private var queue: [[String: Any]] = []
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "disciplina.reach")
    private var started = false

    init(preview: Snapshot? = nil) {
        let defaults = UserDefaults.standard
        baseURL = defaults.string(forKey: "disciplina.baseURL") ?? ""
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = support.appendingPathComponent("Disciplina", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cacheURL = folder.appendingPathComponent("snapshot.json")
        queueURL = folder.appendingPathComponent("queue.json")
        if let preview {
            snapshot = preview
        }
    }

    var serverConfigured: Bool {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https",
              url.host != nil
        else { return false }
        return true
    }

    func boot() {
        guard !started else { return }
        started = true
        if snapshot == nil {
            snapshot = loadCache() ?? Snapshot.bundled()
        }
        loadQueue()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.online = online
                if online { await self?.flush() }
            }
        }
        monitor.start(queue: monitorQueue)
        Task { await refresh() }
    }

    func refresh() async {
        guard serverConfigured else {
            note = nil
            return
        }
        loading = snapshot == nil
        defer { loading = false }
        do {
            let fresh = try await request(path: "api/v1/snapshot", method: "GET", body: nil, as: Snapshot.self)
            snapshot = fresh
            persist(fresh)
            note = nil
            await pullAlerts()
            await flush()
        } catch {
            note = "Нет связи · показаны сохранённые данные"
        }
    }

    func filteredBundles() -> [BundleItem] {
        guard let snapshot else { return [] }
        switch bundleFilter {
        case "test", "profit", "stop":
            return snapshot.bundles.filter { $0.status == bundleFilter }
        default:
            return snapshot.bundles
        }
    }

    func toggleTask(_ item: TaskItem) {
        guard var snap = snapshot, let index = snap.tasks.firstIndex(where: { $0.id == item.id }) else { return }
        snap.tasks[index].done.toggle()
        snap.taskSummary = Summaries.tasks(snap.tasks, dateLabel: snap.dateLabel)
        snap.home = Summaries.home(from: snap)
        apply(snap)
        enqueue(entity: "task", op: "update", payload: ["id": item.id, "done": snap.tasks[index].done])
    }

    func toggleRule(_ item: RuleItem) {
        guard var snap = snapshot, let index = snap.rules.firstIndex(where: { $0.id == item.id }) else { return }
        snap.rules[index].enabled.toggle()
        if snap.rules[index].key == "withdraw_to_zero" {
            snap.rules[index].valueLabel = snap.rules[index].enabled ? "ВКЛ" : "ВЫКЛ"
            snap.rules[index].valueMuted = !snap.rules[index].enabled
        }
        snap.ruleSummary = Summaries.rules(snap.rules)
        snap.home = Summaries.home(from: snap)
        apply(snap)
        enqueue(entity: "rule", op: "update", payload: ["id": item.id, "enabled": snap.rules[index].enabled])
    }

    func addTask(title: String, detail: String, note: String) {
        guard var snap = snapshot else { return }
        let item = TaskItem(
            id: temporaryID(in: snap.tasks.map(\.id)),
            title: title,
            detail: detail,
            note: note,
            noteTone: "accent",
            done: false,
            sortOrder: (snap.tasks.map(\.sortOrder).max() ?? 0) + 1
        )
        snap.tasks.append(item)
        snap.taskSummary = Summaries.tasks(snap.tasks, dateLabel: snap.dateLabel)
        snap.home = Summaries.home(from: snap)
        apply(snap)
        enqueue(entity: "task", op: "create", payload: [
            "title": title,
            "detail": detail,
            "note": note,
            "note_tone": "accent",
        ])
    }

    func addJournal(title: String, reason: String, result: String) {
        guard var snap = snapshot else { return }
        let stamp = Self.stamp()
        let item = JournalItem(
            id: temporaryID(in: snap.journal.map(\.id)),
            occurredAt: stamp,
            dateLabel: "Сегодня, \(stamp.suffix(8).prefix(5))",
            title: title,
            reason: reason,
            result: result,
            resultTone: "neutral"
        )
        snap.journal.insert(item, at: 0)
        snap.journalSummary = Summaries.journal(snap.journal)
        snap.home = Summaries.home(from: snap)
        apply(snap)
        enqueue(entity: "journal", op: "create", payload: [
            "title": title,
            "reason": reason,
            "result": result,
            "result_tone": "neutral",
            "occurred_at": stamp,
        ])
    }

    func addBundle(title: String, vertical: String, geoCode: String, source: String, network: String, model: String) {
        guard var snap = snapshot else { return }
        let subtitle = "\(source) · \(network) · \(model)"
        let item = BundleItem(
            id: temporaryID(in: snap.bundles.map(\.id)),
            title: title,
            subtitle: subtitle,
            vertical: vertical,
            geoCode: geoCode.uppercased(),
            trafficSource: source,
            network: network,
            payoutModel: model,
            status: "test",
            statusLabel: "Тест",
            spend: 0,
            revenue: 0,
            profit: 0,
            roiPct: 0,
            clicks: 0,
            conversions: 0,
            spendLabel: "$0",
            profitLabel: "+$0",
            roiLabel: "0%",
            sortOrder: (snap.bundles.map(\.sortOrder).max() ?? 0) + 1
        )
        snap.bundles.append(item)
        snap.home = Summaries.home(from: snap)
        apply(snap)
        enqueue(entity: "bundle", op: "create", payload: [
            "title": title,
            "subtitle": subtitle,
            "vertical": vertical,
            "geo_code": geoCode.uppercased(),
            "traffic_source": source,
            "network": network,
            "payout_model": model,
            "status": "test",
        ])
    }

    func addGeo(code: String, name: String, subtitle: String) {
        guard var snap = snapshot else { return }
        let item = GeoItem(
            id: temporaryID(in: snap.geos.map(\.id)),
            code: code.uppercased(),
            name: name,
            subtitle: subtitle,
            status: "test",
            statusLabel: "Тест",
            cpc: 0,
            epc: 0,
            trendPct: 0,
            cpcLabel: "$0.00",
            epcLabel: "$0.00",
            trendLabel: "0%",
            bundleId: nil,
            sortOrder: (snap.geos.map(\.sortOrder).max() ?? 0) + 1
        )
        snap.geos.append(item)
        snap.geoSummary.liveCount = snap.geos.filter { $0.status != "stop" }.count
        snap.home = Summaries.home(from: snap)
        apply(snap)
        enqueue(entity: "geo", op: "create", payload: [
            "code": code.uppercased(),
            "name": name,
            "subtitle": subtitle,
            "status": "test",
            "cpc": 0,
            "epc": 0,
            "trend_pct": 0,
        ])
    }

    func restoreDemo() {
        queue = []
        saveQueue()
        if let bundled = Snapshot.bundled() {
            apply(bundled)
        }
        note = nil
    }

    func flush() async {
        guard serverConfigured, !queue.isEmpty else { return }
        let body: [String: Any] = ["mutations": queue]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        do {
            let response = try await request(path: "api/v1/sync", method: "POST", body: data, as: SyncResponse.self)
            let applied = Set(response.applied)
            let rejected = Set(response.conflicts.map(\.id))
            queue.removeAll { applied.contains(stringID($0)) || rejected.contains(stringID($0)) }
            saveQueue()
            snapshot = response.snapshot
            persist(response.snapshot)
            note = nil
        } catch {
            note = "Правки сохранены на телефоне и уйдут на сервер, когда связь вернётся"
        }
    }

    private func pullAlerts() async {
        guard UserDefaults.standard.bool(forKey: "disciplina.alerts") else { return }
        guard let report = try? await request(path: "api/v1/rules/check", method: "GET", body: nil, as: CheckReport.self) else { return }
        let notable = report.violations + report.warnings
        let signature = notable.map { "\($0.key):\($0.status):\($0.message)" }.joined(separator: "|")
        let previous = UserDefaults.standard.string(forKey: "disciplina.alertSignature")
        guard signature != previous else { return }
        UserDefaults.standard.set(signature, forKey: "disciplina.alertSignature")
        for item in notable.prefix(3) {
            Notifier.shared.schedule(title: item.title, body: item.message, after: 1)
        }
    }

    private func apply(_ snap: Snapshot) {
        snapshot = snap
        persist(snap)
    }

    private func persist(_ snap: Snapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadCache() -> Snapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return Snapshot.decode(data)
    }

    private func enqueue(entity: String, op: String, payload: [String: Any]) {
        let item: [String: Any] = [
            "id": UUID().uuidString,
            "entity": entity,
            "op": op,
            "payload": payload,
            "client_updated_at": Self.stamp(),
        ]
        queue.append(item)
        saveQueue()
        Task { await flush() }
    }

    private func loadQueue() {
        guard let data = try? Data(contentsOf: queueURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }
        queue = object
    }

    private func saveQueue() {
        guard let data = try? JSONSerialization.data(withJSONObject: queue, options: [.prettyPrinted]) else { return }
        try? data.write(to: queueURL, options: .atomic)
    }

    private func request<T: Decodable>(path: String, method: String, body: Data?, as type: T.Type) async throws -> T {
        guard let root = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw URLError(.badURL)
        }
        let url = root.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(KeychainStore.get("api-key") ?? "", forHTTPHeaderField: "X-API-Key")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.status(http.statusCode)
        }
        guard let decoded = try? APICoding.decoder.decode(T.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    private func temporaryID(in ids: [Int]) -> Int {
        let lowest = ids.min() ?? 0
        return lowest > 0 ? -1 : lowest - 1
    }

    private func stringID(_ item: [String: Any]) -> String {
        item["id"] as? String ?? ""
    }

    static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: Date())
    }

    static var preview: AppModel {
        let model = AppModel(preview: Snapshot.bundled())
        model.started = true
        return model
    }
}

enum APIError: Error {
    case unauthorized
    case status(Int)
    case decoding
}

enum KeychainStore {
    private static let service = "app.disciplina.ios"

    static func set(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = Data(value.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
