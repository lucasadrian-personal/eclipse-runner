import SwiftUI

// MARK: - Onboarding Page Model
private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

// MARK: - OnboardingView
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentPage = 0
    @State private var pilotName: String = ""
    @FocusState private var nameFocused: Bool
    @EnvironmentObject private var store: GameStore

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "rocket.fill",
            iconColor: Theme.auroraCyan,
            title: L10n.onboardTitle1,
            subtitle: L10n.onboardSub1
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            iconColor: Theme.nebulaPink,
            title: L10n.onboardTitle2,
            subtitle: L10n.onboardSub2
        ),
        OnboardingPage(
            icon: "flame.fill",
            iconColor: Theme.starGold,
            title: L10n.onboardTitle3,
            subtitle: L10n.onboardSub3
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            iconColor: Theme.auroraMint,
            title: L10n.onboardTitle4,
            subtitle: L10n.onboardSub4
        )
    ]

    var body: some View {
        ZStack {
            CosmicBackground()
            StarfieldView()
                .opacity(0.5)
            VStack(spacing: 0) {
                if currentPage < pages.count {
                    tutorialPage(pages[currentPage])
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(currentPage)
                } else {
                    nameEntryPage
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Tutorial page
    private func tutorialPage(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            if currentPage == 0 {
                AstronautView()
                    .frame(width: 160, height: 160)
            } else {
                iconCircle(icon: page.icon, color: page.iconColor)
            }
            pageText(title: page.title, subtitle: page.subtitle)
            Spacer()
            bottomControls
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 52)
    }

    private func iconCircle(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 160, height: 160)
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 1.5)
                .frame(width: 160, height: 160)
            Image(systemName: icon)
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 20)
        }
    }

    private func pageText(title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: Bottom controls
    private var bottomControls: some View {
        VStack(spacing: 20) {
            dotsIndicator
            nextButton
        }
    }

    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<(pages.count + 1), id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? Theme.auroraCyan : Theme.surfaceStroke)
                    .frame(width: i == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35), value: currentPage)
            }
        }
    }

    private var nextButton: some View {
        Button {
            HapticsManager.shared.impactLight()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } label: {
            Text(L10n.onboardNext)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Theme.auroraCyan.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Name entry page (last step)
    private var nameEntryPage: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.nebulaPurple.opacity(0.15))
                    .frame(width: 160, height: 160)
                Circle()
                    .stroke(Theme.nebulaPurple.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 160, height: 160)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 68, weight: .bold))
                    .foregroundStyle(Theme.nebulaPurple)
                    .shadow(color: Theme.nebulaPurple.opacity(0.6), radius: 20)
            }

            VStack(spacing: 14) {
                Text(L10n.onboardNameTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L10n.onboardNameSub)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            nameField

            Spacer()

            VStack(spacing: 16) {
                launchButton
                skipButton
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 52)
    }

    private var nameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.auroraCyan)
                .frame(width: 36, height: 36)
                .background(Theme.auroraCyan.opacity(0.15), in: Circle())
            TextField(L10n.pilotNamePH, text: $pilotName)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.auroraCyan)
                .focused($nameFocused)
                .submitLabel(.go)
                .onSubmit { saveName() }
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(nameFocused ? Theme.auroraCyan.opacity(0.6) : Theme.surfaceStroke, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: nameFocused)
    }

    private var launchButton: some View {
        Button(action: saveName) {
            Text(L10n.onboardLaunch)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.04, green: 0.06, blue: 0.18))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    pilotName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? AnyShapeStyle(Theme.surfaceStroke)
                        : AnyShapeStyle(Theme.primaryGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(
                    color: pilotName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? .clear : Theme.auroraCyan.opacity(0.35),
                    radius: 12, y: 6
                )
        }
        .disabled(pilotName.trimmingCharacters(in: .whitespaces).isEmpty)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: pilotName)
    }

    private var skipButton: some View {
        Button {
            HapticsManager.shared.impactLight()
            onFinish()
        } label: {
            Text(L10n.onboardSkip)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .buttonStyle(.plain)
    }

    private func saveName() {
        let trimmed = pilotName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.savePilotName(trimmed)
        HapticsManager.shared.impactMedium()
        onFinish()
    }
}
