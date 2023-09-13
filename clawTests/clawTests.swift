//
//  clawTests.swift
//  clawTests
//
//  Created by Zachary Gorak on 9/11/20.
//

import XCTest
@testable import claw

class clawTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let scheme = Settings.CommentColorScheme.custom(.blue, .link, .black, .black, .black.withAlphaComponent(0.7), .black, .red)
        let data = try JSONEncoder().encode(scheme)
        let converted = try JSONDecoder().decode(Settings.CommentColorScheme.self, from: data)
        XCTAssertEqual(scheme, converted)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
