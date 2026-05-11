import SwiftUI
import MapKit
import CoreLocation

struct BusStopDetailView: View {
    let stop: BusStop
    let initialArrivals: [BusArrival]

    @Environment(AppState.self) private var appState
    @State private var arrivals: [BusArrival]
    @State private var lastRefresh: Date? = nil
    @State private var filter: BusFilter = .all
    @State private var mapPosition: MapCameraPosition = .automatic

    enum BusFilter: String, CaseIterable, Hashable {
        case all, saved
        var label: String { self == .all ? "All buses" : "Saved" }
    }

    private let lta: LTAService = .shared

    init(stop: BusStop, initialArrivals: [BusArrival]) {
        self.stop = stop
        self.initialArrivals = initialArrivals
        self._arrivals = State(initialValue: initialArrivals)
        if let coord = stop.coordinate {
            self._mapPosition = State(initialValue: .region(
                Self.fitRegion(stop: coord, buses: initialArrivals.compactMap { $0.nextArrivalCoordinate })
            ))
        }
    }

    private static func fitRegion(
        stop: CLLocationCoordinate2D,
        buses: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        let allLats = [stop.latitude] + buses.map(\.latitude)
        let allLngs = [stop.longitude] + buses.map(\.longitude)
        let minLat = allLats.min() ?? stop.latitude
        let maxLat = allLats.max() ?? stop.latitude
        let minLng = allLngs.min() ?? stop.longitude
        let maxLng = allLngs.max() ?? stop.longitude
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.005),
            longitudeDelta: max((maxLng - minLng) * 1.6, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 18)            // breathing room below the notch / status bar
                    .padding(.bottom, 4)
                walkPill
                    .padding(.horizontal, 20)
                miniMap
                    .padding(.horizontal, 8)
                filterRow
                    .padding(.horizontal, 20)
                busList
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.cfPageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await refresh(force: false) }
        .refreshable { await refresh(force: true) }
    }

    // MARK: - Top bar (back + centered title + favorite)

    @Environment(\.dismiss) private var dismiss

    private var topBar: some View {
        HStack(alignment: .top) {
            iconCircleButton(symbol: "chevron.left") { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    BusStopIcon(size: 14, color: Color.black.opacity(0.65), strokeWidth: 2.2)
                    Text(stop.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.cfTextPrimary)
                        .lineLimit(1)
                }
                Text("Stop \(stop.id) · \(stop.road)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.cfTextTertiary)
                    .lineLimit(1)
            }
            .padding(.top, 4)
            Spacer()
            iconCircleButton(symbol: isFavorite ? "star.fill" : "star",
                             foreground: isFavorite ? Color.appAmber : Color.cfTextPrimary) {
                appState.toggleFavoriteBusStop(stop.id)
            }
        }
    }

    private func iconCircleButton(symbol: String, foreground: Color = .cfTextPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.85), in: Circle())
                .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Walk pill

    private var walkPill: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.50))
                Text("\(walkMin) min walk · \(distanceText)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.black.opacity(0.65))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassSurface(cornerRadius: 999, fill: Color.white.opacity(0.70))
            Spacer()
        }
    }

    private var walkMin: Int { StopsAdapters.walkMinutes(forMeters: stop.distanceMeters ?? 0) }

    private var distanceText: String {
        let m = stop.distanceMeters ?? 0
        if m < 1000 { return "\(m) m" }
        return String(format: "%.1f km", Double(m) / 1000)
    }

    // MARK: - Mini map

    private var miniMap: some View {
        ZStack(alignment: .topTrailing) {
            if let coord = stop.coordinate {
                Map(position: $mapPosition) {
                    Annotation(stop.name, coordinate: coord, anchor: .bottom) {
                        ZStack {
                            Circle().fill(Color.cfNowFill).frame(width: 28, height: 28)
                            BusStopIcon(size: 14, color: .white, strokeWidth: 2.3)
                        }
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    }
                    ForEach(busesOnMap, id: \.id) { entry in
                        Annotation("Bus \(entry.serviceNo)", coordinate: entry.coordinate, anchor: .center) {
                            busMarker(serviceNo: entry.serviceNo)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .onChange(of: arrivalsCoordinatesKey, initial: true) { _, _ in refitMap(target: coord) }

                recenterButton(target: coord)
            } else {
                Color.clear
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 0.5)
        )
    }

    private var arrivalsCoordinatesKey: String {
        arrivals
            .map { a in
                let lat = a.nextArrivalLatitude ?? 0
                let lng = a.nextArrivalLongitude ?? 0
                return "\(a.serviceNo):\(lat),\(lng)"
            }
            .joined(separator: "|")
    }

    private func refitMap(target: CLLocationCoordinate2D) {
        let busCoords = busesOnMap.map(\.coordinate)
        let region = Self.fitRegion(stop: target, buses: busCoords)
        withAnimation(.smooth(duration: 0.4)) { mapPosition = .region(region) }
    }

    private func recenterButton(target: CLLocationCoordinate2D) -> some View {
        Button { refitMap(target: target) } label: {
            Image(systemName: "scope")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.cfTextPrimary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.9), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(10)
    }

    private var busesOnMap: [BusOnMap] {
        arrivals.compactMap { arrival in
            guard let coord = arrival.nextArrivalCoordinate else { return nil }
            return BusOnMap(id: arrival.serviceNo, serviceNo: arrival.serviceNo, coordinate: coord)
        }
    }

    private func busMarker(serviceNo: String) -> some View {
        Text(serviceNo)
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .tracking(-0.1)
            .foregroundStyle(Color(hex: 0x1F2937))
            .padding(.horizontal, 6)
            .frame(height: 19)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    // MARK: - Filter row

    private var filterRow: some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(BusFilter.allCases, id: \.self) { f in
                    Button { withAnimation(.snappy) { filter = f } } label: {
                        Text(f.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(filter == f ? Color.cfTextPrimary : Color.black.opacity(0.50))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background {
                                if filter == f {
                                    Capsule().fill(Color.white)
                                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.black.opacity(0.04), in: Capsule())

            Spacer()

            HStack(spacing: 4) {
                LiveDot(color: .cfLiveDot, size: 6)
                Text("Live · \(minutesAgoText)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .glassSurface(cornerRadius: 999, fill: Color.white.opacity(0.80))
        }
    }

    private var minutesAgoText: String {
        guard let last = lastRefresh else { return "now" }
        return "\(max(0, Int(Date().timeIntervalSince(last) / 60)))m"
    }

    // MARK: - Bus list

    private var busList: some View {
        VStack(spacing: 0) {
            if filteredArrivals.isEmpty {
                EmptyStateView(
                    symbol: filter == .saved ? "star" : "bus.fill",
                    title: filter == .saved ? "No saved buses yet" : "No buses arriving",
                    subtitle: filter == .saved
                        ? "Tap the star next to any bus to save it for quick access."
                        : "Pull to refresh, or check back in a moment.",
                    style: .neutral
                )
                .padding(20)
            } else {
                ForEach(Array(filteredArrivals.enumerated()), id: \.offset) { idx, arrival in
                    NavigationLink(value: HomeRoute.tracking(arrival, busStopCode: stop.id)) {
                        BusServiceRow(
                            arrival: arrival,
                            isFavorite: appState.favoriteLineCodes.contains(arrival.serviceNo),
                            onToggleFavorite: { appState.toggleFavoriteLine(arrival.serviceNo) }
                        )
                    }
                    .buttonStyle(.plain)
                    if idx < filteredArrivals.count - 1 {
                        Divider().background(Color.black.opacity(0.04))
                    }
                }
            }
        }
        .glassSurface(cornerRadius: 18)
    }

    // MARK: - Refresh / state

    private var isFavorite: Bool { appState.favoriteBusStopCodes.contains(stop.id) }

    private var filteredArrivals: [BusArrival] {
        switch filter {
        case .all: arrivals
        case .saved: arrivals.filter { appState.favoriteLineCodes.contains($0.serviceNo) }
        }
    }

    private func refresh(force: Bool) async {
        do {
            let live = try await lta.busArrivals(at: stop.id, force: force)
            if !live.isEmpty {
                arrivals = live
                lastRefresh = Date()
            } else {
                arrivals = initialArrivals
            }
        } catch {
            arrivals = initialArrivals
        }
    }
}

// MARK: - Bus marker source

private struct BusOnMap: Identifiable {
    let id: String
    let serviceNo: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Bus service row (Stop Detail)
// Two-line layout per spec §"Bus row structure":
// Top: chip → destination (left) · ETA + reliability indicator (right)
// Bottom (indented): "via {route}" + crowd if packed (left) · "then {next} min" + save (right)
private struct BusServiceRow: View {
    let arrival: BusArrival
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    private var destinationName: String {
        StopsAdapters.destinationLabel(for: arrival).ifEmpty(arrival.destinationCode ?? "—")
    }

    private var nextEtaValue: String {
        arrival.nextArrivalMinutes.map(String.init) ?? "—"
    }

    private var followingText: String {
        guard let f = arrival.followingArrivalMinutes else { return "" }
        return "then \(f) min"
    }

    private var isUrgent: Bool { (arrival.nextArrivalMinutes ?? .max) <= 1 }
    private var isUnreliable: Bool { arrival.nextArrivalIsScheduled }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: chip → destination ........ ETA
            HStack(alignment: .center, spacing: 10) {
                ServiceChip(service: arrival.serviceNo, size: .md)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.cfTextMuted)
                Text(destinationName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    ETAView(urgent: isUrgent, value: nextEtaValue, size: .md)
                    if isUnreliable {
                        Text("± 3")
                            .font(.system(size: 9, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.cfTextTertiary)
                    }
                }
            }

            // Bottom row: via + crowd ........ then + save
            HStack(spacing: 8) {
                if arrival.nextArrivalCrowd == .limited {
                    CrowdPeople(level: .high, size: 10)
                }
                Spacer(minLength: 8)
                if !followingText.isEmpty {
                    Text(followingText)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.cfTextTertiary)
                }
                Button {
                    onToggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color.cfTextPrimary : Color.cfTextDisabled)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 60)  // align past the md chip
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// Tiny string convenience used in this file only.
private extension String {
    func ifEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
