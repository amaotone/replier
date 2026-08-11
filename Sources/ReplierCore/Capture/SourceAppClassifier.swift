public enum SourceAppClassifier {
    private static let slackIDs: Set<String> = [
        "com.tinyspeck.slackmacgap",
    ]

    private static let mailIDs: Set<String> = [
        "com.apple.mail",
        "com.microsoft.outlook",
        "com.readdle.smartemail-mac",
    ]

    private static let browserIDs: Set<String> = [
        "com.apple.safari",
        "com.google.chrome",
        "com.google.chrome.canary",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "company.thebrowser.browser",
        "com.brave.browser",
        "com.vivaldi.vivaldi",
    ]

    public static func classify(bundleID: String?) -> SourceApp {
        guard let bundleID else { return .other }
        let normalized = bundleID.lowercased()

        if slackIDs.contains(normalized) { return .slack }
        if mailIDs.contains(normalized) { return .mail }
        if browserIDs.contains(normalized) { return .browser }
        return .other
    }
}
