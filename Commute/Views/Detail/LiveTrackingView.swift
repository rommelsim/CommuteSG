import SwiftUI
import MapKit
import CoreLocation

struct LiveTrackingView: View {
    let initialArrival: BusArrival
    let busStopCode: String?

    @State private var currentArrival: BusArrival
    @State private var pulseAnimating = false
    @State private var demoSecondsLeft: Int = 180
    @State private var lastPolled: Date = .distantPast
    @State private var isLive: Bool = false
    @State private var nowTick: Date = Date()
    @State private var routeVM: LiveTrackingViewModel
    @State private var stopCoordinate: CLLocationCoordinate2D?
    @State private var timelineExpanded = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var trackingOnLockScreen = false

    /// How many stops to show in the collapsed timeline before the
    /// "Show all stops" button appears.
    private let collapsedTimelineLimit = 6

    private let oneSecond = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let pollInterval: TimeInterval = 30
    private let lta = LTAService.shared
    private let stopsRepo = BusStopsRepository.shared

    init(arrival: BusArrival, busStopCode: String?) {
        self.initialArrival = arrival
        self.busStopCode = busStopCode
        self._currentArrival = State(initialValue: arrival)
        self._routeVM = State(initialValue: LiveTrackingViewModel(
            serviceNo: arrival.serviceNo,
            busStopCode: busStopCode,
            destinationCode: arrival.destinationCode
        ))

        // Pre-fit the camera so the bus is visible on first render. The stop
        // coord arrives async from BusStopsRepository, at which point an
        // .onChange handler refits to span both. Using a generous default
        // span (~1.7 km) makes it likely the stop is already in view too.
        if let busCoord = arrival.nextArrivalCoordinate {
            self._mapPosition = State(initialValue: .region(
                MKCoordinateRegion(
                    center: busCoord,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            ))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(
                center: {
                    DetailHeaderTitle(
                        title: "Bus \(currentArrival.serviceNo)",
                        meta: currentArrival.destination.isEmpty ? "Live tracking" : currentArrival.destination
                    )
                },
                trailing: {
                    LiveBadge(mode: isLive ? .live : .demo)
                }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    map
                    etaCard
                    liveActivityCard
                    detailsCard
                    timeline
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await poll(force: true)
                await routeVM.refreshETAs()
            }
        }
        .background(Color.appSurface)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onReceive(oneSecond) { tick in
            nowTick = tick
            if !isLive {
                demoSecondsLeft = max(60, demoSecondsLeft - 1)
                if demoSecondsLeft <= 60 { demoSecondsLeft = 180 }
            } else if Date().timeIntervalSince(lastPolled) > pollInterval {
                Task {
                    await poll(force: false)
                    await routeVM.refreshETAs()
                }
            }
        }
        .task {
            await loadStopCoordinate()
            // Defensive refit: even if `.onChange(initial: true)` fired before
            // stopCoordinate landed, this guarantees the camera converges on
            // a sensible region as soon as we have any anchor.
            refitMap()
            await poll(force: false)
            refitMap()
            await routeVM.loadInitial()
        }
        .onAppear { pulseAnimating = true }
    }

    private func loadStopCoordinate() async {
        guard let busStopCode else { return }
        let stops = await stopsRepo.stops
        stopCoordinate = stops.first(where: { $0.id == busStopCode })?.coordinate
    }

    @MainActor
    private func poll(force: Bool) async {
        guard let code = busStopCode else { return }
        guard force || Date().timeIntervalSince(lastPolled) > pollInterval - 1 else { return }
        do {
            let live = try await lta.busArrivals(at: code, force: force)
            if let updated = live.first(where: { $0.serviceNo == currentArrival.serviceNo }) {
                currentArrival = updated
                isLive = true
            }
            lastPolled = Date()
        } catch {
            // Keep last known data; the badge stays on previous state.
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var map: some View {
        Group {
            if currentMapRegion != nil {
                Map(position: $mapPosition) {
                    if let stopCoordinate {
                        Marker("Your stop", systemImage: "mappin.circle.fill", coordinate: stopCoordinate)
                            .tint(Color.appText)
                    }
                    if let busCoord = currentArrival.nextArrivalCoordinate {
                        Annotation("Bus \(currentArrival.serviceNo)", coordinate: busCoord) {
                            ZStack {
                                Circle()
                                    .stroke(Color.appInfo, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                                    .scaleEffect(pulseAnimating ? 2.5 : 1)
                                    .opacity(pulseAnimating ? 0 : 0.6)
                                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: false),
                                               value: pulseAnimating)
                                Circle()
                                    .fill(Color.appInfoBg)
                                    .overlay(Circle().stroke(Color.appInfo, lineWidth: 2))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.appInfo)
                            }
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            } else {
                ZStack {
                    Color.appSurface2
                    Image(systemName: "map.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.appText3)
                }
            }
        }
        .frame(height: 200)
        .overlay(alignment: .top) {
            if currentArrival.nextArrivalCoordinate == nil {
                busLocationUnavailableBanner
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
        // Re-fit the camera whenever stop coord lands or the bus moves so
        // the bus marker never drifts off-screen between polls. `initial:
        // true` makes these fire once on first render too, so even when the
        // values are already populated at init the camera converges on a
        // proper stop+bus fit instead of staying on the seed region.
        .onChange(of: stopCoordinate?.latitude, initial: true) { _, _ in refitMap() }
        .onChange(of: currentArrival.nextArrivalLatitude, initial: true) { _, _ in refitMap() }
        .onChange(of: currentArrival.nextArrivalLongitude, initial: true) { _, _ in refitMap() }
    }

    /// Shown when LTA's BusArrival API doesn't include a GPS fix for this
    /// service (typical: bus hasn't started its run, GPS dropout in a
    /// tunnel, or the operator's tracker is offline). Without this, the
    /// map silently shows only the stop and the user thinks the app is broken.
    private var busLocationUnavailableBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 11, weight: .semibold))
            Text("Live bus position unavailable")
                .font(.appCaptionStrong)
        }
        .foregroundStyle(Color.appWarningStrong)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.appWarningBg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.appWarning.opacity(0.4), lineWidth: 0.5))
        .padding(.top, 10)
    }

    private func refitMap() {
        guard let region = currentMapRegion else { return }
        withAnimation(.smooth(duration: 0.4)) {
            mapPosition = .region(region)
        }
    }

    private var currentMapRegion: MKCoordinateRegion? {
        let busCoord = currentArrival.nextArrivalCoordinate
        switch (stopCoordinate, busCoord) {
        case let (s?, b?):
            let center = CLLocationCoordinate2D(
                latitude: (s.latitude + b.latitude) / 2,
                longitude: (s.longitude + b.longitude) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max(abs(s.latitude - b.latitude) * 1.6, 0.005),
                longitudeDelta: max(abs(s.longitude - b.longitude) * 1.6, 0.005)
            )
            return MKCoordinateRegion(center: center, span: span)
        case let (s?, nil):
            return MKCoordinateRegion(
                center: s,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
        case let (nil, b?):
            return MKCoordinateRegion(
                center: b,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
        default:
            return nil
        }
    }

    // MARK: - ETA card

    private var etaCard: some View {
        let mins = displayMinutes(at: nowTick)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Arriving at your stop in")
                .font(.appCaption)
                .foregroundStyle(Color.appInfo)
                .opacity(0.85)
            HStack(alignment: .lastTextBaseline) {
                Text(mins)
                    .font(.appHero)
                    .tracking(-1)
                    .foregroundStyle(Color.appInfoStrong)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: mins)
                if mins != "Now" {
                    Text("min")
                        .font(.appSubTitle)
                        .foregroundStyle(Color.appInfo)
                }
                Spacer()
                if currentArrival.nextArrivalCrowd != .unknown {
                    Text(currentArrival.nextArrivalCrowd.label)
                        .font(.appCaption)
                        .foregroundStyle(Color.appInfo)
                        .opacity(0.85)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInfoBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: - Live Activity card

    private var liveActivityCard: some View {
        Toggle(isOn: Binding(
            get: { trackingOnLockScreen },
            set: { newValue in
                trackingOnLockScreen = newValue
                if newValue { startLiveActivity() } else { stopLiveActivity() }
            }
        )) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appInfo)
                    .frame(width: 32, height: 32)
                    .background(Color.appInfoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track on Lock Screen")
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appText)
                    Text("Live ETA in the Dynamic Island and notifications.")
                        .font(.appCaption)
                        .foregroundStyle(Color.appText2)
                }
            }
        }
        .tint(Color.appInfo)
        .padding(Spacing.cardInner)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
        .sensoryFeedback(trackingOnLockScreen ? .success : .selection, trigger: trackingOnLockScreen)
        // On view appear, sync the toggle with whatever activity is in flight
        // so backgrounding + reopening doesn't lose state.
        .onAppear {
            trackingOnLockScreen = LiveActivityManager.shared.isActive(
                for: currentArrival.serviceNo,
                stopCode: busStopCode
            )
        }
        // While the toggle is on, push the latest ETA to the activity each
        // poll tick so the Lock Screen / Dynamic Island stays in sync.
        .onChange(of: currentArrival.nextArrivalAt) { _, _ in pushActivityUpdate() }
        .onChange(of: currentArrival.nextArrivalCrowd) { _, _ in pushActivityUpdate() }
    }

    private func startLiveActivity() {
        LiveActivityManager.shared.start(
            serviceNo: currentArrival.serviceNo,
            destination: currentArrival.destination,
            stopName: stopNameForActivity(),
            stopCode: busStopCode ?? "",
            etaMinutes: currentArrival.nextArrivalMinutes,
            isLive: isLive,
            crowdLevel: currentArrival.nextArrivalCrowd.label
        )
        // If the system rejected (permission off, throttled, etc.), reflect
        // that in the toggle so it doesn't appear "on" with nothing happening.
        if LiveActivityManager.shared.current == nil {
            trackingOnLockScreen = false
        }
    }

    private func stopLiveActivity() {
        Task { await LiveActivityManager.shared.endActiveActivity() }
    }

    private func pushActivityUpdate() {
        guard trackingOnLockScreen else { return }
        Task {
            await LiveActivityManager.shared.update(
                etaMinutes: currentArrival.nextArrivalMinutes,
                isLive: isLive,
                crowdLevel: currentArrival.nextArrivalCrowd.label
            )
        }
    }

    private func stopNameForActivity() -> String {
        // Best-effort: we don't carry the stop name through this view, so
        // fall back to the code if needed. The Live Activity UI tolerates
        // either.
        busStopCode ?? "your stop"
    }

    private func displayMinutes(at now: Date) -> String {
        // Spec §3: ≤ 2 min collapses to "Now". Same rule across home / detail
        // / live tracking so the labelling is consistent everywhere.
        if isLive, let arrAt = currentArrival.nextArrivalAt {
            let secs = max(0, Int(arrAt.timeIntervalSince(now)))
            if secs <= 120 { return "Now" }
            return "\(Int(ceil(Double(secs) / 60.0)))"
        }
        if demoSecondsLeft <= 120 { return "Now" }
        return "\(Int(ceil(Double(demoSecondsLeft) / 60.0)))"
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            row(key: "Bus type") {
                Text(currentArrival.nextArrivalType.label).font(.appLabelMedium)
            }
            Divider().background(Color.appBorder)
            row(key: "Operator") {
                Text(operatorLabel).font(.appLabelMedium)
            }
            Divider().background(Color.appBorder)
            row(key: "Crowd") {
                CrowdIndicator(level: currentArrival.nextArrivalCrowd)
            }
        }
        .padding(Spacing.cardInner)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    private var operatorLabel: String {
        switch currentArrival.operatorName {
        case "SBST", "SBS": return "SBS Transit"
        case "SMRT": return "SMRT"
        case "TTS":  return "Tower Transit"
        case "GAS":  return "Go-Ahead"
        case "":     return "—"
        default:     return currentArrival.operatorName
        }
    }

    private func row<Trailing: View>(
        key: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(key)
                .font(.appLabel)
                .foregroundStyle(Color.appText2)
            Spacer()
            trailing()
                .foregroundStyle(Color.appText)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Onward journey")
                    .font(.appCaptionStrong)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Color.appText2)
                Spacer()
                LiveBadge(mode: timelineLiveMode)
            }
            .padding(.bottom, 6)
            .padding(.horizontal, Spacing.screen)

