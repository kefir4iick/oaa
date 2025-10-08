import Foundation
import SwiftUI

struct Row {
    var values: [String]
}

struct Table {
    var name: String
    var columns: [String]
    var rows: [Row] = []
}

class Parser: ObservableObject {
    @Published var database: [String: Table] = [:]

    private let identifierRegex = try! NSRegularExpression(pattern: "^[a-zA-Z][a-zA-Z0-9_]*$")

    func execute(_ script: String) -> String {
        let commands = normalizeScript(script)
        guard !commands.isEmpty else { return "enter request pls" }

        var results: [String] = []

        for query in commands {
            let upper = query.uppercased()

            if upper.hasPrefix("CREATE TABLE") {
                results.append(createTable(query))
            } else if upper.hasPrefix("INSERT INTO") {
                results.append(insertInto(query))
            } else if upper.hasPrefix("SELECT") {
                results.append(selectFrom(query))
            } else if upper.hasPrefix("DROP TABLE") {
                results.append(dropTable(query))
            } else {
                results.append("idk")
            }
        }

        return results.joined(separator: "\n")
    }


    private func normalizeScript(_ script: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inString = false
        var lastWasSpace = false

        for ch in script {
            if ch == "\"" {
                inString.toggle()
                current.append(ch)
                lastWasSpace = false
            } else if ch == ";" && !inString {
                if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                }
                current = ""
                lastWasSpace = false
            } else if [" ", "\t", "\r", "\n"].contains(ch) {
                if inString {
                    current.append(ch)
                } else if !lastWasSpace {
                    current.append(" ")
                    lastWasSpace = true
                }
            } else {
                current.append(ch)
                lastWasSpace = false
            }
        }

        return result
    }


    private func isValidIdentifier(_ name: String) -> Bool {
        let range = NSRange(location: 0, length: name.utf16.count)
        return identifierRegex.firstMatch(in: name, options: [], range: range) != nil
    }


    private func createTable(_ query: String) -> String {
        guard let open = query.firstIndex(of: "("),
              let close = query.firstIndex(of: ")") else {
            return "error in create: no brackets"
        }

        let headerPart = query[..<open].replacingOccurrences(of: "(?i)CREATE TABLE", with: "", options: .regularExpression)
        let tableName = headerPart.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidIdentifier(tableName) else {
            return "error in create: wrong name of table (\(tableName))"
        }

        let colsPart = query[query.index(after: open)..<close]
        let cols = colsPart
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard !cols.isEmpty else {
            return "error in create: no columns"
        }

        for col in cols {
            if !isValidIdentifier(col) {
                return "error in create: wrong name of column (\(col))"
            }
        }

        if database[tableName] != nil {
            return "error: table (\(tableName)) already exists"
        }

        database[tableName] = Table(name: tableName, columns: cols)
        return "table (\(tableName)) created"
    }

    private func insertInto(_ query: String) -> String {
        guard let valuesStart = query.range(of: "(?i)VALUES", options: .regularExpression),
              let open = query.firstIndex(of: "("),
              let close = query.firstIndex(of: ")") else {
            return "error in insert: syntax"
        }

        let header = query[..<valuesStart.lowerBound].replacingOccurrences(of: "(?i)INSERT INTO", with: "", options: .regularExpression)
        let tableName = header.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidIdentifier(tableName) else {
            return "error in insert: wrong name of table (\(tableName))"
        }

        guard var table = database[tableName] else {
            return "error: table (\(tableName)) not exist"
        }

        let valsPart = query[query.index(after: open)..<close]
        let vals = valsPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if vals.count != table.columns.count {
            return "error: number of values not equal to number of columns"
        }

        table.rows.append(Row(values: vals))
        database[tableName] = table
        return "row added to table (\(tableName))"
    }

    private func selectFrom(_ query: String) -> String {
        let upper = query.uppercased()
        guard let fromRange = upper.range(of: "FROM") else {
            return "error in select: no from"
        }

        let columnsPart = query[..<fromRange.lowerBound]
            .replacingOccurrences(of: "(?i)SELECT", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tablePart = query[fromRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let tableName = tablePart.components(separatedBy: .whitespaces).first ?? ""

        guard isValidIdentifier(tableName) else {
            return "error in select: wrong name of table (\(tableName))"
        }

        guard let table = database[tableName] else {
            return "error: table (\(tableName)) not exist"
        }

        guard !table.rows.isEmpty else {
            return "table (\(tableName)) is empty"
        }

        let selectedColumns: [String]
        if columnsPart == "*" {
            selectedColumns = table.columns
        } else {
            selectedColumns = columnsPart
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }

        for col in selectedColumns {
            if !isValidIdentifier(col) {
                return "error in select: wrong name of column (\(col))"
            }
        }

        var colIndexes: [Int] = []
        for col in selectedColumns {
            if let idx = table.columns.firstIndex(of: col) {
                colIndexes.append(idx)
            } else {
                return "error in select: column (\(col)) not exist in (\(tableName))"
            }
        }

        var result = selectedColumns.joined(separator: " | ") + "\n"
        for row in table.rows {
            let filtered = colIndexes.map { row.values[$0] }
            result += filtered.joined(separator: " | ") + "\n"
        }
        return result
    }

    private func dropTable(_ query: String) -> String {
        let parts = query.components(separatedBy: .whitespaces)
        guard parts.count >= 3 else { return "error in drop: syntax" }
        let tableName = parts[2]

        guard isValidIdentifier(tableName) else {
            return "error in drop: wrong name of table (\(tableName))"
        }

        guard database[tableName] != nil else {
            return "error: table (\(tableName)) not exist"
        }

        database.removeValue(forKey: tableName)
        return "table (\(tableName)) deleted"
    }
}
