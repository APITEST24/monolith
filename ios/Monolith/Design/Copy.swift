import Foundation

enum RuCopy {
    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let n = abs(n)
        let n10 = n % 10
        let n100 = n % 100
        if n10 == 1 && n100 != 11 { return one }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
        return many
    }

    static func count(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        "\(n) \(plural(n, one, few, many))"
    }

    static func taskSubline(_ open: Int) -> String {
        switch open {
        case 0: return "все задачи закрыты"
        case 1: return "одна задача ещё открыта"
        case 2: return "две задачи ещё открыты"
        case 3: return "три задачи ещё открыты"
        case 4: return "четыре задачи ещё открыты"
        default: return "\(count(open, "задача", "задачи", "задач")) ещё открыты"
        }
    }

    static func rulesSubline(_ enabled: Int) -> String {
        if enabled == 0 { return "все правила выключены" }
        if enabled == 1 { return "правило сейчас включено" }
        return "правил сейчас включены"
    }

    static func money(_ value: Double, cents: Bool? = nil, signed: Bool = false) -> String {
        let negative = value < -0.0000001
        var mag = abs(value)
        mag = (mag * 100).rounded() / 100
        let useCents = cents ?? (abs(mag - mag.rounded()) > 0.001)
        let body: String
        if useCents {
            body = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), mag).grouped()
        } else {
            body = String(Int(mag.rounded())).grouped()
        }
        let sign: String
        if negative {
            sign = "−"
        } else if signed && mag > 0.0000001 {
            sign = "+"
        } else {
            sign = ""
        }
        return "\(sign)$\(body)"
    }
}

private extension String {
    func grouped() -> String {
        guard let dot = firstIndex(of: ".") else {
            return Self.group(self)
        }
        let whole = Self.group(String(self[..<dot]))
        return whole + self[dot...]
    }

    static func group(_ digits: String) -> String {
        let chars = Array(digits)
        var out = ""
        for (index, char) in chars.enumerated() {
            if index > 0 && (chars.count - index) % 3 == 0 {
                out.append(" ")
            }
            out.append(char)
        }
        return out
    }
}

enum Summaries {
    static func tasks(_ tasks: [TaskItem], dateLabel: String) -> TaskSummary {
        let done = tasks.filter(\.done).count
        let total = tasks.count
        let open = total - done
        return TaskSummary(
            done: done,
            total: total,
            open: open,
            headline: "\(done) из \(total)",
            subline: RuCopy.taskSubline(open),
            dateLine: "Сегодня · \(dateLabel)"
        )
    }

    static func rules(_ rules: [RuleItem]) -> RuleSummary {
        let enabled = rules.filter(\.enabled).count
        return RuleSummary(
            enabled: enabled,
            total: rules.count,
            headline: "\(enabled) из \(rules.count)",
            subline: RuCopy.rulesSubline(enabled)
        )
    }

    static func journal(_ entries: [JournalItem]) -> JournalSummary {
        let headline = RuCopy.count(entries.count, "запись", "записи", "записей")
        guard let latest = entries.first else {
            return JournalSummary(count: 0, headline: headline, subline: "журнал пуст")
        }
        let lowered = latest.dateLabel.prefix(1).lowercased() + latest.dateLabel.dropFirst()
        return JournalSummary(count: entries.count, headline: headline, subline: "последняя — \(lowered)")
    }

    static func home(from snapshot: Snapshot) -> HomeLabels {
        let bundles = snapshot.bundles.count
        let geos = snapshot.geos.filter { $0.status != "stop" }.count
        let stop = snapshot.rules.first { $0.key == "daily_stop_loss" }?.params.limit ?? snapshot.finance.stopLimit
        return HomeLabels(
            bundlesLabel: "\(bundles) \(RuCopy.plural(bundles, "активная", "активные", "активных"))",
            geosLabel: "\(geos) \(RuCopy.plural(geos, "страна", "страны", "стран"))",
            tasksLabel: "\(snapshot.tasks.count) на сегодня",
            journalLabel: RuCopy.count(snapshot.journal.count, "запись", "записи", "записей"),
            rulesLabel: "стоп \(RuCopy.money(stop))"
        )
    }
}
