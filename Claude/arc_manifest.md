# Arc Timeline Editor Manifest

Project root: `/Users/matt/Projects/Arc Timeline Editor/Arc Timeline Editor/`

## How to Use This Manifest

This manifest is the definitive source for file locations in the Arc Editor project. When you need to find a file:

1. **Check the Directory Structure sections below** - they provide complete path information for all project files
2. **Use the exact paths listed** - they are guaranteed to be correct and up-to-date
3. **Only use search tools** if you cannot find a file's location in this manifest

The directory structure is organized by system and responsibility:
- Each major section (Timeline, Places, etc) lists all related files
- File descriptions explain each file's purpose
- Indentation shows directory hierarchy
- All paths are relative to the project root listed above

## Directory Structure

Root:
- PhotosActor.swift: Global actor for Photos framework isolation
- CalendarActor.swift: Global actor for EventKit isolation
- Debouncer.swift: Event debouncing
- ArcTimelineEditorApp.swift: App entry point

/Managers:
- PhotosCache.swift: Photo loading and caching
- CalendarManager.swift: Calendar sync implementation
- ArcMigrations.swift: App-specific database migrations

/Views:
- NavDestination.swift: Value-based navigation coordination
- TabBar.swift: Tab bar with bottom sheet handling
- Onboarding.swift: First launch and permissions flow
- ArcHairline.swift: Standard separator with dynamic color
- CustomSearchBar.swift: Map search with shadow UI fix
- ArcSectionBuffer.swift: Spacing for list sections

/Timeline:
- Base/
  - TimelineRootView.swift: Sheet/map coordinator with nav handling
  - TimelineTab.swift: Timeline tab structure and lifecycle
  - TimelineSheet.swift: Sheet state and gesture handling
  - TimelineMap.swift: Map visualization and viewport management
  - TimelinePager.swift: Date-based timeline navigation
  - DateRangeHeader.swift: Date range selection and navigation
- List/
  - TimelineDayList.swift: Main timeline list coordinator
  - TripListView.swift: Trip row presentation
  - VisitListView.swift: Visit row presentation
  - VisitListTimesView.swift: Time display for visits
  - TimelineDisplayInfo.swift: Pre-computed display metadata
  - ItemLayoutInfo.swift: View geometry info for timeline rows
  - PathLineView.swift: Path visualization for trips
  - ItemPhotosRow.swift: Photo grid layout in timeline
  - ConfirmationDot.swift: Uncertainty state indicator
  - ConfirmBanner.swift: Timeline cleanup banner
  - ListItemPreview.swift: Context menu preview
  - ThinkingItemView.swift: Processing state row
  - TimelinePageViewModel.swift: Timeline page state management, photo loading
- Confirm/
  - ConfirmListView.swift: Item confirmation view
  - ConfirmListRow.swift: Individual item confirmation row
  - ConfirmListViewModel.swift: Confirmation state management
- TimelineViewModel.swift: Global timeline state
- MapViewModel.swift: Map state and interaction

/Place:
- PlaceDetailsView.swift: Place details view
- PlaceOccupancyChart.swift: Place occupancy time visualization

/TimelineItem:
- ItemDetailsView.swift: Timeline item details
- ItemHeaderView.swift: Common header component
- ItemSegmentsView.swift: Segment visualization
- NextPrevRow.swift: Item navigation
- SegmentTypeView.swift: Activity type selection
- SegmentPlaceView.swift: Place assignment

/TimelineItem/Photos:
- ItemPhotosLoader.swift: Photo loading and management
- PhotoViewer.swift: Full screen photo viewer
- ItemGalleryView.swift: Photo grid display
- PhotoThumbnail.swift: Individual thumbnails
- FullResolutionImage.swift: High-res photo display

/TimelineItem/Extract Visits:
- ExtractVisitsView.swift: Visit extraction interface
- ExtractVisitsViewModel.swift: Visit extraction state

/TimelineItem/Place Change:
- PlaceChangeViewModel.swift: Place selection state
- PlaceSearchSession.swift: Search state management
- PlaceResultRow.swift: Individual place result
- PlaceResultsList.swift: Ranked place results

/TimelineItem/Segment Split:
- SegmentSplitView.swift: Segment split interface
- SegmentSplitTypeView.swift: Split type selection

/TimelineItem/Item Edit:
- ItemEditView.swift: Item editing interface
- ActivityTypeResultRow.swift: Activity type result
- ActivityTypeResultsList.swift: Activity type selection

/TimelineItem/Histogram:
- HistogramChartView.swift: Pattern visualization
- HistogramChartViewModel.swift: Chart state
- HistogramDetailView.swift: Pattern analysis

/Views/Settings:
- DebugView.swift: Main debugging interface
- DebugLogView.swift: Log file viewer
- DebugLogsView.swift: Log file selection
- DebugNavHeader.swift: Debug view nav header
- DebugInfoBox.swift: Debug info display

/Modifiers:
- RowTapHighlightModifier.swift: Row tap feedback effect

UI Components:
- TabBar.swift: Tab bar
- ArcHairline.swift: Separator

/Models:
- DeviceSize.swift: Screen size classification and layout helpers
- Session.swift: App lifecycle and recording state
- Settings.swift: User settings access and defaults
- StoredSettings.swift: Database-backed settings
- CalendarEvent.swift: Database model for calendar sync tracking
- ConfirmationState.swift: Item confirmation state tracking
- DateInterval+FetchableRecord.swift: Database serialization helpers
- ItemSegment+Arc.swift: App-layer segment extensions
- ItemSegment+MapItem.swift: Map visualization helpers
- MapItem.swift: Map visualization model

/Models/Places:
- GooglePlaces.swift: Google Places API integration and result handling
- Mapbox.swift: Mapbox search API integration and query construction
- Place+Arc.swift: Place provider initialization and scoring
- PlaceResultItem.swift: Single weighted place match result
- PlaceResults.swift: Ordered collection of place matches
- PlaceScore.swift: Multi-factor place scoring system
- Places.swift: Global place search and management
- RemotePlaceRankings.swift: Provider-specific result ranking

/Extensions:
- Calendar+Arc.swift: Date formatting and calculations
- CoreLocation+Arc.swift: Location helpers and formatting
- Foundation+Arc.swift: Foundation class extensions
- SwiftUI+Arc.swift: SwiftUI view and modifier helpers
- UINavigationController+Arc.swift: Back gesture handling

/Meta:
- Dev Logs/: Development logs
- Knowledge/: Domain documentation
- arc_manifest.md: This file
- locokit2_manifest.md: LocoKit2 library structure
- filesystem.md: File access patterns
- calendar_sync_implementation.md: Calendar sync design and implementation details
- private_beta_release_notes.md: Beta build release notes
- private_beta_release_notes_guide.md: Standards for beta release notes
