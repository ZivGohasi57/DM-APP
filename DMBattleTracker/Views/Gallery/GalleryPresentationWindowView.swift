import SwiftUI
import AppKit

struct GalleryPresentationWindowView: View {
    @Environment(GalleryPresentationState.self) private var state

    @State private var isHovered = false

    private var items: [GalleryPresentationItem] { state.items }
    private var idx: Int { state.currentIndex }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if !items.isEmpty, idx < items.count, let nsImage = NSImage(data: items[idx].data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(idx)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }

            if items.count > 1 {
                HStack {
                    navButton(systemImage: "chevron.left.circle.fill", enabled: idx > 0) {
                        state.currentIndex = max(0, idx - 1)
                    }
                    Spacer()
                    navButton(systemImage: "chevron.right.circle.fill", enabled: idx < items.count - 1) {
                        state.currentIndex = min(items.count - 1, idx + 1)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }

            if idx < items.count, let symbolData = items[idx].symbolData,
               let symbolImage = NSImage(data: symbolData) {
                VStack {
                    HStack {
                        Spacer()
                        Image(nsImage: symbolImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .shadow(color: .black.opacity(0.5), radius: 8)
                            .padding(.top, 20)
                            .padding(.trailing, 24)
                    }
                    Spacer()
                }
            }

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    if idx < items.count {
                        Text(items[idx].title)
                            .font(.headline).foregroundStyle(.white)
                    }
                    Spacer()
                    if items.count > 1 {
                        Text("\(idx + 1) / \(items.count)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(.ultraThinMaterial.opacity(0.85))
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)

                Spacer()

                if items.count > 1 && items.count <= 24 {
                    HStack(spacing: 6) {
                        ForEach(0..<items.count, id: \.self) { i in
                            Circle()
                                .fill(i == idx ? Color.white : Color.white.opacity(0.35))
                                .frame(width: i == idx ? 8 : 6, height: i == idx ? 8 : 6)
                                .onTapGesture { state.currentIndex = i }
                                .animation(.easeInOut(duration: 0.15), value: idx)
                        }
                    }
                    .padding(.bottom, 24)
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
            }
        }
        .background(AutoFullScreenHelper())
        .onHover { isHovered = $0 }
        .onKeyPress(.leftArrow) {
            if idx > 0 { state.currentIndex -= 1 }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if idx < items.count - 1 { state.currentIndex += 1 }
            return .handled
        }
    }

    @ViewBuilder
    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.2)
        .disabled(!enabled)
    }
}

// MARK: - Auto full screen

private struct AutoFullScreenHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = nsView.window else { return }
            window.collectionBehavior = [.fullScreenPrimary, .managed]
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
}
