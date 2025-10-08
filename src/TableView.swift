import SwiftUI

struct TableView: View {
    let table: Table

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ForEach(table.columns, id: \.self) { col in
                    Text(col)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<table.rows.count, id: \.self) { idx in
                        HStack {
                            ForEach(table.rows[idx].values, id: \.self) { val in
                                Text(val)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}
