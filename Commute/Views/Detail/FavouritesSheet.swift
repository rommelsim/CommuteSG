import SwiftUI

/// Lists every starred stop and bus number with an "unstar" button. Pure
/// management — tapping doesn't navigate (the user is in a sheet inside
/// Profile, deep linking out would be jarring); they manage their pins
/// here, then dismiss and find the items live on Home's Pinned rail.
struct FavouritesSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var pinnedStops: [BusStop] {
        appState.favoriteBusStopCodes
            .compactMap { BusStopNameCache.shared.stop(forCode: $0) }
            .sorted { $0.name < $1.name }
    }

    private var pinnedBuses: [String] {
        appState.favoriteLineCodes.sorted { lhs, rhs in
            (Int(lhs) ?? .max, lhs) < (Int(rhs) ?? .max, rhs)
        }
    }

    private var isEmpty: Bool {
        pinnedStops.isEmpty && pinnedBuses.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    List {
                        if !pinnedBuses.isEmpty {
                            Section("Buses") {
                                ForEach(pinnedBuses, id: \.self) { number in
                                    busRow(number)
                                }
                            }
                        }
                        if !pinnedStops.isEmpty {
                            Section("Stops") {
                                ForEach(pinnedStops) { stop in
                                    stopRow(stop)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Favourites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appInfo)
                }
            }
        }
    }

    private func busRow(_ number: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.cfTextPrimary)
                .frame(minWidth: 44, minHeight: 24)
                .padding(.horizontal, 8)
                .background(Color.cfChipFill, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.cfChipBorder, lineWidth: 0.5))
            Text("Bus \(number)")
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextPrimary)
            Spacer()
            unstarButton {
                appState.toggleFavoriteLine(number)
            }
        }
        .padding(.vertical, 4)
    }

    private func stopRow(_ stop: BusStop) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "signpost.right.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.cfTextSecondary)
                .frame(width: 28, height: 28)
                .background(Color.cfChipFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(stop.name)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.cfTextPrimary)
                    .lineLimit(1)
                Text("Stop \(stop.id) · \(stop.road)")
                    .font(.appCaption)
                    .foregroundStyle(Color.cfTextTertiary)
                    .lineLimit(1)
            }
            Spacer()
            unstarButton {
                appState.toggleFavoriteBusStop(stop.id)
            }
        }
        .padding(.vertical, 4)
    }

    private func unstarButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "star.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appAmber)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove from favourites")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.cfTextMuted)
            Text("No favourites yet")
                .font(.appBodyMedium)
                .foregroundStyle(Color.cfTextSecondary)
            Text("Tap the star next to any bus or stop to pin it for quick access.")
                .font(.appCaption)
                .foregroundStyle(Color.cfTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
