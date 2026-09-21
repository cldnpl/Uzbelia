import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var chosenNative: Language?
    @State private var chosenLevel: CEFR = .a1
    @State private var chosenGoal: Int = 50
    @State private var bounce = false
    /// Set when she asks to be placed by a quiz instead of choosing a level herself.
    /// Presenting on the quiz itself, rather than on a separate flag, is what keeps
    /// the screen from opening before the questions are in it.
    @State private var quiz: LevelFinder.Quiz?
    @State private var placement: (level: CEFR, unitID: String)?
    /// "I have been here before": signing in restores a course rather than starting one.
    @State private var showAccount = false

    private var lang: Language { chosenNative ?? .it }

    /// Five steps, the last of which is the account. It is always there, even in a
    /// build whose `Secrets` are still empty: the page then says so plainly, which is
    /// far more use than a step that quietly is not.
    private let lastStep = 4

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
                    accountPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                footer
                    .padding(.horizontal, Metrics.hPad)
                    .padding(.bottom, 26)
            }
        }
        .sheet(isPresented: $showAccount) { AccountSheet(mode: .signIn) }
        .fullScreenCover(item: $quiz) { quiz in
            LessonView(request: SessionRequest(mode: .practice,
                                               customExercises: quiz.exercises,
                                               customTitle: S.findLevel,
                                               consumesHearts: false,
                                               xpReward: 0),
                       onFinish: { results in
                           placement = LevelFinder.placement(quiz: quiz, mistakes: results.mistakes)
                           if let placement { chosenLevel = placement.level }
                       })
        }
    }

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0...lastStep, id: \.self) { i in
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

            // the way out of guessing: let the course work it out
            Button {
                Feedback.pop()
                let built = LevelFinder.quiz(curriculum: state.curriculum,
                                             native: lang,
                                             settings: state.effectiveSettings)
                guard !built.exercises.isEmpty else { return }
                quiz = built
            } label: {
                ChunkyCard(fill: placement != nil ? Palette.teal.opacity(0.16) : Palette.card,
                           edge: placement != nil ? Palette.teal.opacity(0.4) : Palette.stroke,
                           border: placement != nil ? Palette.teal : Palette.stroke) {
                    HStack(spacing: 14) {
                        Image(systemName: placement != nil ? "checkmark.seal.fill" : "wand.and.stars")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 42)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Palette.teal))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(S.findLevel[lang]).font(.heading(16)).foregroundStyle(Palette.ink)
                            Text(placementSummary ?? S.findLevelSub[lang])
                                .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Rectangle().fill(Palette.stroke).frame(height: 1.5)
                Text(S.orPickYourself[lang]).font(.heading(11)).foregroundStyle(Palette.inkFaint)
                Rectangle().fill(Palette.stroke).frame(height: 1.5)
            }

            VStack(spacing: 12) {
                ForEach(CEFR.allCases) { lvl in
                    Button {
                        Feedback.tap()
                        withAnimation(.spring(response: 0.3)) { chosenLevel = lvl; placement = nil }
                    } label: {
                        ChunkyCard(fill: chosenLevel == lvl && placement == nil ? Palette.purple.opacity(0.12) : Palette.card,
                                   edge: chosenLevel == lvl && placement == nil ? Palette.purpleDeep.opacity(0.35) : Palette.stroke,
                                   border: chosenLevel == lvl && placement == nil ? Palette.purple : Palette.stroke) {
                            HStack(spacing: 14) {
                                Text(lvl.label)
                                    .font(.display(20))
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 42)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(chosenLevel == lvl && placement == nil ? Palette.purple : Palette.inkFaint))
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

    /// What the quiz decided, in a line she can read on the card.
    private var placementSummary: String? {
        guard let placement,
              let unit = state.curriculum.unit(id: placement.unitID) else { return nil }
        return lang == .it
            ? "Inizi da \(placement.level.label) · \(unit.title.it)"
            : "\(placement.level.label) · \(unit.title.uz) dan boshlaysiz"
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
        // The account step has its own buttons inside the page — a second green one
        // down here would sit right under "Crea un account" and mean something else.
        let waitingToSignIn = step == lastStep && !state.account.isSignedIn
        return VStack(spacing: 12) {
            if !waitingToSignIn {
                Button {
                    Feedback.pop()
                    if step == 1, let chosenNative { state.chooseCourse(native: chosenNative) }
                    if step < lastStep {
                        withAnimation { step += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(step == lastStep ? S.start[lang] : S.continueBtn[lang])
                }
                .buttonStyle(.chunky(Palette.green, Palette.greenDeep))
                .disabled(step == 1 && chosenNative == nil)
                .opacity(step == 1 && chosenNative == nil ? 0.5 : 1)
            }

            // Offered on the very first screen: someone reinstalling the app wants her
            // streak back, not four questions about where to start.
            if step == 0 {
                Button {
                    Feedback.tap(); showAccount = true
                } label: {
                    Text(S.haveAccount[lang])
                        .font(.heading(13)).foregroundStyle(Palette.brand)
                }
                .buttonStyle(.plain)
            }

            // The way past the account step without one. Quiet on purpose, but never
            // hidden: an app that will not open until you sign up is a worse app.
            if waitingToSignIn {
                Button {
                    Feedback.tap(); finish()
                } label: {
                    Text(S.secureSkip[lang])
                        .font(.heading(14)).foregroundStyle(Palette.inkSoft)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func finish() {
        state.finishOnboarding(goal: chosenGoal, startLevel: chosenLevel)
        // a quiz result opens the course up to the chapter it found
        if let placement { LevelFinder.apply(placement, state: state) }
    }

    // MARK: - Last step: the account

    private var accountPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                if state.account.isSignedIn {
                    VStack(spacing: 12) {
                        Mascot(mood: .cheer, size: 110)
                        Text(S.secureDone[lang])
                            .font(.display(24)).foregroundStyle(Palette.ink)
                        Text(S.secureDoneSub[lang])
                            .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 15, weight: .black)).foregroundStyle(Palette.green)
                            Text(state.account.email)
                                .font(.heading(14)).foregroundStyle(Palette.ink)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Capsule().fill(Palette.green.opacity(0.14)))
                    }
                    .padding(.top, 30)
                } else {
                    header(title: S.secureTitle[lang], subtitle: S.secureSub[lang])
                    AccountForm(mode: .signUp, showsMascot: false)
                    if !state.account.isAvailable {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Palette.amberDeep)
                            Text(S.secureNotSetUp[lang])
                                .font(.plain(12)).foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Metrics.radiusSmall,
                                                     style: .continuous)
                            .fill(Palette.amber.opacity(0.16)))
                    }
                }
            }
            .padding(.horizontal, Metrics.hPad)
            // the same air the other four pages leave between the dots and the mascot
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
