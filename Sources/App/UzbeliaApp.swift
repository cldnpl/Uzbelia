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
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state

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
    }
}

// MARK: - Main shell with a custom tab bar

struct MainView: View {
    @Environment(AppState.self) private var state
    @State private var tab: Tab = .path

    enum Tab: String, CaseIterable, Identifiable {
        case path, practice, call, grammar, profile
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .path: return "map.fill"
            case .practice: return "dumbbell.fill"
            case .call: return "video.fill"
            case .grammar: return "character.book.closed.fill"
            case .profile: return "person.crop.circle.fill"
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
        var tint: Color {
            switch self {
            case .path: return Palette.brand
            case .practice: return Palette.amber
            case .call: return Palette.pink
            case .grammar: return Palette.purple
            case .profile: return Palette.green
            }
        }
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            Group {
                switch tab {
                case .path: PathView()
                case .practice: PracticeHubView()
                case .call: CallHubView()
                case .grammar: GrammarView()
                case .profile: ProfileView()
                }
            }
            .safeAreaInset(edge: .bottom) { tabBar }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { t in
                Button {
                    if tab != t { Feedback.tap() }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { tab = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 21, weight: .bold))
                            .symbolEffect(.bounce, value: tab == t)
                        Text(t.label[state.native])
                            .font(.heading(10))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(tab == t ? t.tint : Palette.inkFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tab == t ? t.tint.opacity(0.13) : .clear)
                            .padding(.horizontal, 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .background(
            Palette.bgElevated
                .overlay(alignment: .top) { Palette.stroke.frame(height: 1.5) }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Shared header with the live stats

struct StatsHeader: View {
    @Environment(AppState.self) private var state
    var levelLabel: String?
    var onTapHearts: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            FlagBadge(language: state.target, size: 32)
            if let levelLabel {
                Tag(text: levelLabel, tint: Palette.brand)
            }
            Spacer(minLength: 0)
            StatPill(icon: "flame.fill", text: "\(state.streak)", tint: Palette.amber)
            if state.unlimited {
                InfinityPill(icon: "diamond.fill", tint: Palette.brand)
                InfinityPill(icon: "heart.fill", tint: Palette.red)
            } else {
                StatPill(icon: "diamond.fill", text: "\(state.gems)", tint: Palette.brand)
                if let onTapHearts {
                    Button { onTapHearts() } label: {
                        StatPill(icon: "heart.fill", text: "\(state.hearts)", tint: Palette.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    StatPill(icon: "heart.fill", text: "\(state.hearts)", tint: Palette.red)
                }
            }
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.vertical, 10)
        .background(Palette.bg)
    }
}


/// Shows "∞" next to an icon, for the unlimited hearts/gems this build ships with.
struct InfinityPill: View {
    var icon: String
    var tint: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
            Image(systemName: "infinity").font(.system(size: 14, weight: .black))
        }
        .foregroundStyle(tint)
    }
}
