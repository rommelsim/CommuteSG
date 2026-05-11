import SwiftUI

// MARK: - Train arrival row
struct TrainArrivalRow: View {
    let destination: String
    let nextClockTime: String
    let minutesUntil: Int

    private var isArriving: Bool { minutesUntil < 2 }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "arrow.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Towards \(destination)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text("Next at \(nextClockTime)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            if isArriving {
                Text("Arriving")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cmLive)
            } else {
                Text("\(minutesUntil) min")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Bus arrival row
struct BusArrivalRow: View {
    let busNumber: String
    let destination: String
    let nextMinutes: Int?
    let followingMinutes: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            BusNumberPill(number: busNumber)

            Text("→ \(destination)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                primaryTime
                if let f = followingMinutes {
                    Text("then \(f) min")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    @ViewBuilder
    private var primaryTime: some View {
        if let n = nextMinutes {
            if n < 2 {
                Text("Arriving")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cmLive)
                    .monospacedDigit()
            } else {
                Text("\(n) min")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        } else {
            Text("—")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}
