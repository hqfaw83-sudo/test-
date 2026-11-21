import Foundation

struct SleepPiece {
    let start: Date
    let end: Date
    let stage: Int
    let source: String
    let watch: Bool
}
struct SleepSpan: Identifiable {
    let start: Date
    let end: Date
    let stage: Int
    var id: String { "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)-\(stage)" }
}
struct SleepEpisode {
    let start: Date
    let end: Date
    let seconds: Double
    let source: String
    let watch: Bool
    let spans: [SleepSpan]
}
enum WellnessMath {
    static func companionDays(from start: Date, to end: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0)
    }
    static func union(_ ranges: [(Date, Date)]) -> [(Date, Date)] {
        var result: [(Date, Date)] = []
        for range in ranges.filter({ $0.1 > $0.0 }).sorted(by: { $0.0 < $1.0 }) {
            if let last = result.last, range.0 <= last.1 { result[result.count - 1].1 = max(last.1, range.1) }
            else { result.append(range) }
        }
        return result
    }
    static func duration(_ ranges: [(Date, Date)]) -> Double { union(ranges).reduce(0) { $0 + $1.1.timeIntervalSince($1.0) } }
    static func primarySleep(_ pieces: [SleepPiece], calendar: Calendar = .current) -> [SleepEpisode] {
        var episodes: [SleepEpisode] = []
        for (source, samples) in Dictionary(grouping: pieces, by: { $0.source }) {
            let asleep = samples.filter { [1, 3, 4, 5].contains($0.stage) && $0.end > $0.start }.sorted { $0.start < $1.start }
            var clusters: [[SleepPiece]] = []
            var end: Date?
            for sample in asleep {
                if let previous = end, sample.start.timeIntervalSince(previous) <= 90 * 60 { clusters[clusters.count - 1].append(sample); end = max(previous, sample.end) }
                else { clusters.append([sample]); end = sample.end }
            }
            for cluster in clusters {
                guard let start = cluster.map({ $0.start }).min(), let end = cluster.map({ $0.end }).max() else { continue }
                let details = samples.filter { [1, 2, 3, 4, 5].contains($0.stage) && $0.end > start && $0.start < end }
                var spans: [SleepSpan] = []
                for (stage, group) in Dictionary(grouping: details, by: { $0.stage }) {
                    spans += union(group.map { (max(start, $0.start), min(end, $0.end)) }).map { SleepSpan(start: $0.0, end: $0.1, stage: stage) }
                }
                episodes.append(SleepEpisode(start: start, end: end, seconds: duration(cluster.map { ($0.start, $0.end) }), source: source, watch: cluster.contains { $0.watch }, spans: spans.sorted { $0.start < $1.start }))
            }
        }
        // Pick one source and one main episode per end date, preferring Watch data.
        return Dictionary(grouping: episodes, by: { calendar.startOfDay(for: $0.end) }).values.compactMap { group in
            let watch = group.filter { $0.watch }
            return (watch.isEmpty ? group : watch).max { $0.seconds < $1.seconds }
        }.sorted { $0.end < $1.end }
    }
}
