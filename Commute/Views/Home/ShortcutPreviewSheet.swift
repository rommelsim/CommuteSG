import SwiftUI
import MapKit
import CoreLocation

struct ShortcutPreviewSheet: View {
    let kind: SavedPlace.Kind
    let address: String
    let onPlanJourney: () -> Void
    let onEditAddress: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var distanceMeters: Double?
    @State private var transitETA: TimeInterval?
    @State private var walkingETA: TimeInterval?
    @State private var drivingETA: TimeInterval?
    @State private var alerts: [TransitAlert] = []
    @State private var bestRoute: JourneyOption?
    @State private var phase: Phase = .loading

    private let location = LocationService.shared
    private let lta = LTAService.shared

    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    if let destinationCoordinate {
                        mapView(to: destinationCoordinate)
                    } else if case .failed = phase {
                        errorCard
                    }
                    etaSection
                    if bestRoute != nil {
                        directionsSection
                    }
                    if !alerts.isEmpty {
                        alertsSection
                    }
                    actions
                }
                .padding(Spacing.screen)
                .padding(.bottom, 16)
            }
            .background(Color.appSurface)
            .scrollIndicators(.hidden)
            .navigationTitle(kind == .home ? "Home" : "Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appInfo)
                }
            }
        }
        .task { await load() }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(kind == .home ? Color.appInfo : Color.appPurpleStrong)
                .frame(width: 40, height: 40)
                .background(kind == .home ? Color.appInfoBg : Color.appPurpleBg)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(address)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                    .lineLimit(2)
                if let m = distanceMeters {
                    Text(distanceLabel(m))
                        .font(.appCaption)
                        .foregroundStyle(Color.appText2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func mapView(to coord: CLLocationCoordinate2D) -> some View {
        let userCoord = location.lastLocation?.coordinate
        return Map(initialPosition: .region(region(from: userCoord, to: coord))) {
            Marker(kind == .home ? "Home" : "Work",
                   systemImage: kind.symbol,
                   coordinate: coord)
                .tint(kind == .home ? Color.appInfo : Color.appPurpleStrong)
            if let userCoord {
                Marker("You", systemImage: "location.fill", coordinate: userCoord)
                    .tint(Color.appText)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .allowsHitTesting(false)
    }

    private func region(from origin: CLLocationCoordinate2D?, to dest: CLLocationCoordinate2D) -> MKCoordinateRegion {
        guard let origin else {
            return MKCoordinateRegion(
                center: dest,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
        let center = CLLocationCoordinate2D(
            latitude: (origin.latitude + dest.latitude) / 2,
            longitude: (origin.longitude + dest.longitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(abs(origin.latitude - dest.latitude) * 1.6, 0.02),
            longitudeDelta: max(abs(origin.longitude - dest.longitude) * 1.6, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private var etaSection: some View {
        Group {
            if phase == .loading {
                ShortcutETASkeleton()
            } else {
                VStack(spacing: 0) {
                    etaRow(label: "Transit", icon: "tram.fill", time: transitETA, isFirst: true)
                    Divider().background(Color.appBorder)
                    etaRow(label: "Walking", icon: "figure.walk", time: walkingETA, isFirst: false)
                    Divider().background(Color.appBorder)
                    etaRow(label: "Driving", icon: "car.fill", time: drivingETA, isFirst: false)
                }
                .frame(maxWidth: .infinity)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }

    private func etaRow(label: String, icon: String, time: TimeInterval?, isFirst: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appText2)
                .frame(width: 22)
            Text(label)
                .font(.appBodyMedium)
                .foregroundStyle(Color.appText)
            Spacer()
            Text(formatETA(time))
                .font(.appBody)
                .foregroundStyle(time == nil ? Color.appText3 : Color.appText)
        }
        .padding(14)
    }

    // MARK: - Directions

    @ViewBuilder
    private var directionsSection: some View {
        if let route = bestRoute {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appInfo)
                    Text("Suggested route")
                        .font(.appCaptionStrong)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(Color.appText2)
                    Spacer()
                    Text("\(route.durationMinutes) min · \(formatFare(route.fareSGD))")
                        .font(.appCaption)
                        .foregroundStyle(Color.appText3)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(route.segments.enumerated()), id: \.offset) { idx, seg in
                        directionStep(
                            seg,
                            isFirst: idx == 0,
                            isLast: idx == route.segments.count - 1
                        )
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }

    private func directionStep(
        _ seg: JourneyOption.Segment,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                indicator(for: seg)
                if !isLast {
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 22)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 2) {
                Text(stepTitle(seg))
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                Text(stepSubtitle(seg, isFirst: isFirst, isLast: isLast))
                    .font(.appCaption)
                    .foregroundStyle(Color.appText2)
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func indicator(for seg: JourneyOption.Segment) -> some View {
        switch seg {
        case .walk:
            Image(systemName: "figure.walk")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.appText2)
                .frame(width: 22, height: 22)
                .background(Color.appSurface2)
                .clipShape(Circle())
        case .mrt(let line, _):
            ZStack {
                Circle().fill(line.background)
                Image(systemName: "tram.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(line.foreground)
            }
            .frame(width: 22, height: 22)
        case .bus:
            ZStack {
                Circle().fill(Color.appText.opacity(0.85))
                Image(systemName: "bus.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.appSurface)
            }
            .frame(width: 22, height: 22)
        }
    }

    private func stepTitle(_ seg: JourneyOption.Segment) -> String {
        switch seg {
        case .walk(let m):           "Walk · \(m) min"
        case .mrt(let line, let m):  "Take \(line.fullName) · \(m) min"
        case .bus(let no, let m):    "Take Bus \(no) · \(m) min"
        }
    }

    private func stepSubtitle(
        _ seg: JourneyOption.Segment,
        isFirst: Bool,
        isLast: Bool
    ) -> String {
        switch seg {
        case .walk:
            if isFirst { "From your location" }
            else if isLast { "To \(address)" }
            else { "To the next stop" }
        case .mrt(let line, _):
            "\(line.code) line"
        case .bus:
            "Towards your destination"
        }
    }

    private func formatFare(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appWarningStrong)
                Text("Active service alerts")
                    .font(.appCaptionMedium)
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.appText2)
            }
            VStack(spacing: 8) {
                ForEach(alerts.prefix(3)) { alert in
                    AlertSummaryRow(alert: alert)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                dismiss()
                onPlanJourney()
            } label: {
                HStack {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    Text("Plan journey here")
                        .font(.appBodyMedium)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color.appInfo)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .buttonStyle(CardButtonStyle())

            HStack(spacing: 8) {
                Button(action: openInMaps) {
                    HStack {
                        Image(systemName: "map")
                        Text("Open in Maps")
                            .font(.appLabel)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface2)
                    .foregroundStyle(Color.appText)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(CardButtonStyle())

                Button {
                    dismiss()
                    onEditAddress()
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit address")
                            .font(.appLabel)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface2)
                    .foregroundStyle(Color.appText)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(CardButtonStyle())
            }
        }
    }

    private var errorCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .foregroundStyle(Color.appWarningStrong)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't find this address")
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appText)
                if case .failed(let msg) = phase {
                    Text(msg)
                        .font(.appMicro)
                        .foregroundStyle(Color.appText3)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.appWarningBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: - Loading

    private func load() async {
        phase = .loading
        let coord = await geocode(address: address)
        guard let coord else {
            phase = .failed("Try a more specific address.")
            return
        }
        destinationCoordinate = coord

        let userLoc = (try? await location.currentLocation()) ?? location.lastLocation
        if let userLoc {
            distanceMeters = userLoc.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            await fetchETAs(from: userLoc.coordinate, to: coord)
        }

        // Build a step-by-step suggested route using our journey planner —
        // grounded in the user's GPS and the geocoded destination so the
        // segment durations and lines match real geography.
        bestRoute = MockDataService.shared.journeyOptions(
            from: "Current location",
            to: address,
            originHint: userLoc?.coordinate,
            destinationHint: coord
        ).first

        if let liveAlerts = try? await lta.trainAlertsAsTransitAlerts() {
            alerts = liveAlerts.filter { $0.severity == .danger || $0.severity == .warning }
        }
        phase = .ready
    }

    private func geocode(address: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        // Bias to Singapore by appending country
        let q = address.localizedCaseInsensitiveContains("singapore") ? address : "\(address), Singapore"
        do {
            let placemarks = try await geocoder.geocodeAddressString(q)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    private func fetchETAs(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) async {
        async let transit = ETA(from: origin, to: dest, mode: .transit)
        async let walking = ETA(from: origin, to: dest, mode: .walking)
        async let driving = ETA(from: origin, to: dest, mode: .automobile)
        let results = await (transit, walking, driving)
        transitETA = results.0
        walkingETA = results.1
        drivingETA = results.2
    }

    private func ETA(
        from origin: CLLocationCoordinate2D,
        to dest: CLLocationCoordinate2D,
        mode: MKDirectionsTransportType
    ) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        request.transportType = mode
        let directions = MKDirections(request: request)
        do {
            if mode == .transit {
                let response = try await directions.calculateETA()
                return response.expectedTravelTime
            } else {
                let response = try await directions.calculate()
                return response.routes.first?.expectedTravelTime
            }
        } catch {
            return nil
        }
    }

    private func openInMaps() {
        guard let coord = destinationCoordinate else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = address
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
        ])
    }

    // MARK: - Helpers

    private func formatETA(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let mins = Int(seconds / 60)
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    private func distanceLabel(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters))m away" }
        return String(format: "%.1f km away", meters / 1000)
    }
}

private struct AlertSummaryRow: View {
    let alert: TransitAlert

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.appLabelMedium)
                    .foregroundStyle(Color.appText)
                if let body = alert.body {
                    Text(body)
                        .font(.appMicro)
                        .foregroundStyle(Color.appText2)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    private var dotColor: Color {
        switch alert.severity {
        case .danger:  Color.appDangerStrong
        case .warning: Color.appWarningStrong
        case .info:    Color.appInfo
        case .success: Color.appSuccessStrong
        }
    }

    private var background: Color {
        switch alert.severity {
        case .danger:  Color.appDangerBg
        case .warning: Color.appWarningBg
        case .info:    Color.appInfoBg
        case .success: Color.appSuccessBg
        }
    }
}
