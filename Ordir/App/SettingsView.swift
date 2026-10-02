//
//  SettingsView.swift
//  Ordir
//
//  The language Ordir speaks, and the tutorial again. Opened from Home's gear (the preview has these on its
//  Account tab).
//

import SwiftUI

struct SettingsView: View {
    /// Closes Settings and plays the tutorial.
    let replayTutorial: () -> Void
    @AppStorage(OrdirLanguage.storageKey) private var language = OrdirLanguage.current.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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
                }
                Section {
                    Text(tr("Logo: “Magic Ball” by Ziyad Aljunaidi, Noun Project (CC BY 3.0). Type: Google Sans Flex (SIL OFL 1.1)."))
                    Text(tr("Rules © CMON / Gale Force Nine, Fantasy Flight Games and Ares Games; Ordir cites them by page and isn’t affiliated with them."))
                }
                .font(.ordir(.footnote))
                .foregroundStyle(.secondary)
            }
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
