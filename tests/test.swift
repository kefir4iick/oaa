import XCTest
@testable import oaaApp

final class ParserTests: XCTestCase {
    var parser: Parser!

    override func setUp() {
        super.setUp()
        parser = Parser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }



    func test1() {
        let result = parser.execute("CREATE TABLE users (id, name);")
        XCTAssertEqual(result, "table (users) created")
        XCTAssertNotNil(parser.database["users"])
        XCTAssertEqual(parser.database["users"]?.columns, ["id", "name"])
    }

    func test2() {
        let result = parser.execute("CREATE TABLE 123users (id, name);")
        XCTAssertTrue(result.contains("error in create: wrong name of table"))
    }

    func test3() {
        _ = parser.execute("CREATE TABLE users (id, name);")
        let result = parser.execute("CREATE TABLE users (id, name);")
        XCTAssertEqual(result, "error: table (users) already exists")
    }

    func test4() {
        _ = parser.execute("CREATE TABLE users (id, name);")
        let result = parser.execute("INSERT INTO users VALUES (1, \"Alice\");")
        XCTAssertEqual(result, "row added to table (users)")
        XCTAssertEqual(parser.database["users"]?.rows.count, 1)
        XCTAssertEqual(parser.database["users"]?.rows.first?.values, ["1", "\"Alice\""])
    }

    func test5() {
        let result = parser.execute("INSERT INTO ghosts VALUES (1, \"Bob\");")
        XCTAssertEqual(result, "error: table (ghosts) not exist")
    }

    func test6() {
        _ = parser.execute("CREATE TABLE users (id, name);")
        let result = parser.execute("INSERT INTO users VALUES (1);")
        XCTAssertEqual(result, "error: number of values not equal to number of columns")
    }

    func test7() {
        _ = parser.execute("CREATE TABLE users (id, name);")
        _ = parser.execute("INSERT INTO users VALUES (1, \"Alice\");")
        _ = parser.execute("INSERT INTO users VALUES (2, \"Bob\");")

        let result = parser.execute("SELECT * FROM users;")
        let expectedHeader = "id | name"
        XCTAssertTrue(result.contains(expectedHeader))
        XCTAssertTrue(result.contains("1 | \"Alice\""))
        XCTAssertTrue(result.contains("2 | \"Bob\""))
    }

    func test8() {
        _ = parser.execute("CREATE TABLE users (id, name, age);")
        _ = parser.execute("INSERT INTO users VALUES (1, \"Alice\", 25);")

        let result = parser.execute("SELECT name, age FROM users;")
        XCTAssertTrue(result.contains("name | age"))
        XCTAssertTrue(result.contains("\"Alice\" | 25"))
    }

    func test9() {
    _ = parser.execute("CREATE TABLE users (id, name);")
    _ = parser.execute("INSERT INTO users VALUES (1, \"Alice\");")
    let result = parser.execute("SELECT age FROM users;")
    XCTAssertTrue(result.contains("error in select: column (age) not exist"))
    }

    func test10() {
        let result = parser.execute("SELECT * FROM ghosts;")
        XCTAssertEqual(result, "error: table (ghosts) not exist")
    }

    func test11() {
        _ = parser.execute("CREATE TABLE users (id, name);")
        let result = parser.execute("SELECT * FROM users;")
        XCTAssertEqual(result, "table (users) is empty")
    }

    func test12() {
        _ = parser.execute("CREATE TABLE users (id, name);")
        let result = parser.execute("DROP TABLE users;")
        XCTAssertEqual(result, "table (users) deleted")
        XCTAssertNil(parser.database["users"])
    }

    func test13() {
        let result = parser.execute("DROP TABLE ghosts;")
        XCTAssertEqual(result, "error: table (ghosts) not exist")
    }

    func test14() {
        let script = """
        CREATE TABLE users (id, name);
        INSERT INTO users VALUES (1, "Alice");
        SELECT * FROM users;
        """
        let result = parser.execute(script)
        XCTAssertTrue(result.contains("table (users) created"))
        XCTAssertTrue(result.contains("row added to table (users)"))
        XCTAssertTrue(result.contains("id | name"))
    }

    func test15() {
        let result = parser.execute("UPDATE users SET name=\"Bob\";")
        XCTAssertEqual(result, "idk")
    }

    func test16() {
        let result = parser.execute("  ")
        XCTAssertEqual(result, "enter request pls")
    }

    func test17() {
        let script = """
        CREATE   TABLE
        users
        (id,
        name)
        ;
        """
        let result = parser.execute(script)
        XCTAssertEqual(result, "table (users) created")
    }
}
