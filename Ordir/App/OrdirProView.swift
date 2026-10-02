//
//  OrdirProView.swift
//  Ordir
//
//  Ordir Pro, coming soon: Free next to Pro (the cooler Ordi, in shades) and the plans, none on sale yet.
//  Opened from Settings (the preview has it on its Account tab and in the rules chat).
//

import SwiftUI

enum OrdirPro {
    /// Shown, not enforced yet: while Ordir is in testing, every rules question is answered.
    static let freeQuestions = 5
    static let proQuestions = 100
}

/// "Pro" knocked out of a white rounded tag: the letters are see-through.
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "Pro")
            .font(.ordir(.subheadline).weight(.heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .blendMode(.destinationOut)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
            .compositingGroup()
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "Pro"))
    }
}

/// "Ordir" followed by the Pro tag.
struct ProMark: View {
    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "Ordir").fontWeight(.bold)
            ProBadge()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Ordir Pro"))
    }
}

struct OrdirProView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Cell { case count(Int), included, notIncluded }

    private let rows: [(String, Cell, Cell)] = [
        (tr("Rules questions a month"), .count(OrdirPro.freeQuestions), .count(OrdirPro.proQuestions)),
        (tr("Turn guides for every game"), .included, .included),
        (tr("One phone, or each on your own"), .included, .included),
        (tr("Expansions"), .included, .included),
        (tr("New games before everyone else"), .notIncluded, .included),
        (tr("Ordi in shades, and the app icon"), .notIncluded, .included),
    ]

    private let plans: [(String, String)] = [
        (tr("Yearly"), tr("{0} rules questions a month, and Ordi in shades", OrdirPro.proQuestions)),
        (tr("Monthly"), tr("{0} rules questions a month, and Ordi in shades", OrdirPro.proQuestions)),
        (tr("Game Night pass"), tr("25 rules questions for 24 hours, on one game")),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    VStack(spacing: 8) {
                        Text(tr("Same Ordi. Cooler shades."))
                            .font(.ordir(.title).weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(tr("Ordir Pro answers far more rules questions, and Ordi gets the sunglasses."))
                            .font(.ordir(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    comparison
                    Text(tr("Free plan · {0} rules questions a month", OrdirPro.freeQuestions))
                        .font(.ordir(.footnote))
                        .foregroundStyle(.secondary)
                    planList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { footer }
            .background { glow.ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 28) {
            VStack(spacing: 6) {
                OrdirMascotView().frame(width: 72)
                Text(verbatim: "Ordi").font(.ordir(.subheadline).weight(.semibold))
                Text(tr("Free")).font(.ordir(.footnote)).foregroundStyle(.secondary)
            }
            .opacity(0.75)
            VStack(spacing: 6) {
                OrdirMascotView(isCool: true).frame(width: 116)
                Text(tr("The cooler Ordi")).font(.ordir(.subheadline).weight(.semibold))
                ProMark().font(.ordir(.footnote))
            }
        }
        .padding(.top, 8)
    }

    private var comparison: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 12) {
            GridRow {
                Text(tr("Feature")).hidden().accessibilityHidden(true)
                Text(tr("Free")).foregroundStyle(.secondary).frame(width: 52)
                Text(verbatim: "Pro").fontWeight(.semibold).frame(width: 52)
            }
            .font(.ordir(.footnote))
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                Divider()
                GridRow {
                    Text(row.0).frame(maxWidth: .infinity, alignment: .leading)
                    cell(row.1).foregroundStyle(.secondary)
                    cell(row.2).fontWeight(.semibold)
                }
                .font(.ordir(.subheadline))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(tr("Free and Pro compared"))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func cell(_ cell: Cell) -> some View {
        switch cell {
        case .count(let n): Text(verbatim: String(n))
        case .included: Image(systemName: "checkmark").accessibilityLabel(tr("Included"))
        case .notIncluded: Text(verbatim: "–").accessibilityLabel(tr("Not included"))
        }
    }

    private var planList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Plans"))
                .font(.ordir(.footnote).weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(plans.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plans[index].0).font(.ordir(.callout).weight(.semibold))
                        Text(plans[index].1).font(.ordir(.subheadline)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(tr("Coming soon"))
                        .font(.ordir(.caption).weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(Capsule().stroke(Color(white: 0.17)))
                }
                .padding(16)
                .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {} label: {
                Text(tr("Coming soon"))
                    .font(.ordir(.headline))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .disabled(true)
            Text(tr("Ordir Pro isn’t available yet. While Ordir is in testing, rules questions are on us."))
                .font(.ordir(.footnote))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black)
    }

    /// The opening's violet glow behind the two Ordis.
    private var glow: some View {
        RadialGradient(
            colors: [Color(red: 120 / 255, green: 70 / 255, blue: 200 / 255).opacity(0.30), .black],
            center: UnitPoint(x: 0.5, y: 0.12),
            startRadius: 0,
            endRadius: 340
        )
    }
}

#Preview {
    OrdirProView().preferredColorScheme(.dark)
}
