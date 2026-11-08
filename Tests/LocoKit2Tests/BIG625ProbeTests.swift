//
//  BIG625ProbeTests.swift
//  LocoKit2
//
//  Created by Claude on 2026-11-08
//
//  BIG-625 / BIG-968 probe (hygiene's 2026-11-08 ask; the implementer's 11-07 lean, item 4). A throwaway READING,
//  not a regression test: it stages siso's post-merge Home visit in memory (the BIG-308 probe A shape, with the
//  swallowed drive inside the visit) plus five drift bursts days apart, runs today's `DriftProfile.computeProfile`
//  over it, and beside it an episode-weighted learner written here. Three cells: bursts only (the control: what
//  Home should learn), bursts + drive through today's learner, bursts + drive through the episode variant. It
//  asserts only the staging and prints the table. `computeProfile` is a pure function of samples and place, so
//  nothing touches the database.

import XCTest
import CoreLocation
@testable import LocoKit2

final class BIG625ProbeTests: XCTestCase {

    // MARK: - The staging

    private static let lat = 13.75
    private static let lon = 100.55
    private static var home: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    private static let metresPerDegLat = 111_320.0
    private static var metresPerDegLon: Double { 111_320 * cos(lat * .pi / 180) }

    /// A point `metres` from Home at compass `bearing` (degrees).
    private static func point(metres: Double, bearing: Double) -> CLLocationCoordinate2D {
        let rad = bearing * .pi / 180
        return CLLocationCoordinate2D(latitude: lat + metres * cos(rad) / metresPerDegLat,
                                      longitude: lon + metres * sin(rad) / metresPerDegLon)
    }

    private static func sample(at coordinate: CLLocationCoordinate2D, date: Date, speed: Double, hAcc: Double, moving: Bool) -> LocomotionSample {
        let location = CLLocation(coordinate: coordinate, altitude: 10, horizontalAccuracy: hAcc, verticalAccuracy: 10,
                                  course: moving ? 90 : -1, speed: speed, timestamp: date)
        return LocomotionSample(date: date, movingState: moving ? .moving : .stationary, recordingState: .recording, location: location)
    }

    /// Thirty days of Home: one stationary sample every 10 minutes within 8 m of the centroid (all under the
    /// 30 m excursion threshold, so they only prove the staging is a visit's worth of data).
    private static func homeBackground(from start: Date, days: Int) -> [LocomotionSample] {
        var out: [LocomotionSample] = []
        let count = days * 24 * 6
        for i in 0..<count {
            let angle = Double(i % 12) * 30
            let r = Double(i % 5) * 2   // 0, 2, 4, 6, 8 m
            out.append(sample(at: point(metres: r, bearing: angle), date: start.addingTimeInterval(Double(i) * 600), speed: 0, hAcc: 12, moving: false))
        }
        return out
    }

    /// One drift burst: `count` samples 60 s apart, the position jumped out to `metres` at `bearing`, with a ±15% ripple
    /// so the burst's distances are not all identical. Recorded as stationary with a degraded hAcc, which is what
    /// drift looks like in a stored sample; the learner never reads either field for the statistics measured here.
    private static func driftBurst(day: Int, hour: Int, metres: Double, bearing: Double, count: Int, from start: Date) -> [LocomotionSample] {
        let t0 = start.addingTimeInterval(Double(day) * 86_400 + Double(hour) * 3_600 + 17)
        return (0..<count).map { i in
            let ripple = 1.0 + 0.15 * sin(Double(i) * 1.3)
            return sample(at: point(metres: metres * ripple, bearing: bearing + Double(i % 3) * 2), date: t0.addingTimeInterval(Double(i) * 60), speed: 0, hAcc: 65, moving: false)
        }
    }

