import SwiftUI

struct DamageResponseGrid: View {
    @Binding var responses: [String: String]

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(DamageType.allCases) { type in
                HStack(spacing: 8) {
                    Text(type.rawValue)
                        .font(.subheadline)
                        .frame(width: 94, alignment: .leading)
                        .lineLimit(1)

                    Picker("", selection: Binding(
                        get: { DamageResponse(rawValue: responses[type.rawValue] ?? "") ?? .regular },
                        set: { responses[type.rawValue] = $0.rawValue }
                    )) {
                        ForEach(DamageResponse.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 116)
                }
            }
        }
        .padding(14)
    }
}
