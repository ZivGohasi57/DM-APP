import SwiftUI

struct CatalogItemDetailView: View {
    let item: CatalogItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                CatalogItemBody(item: item)
            }
            .padding(24)
        }
        .frame(width: 560, height: 640)
    }
}
