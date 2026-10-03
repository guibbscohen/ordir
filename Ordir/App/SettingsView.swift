//
//  SettingsView.swift
//  Ordir
//
//  Ordir Pro (coming soon), the language Ordir speaks, the tutorial again and what's new. Opened from Home's gear (the
//  preview has these on its Account tab).
//

import SwiftUI

struct SettingsView: View {
    /// Closes Settings and plays the tutorial.
    let replayTutorial: () -> Void
    @AppStorage(OrdirLanguage.storageKey) private var language = OrdirLanguage.current.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var showsPro = false
    @State private var showsNews = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showsPro = true
                    } label: {
                        HStack(spacing: 14) {
                            OrdirMascotView(isCool: true)
                                .frame(width: 44)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                ProMark()
                                Text(tr("Free plan · {0} rules questions a month", OrdirPro.freeQuestions))
                                    .font(.ordir(.footnote))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.ordir(.footnote))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("ordir-pro")
                }
                Section(tr("Language")) {
                    ForEach(OrdirLanguage.allCases) { option in
                        let isSelected = option.rawValue == language
                        Button {
                            language = option.rawValue
                        } label: {
                            HStack {
                                Text(option.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier("language-\(option.rawValue)")
                    }
                }
                Section(tr("Help")) {
                    Button {
                        replayTutorial()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Replay the tutorial"))
                            Text(tr("A quick tour of how Ordir works."))
                                .font(.ordir(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("replay-tutorial")
                    Button {
                        showsNews = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("What’s new"))
                            Text(tr("Everything Ordi has fixed and improved lately."))
                                .font(.ordir(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("whats-new")
                    .sheet(isPresented: $showsNews) { WhatsNewView(all: true) }
                }
                Section {
                    Text(tr("Logo: “Magic Ball” by Ziyad Aljunaidi, Noun Project (CC BY 3.0). Type: Google Sans Flex (SIL OFL 1.1)."))
                    Text(tr("Rules © CMON / Gale Force Nine, Fantasy Flight Games and Ares Games; Ordir cites them by page and isn’t affiliated with them."))
                }
                .font(.ordir(.footnote))
                .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showsPro) { OrdirProView() }
            .navigationTitle(tr("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
