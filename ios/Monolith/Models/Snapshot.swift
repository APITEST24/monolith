import Foundation

struct Snapshot: Codable {
    var asOf: String
    var dateLabel: String
    var finance: Finance
    var transactions: [TransactionItem]
    var bundles: [BundleItem]
    var geos: [GeoItem]
    var geoSummary: GeoSummary
    var tasks: [TaskItem]
    var taskSummary: TaskSummary
    var journal: [JournalItem]
    var journalSummary: JournalSummary
    var rules: [RuleItem]
    var ruleSummary: RuleSummary
    var home: HomeLabels
}

struct Finance: Codable {
    var balance: Double
    var reserve: Double
    var onHold: Double
    var free: Double
    var invested: Double
    var returned: Double
    var breakEvenRatio: Double
    var profitToday: Double
    var spendToday: Double
    var incomeToday: Double
    var roiTodayPct: Double
    var stopLimit: Double
    var stopSpent: Double
    var series: [SeriesPoint]
    var display: FinanceDisplay
}

struct FinanceDisplay: Codable {
    var profitToday: String
    var spendToday: String
    var incomeToday: String
    var roiToday: String
    var stopRatio: String
    var balance: String
    var reserve: String
    var onHold: String
    var free: String
    var invested: String
    var returned: String
    var breakEven: String
}

struct SeriesPoint: Codable, Identifiable {
    var date: String
    var profit: Double
    var id: String { date }
}

struct TransactionItem: Codable, Identifiable {
    var id: Int
    var occurredAt: String
    var title: String
    var subtitle: String
    var geoName: String
    var amount: Double
    var amountLabel: String
}

struct BundleItem: Codable, Identifiable {
    var id: Int
    var title: String
    var subtitle: String
    var vertical: String
    var geoCode: String
    var trafficSource: String
    var network: String
    var payoutModel: String
    var status: String
    var statusLabel: String
    var spend: Double
    var revenue: Double
    var profit: Double
    var roiPct: Double
    var clicks: Int
    var conversions: Int
    var spendLabel: String
    var profitLabel: String
    var roiLabel: String
    var sortOrder: Int
}

struct GeoItem: Codable, Identifiable {
    var id: Int
    var code: String
    var name: String
    var subtitle: String
    var status: String
    var statusLabel: String
    var cpc: Double
    var epc: Double
    var trendPct: Double
    var cpcLabel: String
    var epcLabel: String
    var trendLabel: String
    var bundleId: Int?
    var sortOrder: Int
}

struct GeoSummary: Codable {
    var liveCount: Int
    var stoppedCount: Int
    var capital: Double
    var avgCpc: Double
    var avgEpc: Double
    var capitalLabel: String
    var avgCpcLabel: String
    var avgEpcLabel: String
    var stoppedLine: String
}

struct TaskItem: Codable, Identifiable {
    var id: Int
    var title: String
    var detail: String
    var note: String
    var noteTone: String
    var done: Bool
    var sortOrder: Int
}

struct TaskSummary: Codable {
    var done: Int
    var total: Int
    var open: Int
    var headline: String
    var subline: String
    var dateLine: String
}

struct JournalItem: Codable, Identifiable {
    var id: Int
    var occurredAt: String
    var dateLabel: String
    var title: String
    var reason: String
    var result: String
    var resultTone: String
}

struct JournalSummary: Codable {
    var count: Int
    var headline: String
    var subline: String
}

struct RuleParams: Codable {
    var limit: Double?
    var amount: Double?
    var percent: Double?
    var days: Int?
    var roiThreshold: Double?
}

struct RuleItem: Codable, Identifiable {
    var id: Int
    var key: String
    var title: String
    var valueLabel: String
    var valueMuted: Bool
    var detail: String
    var enabled: Bool
    var params: RuleParams
    var sortOrder: Int
}

struct RuleSummary: Codable {
    var enabled: Int
    var total: Int
    var headline: String
    var subline: String
}

struct HomeLabels: Codable {
    var bundlesLabel: String
    var geosLabel: String
    var tasksLabel: String
    var journalLabel: String
    var rulesLabel: String
}

struct CheckReport: Codable {
    var asOf: String
    var items: [CheckItem]
    var violations: [CheckItem]
    var warnings: [CheckItem]
    var signals: [CheckItem]
}

struct CheckItem: Codable, Identifiable {
    var key: String
    var title: String
    var status: String
    var message: String
    var id: String { key }
}

struct SyncResponse: Codable {
    var applied: [String]
    var conflicts: [SyncConflict]
    var snapshot: Snapshot
}

struct SyncConflict: Codable {
    var id: String
    var reason: String
}

enum APICoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

extension Snapshot {
    static func decode(_ data: Data) -> Snapshot? {
        try? APICoding.decoder.decode(Snapshot.self, from: data)
    }

    static func bundled() -> Snapshot? {
        let bundles = [Bundle.main]
        var urls: [URL] = []
        for bundle in bundles {
            urls += bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
            urls += bundle.urls(forResourcesWithExtension: "json", subdirectory: "Resources") ?? []
        }
        for url in urls where url.lastPathComponent == "snapshot.json" {
            if let data = try? Data(contentsOf: url), let snapshot = decode(data) {
                return snapshot
            }
        }
        return nil
    }
}
