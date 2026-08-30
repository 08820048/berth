import XCTest
@testable import Berth

final class LsofParserTests: XCTestCase {
    func testParsesIPv4AndIPv6ListenSocketsForSameProcess() {
        let output = """
        p18422
        cnode
        u501
        PTCP
        n127.0.0.1:3000
        TST=LISTEN
        PTCP
        n[::1]:3000
        TST=LISTEN
        """
        let sockets = LsofParser.parse(output)
        XCTAssertEqual(sockets.count, 2)
        XCTAssertEqual(Set(sockets.map(\.port)), [3000])
        XCTAssertEqual(Set(sockets.map(\.address)), ["127.0.0.1", "::1"])
        XCTAssertEqual(sockets.map(\.pid), [18422, 18422])
        XCTAssertEqual(sockets.first?.processName, "node")
    }

    func testParsesWildcardAndIPv6AllInterfaces() {
        let output = """
        p99
        cvite
        u501
        PTCP
        n*:5173
        TST=LISTEN
        p100
        cnext-server
        u501
        PTCP
        n[::]:4000
        TST=LISTEN
        """
        let sockets = LsofParser.parse(output)
        XCTAssertEqual(sockets.map(\.address), ["*", "*"])
        XCTAssertEqual(sockets.map(\.port), [5173, 4000])
    }

    func testParseNameHandlesBracketIPv6() {
        let parsed = LsofParser.parseName("[::1]:8080")
        XCTAssertEqual(parsed?.address, "::1")
        XCTAssertEqual(parsed?.port, 8080)
    }
}
