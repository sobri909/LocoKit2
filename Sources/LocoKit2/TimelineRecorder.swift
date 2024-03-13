//
//  TimelineRecorder.swift
//
//
//  Created by Matt Greenfield on 11/3/24.
//

import Foundation
import Combine
import GRDB

@Observable
public final class TimelineRecorder {

    public static let highlander = TimelineRecorder()

    public var sampleFrequency: TimeInterval = 6

    // MARK: -

    public func startRecording() {
        LocomotionManager.highlander.startRecording()
    }

    public func stopRecording() {
        LocomotionManager.highlander.stopRecording()
    }

    public var isRecording: Bool {
        return LocomotionManager.highlander.recordingState != .off
    }

    public private(set) var mostRecentSample: LocomotionSampleBase?

    // MARK: -

    private var loco = LocomotionManager.highlander

    @ObservationIgnored
    private var observers: Set<AnyCancellable> = []

    private init() {
        withContinousObservation(of: LocomotionManager.highlander.filteredLocations) { _ in
            Task { await self.recordSample() }
        }
    }

    func nothing() async {
        do {
            let samples = try await Database.pool.read {
                let request = LocomotionSampleBase
                    .including(optional: LocomotionSampleBase.location)
                    .including(optional: LocomotionSampleBase.extended)
                return try LocomotionSample.fetchAll($0, request)
            }

            print("samples: \(samples.count)")

            if let last = samples.last {
                print("latest.movingSate: \(last.base.movingState.stringValue)")
                print("latest.coordinate: \(last.location?.coordinate)")
            }

        } catch {
            print("\(error)")
        }
    }

    // MARK: -

    private func recordSample() async {
        guard isRecording else { return }

        // don't record too soon
        if let lastRecorded = mostRecentSample?.date, lastRecorded.age < sampleFrequency { return }

        guard let location = loco.filteredLocations.last else { return }
        guard let movingState = loco.currentMovingState else { return }

        let sampleBase = LocomotionSampleBase(date: location.timestamp, movingState: movingState.movingState, recordingState: loco.recordingState)
        let sampleLocation = SampleLocation(from: location, sampleId: sampleBase.id)

        do {
            try await Database.pool.write {
                try sampleBase.save($0)
                try sampleLocation.save($0)
            }
            
        } catch {
            DebugLogger.logger.error(error, subsystem: .database)
        }

        await nothing()
    }

}
