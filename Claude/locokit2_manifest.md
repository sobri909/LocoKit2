# LocoKit2 Library Manifest

Project root: `/Users/matt/Projects/LocoKit2/Sources/LocoKit2/`

## How to Use This Manifest

This manifest is the definitive source for file locations in the LocoKit2 library. When you need to find a file:

1. **Check the Directory Structure sections below** - they provide complete path information for all project files
2. **Use the exact paths listed** - they are guaranteed to be correct and up-to-date
3. **Only use search tools** if you cannot find a file's location in this manifest

The directory structure is organized by system and responsibility:
- Each major section (Timeline, Places, etc) lists all related files
- File descriptions explain each file's purpose
- Indentation shows directory hierarchy
- All paths are relative to the project root listed above

## Directory Structure

Root Files:
- TimelineActor.swift: Global actor for safe timeline modification
- PlacesActor.swift: Global actor for place operations and scoring
- ActivityTypesActor.swift: Global actor for ML model access
- AppGroup.swift: App group data coordination
- CustomSerialExecutor.swift: Custom actor executor
- PathSimplifier.swift: Trip path optimization
- Debouncer.swift: Event debouncing
- DebugLogger.swift: Structured logging setup

/Database:
- Database.swift: GRDB setup and configuration
- Database+Schema.swift: Schema definition
- Database+EdgeTriggers.swift: SQL triggers for bi-directional edge maintenance
- Database+SampleTriggers.swift: Sample relationship triggers
- Database+LastSavedTriggers.swift: Timestamp maintenance
- Database+DelayedMigrations.swift: Database migration support

/Models:
- TimelineItem.swift: Visit/Trip container with validation rules
- TimelineItem+Processing.swift: Sample processing and state updates
- TimelineItem+Pruning.swift: Sample pruning implementation
- TimelineItem+Strings.swift: String formatting helpers
- TimelineItem+ActivityType.swift: Activity type handling
- TimelineItemBase.swift: Core GRDB model with edge relationships
- TimelineItemVisit.swift: Visit model with radius and place handling
- TimelineItemTrip.swift: Trip model with activity type and stats
- TimelineSegment.swift: Observable timeline data window
- TimelineLinkedList.swift: Concurrent observable item list with auto-loading
- TimelineObserver.swift: Database observation and timeline updates
- Place.swift: GRDB model with identifier and provider support
- Place+Stats.swift: Visit pattern analysis and histograms
- Place+Comparisons.swift: Radius-based overlap and distance tests
- Histogram.swift: Visit pattern analysis
- LocomotionSample.swift: Core location and motion sample
- LocomotionSample+Array.swift: Sample array extensions
- ItemSegment.swift: Temporal/spatial clusters
- MovingState.swift: Stationary/moving enum with speed stats
- RecordingState.swift: Recording/sleep/standby state transitions
- Radius.swift: Location radius handling
- LegacyItem.swift: Legacy timeline item support
- LegacySample.swift: Legacy sample support
- PlaceRTree.swift: Place spatial index
- SampleRTree.swift: Sample spatial index
- TimelineError.swift: Timeline error types

/Managers:
- TimelineProcessor.swift: Core item merge and processing coordinator
- TimelineProcessor+Edges.swift: Edge stealing and healing operations
- TimelineProcessor+Merges.swift: Potential merge collection and scoring
- TimelineProcessor+Extraction.swift: Safe visit/trip extraction
- TimelineProcessor+Delete.swift: Item deletion with edge cleanup
- LocomotionManager.swift: State machine with filtered location handling
- TimelineRecorder.swift: Sample recording with moving/sleep state transitions
- Merge.swift: Individual merge operation
- MergeScores.swift: Merge confidence scoring

/Samplers:
- KalmanFilter.swift: 4-state Kalman filter for location smoothing
- AltitudeKalmanFilter.swift: Single-state altitude smoothing
- StationaryStateDetector.swift: Moving/stationary state from weighted speed stats
- AccelerometerSampler.swift: 4Hz device motion with XY/Z stats
- SleepModeDetector.swift: Geofence-based power management
- StepsMonitor.swift: CMPedometer wrapper with cadence

/ActivityTypes:
- ActivityType.swift: Core activity type enumeration with categories and metadata
- ActivityTypesModel.swift: Regional ML model management and disk storage
- ActivityClassifier.swift: CoreML model coordination and classification
- ClassifierResultItem.swift: Single activity type classification result
- ClassifierResults.swift: Full classification result set
- CoreMLFeatureProvider.swift: ML model feature preparation
- CoreMLModelUpdater.swift: ML model version and update management

/Persistence:
- ExportManager.swift: Timeline data export
- ImportManager.swift: Timeline data import
- ExportMetadata.swift: Export file metadata
- PersistenceActor.swift: Import/export coordination

/Extensions:
- Calendar+LocoKit.swift: Date handling
- CoreLocation+LocoKit.swift: Location utilities
- Foundation+LocoKit.swift: Foundation extensions