            if let summary = timelineSummary {
                Text(summary)
                    .font(.appCaption)
                    .foregroundStyle(Color.appText3)
                    .padding(.bottom, 10)
                    .padding(.horizontal, Spacing.screen)
            }

            timelineBody
                .padding(.horizontal, Spacing.screen)
        }
    }

    /// "{N} stops · ~{M} min to {terminus name}" — uses live ETA from the
    /// last stop with a known ETA, otherwise the model's ETA window.
    private var timelineSummary: String? {
        guard !routeVM.upcomingStops.isEmpty else { return nil }
        let count = routeVM.upcomingStops.count
        let stopsWord = count == 1 ? "stop" : "stops"
        let terminusName = routeVM.upcomingStops.last?.name ?? "terminus"

        // Use the latest known ETA among visible stops as a rough total.
        let lastWithETA = routeVM.upcomingStops.last { $0.etaMinutes != nil }
        if let lastETA = lastWithETA?.etaMinutes, count > 1 {
            return "\(count) \(stopsWord) · ~\(lastETA) min+ to \(terminusName)"
        }
        return "\(count) \(stopsWord) to \(terminusName)"
    }

    private var timelineLiveMode: LiveBadge.Mode {
        switch routeVM.routesState {
        case .ready: routeVM.upcomingStops.isEmpty ? .demo : .live
        default:     .demo
        }
    }

    @ViewBuilder
    private var timelineBody: some View {
        switch routeVM.routesState {
        case .loading(let rowsLoaded):
            HStack(spacing: 12) {
                ProgressView().controlSize(.small).tint(Color.appInfo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loading route data")
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appText)
                    Text(rowsLoaded == 0 ? "Connecting to LTA…" : "\(rowsLoaded) route stops loaded")
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                }
                Spacer()
            }
            .padding(.vertical, 12)

        case .unavailable, .idle:
            VStack(spacing: 0) {
                let mock = MockDataService.shared.upcomingStops(forService: currentArrival.serviceNo)
                ForEach(Array(mock.enumerated()), id: \.offset) { idx, stop in
                    timelineRow(
                        idx: idx,
                        name: stop.name,
                        etaText: "\(stop.etaMin) min",
                        isFirst: idx == 0,
                        isTerminus: idx == mock.count - 1,
                        isLast: idx == mock.count - 1,
                        hasETA: true
                    )
                }
            }

        case .ready:
            if routeVM.upcomingStops.isEmpty {
                Text("No upcoming stops found for this route.")
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
                    .padding(.vertical, 12)
            } else {
                expandableTimeline
            }
        }
    }

    /// Live-data timeline. Shows the first `collapsedTimelineLimit` stops by
    /// default; "Show all stops" reveals the rest down to the terminus.
    private var expandableTimeline: some View {
        let stops = routeVM.upcomingStops
        let total = stops.count
        let shouldCollapse = !timelineExpanded && total > collapsedTimelineLimit
        let visibleCount = shouldCollapse ? collapsedTimelineLimit : total
        let visible = Array(stops.prefix(visibleCount))
        let hidden = total - visibleCount

        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { idx, stop in
                let absoluteIdx = idx
                timelineRow(
                    idx: absoluteIdx,
                    name: stop.name,
                    etaText: etaLabel(stop),
                    isFirst: absoluteIdx == 0,
                    isTerminus: absoluteIdx == total - 1,
                    isLast: idx == visible.count - 1 && hidden == 0,
                    hasETA: stop.etaMinutes != nil
                )
            }

            if shouldCollapse {
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        timelineExpanded = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .stroke(Color.appBorderStrong, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(width: 9, height: 9)
                        Text("Show all stops")
                            .font(.appLabelMedium)
                            .foregroundStyle(Color.appInfo)
                        Text("(\(hidden) more to terminus)")
                            .font(.appCaption)
                            .foregroundStyle(Color.appText3)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appInfo)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if timelineExpanded && total > collapsedTimelineLimit {
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        timelineExpanded = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appInfo)
                        Text("Show less")
                            .font(.appLabelMedium)
                            .foregroundStyle(Color.appInfo)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 19)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func etaLabel(_ stop: LiveTrackingViewModel.UpcomingStop) -> String {
        // Empty (not "—") for nil — the timeline row hides the ETA chip
        // entirely when there's no signal, which reads cleaner than a dash.
        guard stop.etaMinutes != nil else { return "" }
        return ArrivalStatus.label(minutes: stop.etaMinutes, scheduled: stop.etaScheduled)
    }

    /// One row in the journey timeline, with a hairline connector down the
    /// left to the next row. The terminus is highlighted with a flag glyph
    /// and a "Terminus" tag.
    private func timelineRow(
        idx: Int,
        name: String,
        etaText: String,
        isFirst: Bool,
        isTerminus: Bool,
        isLast: Bool,
        hasETA: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                indicator(isFirst: isFirst, isTerminus: isTerminus)
                if !isLast {
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(.appBody)
                        .foregroundStyle(rowTextColor(isFirst: isFirst, isTerminus: isTerminus))
                        .fontWeight(isTerminus ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if !etaText.isEmpty {
                        Text(etaText)
                            .font(.appCaption)
                            .foregroundStyle(Color.appText2)
                    }
                }
                if isTerminus {
                    Text("Terminus")
                        .font(.appMicroStrong)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(Color.appInfo)
                } else if !hasETA {
                    Text("Stop \(idx + 1)")
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                }
            }
            .padding(.bottom, isLast ? 0 : 10)
        }
    }

    @ViewBuilder
    private func indicator(isFirst: Bool, isTerminus: Bool) -> some View {
        if isTerminus {
            ZStack {
                Circle().fill(Color.appInfo).frame(width: 14, height: 14)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else {
            Circle()
                .fill(isFirst ? Color.appInfo : Color.appBorderStrong)
                .frame(width: isFirst ? 11 : 9, height: isFirst ? 11 : 9)
                .padding(.top, 4)
        }
    }

    private func rowTextColor(isFirst: Bool, isTerminus: Bool) -> Color {
        if isTerminus { return Color.appText }
        if isFirst { return Color.appText }
        return Color.appText2
    }
}
