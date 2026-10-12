import SwiftUI

@main
struct UzbeliaApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .tint(Palette.brand)
                .preferredColorScheme(nil)
                .onAppear {
                    Feedback.hapticsEnabled = state.settings.haptics
                    Feedback.soundsEnabled = state.settings.sounds
                    _ = AnswerSounds.shared        // load the chimes before the first answer
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var dialogs = DialogPresenter()

    var body: some View {
        Group {
            if state.isOnboarded {
                MainView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isOnboarded)
        .environment(dialogs)
        // above everything, tab bar included
        .glassDialog(Binding(get: { dialogs.current }, set: { dialogs.current = $0 }))
    }
}

// MARK: - Main shell with a floating glass tab bar

struct MainView: View {
    @Environment(AppState.self) private var state
    @State private var tab: Tab = .path
    @Namespace private var tabSpace

    enum Tab: String, CaseIterable, Identifiable {
        case path, practice, call, grammar, profile
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .path: return "map"
            case .practice: return "dumbbell"
            case .call: return "video"
            case .grammar: return "character.book.closed"
            case .profile: return "person"
            }
        }
        var label: Bilingual {
            switch self {
            case .path: return S.tabPath
            case .practice: return S.tabPractice
            case .call: return S.tabCall
            case .grammar: return S.tabGrammar
            case .profile: return S.tabProfile
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .path: PathView()
                case .practice: PracticeHubView()
                case .call: CallHubView()
                case .grammar: GrammarView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
        }
        .ignoresSafeArea(.keyboard)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                let on = tab == t
                Button {
                    if !on { Feedback.tap() }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { tab = t }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: on ? t.icon + ".fill" : t.icon)
                            .font(.system(size: 18, weight: on ? .semibold : .regular))
                            .symbolEffect(.bounce, value: on)
                        if on {
                            Text(t.label[state.native])
                                .font(.heading(13.5))
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .foregroundStyle(on ? .white : Palette.inkSoft)
                    .padding(.horizontal, on ? 16 : 0)
                    .frame(maxWidth: on ? nil : .infinity)
                    .frame(height: 48)
                    .background {
                        if on {
                            Capsule()
                                .fill(Gradients.primary)
                                .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                                       startPoint: .top, endPoint: .center)))
                                .shadow(color: Palette.brand.opacity(0.4), radius: 10, y: 5)
                                .matchedGeometryEffect(id: "tab", in: tabSpace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.label[state.native])
            }
        }
        .padding(6)
        .glassCapsule()
    }
}

// MARK: - Shared header with the live stats

/// Streak, gems and hearts on little glass chips, and the flag of the language being
/// learnt on a glass button in the corner.
struct StatsHeader: View {
    @Environment(AppState.self) private var state
    var levelLabel: String?
    var onTapHearts: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // the flame is lit once today's work is done, and waits in grey until then
            StatPill(icon: "flame.fill", text: "\(state.streak)",
                     tint: state.practisedToday ? Ember.body : Palette.inkFaint)
            if state.unlimited {
                InfinityPill(icon: "diamond.fill", tint: Palette.brand)
                InfinityPill(icon: "heart.fill", tint: Palette.brand)
            } else {
                StatPill(icon: "diamond.fill", text: "\(state.gems)", tint: Palette.brand)
                if let onTapHearts {
                    Button { onTapHearts() } label: {
                        StatPill(icon: "heart.fill", text: "\(state.hearts)", tint: Palette.brand)
                    }
                    .buttonStyle(.pressable)
                } else {
                    StatPill(icon: "heart.fill", text: "\(state.hearts)", tint: Palette.brand)
                }
            }
            Spacer(minLength: 0)
            if let levelLabel {
                Text(levelLabel)
                    .font(.heading(13)).foregroundStyle(Palette.brand)
                    .padding(.horizontal, 11).frame(height: 34)
                    .glassCapsule(material: false, shadow: false)
            }
            FlagOrb(language: state.target, size: 44)
        }
    }
}
