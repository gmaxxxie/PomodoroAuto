import Foundation
import XCTest

final class ReleaseAutomationTests: XCTestCase {
    func testPackageReleaseScriptBuildsDmgArtifact() throws {
        let content = try readFile(path: "scripts/package-release.sh")
        XCTAssertTrue(content.contains("hdiutil create"), "Release package script should create a DMG artifact.")
        XCTAssertTrue(content.contains("-macOS.dmg"), "Release package script should emit a macOS DMG filename.")
    }

    func testReleaseWorkflowPublishesDmgAsset() throws {
        let content = try readFile(path: ".github/workflows/release.yml")
        XCTAssertTrue(
            content.contains("PomodoroAuto-${{ steps.resolve_tag.outputs.tag }}-macOS.dmg"),
            "Release workflow should upload and publish DMG artifacts."
        )
    }

    func testReleaseWorkflowDoesNotUseUnsupportedInputsContextOnPush() throws {
        let content = try readFile(path: ".github/workflows/release.yml")
        XCTAssertFalse(
            content.contains("${{ inputs.tag }}"),
            "Push-triggered workflows should not rely on the workflow_dispatch-only inputs context."
        )
    }

    private func readFile(path: String) throws -> String {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileURL = root.appendingPathComponent(path)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
