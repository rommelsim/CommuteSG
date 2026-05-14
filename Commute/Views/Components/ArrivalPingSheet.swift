import SwiftUI

/// User-pickable thresholds for the "Ping me when arriving" notification.
/// `.both` schedules two pings — one at 2 min (active) and one at 1 min
/// (time-sensitive, breaks DND) per the commuter-advocate handoff.
enum ArrivalPingThreshold: String, CaseIterable, Identifiable {
    case oneMinute, twoMinutes, both, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneMinute:  "1 min — leave-now nudge"
        case .twoMinutes: "2 min — start walking"
        case .both:       "Both — 2 min + 1 min"
        case .custom:     "Custom…"
        }
    }

    /// `true` when this threshold should fire as a time-sensitive
    /// notification (breaks Do Not Disturb). Maps directly to the spec:
    /// 2-min = `.active`, 1-min = `.timeSensitive`.
    var isTimeSensitive: Bool {
        switch self {
        case .oneMinute, .both, .custom: true
        case .twoMinutes: false
        }
    }
}

/// Bottom-sheet picker shown after a long-press "Ping me when arriving" on a
/// bus row. Caller persists the chosen threshold against the
/// service+stop pair and arms the underlying poller.
struct ArrivalPingSheet: View {
    let serviceNo: String
    let stopName: String
    @Binding var selection: ArrivalPingThreshold
    var onConfirm: (ArrivalPingThreshold) -> Void
    @State private var customMinutes: Int = 3
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Text("We'll ping you when bus \(serviceNo) is close to \(stopName).")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.cfTextSecondary)

            VStack(spacing: 8) {
                ForEach(ArrivalPingThreshold.allCases) { t in
                    optionRow(t)
                }
                if selection == .custom {
                    Stepper("Custom: \(customMinutes) min", value: $customMinutes, in: 1...15)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.cfGlassFillSoft, in: RoundedRectangle(cornerRadius: 10))
                }
            }

            Button {
                onConfirm(selection)
                dismiss()
            } label: {
                Text("Ping me")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appInfo, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.cfPageBackground)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.appInfo)
            Text("Ping me when arriving")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
        }
    }

    private func optionRow(_ t: ArrivalPingThreshold) -> some View {
        Button {
            selection = t
        } label: {
            HStack {
                Text(t.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
                Spacer()
                if selection == t {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appInfo)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selection == t ? Color.appInfoBg : Color.cfGlassFillSoft)
            )
        }
        .buttonStyle(.plain)
    }
}
