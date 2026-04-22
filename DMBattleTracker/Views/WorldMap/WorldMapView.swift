import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

// MARK: - Controller bridge (AppKit ↔ SwiftUI)

@MainActor
final class MapController: ObservableObject {
    @Published var magnificationPercent: Int = 100
    weak var scrollView: NSScrollView?

    func zoomIn() {
        guard let sv = scrollView else { return }
        setMagnification(min(30.0, sv.magnification * 1.4), centeredInView: true)
    }

    func zoomOut() {
        guard let sv = scrollView else { return }
        setMagnification(max(0.02, sv.magnification / 1.4), centeredInView: true)
    }

    func fitToView() {
        guard let sv = scrollView, let doc = sv.documentView else { return }
        let svSize = sv.contentSize
        let docSize = doc.frame.size
        guard docSize.width > 0, docSize.height > 0 else { return }
        let fit = min(svSize.width / docSize.width, svSize.height / docSize.height)
        sv.magnification = fit
        let x = (docSize.width  * fit - svSize.width)  / 2
        let y = (docSize.height * fit - svSize.height) / 2
        sv.contentView.scroll(to: NSPoint(x: max(0, x), y: max(0, y)))
        magnificationPercent = Int(sv.magnification * 100)
    }

    func updatePercent() {
        magnificationPercent = Int((scrollView?.magnification ?? 1) * 100)
    }

    private func setMagnification(_ mag: CGFloat, centeredInView: Bool) {
        guard let sv = scrollView else { return }
        if centeredInView {
            let vis = sv.contentView.bounds
            let center = sv.contentView.convert(
                CGPoint(x: vis.midX, y: vis.midY), to: sv.documentView
            )
            sv.setMagnification(mag, centeredAt: center)
        } else {
            sv.magnification = mag
        }
        magnificationPercent = Int(sv.magnification * 100)
    }
}

// MARK: - Zoomable scroll view

final class ZoomableScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        let factor = event.deltaY > 0 ? 1.1 : (event.deltaY < 0 ? 1.0 / 1.1 : 1.0)
        guard factor != 1.0, let doc = documentView else { return }
        let cursorInDoc = doc.convert(event.locationInWindow, from: nil)
        let newMag = (magnification * factor).clamped(to: minMagnification...maxMagnification)
        setMagnification(newMag, centeredAt: cursorInDoc)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - AppKit canvas

struct MapCanvasView: NSViewRepresentable {
    let image: NSImage
    let controller: MapController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> ZoomableScrollView {
        let sv = ZoomableScrollView()
        sv.allowsMagnification = true
        sv.minMagnification = 0.02
        sv.maxMagnification = 30.0
        sv.backgroundColor = .black
        sv.drawsBackground = true
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.usesPredominantAxisScrolling = false

        let iv = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        iv.image = image
        iv.imageScaling = .scaleNone
        sv.documentView = iv

        context.coordinator.attach(to: sv)
        controller.scrollView = sv

        DispatchQueue.main.async { self.controller.fitToView() }
        return sv
    }

    func updateNSView(_ sv: ZoomableScrollView, context: Context) {
        guard let iv = sv.documentView as? NSImageView else { return }
        if iv.image !== image {
            iv.image = image
            iv.frame = NSRect(origin: .zero, size: image.size)
            DispatchQueue.main.async { self.controller.fitToView() }
        }
    }

    static func dismantleNSView(_ sv: ZoomableScrollView, coordinator: Coordinator) {
        coordinator.detach(from: sv)
    }

    final class Coordinator: NSObject {
        let controller: MapController
        private var panStart: NSPoint = .zero
        private var originAtPanStart: NSPoint = .zero
        private var trackingArea: NSTrackingArea?

        init(controller: MapController) { self.controller = controller }

        func attach(to sv: NSScrollView) {
            sv.addObserver(self, forKeyPath: "magnification", options: [.new], context: nil)

            let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            sv.addGestureRecognizer(pan)

            let area = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self, userInfo: nil
            )
            sv.addTrackingArea(area)
            trackingArea = area
        }

        func detach(from sv: NSScrollView) {
            sv.removeObserver(self, forKeyPath: "magnification")
            if let area = trackingArea { sv.removeTrackingArea(area) }
        }

        @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let sv = gesture.view as? NSScrollView else { return }
            switch gesture.state {
            case .began:
                panStart = gesture.location(in: sv)
                originAtPanStart = sv.contentView.bounds.origin
                NSCursor.closedHand.set()
            case .changed:
                let current = gesture.location(in: sv)
                let dx = current.x - panStart.x
                let dy = current.y - panStart.y
                let newOrigin = NSPoint(x: originAtPanStart.x - dx, y: originAtPanStart.y + dy)
                sv.contentView.scroll(to: newOrigin)
                sv.reflectScrolledClipView(sv.contentView)
            default:
                NSCursor.openHand.set()
            }
        }

        func mouseEntered(with event: NSEvent) { NSCursor.openHand.set() }
        func mouseExited(with event: NSEvent)  { NSCursor.arrow.set() }

        override func observeValue(forKeyPath keyPath: String?,
                                   of object: Any?,
                                   change: [NSKeyValueChangeKey: Any]?,
                                   context: UnsafeMutableRawPointer?) {
            guard keyPath == "magnification" else { return }
            DispatchQueue.main.async { self.controller.updatePercent() }
        }
    }
}

// MARK: - SwiftUI wrapper

struct WorldMapView: View {
    let campaign: Campaign
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorldMapRecord]

    @StateObject private var controller = MapController()
    @State private var cachedImage: NSImage?
    @State private var showImporter = false

    init(campaign: Campaign) {
        self.campaign = campaign
        let cid = campaign.id
        _records = Query(filter: #Predicate<WorldMapRecord> { $0.campaignID == cid })
    }

    var record: WorldMapRecord? { records.first }

    var body: some View {
        Group {
            if let img = cachedImage {
                MapCanvasView(image: img, controller: controller)
            } else {
                ContentUnavailableView(
                    "No World Map",
                    systemImage: "map.fill",
                    description: Text("Import an image of your world map to get started.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("World Map")
        .onAppear { loadImage() }
        .onChange(of: record?.imageData) { _, _ in loadImage() }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if cachedImage != nil {
                    Text("\(controller.magnificationPercent)%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44)

                    Button { controller.zoomOut() } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom Out (⌘−)")
                    .keyboardShortcut("-", modifiers: .command)

                    Button { controller.zoomIn() } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom In (⌘=)")
                    .keyboardShortcut("=", modifiers: .command)

                    Button { controller.fitToView() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .help("Fit to Screen (⌘0)")
                    .keyboardShortcut("0", modifiers: .command)

                    Divider()
                }

                Button { showImporter = true } label: {
                    Label(cachedImage == nil ? "Import Map" : "Replace Map", systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url),
                  let img = NSImage(data: data),
                  let png = img.pngData else { return }
            if let existing = record {
                existing.imageData = png
            } else {
                let rec = WorldMapRecord(campaignID: campaign.id)
                rec.imageData = png
                modelContext.insert(rec)
            }
        }
    }

    private func loadImage() {
        if let data = record?.imageData {
            cachedImage = NSImage(data: data)
        } else {
            cachedImage = nil
        }
    }
}

// MARK: - NSImage helper

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
