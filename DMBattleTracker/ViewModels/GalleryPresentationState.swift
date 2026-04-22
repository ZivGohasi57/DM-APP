import Foundation

struct GalleryPresentationItem {
    var title: String
    var data: Data
    var symbolData: Data? = nil
}

@Observable final class GalleryPresentationState {
    var items: [GalleryPresentationItem] = []
    var currentIndex: Int = 0
}
