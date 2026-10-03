//
//  WhatsNewView.swift
//  Ordir
//
//  "Since last time": after an update, what Ordi fixed and improved in the releases this phone hasn't seen, once,
//  on Home. Settings' "What's new" shows the last few releases. The lines come from whats_new.json, which the
//  preview shares (lines marked "only": "preview" are left out); each is translated in strings.json.
//

import SwiftUI

enum WhatsNew {
    struct Release: Decodable, Identifiable {
        struct Item: Decodable {
            let text: String
            let only: String?
        }

        let id: String
        let items: [Item]
    }

    /// Newest first, keeping only the lines that apply to the app.
    static let releases: [Release] = {
        guard let url = Bundle.main.url(forResource: "whats_new", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([Release].self, from: data) else { return [] }
        return all
            .map { Release(id: $0.id, items: $0.items.filter { $0.only != "preview" }) }
            .filter { !$0.items.isEmpty }
    }()

    private static let seenKey = "OrdirNewsSeen"

    /// Releases newer than the last one seen; a phone that played before this screen existed gets the latest one.
    static var unseen: [Release] {
        guard let seen = UserDefaults.standard.string(forKey: seenKey) else { return Array(releases.prefix(1)) }
        return Array(releases.filter { $0.id > seen }.prefix(3))
    }

    /// Everything so far counts as seen (after this screen, or after a first launch's tutorial).
    static func markSeen() {
        if let latest = releases.first { UserDefaults.standard.set(latest.id, forKey: seenKey) }
    }
}

struct WhatsNewView: View {
    /// From Settings: the last few releases, titled "What's new". Otherwise the unseen ones, "Since last time".
    var all = false
    @Environment(\.dismiss) private var dismiss
    private let releases: [WhatsNew.Release]

    init(all: Bool = false) {
        self.all = all
        releases = all ? Array(WhatsNew.releases.prefix(5)) : WhatsNew.unseen
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 8) {
                        OrdirMascotView(isSpeaking: true).frame(width: 88)
                        Text(all ? tr("What’s new") : tr("Since last time"))
                            .font(.ordir(.title).weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(all ? tr("Everything Ordi has fixed and improved lately.") : tr("Ordi fixed and improved a few things:"))
                            .font(.ordir(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    ForEach(releases) { release in
                        Text(Self.day(release.id))
                            .font(.ordir(.footnote).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(release.items.indices, id: \.self) { index in
                                if index > 0 { Divider() }
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Circle()
                                        .fill(Color.ordirSparkle)
                                        .frame(width: 7, height: 7)
                                        .accessibilityHidden(true)
                                    Text(tr(release.items[index].text))
                                        .font(.ordir(.subheadline))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text(tr("Got it"))
                        .font(.ordir(.headline))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("news-done")
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.black)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Close")) { dismiss() }
                }
            }
        }
        .onAppear { WhatsNew.markSeen() }
    }

    /// "3 October", in the language Ordir speaks.
    private static func day(_ id: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: id) else { return id }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: OrdirLanguage.current.rawValue)
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: date)
    }
}

#Preview {
    WhatsNewView().preferredColorScheme(.dark)
}
