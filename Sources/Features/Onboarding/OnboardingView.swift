import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var chosenNative: Language?
    @State private var chosenLevel: CEFR = .a1
    @State private var chosenGoal: Int = 50
    @State private var bounce = false

    private var lang: Language { chosenNative ?? .it }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.bg, Palette.brand.opacity(0.12)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 8)

                TabView(selection: $step) {
                    welcomePage.tag(0)
                    coursePage.tag(1)
                    levelPage.tag(2)
                    goalPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                footer
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 26)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i <= step ? Palette.brand : Palette.locked)
                    .frame(width: i == step ? 26 : 9, height: 9)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 22) {
            Spacer()
            Mascot(mood: .cheer, size: 140)
                .scaleEffect(bounce ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bounce)
                .onAppear { bounce = true }
            VStack(spacing: 10) {
                Text("Uzbelia")
                    .font(.display(42))
                    .foregroundStyle(
                        LinearGradient(colors: [Palette.brand, Palette.teal],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                Text("Italiano 🇮🇹 ⇄ 🇺🇿 O'zbekcha")
                    .font(.heading(17)).foregroundStyle(Palette.inkSoft)
                Text("A1 → B2")
                    .font(.heading(14)).foregroundStyle(Palette.inkFaint)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Palette.locked))
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hPad)
    }

    private var coursePage: some View {
        VStack(spacing: 18) {
            header(title: S.pickCourse[lang], subtitle: nil)
            VStack(spacing: 14) {
                courseCard(native: .it)
                courseCard(native: .uz)
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 24)
    }

    private func courseCard(native: Language) -> some View {
        let learning = native.other
        let selected = chosenNative == native
        return Button {
            Feedback.tap()
            withAnimation(.spring(response: 0.3)) { chosenNative = native }
        } label: {
            ChunkyCard(fill: selected ? Palette.brand.opacity(0.12) : Palette.card,
                       edge: selected ? Palette.brandDeep.opacity(0.35) : Palette.stroke,
                       border: selected ? Palette.brand : Palette.stroke) {
                HStack(spacing: 14) {
                    FlagBadge(language: learning, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(native == .it ? "Imparo l'uzbeko" : "Italyan tilini o'rganaman")
                            .font(.heading(18)).foregroundStyle(Palette.ink)
                        Text(native == .it ? S.iSpeak.it : S.iSpeakUz.uz)
                            .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(selected ? Palette.brand : Palette.inkFaint)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }

    private var levelPage: some View {
        VStack(spacing: 18) {
            header(title: S.pickLevel[lang], subtitle: S.pickLevelSub[lang])
            VStack(spacing: 12) {
                ForEach(CEFR.allCases) { lvl in
                    Button {
                        Feedback.tap()
                        withAnimation(.spring(response: 0.3)) { chosenLevel = lvl }
                    } label: {
                        ChunkyCard(fill: chosenLevel == lvl ? Palette.purple.opacity(0.12) : Palette.card,
                                   edge: chosenLevel == lvl ? Palette.purpleDeep.opacity(0.35) : Palette.stroke,
                                   border: chosenLevel == lvl ? Palette.purple : Palette.stroke) {
                            HStack(spacing: 14) {
                                Text(lvl.label)
                                    .font(.display(20))
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 42)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(chosenLevel == lvl ? Palette.purple : Palette.inkFaint))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lvl.blurb[lang]).font(.heading(16)).foregroundStyle(Palette.ink)
                                    Text(lvl == .a1 ? S.fromZero[lang] : levelHint(lvl))
                                        .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                            }
                            .padding(14)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 20)
    }

    private func levelHint(_ lvl: CEFR) -> String {
        switch (lvl, lang) {
        case (.a2, .it): return "So già le basi"
        case (.a2, .uz): return "Asoslarni bilaman"
        case (.b1, .it): return "Riesco a conversare"
        case (.b1, .uz): return "Suhbatlasha olaman"
        case (.b2, .it): return "Parlo già bene"
        case (.b2, .uz): return "Yaxshi gapiraman"
        default: return ""
        }
    }

    private var goalPage: some View {
        VStack(spacing: 18) {
            header(title: S.pickGoal[lang], subtitle: nil)
            VStack(spacing: 12) {
                goalRow(20, S.goalCasual[lang], 5)
                goalRow(50, S.goalRegular[lang], 10)
                goalRow(100, S.goalSerious[lang], 20)
                goalRow(150, S.goalIntense[lang], 30)
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 24)
    }

    private func goalRow(_ xp: Int, _ title: String, _ minutes: Int) -> some View {
        Button {
            Feedback.tap()
            withAnimation(.spring(response: 0.3)) { chosenGoal = xp }
        } label: {
            ChunkyCard(fill: chosenGoal == xp ? Palette.amber.opacity(0.14) : Palette.card,
                       edge: chosenGoal == xp ? Palette.amberDeep.opacity(0.35) : Palette.stroke,
                       border: chosenGoal == xp ? Palette.amber : Palette.stroke) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.heading(17)).foregroundStyle(Palette.ink)
                        Text("\(minutes) \(S.minPerDay[lang])")
                            .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Text("\(xp) XP").font(.heading(15)).foregroundStyle(Palette.amberDeep)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }

    private func header(title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Mascot(mood: .happy, size: 62)
            SpeechBubble {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.heading(18)).foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle).font(.plain(13)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            Feedback.pop()
            if step == 1, let chosenNative { state.chooseCourse(native: chosenNative) }
            if step < 3 {
                withAnimation { step += 1 }
            } else {
                state.finishOnboarding(goal: chosenGoal, startLevel: chosenLevel)
            }
        } label: {
            Text(step == 3 ? S.start[lang] : S.continueBtn[lang])
        }
        .buttonStyle(.chunky(Palette.green, Palette.greenDeep))
        .disabled(step == 1 && chosenNative == nil)
        .opacity(step == 1 && chosenNative == nil ? 0.5 : 1)
    }
}
