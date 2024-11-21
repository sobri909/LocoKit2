//
//  RamerDouglasPeucker.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 31/10/2024.
//

import Foundation
import CoreLocation

enum RamerDouglasPeucker {
    private struct PathPoint {
        let coordinate: CLLocationCoordinate2D
        let date: Date
        let index: Int
    }

    static func simplify(coordinates: [(coordinate: CLLocationCoordinate2D, date: Date, index: Int)],
                         maxInterval: TimeInterval, epsilon: Double) -> Set<Int> {
        let points = coordinates.map { PathPoint(coordinate: $0.coordinate, date: $0.date, index: $0.index) }
        guard points.count > 2 else { return Set(points.map(\.index)) }

        var keepIndices = Set<Int>()

        func douglasPeucker(_ start: Int, _ end: Int) {
            keepIndices.insert(points[start].index)
            keepIndices.insert(points[end].index)

            guard end > start + 1 else { return }

            var maxDistance = 0.0
            var maxIndex = start
            let line = (points[start].coordinate, points[end].coordinate)

            for i in (start + 1)..<end {
                let distance = points[i].coordinate.perpendicularDistance(to: line)
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = i
                }
            }

            if maxDistance > epsilon {
                douglasPeucker(start, maxIndex)
                douglasPeucker(maxIndex, end)
            } else {
                var current = points[start].date
                for i in (start + 1)..<end {
                    let pointDate = points[i].date
                    if pointDate.timeIntervalSince(current) > maxInterval {
                        keepIndices.insert(points[i].index)
                        current = pointDate
                    }
                }
            }
        }

        douglasPeucker(0, points.count - 1)
        return keepIndices
    }

}
