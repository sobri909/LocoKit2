//
//  Database+Schema.swift
//  LocoKit2
//
//  Created by Matt Greenfield on 12/1/25.
//

import GRDB

extension Database {
    func addInitialSchema(to migrator: inout DatabaseMigrator) {
        migrator.registerMigration("Initial") { db in

            // MARK: - Place

            try db.create(table: "Place") { table in
                table.primaryKey("id", .text)
                table.column("lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")

                table.column("rtreeId", .integer).indexed()
                table.column("isStale", .boolean).notNull()
                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()
                table.column("radiusMean", .double).notNull()
                table.column("radiusSD", .double).notNull()
                table.column("secondsFromGMT", .integer)
                table.column("name", .text).notNull().indexed()
                    .check { length($0) > 0 }
                table.column("streetAddress", .text)
                table.column("countryCode", .text).indexed()
                table.column("locality", .text).indexed()

                table.column("mapboxPlaceId", .text).indexed()
                table.column("mapboxCategory", .text)
                table.column("mapboxMakiIcon", .text)

                table.column("googlePlaceId", .text).indexed()
                table.column("googlePrimaryType", .text)

                table.column("foursquarePlaceId", .text).indexed()
                table.column("foursquareCategoryId", .integer)

                table.column("visitCount", .integer).notNull().indexed()
                table.column("visitDays", .integer).notNull()

                table.column("arrivalTimes", .blob)
                table.column("leavingTimes", .blob)
                table.column("visitDurations", .blob)
                table.column("occupancyTimes", .blob)
            }

            try db.create(
                virtualTable: "PlaceRTree",
                using: "rtree(id, latMin, latMax, lonMin, lonMax)"
            )

            // MARK: - TimelineItem

            try db.create(table: "TimelineItemBase") { table in
                table.primaryKey("id", .text)
                table.column("lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")

                table.column("isVisit", .boolean).notNull()
                table.column("startDate", .datetime).indexed()
                table.column("endDate", .datetime).indexed()
                table.column("source", .text).notNull()
                table.column("sourceVersion", .text).notNull()
                table.column("disabled", .boolean).notNull()
                table.column("deleted", .boolean).notNull()
                table.column("samplesChanged", .boolean).notNull()

                table.column("previousItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)
                    .check { $0 != Column("id") }

                table.column("nextItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .setNull, deferred: true)
                    .check { $0 != Column("id") }

                table.column("stepCount", .integer)
                table.column("floorsAscended", .integer)
                table.column("floorsDescended", .integer)
                table.column("averageAltitude", .double)
                table.column("activeEnergyBurned", .double)
                table.column("averageHeartRate", .double)
                table.column("maxHeartRate", .double)
            }

            try db.create(
                index: "TimelineItemBase_on_deleted_startDate",
                on: "TimelineItemBase",
                columns: ["deleted", "startDate"]
            )

            try db.create(table: "TimelineItemVisit") { table in
                table.primaryKey("itemId", .text)
                    .references("TimelineItemBase", onDelete: .cascade, deferred: true)
                table.column("lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")

                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()
                table.column("radiusMean", .double).notNull()
                table.column("radiusSD", .double).notNull()

                table.column("placeId", .text).indexed()
                    .references("Place", onDelete: .restrict, deferred: true)

                table.column("confirmedPlace", .boolean).notNull()
                    .check { $0 == false || Column("placeId") != nil }
                table.column("uncertainPlace", .boolean).notNull().defaults(to: true)
                    .check { ($0 == true && Column("confirmedPlace") == false) || ($0 == false && Column("placeId") != nil) }

                table.column("customTitle", .text).indexed()
                    .check { $0 == nil || length($0) > 0 }
                table.column("streetAddress", .text).indexed()
            }

            try db.create(table: "TimelineItemTrip") { table in
                table.primaryKey("itemId", .text)
                    .references("TimelineItemBase", onDelete: .cascade, deferred: true)
                table.column("lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")

                table.column("distance", .double).notNull()
                table.column("speed", .double).notNull()
                table.column("classifiedActivityType", .integer)
                table.column("confirmedActivityType", .integer)
                table.column("uncertainActivityType", .boolean).notNull().defaults(to: true)
                    .check { $0 == true || Column("classifiedActivityType") != nil || Column("confirmedActivityType") != nil }
                    .check { $0 == false || Column("confirmedActivityType") == nil }
            }

            // MARK: - LocomotionSample

            try db.create(table: "LocomotionSample") { table in
                table.primaryKey("id", .text)
                table.column("lastSaved", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")

                // NOTE: indexing this column in old LocoKit made the query planner do dumb things
                // make sure there's a composite index that includes it instead
                // and make sure rtreeId IS NOT the first column in the composite index
                // otherwise again the query planner did dumb things
                table.column("rtreeId", .integer)

                table.column("date", .datetime).notNull().indexed()
                table.column("source", .text).notNull()
                table.column("sourceVersion", .text).notNull()
                table.column("secondsFromGMT", .integer).notNull()
                table.column("movingState", .integer).notNull()
                table.column("recordingState", .integer).notNull()
                table.column("disabled", .boolean).notNull()

                table.column("timelineItemId", .text).indexed()
                    .references("TimelineItemBase", onDelete: .restrict, deferred: true)

                // CLLocation
                table.column("latitude", .double)
                table.column("longitude", .double)
                table.column("altitude", .double)
                table.column("horizontalAccuracy", .double)
                table.column("verticalAccuracy", .double)
                table.column("speed", .double)
                table.column("course", .double)

                // motion sensor data
                table.column("stepHz", .double)
                table.column("xyAcceleration", .double)
                table.column("zAcceleration", .double)

                table.column("heartRate", .double)

                table.column("classifiedActivityType", .integer)
                table.column("confirmedActivityType", .integer)
            }

            try db.create(
                virtualTable: "SampleRTree",
                using: "rtree(id, latMin, latMax, lonMin, lonMax)"
            )

            try db.create(
                index: "LocomotionSample_on_date_rtreeId_confirmedActivityType_xyAcceleration_zAcceleration_stepHz",
                on: "LocomotionSample",
                columns: ["date", "rtreeId", "confirmedActivityType", "xyAcceleration", "zAcceleration", "stepHz"]
            )

            // MARK: - ActivityTypesModel

            try db.create(table: "ActivityTypesModel") { table in
                table.column("geoKey", .text).primaryKey()
                table.column("lastUpdated", .datetime).indexed()
                table.column("filename", .text).notNull()

                table.column("depth", .integer).notNull().indexed()
                table.column("needsUpdate", .boolean).indexed()
                table.column("totalSamples", .integer).notNull()
                table.column("accuracyScore", .double)

                table.column("latitudeMax", .double).notNull().indexed()
                table.column("latitudeMin", .double).notNull().indexed()
                table.column("longitudeMax", .double).notNull().indexed()
                table.column("longitudeMin", .double).notNull().indexed()
            }

            // MARK: - TaskStatus

            try db.create(table: "TaskStatus") { table in
                table.primaryKey("identifier", .text)
                table.column("state", .text).notNull()
                table.column("minimumDelay", .double).notNull()
                table.column("lastUpdated", .datetime).notNull()
                table.column("lastStarted", .datetime)
                table.column("lastExpired", .datetime)
                table.column("lastCompleted", .datetime)
            }
        }
    }
}
