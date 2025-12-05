//
//  PlanSelectionView.swift
//  Minutly
//
//  Created by Claude Code on 04/12/2025.
//

import SwiftUI

struct PlanSelectionView: View {
    @Binding var hasSelectedPlan: Bool
    @State private var selectedPlan: PlanType? = nil
    @State private var hoveredPlan: PlanType? = nil

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 12) {
                    Text("Plan")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.black)

                    Text("Pick a plan and start today !")
                        .font(.system(size: 30))
                        .foregroundStyle(.black)
                }
                .padding(.top, 60)

                // Plans Grid - All in card in the middle
                HStack(spacing: 60) {
                    ForEach([PlanType.free, PlanType.allIn, PlanType.control], id: \.self) { plan in
                        PlanCard(
                            plan: plan,
                            isSelected: selectedPlan == plan,
                            isHovered: hoveredPlan == plan,
                            onSelect: {
                                selectedPlan = plan
                            },
                            onHover: { isHovering in
                                hoveredPlan = isHovering ? plan : nil
                            }
                        )
                    }
                }
                .padding(.horizontal, 60)

                Spacer()

                // Continue Button
                if selectedPlan != nil {
                    Button(action: {
                        hasSelectedPlan = true
                    }) {
                        Text("Go with this plan")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

struct PlanCard: View {
    let plan: PlanType
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Plan Name and Price
                VStack(alignment: .center, spacing: 8) {
                    Text(plan.displayName)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(plan.price)
                        .font(.system(size: 20))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 72)

                Divider()

                // Features List
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(plan.features, id: \.text) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(isSelected || isHovered ? Color(hex: "21be60") : .black)

                                Text(feature.text)
                                    .font(.system(size: 16))
                                    .foregroundStyle(feature.isWarning ? .red : .black)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if let disclaimer = plan.disclaimer {
                    Text(disclaimer)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }
            }
            .frame(width: 300, height: 300)
            .padding(.vertical, 20)
            .background(isSelected || isHovered ? Color(hex: "d5fde5") : Color(hex: "f9f9f9"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected || isHovered ? Color(hex: "21be60") : Color(hex: "a9a9a9"), lineWidth: 2)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

struct PlanFeature: Hashable {
    let text: String
    let isWarning: Bool

    init(_ text: String, isWarning: Bool = false) {
        self.text = text
        self.isWarning = isWarning
    }
}

enum PlanType: String, Hashable {
    case free
    case control
    case allIn

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .control: return "Be in control*"
        case .allIn: return "All in"
        }
    }

    var price: String {
        switch self {
        case .free: return "0 €"
        case .control: return "9 € / month"
        case .allIn: return "18 € / months"
        }
    }

    var features: [PlanFeature] {
        switch self {
        case .free:
            return [
                PlanFeature("Use Apple integrated free model"),
                PlanFeature("Free forever with no hidden cost"),
                PlanFeature("Transcription + Summary"),
                PlanFeature("Limited quality responses", isWarning: true)
            ]
        case .allIn:
            return [
                PlanFeature("50 hours of meeting"),
                PlanFeature("Get the best language for your meetings"),
                PlanFeature("Voice recognition"),
                PlanFeature("Unlimited custom meeting prompt")
            ]
        case .control:
            return [
                PlanFeature("Plug your APIs"),
                PlanFeature("Control everything"),
                PlanFeature("Limited access to custom prompt"),
                PlanFeature("1 custom prompt for summary")
            ]
        }
    }

    var disclaimer: String? {
        switch self {
        case .control:
            return "*this plan required some technical knowledge"
        default:
            return nil
        }
    }
}

#Preview {
    PlanSelectionView(hasSelectedPlan: .constant(false))
}
