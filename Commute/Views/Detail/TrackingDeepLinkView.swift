import SwiftUI

/// Resolves a `commute://track/<serviceNo>/<stopCode>` deep link into a
/// fully-built `LiveTrackingView`. The Live Activity payload doesn't carry
/// a complete `BusArrival` — just the service number + stop code — so this
/// view fetches arrivals on appear, finds the matching service, and hands
/// it off. Shows a slim loading state while the fetch is in flight, and
/// surfaces an empty state if the bus isn't currently in the LTA feed
/// (e.g. last service of the day, suspended route).
struct TrackingDeepLinkView: View {
    let serviceNo: String
    let stopCode: String

    @State private var resolved: BusArrival?
    @State private var loadState: LoadState = .loading

    private enum LoadState: Equatable {
        case loading, found, notFound, failed
    }

    var body: some View {
        Group {
            if let arrival = resolved {
                LiveTrackingView(arrival: arrival, busStopCode: stopCode)
            } else {
                placeholder
            }
        }
        .task(id: "\(serviceNo)@\(stopCode)") {
            await resolveArrival()
        }
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            switch loadState {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Finding bus \(serviceNo)…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.cfTextSecondary)
            case .notFound, .failed:
                Image(systemName: "bus.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.cfTextTertiary)
                Text("Bus \(serviceNo) isn't running right now")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.cfTextPrimary)
                Text("Open the stop to see other services.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.cfTextSecondary)
            case .found:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cfPageBackground.ignoresSafeArea())
    }

    private func resolveArrival() async {
        loadState = .loading
        do {
            let arrivals = try await LTAService.shared.busArrivals(at: stopCode, force: true)
            if let match = arrivals.first(where: { $0.serviceNo == serviceNo }) {
                resolved = match
                loadState = .found
            } else {
                loadState = .notFound
            }
        } catch {
            loadState = .failed
        }
    }
}
