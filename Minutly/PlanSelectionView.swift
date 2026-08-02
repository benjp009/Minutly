//
//  PlanSelectionView.swift
//  Minutly
//
//  Created by Claude Code on 04/12/2025.
//

import SwiftUI

struct PlanSelectionView: View {
    @Binding var hasSelectedPlan: Bool
    @State private var selectedPlan: PlanType? = .control
    @State private var billing: BillingCycle = .monthly

    var body: some View {
        ZStack {
            Theme.surfacePrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {
                    header
                    cardsRow
                    trustRow
                    Button(action: { hasSelectedPlan = true }) {
                        Text("Compare all features in detail →")
                            .font(Theme.body(13, weight: .medium))
                            .foregroundStyle(Theme.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 1100, minHeight: 720)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Choose Your Plan")
                .font(Theme.heading(32, weight: .bold))
                .foregroundStyle(Theme.foregroundPrimary)

            Text("Unlock the full power of Minutly with a plan that fits your workflow")
                .font(Theme.body(15))
                .foregroundStyle(Theme.foregroundSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            billingToggle
                .padding(.top, Theme.Spacing.sm)
        }
    }

    private var billingToggle: some View {
        HStack(spacing: 4) {
            toggleSegment(label: "Monthly", isActive: billing == .monthly) {
                billing = .monthly
            }
            toggleSegment(label: "Yearly", isActive: billing == .yearly) {
                billing = .yearly
            }
            Text("Save 20%")
                .font(Theme.body(10, weight: .semibold))
                .foregroundStyle(Theme.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.successSubtle))
                .padding(.trailing, 4)
        }
        .padding(4)
        .background(Capsule().fill(Theme.surfaceSecondary))
    }

    private func toggleSegment(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.body(13, weight: .semibold))
                .foregroundStyle(isActive ? .white : Theme.foregroundSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Capsule().fill(isActive ? Theme.accentPrimary : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var cardsRow: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach([PlanType.free, .control, .allIn], id: \.self) { plan in
                PlanCard(
                    plan: plan,
                    billing: billing,
                    isSelected: selectedPlan == plan,
                    onSelect: {
                        selectedPlan = plan
                        if plan != .free { hasSelectedPlan = true }
                    }
                )
            }
        }
    }

    private var trustRow: some View {
        HStack(spacing: 32) {
            trustItem(icon: "shield", label: "AES-256 Encryption")
            trustItem(icon: "lock", label: "Secure Keychain Storage")
            trustItem(icon: "eye.slash", label: "No Telemetry")
            trustItem(icon: "creditcard", label: "Cancel Anytime")
        }
    }

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(label)
                .font(Theme.body(12))
        }
        .foregroundStyle(Theme.foregroundMuted)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PlanType
    let billing: BillingCycle
    let isSelected: Bool
    let onSelect: () -> Void

    private var isRecommended: Bool { plan == .control }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if isRecommended {
                Text("Recommended")
                    .font(Theme.body(11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accentPrimary))
            }

            Text(plan.displayName)
                .font(Theme.heading(18, weight: .semibold))
                .foregroundStyle(Theme.foregroundPrimary)

            priceRow

            Text(plan.tagline)
                .font(Theme.body(13))
                .foregroundStyle(Theme.foregroundSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Theme.borderPrimary)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.features, id: \.text) { feature in
                    featureRow(feature)
                }
            }

            actionButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(isRecommended ? Theme.accentPrimary : Theme.borderPrimary,
                        lineWidth: isRecommended ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var priceRow: some View {
        let price = plan.price(for: billing)
        return HStack(alignment: .lastTextBaseline, spacing: 4) {
            if let currency = price.currency {
                Text(currency)
                    .font(Theme.heading(20, weight: .semibold))
                    .foregroundStyle(Theme.foregroundSecondary)
            }
            Text(price.amount)
                .font(Theme.mono(48, weight: .bold))
                .foregroundStyle(isRecommended ? Theme.accentPrimary : Theme.foregroundPrimary)
            Text(price.suffix)
                .font(Theme.body(14))
                .foregroundStyle(Theme.foregroundMuted)
                .padding(.bottom, 6)
        }
    }

    private func featureRow(_ feature: PlanFeature) -> some View {
        HStack(spacing: 8) {
            Image(systemName: feature.included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(feature.included ? Theme.success : Theme.foregroundMuted)

            Text(feature.text)
                .font(Theme.body(13))
                .foregroundStyle(feature.included ? Theme.foregroundPrimary : Theme.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch plan.action {
        case .currentPlan:
            Text("Current Plan")
                .font(Theme.body(14, weight: .semibold))
                .foregroundStyle(Theme.foregroundSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.surfaceTertiary))
                .overlay(Capsule().stroke(Theme.borderPrimary, lineWidth: 1))
        case .primary(let label):
            Button(action: onSelect) {
                Text(label)
                    .font(Theme.body(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.accentPrimary))
            }
            .buttonStyle(.plain)
        case .secondary(let label):
            Button(action: onSelect) {
                Text(label)
                    .font(Theme.body(14, weight: .semibold))
                    .foregroundStyle(Theme.foregroundSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.surfaceTertiary))
                    .overlay(Capsule().stroke(Theme.borderPrimary, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Models

enum BillingCycle {
    case monthly, yearly
}

struct PlanPrice {
    let currency: String?
    let amount: String
    let suffix: String
}

struct PlanFeature: Hashable {
    let text: String
    let included: Bool

    init(_ text: String, included: Bool = true) {
        self.text = text
        self.included = included
    }
}

enum PlanAction {
    case currentPlan
    case primary(String)
    case secondary(String)
}

enum PlanType: String, Hashable {
    case free
    case control
    case allIn

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .control: return "Be in Control"
        case .allIn: return "All In"
        }
    }

    func price(for billing: BillingCycle) -> PlanPrice {
        switch self {
        case .free:
            return PlanPrice(currency: "€", amount: "0", suffix: "forever")
        case .control:
            return billing == .monthly
                ? PlanPrice(currency: "€", amount: "9", suffix: "/month")
                : PlanPrice(currency: "€", amount: "86", suffix: "/year")
        case .allIn:
            return billing == .monthly
                ? PlanPrice(currency: "€", amount: "18", suffix: "/month")
                : PlanPrice(currency: "€", amount: "173", suffix: "/year")
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Get started with basic recording"
        case .control: return "Bring your own API keys for full power"
        case .allIn: return "Everything managed, zero config needed"
        }
    }

    var features: [PlanFeature] {
        switch self {
        case .free:
            return [
                PlanFeature("Unlimited recordings"),
                PlanFeature("Apple Speech transcription"),
                PlanFeature("AES-256 encryption"),
                PlanFeature("Speaker identification", included: false),
                PlanFeature("AI summaries", included: false),
                PlanFeature("Meeting detection", included: false),
                PlanFeature("Priority support", included: false)
            ]
        case .control:
            return [
                PlanFeature("Everything in Free"),
                PlanFeature("Use your own API keys"),
                PlanFeature("AssemblyAI & Whisper"),
                PlanFeature("Speaker identification"),
                PlanFeature("AI summaries (BYOK)"),
                PlanFeature("Meeting detection"),
                PlanFeature("Priority support", included: false)
            ]
        case .allIn:
            return [
                PlanFeature("Everything in Control"),
                PlanFeature("Managed API keys"),
                PlanFeature("No API key setup"),
                PlanFeature("Unlimited transcriptions"),
                PlanFeature("Unlimited AI summaries"),
                PlanFeature("Meeting detection"),
                PlanFeature("Priority support")
            ]
        }
    }

    var action: PlanAction {
        switch self {
        case .free: return .currentPlan
        case .control: return .primary("Get Started")
        case .allIn: return .secondary("Get Started")
        }
    }
}

#Preview {
    PlanSelectionView(hasSelectedPlan: .constant(false))
        .frame(width: 1200, height: 800)
}
