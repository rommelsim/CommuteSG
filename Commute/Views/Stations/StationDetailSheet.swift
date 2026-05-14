import SwiftUI

/// Bottom sheet for the Station Browser. Slides up over the screen
/// content with a dark backdrop and is dismissable via:
///   • tap-on-backdrop
///   • the close button in the header
///   • swipe-down on the handle (80pt threshold)
///
/// Uses a custom overlay + DragGesture rather than `.sheet(...)` so the
/// motion matches `PlannerMorphContainer` exactly: `0.42s` with
/// `cubic-bezier(0.32, 0.72, 0, 1)`.
struct StationDetailSheet: View {
    @Binding var snapshot: StationCrowdSnapshot?

    @State private var dragOffset: CGFloat = 0
    @State private var sheetHeight: CGFloat = 1
    private let openCurve: Animation = .timingCurve(0.32, 0.72, 0, 1, duration: 0.42)
    private let dismissThreshold: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                backdrop
                if let snapshot {
                    sheet(snapshot: snapshot)
                        // Cap at ~75% of available height. Without this
                        // the sheet's ScrollView eats the whole screen
                        // and the card reads as a fullscreen takeover
                        // instead of a bottom sheet.
                        .frame(maxHeight: geo.size.height * 0.75)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .animation(openCurve, value: snapshot)
    }

    private var backdrop: some View {
        Color.black
            .opacity(snapshot == nil ? 0 : 0.32)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            .allowsHitTesting(snapshot != nil)
    }

    private func sheet(snapshot snap: StationCrowdSnapshot) -> some View {
        VStack(spacing: 0) {
            handleArea
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(snap: snap)
                    crowdCard(snap: snap)
                    forecastCard(snap: snap)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 24, bottomLeading: 0,
                                   bottomTrailing: 0, topTrailing: 24),
                style: .continuous
            )
            .fill(Color.appSurface)
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { sheetHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in sheetHeight = h }
            }
        )
        .offset(y: max(0, dragOffset))
        .gesture(dragGesture)
    }

    // MARK: - Header

    private func header(snap: StationCrowdSnapshot) -> some View {
        HStack(spacing: 10) {
            Text(snap.stationCode)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Capsule().fill(snap.line.background))
            Text(snap.stationName)
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Color.cfTextPrimary)
                .lineLimit(1)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cfTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.cfTextPrimary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    // MARK: - Crowd card

    private func crowdCard(snap: StationCrowdSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Crowd now")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.cfTextTertiary)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.appSuccess).frame(width: 6, height: 6)
                    Text("Typical")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cfTextTertiary)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(snap.currentTier.word)
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(feelColor(snap.currentTier))
                Spacer()
                HStack(alignment: .bottom, spacing: 3) {
                    let heights: [CGFloat] = [6, 9, 12, 15, 18]
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(i < snap.currentTier.litPipCount
                                  ? feelColor(snap.currentTier)
                                  : Color.cfTextPrimary.opacity(0.1))
                            .frame(width: 5, height: heights[i])
                    }
                }
            }
            Text(snap.currentTier.advice)
                .font(.system(size: 12))
                .foregroundStyle(Color.cfTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cfTextPrimary.opacity(0.04))
        )
    }

    // MARK: - Forecast slots
    //
    // LTA's `PCDRealTimeForecast` returns 30-min slots over the next
    // ~90 min. We list each slot as a row; the prototype's 24-bar
    // historical timeline isn't possible without server-side ZIP
    // parsing of LTA's `PCDByStation` downloads. Forward-only is the
    // honest representation of what the JSON APIs expose.

    @ViewBuilder
    private func forecastCard(snap: StationCrowdSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Forecast · next ~90 min")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.cfTextTertiary)
                Spacer()
            }

            if snap.forecast.isEmpty {
                Text("No forecast data from LTA for this station right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cfTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(snap.forecast.enumerated()), id: \.offset) { _, slot in
                        forecastRow(slot: slot, line: snap.line)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cfTextPrimary.opacity(0.04))
        )
    }

    private func forecastRow(slot: StationCrowdSnapshot.ForecastSlot, line: MRTLine) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(line.background)
                .frame(width: 6, height: 6)
            Text(slotLabel(hour: slot.startHour, minute: slot.startMinute))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
            Text(slot.tier.word)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(feelColor(slot.tier))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    private func slotLabel(hour: Int, minute: Int) -> String {
        let endTotal = hour * 60 + minute + 30
        let endHour = (endTotal / 60) % 24
        let endMin = endTotal % 60
        return "\(timeLabel(h: hour, m: minute))–\(timeLabel(h: endHour, m: endMin))"
    }

    private func timeLabel(h: Int, m: Int) -> String {
        let suffix = h < 12 ? "AM" : "PM"
        let display = (h % 12 == 0) ? 12 : (h % 12)
        return String(format: "%d:%02d %@", display, m, suffix)
    }

    // MARK: - Handle / drag

    private var handleArea: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.cfTextPrimary.opacity(0.15))
                .frame(width: 38, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldClose = value.translation.height > dismissThreshold
                    || value.predictedEndTranslation.height > 200
                if shouldClose {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismiss() {
        withAnimation(openCurve) {
            snapshot = nil
            dragOffset = 0
        }
    }

    // MARK: - Helpers

    private func feelColor(_ tier: CrowdTier) -> Color {
        switch tier {
        case .low:      Color.appSuccess
        case .moderate: Color.cfTextPrimary
        case .busy:     Color.appDanger
        case .unknown:  Color.cfTextTertiary
        }
    }
}
