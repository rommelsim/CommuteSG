import SwiftUI
import CoreLocation

struct LiveTrackingView: View {
    let initialArrival: BusArrival
    let busStopCode: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var currentArrival: BusArrival
    @State private var demoSecondsLeft: Int = 180
    @State private var lastPolled: Date = .distantPast
    @State private var isLive: Bool = false
    @State private var nowTick: Date = Date()
    @State private var routeVM: LiveTrackingViewModel
    @State private var stopName: String?
    @State private var trackingOnLockScreen = false

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
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                topBar
                heroCard
                routeTimelineCard
                onThisBusCard
                liveActivityCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.cfPageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .refreshable {
            await poll(force: true)
            await routeVM.refreshETAs()
        }
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
            await loadStopName()
            await poll(force: false)
            await routeVM.loadInitial()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            iconCircleButton(symbol: "chevron.left") { dismiss() }
            Spacer()
            Text("Bus details")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.cfTextSecondary)
            Spacer()
            iconCircleButton(
                symbol: isFavorite ? "star.fill" : "star",
                foreground: isFavorite ? Color.cfTextPrimary : Color.cfTextTertiary
            ) {
                appState.toggleFavoriteLine(currentArrival.serviceNo)
            }
        }
    }

    private var isFavorite: Bool { appState.favoriteLineCodes.contains(currentArrival.serviceNo) }

    private func iconCircleButton(symbol: String, foreground: Color = .cfTextPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(Color.cfGlassFillStrong, in: Circle())
                .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero (dark)

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x0F1729), Color(hex: 0x1E293B)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 96, height: 96)
                .offset(x: 130, y: -64)
            Circle()
                .fill(Color.white.opacity(0.03))
                .frame(width: 80, height: 80)
                .offset(x: -110, y: 80)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    LiveDot(color: Color(red: 0.46, green: 0.86, blue: 0.50), size: 6)
                    Text(arrivingLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.cfOnDarkMuted)
                }
                .padding(.bottom, 12)

                HStack(spacing: 12) {
                    ServiceChip(service: currentArrival.serviceNo, size: .lg, onDark: true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TO")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.cfOnDarkLabel)
                        Text(destinationName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.cfOnDarkPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.10))

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARRIVES IN")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.cfOnDarkLabel)
                        bigEta
                        if currentArrival.nextArrivalIsScheduled {
                            Text("± 3 min · scheduled estimate")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.cfOnDarkLabel)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    if let f = currentArrival.followingArrivalMinutes {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("THEN")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(Color.cfOnDarkLabel)
                            Text("\(f) min")
                                .font(.system(size: 18, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.cfOnDarkPrimary)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: 0x0F1729).opacity(0.40), radius: 14, y: 12)
    }

    private var arrivingLabel: String {
        let mins = displayMinutes()
        return mins == "Now" ? "Arriving now" : "Arriving"
    }

    private var destinationName: String {
        let resolved = StopsAdapters.destinationLabel(for: currentArrival)
        if !resolved.isEmpty { return resolved }
        return currentArrival.destinationCode ?? currentArrival.destination
    }

    @ViewBuilder
    private var bigEta: some View {
        let mins = displayMinutes()
        if mins == "Now" {
            NowTag()
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(mins)
                    .font(.system(size: 44, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.cfOnDarkPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: mins)
                Text("min")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cfOnDarkMuted)
            }
        }
    }

    private func displayMinutes() -> String {
        if isLive, let arrAt = currentArrival.nextArrivalAt {
            let secs = max(0, Int(arrAt.timeIntervalSince(nowTick)))
            if secs <= 120 { return "Now" }
            return "\(Int(ceil(Double(secs) / 60.0)))"
        }
        if demoSecondsLeft <= 120 { return "Now" }
        return "\(Int(ceil(Double(demoSecondsLeft) / 60.0)))"
    }

    // MARK: - Route timeline

    private var routeTimelineCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BUS ROUTE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.cfTextTertiary)
                Spacer()
                Text(timelineSummary)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cfTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color.cfHairline)

            timelineBody
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 18)
    }

    private var timelineSummary: String {
        let n = routeVM.upcomingStops.count + 1  // include user's stop
        let word = n == 1 ? "stop" : "stops"
        return "\(n) \(word) to terminus"
    }

    @ViewBuilder
    private var timelineBody: some View {
        switch routeVM.routesState {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading route…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cfTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        case .unavailable, .idle:
            Text("Route data unavailable")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cfTextTertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        case .ready:
            timelineRows
        }
    }

    private var timelineRows: some View {
        let upcoming = routeVM.upcomingStops
        let total = upcoming.count + 1  // + user's stop
        return VStack(spacing: 0) {
            // User's boarding stop at the top
            timelineRow(
                name: stopName ?? (busStopCode.map { "Stop \($0)" } ?? "Your stop"),
                eta: displayMinutes() == "Now" ? "Now" : "\(displayMinutes()) min",
                marker: .userBoarding,
                isFirst: true,
                isLast: total == 1
            )
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { idx, stop in
                let isTerminus = idx == upcoming.count - 1
                timelineRow(
                    name: stop.name,
                    eta: stop.etaMinutes.map { "\($0) min" } ?? "",
                    marker: isTerminus ? .terminus : .future,
                    isFirst: false,
                    isLast: idx == upcoming.count - 1
                )
            }
        }
    }

    private enum Marker { case past, current, future, userBoarding, terminus }

    private func timelineRow(name: String, eta: String, marker: Marker, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left rail: connector + marker
            ZStack(alignment: .top) {
                if !isFirst {
                    Rectangle()
                        .fill(railColor(below: marker))
                        .frame(width: 2)
                        .frame(maxHeight: 18)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                if !isLast {
                    Rectangle()
                        .fill(railColor(above: marker))
                        .frame(width: 2)
                        .padding(.top, 28)
                }
                markerView(marker)
                    .padding(.top, 10)
            }
            .frame(width: 16, alignment: .center)
            .frame(maxHeight: .infinity)

            // Right content
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(
                            size: marker == .userBoarding ? 14 : 13,
                            weight: marker == .userBoarding || marker == .terminus ? .bold : .medium
                        ))
                        .foregroundStyle(textColor(marker))
                        .lineLimit(1)
                    if marker == .userBoarding {
                        Text("Your boarding stop")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.cfTextSecondary)
                    } else if marker == .terminus {
                        Text("Terminus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.cfTextTertiary)
                    }
                }
                Spacer(minLength: 8)
                if !eta.isEmpty {
                    Text(eta)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(textColor(marker))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, marker == .userBoarding ? 8 : 0)
            .padding(.leading, marker == .userBoarding ? -1 : 0)
            .background {
                if marker == .userBoarding {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.cfNowFill.opacity(0.05))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func markerView(_ m: Marker) -> some View {
        switch m {
        case .userBoarding:
            ZStack {
                // Inner circle uses page-background so it flips: near-white
                // in light, near-black in dark — keeps contrast against the
                // ring (cfNowFill, which also flips) regardless of mode.
                Circle().fill(Color.cfPageBackground).frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.cfNowFill, lineWidth: 2))
                BusStopIcon(size: 10, color: Color.cfNowFill, strokeWidth: 2.5)
            }
        case .terminus:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.cfNowFill)
                .frame(width: 12, height: 12)
        case .future:
            Circle().fill(Color.cfTextDisabled).frame(width: 8, height: 8)
                .padding(.top, 6)
        case .past:
            Circle().fill(Color.cfTextTertiary).frame(width: 8, height: 8)
                .padding(.top, 6)
        case .current:
            ZStack {
                Circle().fill(Color.cfTextMuted).frame(width: 24, height: 24)
                Circle().fill(Color.cfNowFill).frame(width: 18, height: 18)
                // Bus icon uses cfNowText (the inverse of cfNowFill) so it
                // always reads against the marker: white-on-dark in light,
                // dark-on-light in dark.
                Image(systemName: "bus.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cfNowText)
            }
        }
    }

    private func textColor(_ m: Marker) -> Color {
        switch m {
        case .past: Color.cfTextTertiary
        default: Color.cfTextPrimary
        }
    }

    private func railColor(above m: Marker) -> Color {
        switch m { case .past, .current: Color.cfTextTertiary; default: Color.cfTextDisabled }
    }
    private func railColor(below m: Marker) -> Color {
        // Connector entering this marker mirrors what's above the prior one;
        // for v1 (no past stops surfaced) every connector is "future" tone.
        Color.cfTextDisabled
    }

    // MARK: - On this bus

    private var onThisBusCard: some View {
        VStack(spacing: 0) {
            sectionHeader("ON THIS BUS")
            Divider().background(Color.cfHairline)
            row(label: "Crowd level") {
                HStack(spacing: 6) {
                    CrowdPeople(level: crowdLevel, size: 12)
                    Text(crowdText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                }
            }
            Divider().background(Color.cfHairline)
            row(label: "Reliability") {
                Text(currentArrival.nextArrivalIsScheduled ? "Volatile · ± 3 min" : "On time")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
            }
            Divider().background(Color.cfHairline)
            row(label: "Bus type") {
                Text(currentArrival.nextArrivalType.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
            }
            Divider().background(Color.cfHairline)
            row(label: "Operator") {
                Text(operatorLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
            }
        }
        .glassSurface(cornerRadius: 18)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.cfTextTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func row<Trailing: View>(label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cfTextSecondary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var crowdLevel: CrowdPeople.Level {
        switch currentArrival.nextArrivalCrowd {
        case .seats: .low
        case .standing: .med
        case .limited: .high
        case .unknown: .low
        }
    }

    private var crowdText: String {
        switch currentArrival.nextArrivalCrowd {
        case .seats: "Seats available"
        case .standing: "Standing room"
        case .limited: "Packed"
        case .unknown: "—"
        }
    }

    private var operatorLabel: String {
        switch currentArrival.operatorName {
        case "SBST", "SBS": return "SBS Transit"
        case "SMRT": return "SMRT"
        case "TTS": return "Tower Transit"
        case "GAS": return "Go-Ahead"
        case "": return "—"
        default: return currentArrival.operatorName
        }
    }

    // MARK: - Live Activity (kept from original feature set)

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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.cfHairlineStrong, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track on Lock Screen")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                    Text("Live ETA in the Dynamic Island")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.cfTextSecondary)
                }
            }
        }
        .tint(Color.cfNowFill)
        .padding(14)
        .glassSurface(cornerRadius: 16)
        .sensoryFeedback(trackingOnLockScreen ? .success : .selection, trigger: trackingOnLockScreen)
        .onAppear {
            trackingOnLockScreen = LiveActivityManager.shared.isActive(
                for: currentArrival.serviceNo,
                stopCode: busStopCode
            )
        }
        .onChange(of: currentArrival.nextArrivalAt) { _, _ in pushActivityUpdate() }
        .onChange(of: currentArrival.nextArrivalCrowd) { _, _ in pushActivityUpdate() }
    }

    private func startLiveActivity() {
        LiveActivityManager.shared.start(
            serviceNo: currentArrival.serviceNo,
            destination: currentArrival.destination,
            stopName: stopName ?? (busStopCode ?? "your stop"),
            stopCode: busStopCode ?? "",
            etaMinutes: currentArrival.nextArrivalMinutes,
            isLive: isLive,
            crowdLevel: currentArrival.nextArrivalCrowd.label
        )
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

    // MARK: - Data

    private func loadStopName() async {
        guard let busStopCode else { return }
        let stops = await stopsRepo.stops
        stopName = stops.first { $0.id == busStopCode }?.name
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
            // keep last known data
        }
    }
}
