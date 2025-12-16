import Foundation

enum IndexKey: Comparable {
    case number(Double)
    case text(String)

    static func from(_ raw: String) -> IndexKey {
        if let d = Double(raw) {
            return .number(d)
        }
        return .text(raw)
    }

    static func < (lhs: IndexKey, rhs: IndexKey) -> Bool {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            return a < b
        case (.text(let a), .text(let b)):
            return a < b
        case (.number, .text):
            return true
        case (.text, .number):
            return false
        }
    }
}

final class BSTNode {
    var key: IndexKey
    var rowIDs: [Int]
    var left: BSTNode?
    var right: BSTNode?

    init(key: IndexKey, rowID: Int) {
        self.key = key
        self.rowIDs = [rowID]
    }
}

final class BSTIndex {
    private var root: BSTNode?

    func insert(key: IndexKey, rowID: Int) {
        root = insertNode(root, key, rowID)
    }

    private func insertNode(_ node: BSTNode?, _ key: IndexKey, _ rowID: Int) -> BSTNode {
        guard let node else {
            return BSTNode(key: key, rowID: rowID)
        }

        if key == node.key {
            node.rowIDs.append(rowID)
        } else if key < node.key {
            node.left = insertNode(node.left, key, rowID)
        } else {
            node.right = insertNode(node.right, key, rowID)
        }
        return node
    }

    func findEqual(_ key: IndexKey) -> [Int] {
        var cur = root
        while let node = cur {
            if node.key == key { return node.rowIDs }
            cur = (key < node.key) ? node.left : node.right
        }
        return []
    }

    func findLessThan(_ key: IndexKey, inclusive: Bool) -> [Int] {
        var out: [Int] = []
        collectLess(root, key, inclusive, &out)
        return out
    }

    func findGreaterThan(_ key: IndexKey, inclusive: Bool) -> [Int] {
        var out: [Int] = []
        collectGreater(root, key, inclusive, &out)
        return out
    }

    private func collectLess(_ node: BSTNode?, _ key: IndexKey, _ inclusive: Bool, _ out: inout [Int]) {
        guard let node else { return }

        if node.key < key || (inclusive && node.key == key) {
            collectLess(node.left, key, inclusive, &out)
            out.append(contentsOf: node.rowIDs)
            collectLess(node.right, key, inclusive, &out)
        } else {
            collectLess(node.left, key, inclusive, &out)
        }
    }

    private func collectGreater(_ node: BSTNode?, _ key: IndexKey, _ inclusive: Bool, _ out: inout [Int]) {
        guard let node else { return }

        if node.key > key || (inclusive && node.key == key) {
            collectGreater(node.left, key, inclusive, &out)
            out.append(contentsOf: node.rowIDs)
            collectGreater(node.right, key, inclusive, &out)
        } else {
            collectGreater(node.right, key, inclusive, &out)
        }
    }
}
