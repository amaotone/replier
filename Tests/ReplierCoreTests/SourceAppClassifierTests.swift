import Testing
@testable import ReplierCore

@Suite struct SourceAppClassifierTests {
    @Test func classifiesSlack() {
        #expect(SourceAppClassifier.classify(bundleID: "com.tinyspeck.slackmacgap") == .slack)
    }

    @Test func classifiesAppleMail() {
        #expect(SourceAppClassifier.classify(bundleID: "com.apple.mail") == .mail)
    }

    @Test func classifiesOutlook() {
        #expect(SourceAppClassifier.classify(bundleID: "com.microsoft.Outlook") == .mail)
    }

    @Test func classifiesSpark() {
        #expect(SourceAppClassifier.classify(bundleID: "com.readdle.smartemail-Mac") == .mail)
    }

    @Test func classifiesSafari() {
        #expect(SourceAppClassifier.classify(bundleID: "com.apple.Safari") == .browser)
    }

    @Test func classifiesChrome() {
        #expect(SourceAppClassifier.classify(bundleID: "com.google.Chrome") == .browser)
    }

    @Test func classifiesChromeCanary() {
        #expect(SourceAppClassifier.classify(bundleID: "com.google.Chrome.canary") == .browser)
    }

    @Test func classifiesFirefox() {
        #expect(SourceAppClassifier.classify(bundleID: "org.mozilla.firefox") == .browser)
    }

    @Test func classifiesEdge() {
        #expect(SourceAppClassifier.classify(bundleID: "com.microsoft.edgemac") == .browser)
    }

    @Test func classifiesArc() {
        #expect(SourceAppClassifier.classify(bundleID: "company.thebrowser.Browser") == .browser)
    }

    @Test func classifiesBrave() {
        #expect(SourceAppClassifier.classify(bundleID: "com.brave.Browser") == .browser)
    }

    @Test func classifiesVivaldi() {
        #expect(SourceAppClassifier.classify(bundleID: "com.vivaldi.Vivaldi") == .browser)
    }

    @Test func classifiesZedAsOther() {
        #expect(SourceAppClassifier.classify(bundleID: "dev.zed.Zed") == .other)
    }

    @Test func classifiesUnknownBundleIDAsOther() {
        #expect(SourceAppClassifier.classify(bundleID: "com.example.somethingunknown") == .other)
    }

    @Test func classifiesNilAsOther() {
        #expect(SourceAppClassifier.classify(bundleID: nil) == .other)
    }

    @Test func classifiesCaseInsensitively() {
        #expect(SourceAppClassifier.classify(bundleID: "COM.TINYSPECK.SLACKMACGAP") == .slack)
        #expect(SourceAppClassifier.classify(bundleID: "Com.Apple.Mail") == .mail)
        #expect(SourceAppClassifier.classify(bundleID: "Com.Apple.Safari") == .browser)
    }
}
