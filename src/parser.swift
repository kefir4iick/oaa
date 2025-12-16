import Foundation
import SwiftUI

struct Row {
    let id: Int
    var values: [String]
}

struct Table {
    var name: String
    var columns: [String]
    var rows: [Row] = []

    var nextRowID: Int = 1
    var rowIndexByID: [Int: Int] = [:]
    var indexes: [String: BSTIndex] = [:]
}

final class Parser: ObservableObject {

    @Published var database: [String: Table] = [:]
    private let identifierRegex = try! NSRegularExpression(pattern: "^[a-zA-Z][a-zA-Z0-9_]*$")



    func execute(_ script: String) -> String {
        let commands = normalizeScript(script)
        guard !commands.isEmpty else { return "enter request pls" }

        var result: [String] = []

        for q in commands {
            let u = q.uppercased()

            if u.hasPrefix("CREATE TABLE") {
                result.append(createTable(q))
            } else if u.hasPrefix("CREATE INDEX") {
                result.append(createIndex(q))
            } else if u.hasPrefix("INSERT INTO") {
                result.append(insertInto(q))
            } else if u.hasPrefix("SELECT") {
                if u.contains("JOIN") && u.contains("ON") {
                    result.append(selectWithJoin(q))
                } else {
                    result.append(selectFrom(q))
                }
            } else if u.hasPrefix("DROP TABLE") {
                result.append(dropTable(q))
            } else {
                result.append("idk")
            }
        }
        return result.joined(separator: "\n")
    }



    private func normalizeScript(_ script: String) -> [String] {
        var out: [String] = []
        var cur = ""
        var inString = false

        for c in script {
            if c == "\"" {
                inString.toggle()
            }
            if c == ";" && !inString {
                if !cur.trimmingCharacters(in: .whitespaces).isEmpty {
                    out.append(cur.trimmingCharacters(in: .whitespaces))
                }
                cur = ""
            } else {
                cur.append(c)
            }
        }

        if !cur.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(cur.trimmingCharacters(in: .whitespaces))
        }
        return out
    }



    private func createTable(_ q: String) -> String {
        guard let o = q.firstIndex(of: "("),
              let c = q.firstIndex(of: ")") else { return "error" }

        let name = q[..<o]
            .replacingOccurrences(of: "(?i)CREATE TABLE", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let cols = q[q.index(after: o)..<c]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        database[name] = Table(name: name, columns: cols)
        return "table \(name) created"
    }

    private func createIndex(_ q: String) -> String {
        let u = q.uppercased()
        guard let on = u.range(of: "ON") else { return "error" }

        let part = q[on.upperBound...].trimmingCharacters(in: .whitespaces)
        guard let o = part.firstIndex(of: "("),
              let c = part.firstIndex(of: ")") else { return "error" }

        let t = String(part[..<o])
        let col = String(part[part.index(after: o)..<c])

        guard var table = database[t],
              let idx = table.columns.firstIndex(of: col) else { return "error" }

        let tree = BSTIndex()
        for r in table.rows {
            tree.insert(key: IndexKey.from(r.values[idx]), rowID: r.id)
        }

        table.indexes[col] = tree
        database[t] = table
        return "index created on \(t)(\(col))"
    }

    private func insertInto(_ q: String) -> String {
        guard let v = q.range(of: "(?i)VALUES", options: .regularExpression),
              let o = q.firstIndex(of: "("),
              let c = q.firstIndex(of: ")") else { return "error" }

        let t = q[..<v.lowerBound]
            .replacingOccurrences(of: "(?i)INSERT INTO", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        guard var table = database[t] else { return "no table" }

        let vals = q[q.index(after: o)..<c]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let id = table.nextRowID
        table.nextRowID += 1

        let row = Row(id: id, values: vals)
        table.rows.append(row)
        table.rowIndexByID[id] = table.rows.count - 1

        for (col, idx) in table.indexes {
            if let i = table.columns.firstIndex(of: col) {
                idx.insert(key: IndexKey.from(vals[i]), rowID: id)
            }
        }

        database[t] = table
        return "row added"
    }



    private func indexedJoin(
        left: Table,
        right: Table,
        lcol: String,
        rcol: String
    ) -> [[String]] {


        if let idx = right.indexes[rcol],
           let li = left.columns.firstIndex(of: lcol) {

            var out: [[String]] = []
            for r in left.rows {
                let key = IndexKey.from(r.values[li])
                for id in idx.findEqual(key) {
                    if let pos = right.rowIndexByID[id] {
                        out.append(r.values + right.rows[pos].values)
                    }
                }
            }
            return out
        }


        if let idx = left.indexes[lcol],
           let ri = right.columns.firstIndex(of: rcol) {

            var out: [[String]] = []
            for r in right.rows {
                let key = IndexKey.from(r.values[ri])
                for id in idx.findEqual(key) {
                    if let pos = left.rowIndexByID[id] {
                        out.append(left.rows[pos].values + r.values)
                    }
                }
            }
            return out
        }


        guard let li = left.columns.firstIndex(of: lcol),
              let ri = right.columns.firstIndex(of: rcol) else { return [] }

        var out: [[String]] = []
        for a in left.rows {
            for b in right.rows {
                if a.values[li] == b.values[ri] {
                    out.append(a.values + b.values)
                }
            }
        }
        return out
    }



    private func selectWithJoin(_ q: String) -> String {
        let u = q.uppercased()
        let afterFrom = q[u.range(of: "FROM")!.upperBound...]

        let jp = afterFrom.components(separatedBy: .whitespaces)
        let t1 = jp[0]
        let t2 = jp[2]

        guard let table1 = database[t1],
              let table2 = database[t2] else { return "error" }

        let onIdx = jp.firstIndex(of: "ON")!
        let on = jp[onIdx + 1].components(separatedBy: "=")

        let l = on[0].components(separatedBy: ".")
        let r = on[1].components(separatedBy: ".")

        let rows = indexedJoin(
            left: table1,
            right: table2,
            lcol: l[1],
            rcol: r[1]
        )

        if rows.isEmpty { return "no rows" }

        let header =
            table1.columns.map { "\(t1).\($0)" } +
            table2.columns.map { "\(t2).\($0)" }

        var res = header.joined(separator: " | ") + "\n"
        for r in rows {
            res += r.joined(separator: " | ") + "\n"
        }
        return res
    }


    private func selectFrom(_ q: String) -> String {
        return "simple select"
    }

    private func dropTable(_ q: String) -> String {
        let name = q.components(separatedBy: .whitespaces)[2]
        database.removeValue(forKey: name)
        return "table dropped"
    }
}
