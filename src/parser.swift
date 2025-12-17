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
                if upper.contains("JOIN") && upper.contains("ON") {
                    results.append(selectWithJoin(query))
                } else {
                    results.append(selectFrom(query))
                }
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

        let afterFrom = query[fromRange.upperBound...].trimmingCharacters(in: .whitespaces)
        
        var tableName = ""
        var whereClause: String? = nil

        if let whereRange = afterFrom.uppercased().range(of: "WHERE") {
            tableName = afterFrom[..<whereRange.lowerBound].trimmingCharacters(in: .whitespaces)
            whereClause = afterFrom[whereRange.upperBound...].trimmingCharacters(in: .whitespaces)
        } else {
            tableName = afterFrom.components(separatedBy: .whitespaces).first ?? ""
        }

        let columnsPart = query[..<fromRange.lowerBound]
            .replacingOccurrences(of: "(?i)SELECT", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

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
            selectedColumns = columnsPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
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

            if let cond = whereClause {
                if !matchesWhere(values: row.values, columns: table.columns, condition: cond) {
                    continue
                }
            }

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
    
    
    
    
    private func selectWithJoin(_ query: String) -> String {
        let upper = query.uppercased()

        guard let fromRange = upper.range(of: "FROM") else {
            return "error in select: no FROM"
        }

        let columnsPart = query[..<fromRange.lowerBound]
            .replacingOccurrences(of: "(?i)SELECT", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let afterFrom = query[fromRange.upperBound...].trimmingCharacters(in: .whitespaces)
        let afterFromUpper = afterFrom.uppercased()

        var whereClause: String? = nil
        var joinPart = afterFrom

        if let whereRange = afterFromUpper.range(of: "WHERE") {
            joinPart = afterFrom[..<whereRange.lowerBound].trimmingCharacters(in: .whitespaces)
            whereClause = afterFrom[whereRange.upperBound...].trimmingCharacters(in: .whitespaces)
        }

        let joinUpper = joinPart.uppercased()

        guard let joinRange = joinUpper.range(of: "JOIN"),
              let onRange = joinUpper.range(of: "ON") else {
            return "error in join: missing JOIN or ON"
        }

        let table1Name = joinPart[..<joinRange.lowerBound].trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)[0]
        let table2Name = joinPart[joinRange.upperBound..<onRange.lowerBound].trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)[0]

        let onCondition = joinPart[onRange.upperBound...].trimmingCharacters(in: .whitespaces)

        guard let table1 = database[table1Name],
              let table2 = database[table2Name] else {
            return "error: one or both tables not exist"
        }

        let onParts = onCondition.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
        guard onParts.count == 2 else { return "error in join: invalid ON" }

        func parseON(_ s: String) -> (String, String)? {
            let p = s.components(separatedBy: ".")
            return p.count == 2 ? (p[0], p[1]) : nil
        }

        guard
            let (leftTable, leftColumn) = parseON(onParts[0]),
            let (rightTable, rightColumn) = parseON(onParts[1])
        else { return "error in join: invalid ON structure" }

        guard
            let leftIndex = database[leftTable]?.columns.firstIndex(of: leftColumn),
            let rightIndex = database[rightTable]?.columns.firstIndex(of: rightColumn)
        else { return "error in join: columns not found" }

        var joinedRows: [[String]] = []

        for r1 in table1.rows {
            for r2 in table2.rows {
                let leftValue = (leftTable == table1Name) ? r1.values[leftIndex] : r2.values[leftIndex]
                let rightValue = (rightTable == table1Name) ? r1.values[rightIndex] : r2.values[rightIndex]

                if leftValue == rightValue {
                    joinedRows.append(r1.values + r2.values)
                }
            }
        }

        if joinedRows.isEmpty { return "no matching rows found" }

        let fullColumns = table1.columns.map { "\(table1Name).\($0)" } +
                          table2.columns.map { "\(table2Name).\($0)" }

        let selectedColumns: [String] =
            (columnsPart == "*")
            ? fullColumns
            : columnsPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let indexes = selectedColumns.compactMap { fullColumns.firstIndex(of: $0) }

        if let cond = whereClause {
            joinedRows = joinedRows.filter { row in
                matchesWhere(values: row, columns: fullColumns, condition: cond)
            }
        }

        if joinedRows.isEmpty { return "no rows after WHERE" }

        var result = selectedColumns.joined(separator: " | ") + "\n"
        for r in joinedRows {
            let filtered = indexes.map { r[$0] }
            result += filtered.joined(separator: " | ") + "\n"
        }
        return result
    }



    private func findColumnIndex(tableName: String, column: String) -> (table: Table, index: Int)? {
        guard let table = database[tableName],
              let index = table.columns.firstIndex(of: column) else {
            return nil
        }
        return (table, index)
    }
    
    
    
    private func matchesWhere(values: [String], columns: [String], condition: String) -> Bool {
        let ops = ["<=", ">=", "=", ">", "<"]
        var op: String?

        for o in ops {
            if condition.contains(o) {
                op = o
                break
            }
        }
        guard let oper = op else { return false }

        let parts = condition.components(separatedBy: oper)
        guard parts.count == 2 else { return false }

        let left = parts[0].trimmingCharacters(in: .whitespaces)
        var right = parts[1].trimmingCharacters(in: .whitespaces)

        if right.hasPrefix("\"") && right.hasSuffix("\"") {
            right = String(right.dropFirst().dropLast())
        }

        guard let idx = columns.firstIndex(of: left) else { return false }
        let value = values[idx]

        if let vNum = Double(value), let rNum = Double(right) {
            switch oper {
            case ">": return vNum > rNum
            case "<": return vNum < rNum
            case "=": return vNum == rNum
            case ">=": return vNum >= rNum
            case "<=": return vNum <= rNum
            default: return false
            }
        }

        if oper == "=" {
            return value == right
        }

        return false
    }
        
}