    /// The swallowed drive, the BIG-308 probe A shape with a bend so it crosses two compass sectors: out 6 km at
    /// bearing 110° (sector E, 90–135°), then 5 km due north from there (the bearing from Home falls from 110°
    /// through 90° to ~62°, so the leg's second half is sector NE), a 37 s stop at the far corner, and the same
    /// route back. 20 s cadence, road speeds. 83 samples, all now inside Home.
    /// (Run 1 had the first leg due east: on a sphere a due-east point's initial bearing is just UNDER 90° in the
    /// northern hemisphere, so the whole drive fell into NE with the 85° burst. The bearings are off the cardinal
    /// boundaries now, and the staging asserts both sectors are touched.)
    private static func swallowedDrive(day: Int, hour: Int, from start: Date) -> [LocomotionSample] {
        let t0 = start.addingTimeInterval(Double(day) * 86_400 + Double(hour) * 3_600)
        var points: [CLLocationCoordinate2D] = []
        for i in 1...24 { points.append(point(metres: Double(i) * 250, bearing: 110)) }                                                      // out leg, 250 m steps at 110°
        let corner0 = point(metres: 6_000, bearing: 110)
        for i in 1...16 { points.append(CLLocationCoordinate2D(latitude: corner0.latitude + Double(i) * 312.5 / metresPerDegLat, longitude: corner0.longitude)) } // north leg, 312.5 m steps
        let corner = points.last!
        var out: [LocomotionSample] = []
        var t = t0
        for p in points { out.append(sample(at: p, date: t, speed: 13, hAcc: 8, moving: true)); t = t.addingTimeInterval(20) }
        for _ in 0..<3 { out.append(sample(at: corner, date: t, speed: 0, hAcc: 8, moving: false)); t = t.addingTimeInterval(18.5) }         // the 37 s station stop
        t = t.addingTimeInterval(20)
        for p in points.reversed() { out.append(sample(at: p, date: t, speed: 11.5, hAcc: 8, moving: true)); t = t.addingTimeInterval(20) }
        return out
    }

    // MARK: - The episode variant (written here, not in LocoKit2)

    struct Episode { let sector: Int; let distances: [Double]; let start: Date; let end: Date
        var median: Double { Self.percentile(distances, 0.5) }
        var max: Double { distances.max() ?? 0 }
        static func percentile(_ values: [Double], _ p: Double) -> Double {
            guard !values.isEmpty else { return 0 }
            let s = values.sorted()
            let rank = p * Double(s.count - 1)
            let lo = Int(rank.rounded(.down)), hi = Int(rank.rounded(.up))
            return s[lo] + (s[hi] - s[lo]) * (rank - Double(lo))
        }
    }

    struct Excursion { let date: Date; let sector: Int; let distance: Double }

    /// Group excursion samples into episodes: consecutive excursion samples whose time gap is under `gap`.
    /// `perSector` groups within each sector separately (a drive that leaves a sector and comes back is two
    /// episodes there); otherwise episodes are global and an episode counts in every sector it touched.
    static func episodes(_ excursions: [Excursion], gap: TimeInterval, perSector: Bool) -> [Episode] {
        var result: [Episode] = []
        let groups: [[Excursion]] = perSector ? (0..<8).map { s in excursions.filter { $0.sector == s } } : [excursions]
        for group in groups {
            let sorted = group.sorted { $0.date < $1.date }
            var run: [Excursion] = []
            func flush() {
                guard !run.isEmpty else { return }
                if perSector {
                    result.append(Episode(sector: run[0].sector, distances: run.map(\.distance), start: run.first!.date, end: run.last!.date))
                } else {
                    // one episode, counted in every sector it touched, with that sector's own distances
                    for s in Set(run.map(\.sector)) {
                        let d = run.filter { $0.sector == s }.map(\.distance)
                        result.append(Episode(sector: s, distances: d, start: run.first!.date, end: run.last!.date))
                    }
                }
                run = []
            }
            for e in sorted {
                if let last = run.last, e.date.timeIntervalSince(last.date) > gap { flush() }
                run.append(e)
            }
            flush()
        }
        return result
    }

