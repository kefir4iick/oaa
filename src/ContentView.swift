import SwiftUI

struct ContentView: View {
    @State private var scriptText: String = ""
    @State private var outputLog: String = "log..."
    @StateObject private var parser = Parser()
    @State private var selectedTable: String?

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                if parser.database.isEmpty {
                    Text("visualization")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    Picker("table", selection: $selectedTable) {
                        ForEach(Array(parser.database.keys), id: \.self) { tableName in
                            Text(tableName).tag(Optional(tableName))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if let selectedTable, let table = parser.database[selectedTable] {
                        TableView(table: table)
                    } else {
                        Text("choose table pls")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 300)
            .background(Color.gray.opacity(0.1))

            Divider()

            VStack(alignment: .leading) {
                Text("script:")
                    .font(.headline)

                TextEditor(text: $scriptText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray, width: 1)

                HStack {
                    Button("start") {
                        runParser()
                    }
                    .keyboardShortcut(.return, modifiers: [.command])

                    Spacer()
                }

                ScrollView {
                    Text(outputLog)
                        .font(.system(.footnote, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                }
            }
            .padding()
            .frame(minWidth: 400)
        }
    }

    private func runParser() {
        let result = parser.execute(scriptText)
        outputLog = result

        if selectedTable == nil, let any = parser.database.keys.first {
            selectedTable = any
        }
    }
}

#Preview {
    ContentView()
}
