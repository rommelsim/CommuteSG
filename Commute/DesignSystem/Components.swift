import SwiftUI

// MARK: - MRT line pill
struct MRTLinePill: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.caption2)
            .fontWeight(.medium)
            .tracking(0.4)
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                (MRTLineToken.from(code: code)?.color ?? .gray),
                in: RoundedRectangle(cornerRadius: CMRadius.pill, style: .continuous)
            )
    }
}

// MARK: - Bus number pill
// Hollow outlined pill — solid colored fills are reserved for MRT line codes.
struct BusNumberPill: View {
    let number: String

    var body: some View {
        Text(number)
            .font(.subheadline)
            .fontWeight(.medium)
            .monospacedDigit()
            .foregroundStyle(.primary)
            .frame(minWidth: 42)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
            )
    }
}

// MARK: - Card container
struct CMCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(CMSpacing.cardPadding)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: CMRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CMRadius.card, style: .continuous)
                .strokeBorder(Color.cmHairline, lineWidth: 0.5)
        )
    }
}

// MARK: - Live status pill (header)
struct LiveStatusPill: View {
    let minutesAgo: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.cmLive)
                .frame(width: 6, height: 6)
            Text("Live · \(minutesAgo)m")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CMRadius.statusPill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CMRadius.statusPill, style: .continuous)
                .strokeBorder(Color.cmHairline, lineWidth: 0.5)
        )
    }
}

// MARK: - Search bar (idle/static)
struct CMSearchBar: View {
    let placeholder: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: CMRadius.searchBar, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CMRadius.searchBar, style: .continuous)
                    .strokeBorder(Color.cmHairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter chip
struct CMFilterChip: View {
    let label: String
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.cmAccent : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: CMRadius.chip, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CMRadius.chip, style: .continuous)
                        .strokeBorder(Color.cmHairline, lineWidth: isSelected ? 0 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section header
struct CMSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2)
            .fontWeight(.medium)
            .tracking(0.6)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Walk distance label
struct WalkDistanceLabel: View {
    let walkMinutes: Int
    let meters: Int
    var extraSuffix: String? = nil

    private var distanceText: String {
        if meters < 1000 {
            return "\(meters) m"
        } else {
            return String(format: "%.1f km", Double(meters) / 1000)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.walk")
                .font(.system(size: 11))
            Text("\(walkMinutes) min walk · \(distanceText)\(extraSuffix ?? "")")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
