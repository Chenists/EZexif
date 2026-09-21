import SwiftUI
import MapKit
import CoreLocation

/// Click-to-drop-a-pin location picker, backed by the system's built-in
/// Maps framework (MapKit is a system framework on macOS — using it here
/// adds no meaningful size to the app bundle).
struct MapLocationPickerView: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Environment(\.dismiss) private var dismiss

    @State private var region: MKCoordinateRegion
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var locationFetcher = LocationFetcher()
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchFailed = false

    init(latitude: Binding<Double?>, longitude: Binding<Double?>) {
        _latitude = latitude
        _longitude = longitude
        let hasExisting = latitude.wrappedValue != nil && longitude.wrappedValue != nil
        // No location assigned yet — still a whole-world view, just
        // centered on Wuhan, Hubei, China rather than (20, 0), since that's
        // where most of this app's photos are taken.
        let start = CLLocationCoordinate2D(
            latitude: latitude.wrappedValue ?? 30.5928,
            longitude: longitude.wrappedValue ?? 114.3055
        )
        _region = State(initialValue: MKCoordinateRegion(
            center: start,
            span: MKCoordinateSpan(
                latitudeDelta: hasExisting ? 0.2 : 90,
                longitudeDelta: hasExisting ? 0.2 : 90
            )
        ))
        _pinCoordinate = State(initialValue: hasExisting ? start : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                ClickableMapView(region: $region, pinCoordinate: $pinCoordinate)

                // Map controls cluster — zoom in/out above "use current
                // location", all in the same corner like a standard map UI.
                VStack(spacing: 8) {
                    Button {
                        zoom(by: 0.5)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Zoom In")
                    Button {
                        zoom(by: 2)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Zoom Out")
                    Button {
                        locationFetcher.requestLocation { coordinate in
                            region = MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                            )
                            pinCoordinate = coordinate
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Use Current Location")
                }
                .padding(12)

                // Place search — `MKLocalSearch` is part of the same
                // system MapKit framework already used for the map itself,
                // so this doesn't add any real weight to the app.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search for a place", text: $searchText)
                            .textFieldStyle(.plain)
                            .onSubmit { performSearch() }
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchFailed = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    if searchFailed {
                        Text("No matching place found.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .frame(width: 260)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            Divider()
            HStack {
                if let pin = pinCoordinate {
                    Text(String(format: "%.5f, %.5f", pin.latitude, pin.longitude))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Click the map to drop a pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if pinCoordinate != nil {
                    Button("Clear Pin", role: .destructive) { pinCoordinate = nil }
                }
                Button("Cancel") { dismiss() }
                Button("Done") {
                    latitude = pinCoordinate?.latitude
                    longitude = pinCoordinate?.longitude
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(10)
        }
        .frame(width: 560, height: 480)
    }

    private func zoom(by factor: Double) {
        var newRegion = region
        newRegion.span.latitudeDelta = min(180, max(0.005, region.span.latitudeDelta * factor))
        newRegion.span.longitudeDelta = min(180, max(0.005, region.span.longitudeDelta * factor))
        region = newRegion
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchFailed = false
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        MKLocalSearch(request: request).start { response, _ in
            isSearching = false
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else {
                searchFailed = true
                return
            }
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
            )
            pinCoordinate = coordinate
        }
    }
}

/// `MKMapView` wrapped for SwiftUI, with a click gesture that converts the
/// clicked point to a coordinate and drops/moves a single pin there — the
/// classic macOS-13-era `Map(coordinateRegion:)` SwiftUI view has no
/// built-in "tap to pick a coordinate" callback, so this goes straight to
/// AppKit for that one interaction.
struct ClickableMapView: NSViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var pinCoordinate: CLLocationCoordinate2D?

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        mapView.addGestureRecognizer(click)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // See `ComboBoxField.updateNSView` for why this is needed: without
        // it, the coordinator's delegate callbacks below would keep writing
        // through the `pinCoordinate`/`region` bindings captured when this
        // `MKMapView` was first created, not the current ones.
        context.coordinator.parent = self
        mapView.removeAnnotations(mapView.annotations)
        if let coordinate = pinCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
        }
        // Only pushed to the map view when it actually differs from what's
        // already displayed (beyond floating-point noise) — otherwise this
        // would fight with `regionDidChangeAnimated` reporting the user's
        // own panning/zooming back into `region`, re-applying it to the map
        // and needlessly interrupting the gesture. A real mismatch only
        // happens when something outside the map (e.g. the current-location
        // button) sets a new region directly.
        if !Self.regionsRoughlyEqual(mapView.region, region) {
            mapView.setRegion(region, animated: true)
        }
    }

    private static func regionsRoughlyEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        abs(a.center.latitude - b.center.latitude) < 0.0001
            && abs(a.center.longitude - b.center.longitude) < 0.0001
            && abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.0001
            && abs(a.span.longitudeDelta - b.span.longitudeDelta) < 0.0001
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClickableMapView
        weak var mapView: MKMapView?

        init(_ parent: ClickableMapView) { self.parent = parent }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let mapView else { return }
            let point = gesture.location(in: mapView)
            parent.pinCoordinate = mapView.convert(point, toCoordinateFrom: mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

/// One-shot current-location lookup for the "Use Current Location" map
/// button — a plain `CLLocationManagerDelegate` wrapper rather than
/// `ObservableObject`, since the result is only ever needed once per tap,
/// via `completion`, not observed continuously.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation(completion: @escaping (CLLocationCoordinate2D) -> Void) {
        self.completion = completion
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        completion?(coordinate)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignored — e.g. permission denied, or no location fix
        // available (common in a desktop Mac with no GPS/Wi-Fi signal).
        completion = nil
    }
}
