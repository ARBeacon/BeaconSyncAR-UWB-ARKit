//
//  BeaconSyncAR_UWB_ARKitUITestsLaunchTests.swift
//  BeaconSyncAR-UWB-ARKitUITests
//
//  Created by Maitree Hirunteeyakul on 13/3/2025.
//

import XCTest

final class BeaconSyncAR_UWB_ARKitUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