    static func excursions(of samples: [LocomotionSample], place: Place) -> (threshold: Double, excursions: [Excursion]) {
        let centroid = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let threshold = max(place.radius.with1sd, 30.0)   // computeProfile's own rule
        var out: [Excursion] = []
        for s in samples {
            guard let loc = s.location else { continue }
            let d = loc.distance(from: centroid)
            guard d > threshold else { continue }
            let bearing = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude).bearing(to: loc.coordinate)
            out.append(Excursion(date: s.date, sector: Int(bearing / 45.0) % 8, distance: d))
        }
        return (threshold, out)
    }

    // MARK: - The probe

    func testProbe_sisoHome_todayVsEpisodes() throws {
        let start = Date(timeIntervalSince1970: 1_770_000_000)   // 2026-02-02 UTC, any fixed epoch
        var place = Place(coordinate: Self.home, name: "Probe Home")
        // A fresh Place carries the 60 m minimum radius (sd 0), so computeProfile's threshold would be 60 m and the
        // 50 m and 60 m bursts would not be excursions at all. A long-lived Home has a learned radius; stage one
        // whose 1 sd is 30 m, the threshold floor, so every burst counts the way siso's would.
        place.radiusMean = 20
        place.radiusSD = 10

        let background = Self.homeBackground(from: start, days: 30)
        let bursts: [[LocomotionSample]] = [
            Self.driftBurst(day: 3,  hour: 2,  metres: 60,  bearing: 100, count: 5,  from: start),   // E
            Self.driftBurst(day: 8,  hour: 23, metres: 90,  bearing: 62,  count: 12, from: start),   // NE
            Self.driftBurst(day: 14, hour: 4,  metres: 120, bearing: 226, count: 6,  from: start),   // SW
            Self.driftBurst(day: 20, hour: 1,  metres: 50,  bearing: 105, count: 20, from: start),   // E, the long one
            Self.driftBurst(day: 26, hour: 3,  metres: 300, bearing: 271, count: 8,  from: start),   // W
        ]
        let drive = Self.swallowedDrive(day: 29, hour: 7, from: start)

        let control = background + bursts.flatMap { $0 }
        let poisoned = control + drive

        // staging receipts
        XCTAssertEqual(drive.count, 24 + 16 + 3 + 40, "staging: the drive is 83 samples")
        XCTAssertEqual(bursts.flatMap { $0 }.count, 51, "staging: five bursts, 51 samples")
        let controlEx = Self.excursions(of: control, place: place)
        let poisonedEx = Self.excursions(of: poisoned, place: place)
        XCTAssertEqual(controlEx.excursions.count, 51, "staging: every burst sample is an excursion and no background sample is")
        XCTAssertEqual(poisonedEx.excursions.count, 51 + 83, "staging: every drive sample is an excursion")
        let farthest = poisonedEx.excursions.map(\.distance).max() ?? 0
        // 6 km at 110° then 5 km north: (5.64 km E, 2.95 km N) from Home, 6.36 km out (run 2's assertion carried the
        // old due-east L's 7.8 km and failed on arithmetic, not data)
        XCTAssert(farthest > 6_300 && farthest < 6_450, "staging: the corner is ~6.36 km out (got \(Int(farthest)))")
        let driveEx = Self.excursions(of: drive, place: place).excursions
        let driveE = driveEx.filter { $0.sector == 2 }.count, driveNE = driveEx.filter { $0.sector == 1 }.count
        XCTAssert(driveE > 0 && driveNE > 0 && driveE + driveNE == driveEx.count, "staging: the drive must span E and NE only (E \(driveE), NE \(driveNE), total \(driveEx.count))")
        let burstSectors = bursts.map { Self.excursions(of: $0, place: place).excursions.map(\.sector) }
        XCTAssertEqual(burstSectors.map { Set($0) }, [[2], [1], [5], [2], [6]], "staging: bursts land in E, NE, SW, E, W")

        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        var out = "\n===== BIG-625 / BIG-968 probe readout (LocoKit2 \(Self.build)) =====\n"
        out += "Home: 30 days × 144 stationary samples within 8 m; excursion threshold \(Int(poisonedEx.threshold)) m (place radius mean \(Int(place.radiusMean)) sd \(Int(place.radiusSD)))\n"
        out += "bursts: E 60 m ×5 (day 3, 100°), NE 90 m ×12 (day 8, 62°), SW 120 m ×6 (day 14), E 50 m ×20 (day 20, 105°), W 300 m ×8 (day 26); drive day 29: 6 km at 110° then 5 km N (E then NE), 37 s stop, back; 83 samples (E \(driveE), NE \(driveNE))\n"

        for (cell, samples, ex) in [("CONTROL (bursts only)", control, controlEx), ("POISONED (bursts + swallowed drive)", poisoned, poisonedEx)] {
            guard let today = DriftProfile.computeProfile(for: samples, place: place) else { XCTFail("computeProfile returned nil for \(cell)"); continue }
            out += "\n--- \(cell): today's learner (computeProfile) ---\n"
            out += "excursionSampleCount \(today.excursionSampleCount)  maxObservedDrift \(Int(today.maxObservedDrift)) m  meanDriftDistance \(Int(today.meanDriftDistance)) m\n"
            out += "sector   n   mean(today)  median   p90    max   conf(today)\n"
            for s in 0..<8 {
                let d = ex.excursions.filter { $0.sector == s }.map(\.distance)
                guard !d.isEmpty else { continue }
                out += String(format: "%-6@ %4d  %8d  %8d  %6d %6d   %.2f\n", names[s] as NSString, today.directionCounts[s], Int(today.directionMagnitudes[s]),
                              Int(Episode.percentile(d, 0.5)), Int(Episode.percentile(d, 0.9)), Int(d.max()!), min(1.0, Double(today.directionCounts[s]) / 5.0))
                XCTAssertEqual(today.directionCounts[s], d.count, "my sector assignment must match the learner's")
            }
            for gap: TimeInterval in [120, 300, 900] {
                for perSector in [true, false] {
                    let eps = Self.episodes(ex.excursions, gap: gap, perSector: perSector)
                    let globalMaxima = Self.episodes(ex.excursions, gap: gap, perSector: false)
                    // one max per GLOBAL episode: the per-sector splits of a global episode share a start, so take the
                    // largest max among them (run 3 took whichever split Set order yielded first: 3,170 m vs 3,349 m)
                    let maxima = Array(Dictionary(grouping: globalMaxima, by: \.start).values.map { $0.map(\.max).max()! })
                    out += "--- \(cell): episode variant, gap \(Int(gap)) s, \(perSector ? "episodes per sector" : "global episodes counted in each sector touched") ---\n"
                    out += "episodes (all) \(maxima.count)  window p90 of episode maxima \(Int(Episode.percentile(maxima, 0.9))) m, median of episode maxima \(Int(Episode.percentile(maxima, 0.5))) m (today: max \(Int(today.maxObservedDrift)) m)\n"
                    out += "sector  eps  median(ep medians)  p25(ep medians)  conf(eps/5)\n"
                    for s in 0..<8 {
                        let se = eps.filter { $0.sector == s }
                        guard !se.isEmpty else { continue }
                        let meds = se.map(\.median)
                        out += String(format: "%-6@ %4d  %12d  %14d   %.2f\n", names[s] as NSString, se.count, Int(Episode.percentile(meds, 0.5)), Int(Episode.percentile(meds, 0.25)), min(1.0, Double(se.count) / 5.0))
                    }
                }
            }
        }
        print(out)
    }

    static var build: String {
        (try? String(contentsOfFile: "/tmp/308-build.txt", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown build"
    }
}
