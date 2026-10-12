import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var step = 0
    @State private var chosenCourse: Language?
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

    private let lang = Language.en

    /// Five steps, the last of which is the account. It is always there, even in a
    /// build whose `Secrets` are still empty: the page then says so plainly, which is
    /// far more use than a step that quietly is not.
    private let lastStep = 4

    var body: some View {
        ZStack {
            AuroraBackground(mood: step == 0 ? .celebrate : .home)
                .animation(.easeInOut(duration: 0.6), value: step)

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
        .sheet(isPresented: $showAccount) { AccountSheet(mode: .signIn).presentationCornerRadius(34) }
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
                    .fill(i <= step ? AnyShapeStyle(Gradients.primary) : AnyShapeStyle(Palette.inkFaint.opacity(0.35)))
                    .frame(width: i == step ? 28 : 9, height: 9)
                    .shadow(color: i == step ? Palette.brand.opacity(0.35) : .clear, radius: 5, y: 2)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Gradients.holo)
                    .frame(width: 210, height: 210)
                    .blur(radius: 30)
                    .opacity(0.8)
                    .rotationEffect(.degrees(bounce ? 200 : 0))
                    .animation(.linear(duration: 18).repeatForever(autoreverses: false), value: bounce)
                MascotBubble(mood: .cheer, size: 176)
                    .scaleEffect(bounce ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bounce)
            }
            .onAppear { bounce = true }
            VStack(spacing: 12) {
                Text("Lingora")
                    .font(.display(50))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xB49CFF), Color(hex: 0x7B5CF2), Color(hex: 0x5B43C7)],
                                                    startPoint: .leading, endPoint: .trailing))
                Text(S.welcomeSub[lang])
                    .font(.heading(17)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                welcomeFlags
                GlassChip(text: "A1 → B2", icon: "sparkles", tint: Palette.brand)
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.hPad)
    }

    /// A row of the courses' flags — each flag once — and how many more there are.
    private var welcomeFlags: some View {
        var seen = Set<String>()
        let distinct = Language.courses.filter { seen.insert($0.flag.isEmpty ? "ku" : $0.flag).inserted }
        let shown = Array(distinct.prefix(7))
        return HStack(spacing: 6) {
            ForEach(shown) { FlagMark(language: $0, size: 26) }
            if Language.courses.count > shown.count {
                Text("+\(Language.courses.count - shown.count)")
                    .font(.heading(14)).foregroundStyle(Palette.brandDeep)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .glassCapsule(tint: Palette.brand, material: false, shadow: false)
            }
        }
    }

    /// Every course, the ones with content first.
    private var orderedCourses: [Language] {
        Language.courses.filter { ContentStore.hasCourse($0) } + Language.courses.filter { !ContentStore.hasCourse($0) }
    }

    /// The courses this build carries content for.
    private var availableCourses: [Language] {
        Language.courses.filter { ContentStore.hasCourse($0) }
    }

    private var coursePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: S.pickCourse[lang], subtitle: nil)
                VStack(spacing: 12) {
                    // every course, the ones still being written shown as on their way
                    ForEach(orderedCourses) { courseCard($0) }
                }
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func courseCard(_ course: Language) -> some View {
        let selected = chosenCourse == course
        let ready = ContentStore.hasCourse(course)
        return Button {
            Feedback.tap()
            withAnimation(.spring(response: 0.3)) { chosenCourse = course }
        } label: {
            HStack(spacing: 14) {
                FlagOrb(language: course, size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.heading(18)).foregroundStyle(Palette.ink)
                    HStack(spacing: 8) {
                        Text(course.endonym)
                            .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        if !ready {
                            Text("Coming soon")
                                .font(.heading(11)).foregroundStyle(Palette.brandDeep)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .glassCapsule(tint: Palette.brand, material: false, shadow: false)
                        } else if !course.canBeSpoken {
                            // honest up front: no voice reads this one yet
                            Label("Text only", systemImage: "speaker.slash.fill")
                                .font(.heading(11)).foregroundStyle(Palette.inkSoft)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .glassCapsule(material: false, shadow: false)
                        }
                    }
                }
                Spacer()
                selectionMark(selected)
            }
            .padding(16)
            .modifier(SelectableGlass(selected: selected, tint: Palette.brand))
            .opacity(ready ? 1 : 0.5)
        }
        .buttonStyle(.pressable)
        .disabled(!ready)
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
                HStack(spacing: 14) {
                    OrbIcon(placement != nil ? "checkmark.seal.fill" : "wand.and.stars",
                            accent: .teal, size: 48, symbolScale: 0.4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(S.findLevel[lang]).font(.heading(16)).foregroundStyle(Palette.ink)
                        Text(placementSummary ?? S.findLevelSub[lang])
                            .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .modifier(SelectableGlass(selected: placement != nil, tint: Palette.teal))
            }
            .buttonStyle(.pressable)

            HStack(spacing: 10) {
                Rectangle().fill(Palette.strokeDeep.opacity(0.6)).frame(height: 1)
                Text(S.orPickYourself[lang]).font(.heading(11)).kerning(0.6).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).fixedSize()
                Rectangle().fill(Palette.strokeDeep.opacity(0.6)).frame(height: 1)
            }

            VStack(spacing: 12) {
                ForEach(CEFR.allCases) { lvl in
                    Button {
                        Feedback.tap()
                        withAnimation(.spring(response: 0.3)) { chosenLevel = lvl; placement = nil }
                    } label: {
                        let on = chosenLevel == lvl && placement == nil
                        HStack(spacing: 14) {
                            Text(lvl.label)
                                .font(.display(19))
                                .foregroundStyle(on ? .white : Palette.inkSoft)
                                .frame(width: 54, height: 42)
                                .background {
                                    if on {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Gradients.primary)
                                    } else {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Palette.locked)
                                    }
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lvl.blurb[lang]).font(.heading(16)).foregroundStyle(Palette.ink)
                                Text(lvl == .a1 ? S.fromZero[lang] : levelHint(lvl))
                                    .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            selectionMark(on)
                        }
                        .padding(12)
                        .modifier(SelectableGlass(selected: on, tint: Palette.brand))
                    }
                    .buttonStyle(.pressable)
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
        return "You start at \(placement.level.label) · \(unit.title.en)"
    }

    private func levelHint(_ lvl: CEFR) -> String {
        switch lvl {
        case .a1: return ""
        case .a2: return "I know the basics"
        case .b1: return "I can hold a conversation"
        case .b2: return "I already speak it well"
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
            let on = chosenGoal == xp
            HStack(spacing: 14) {
                OrbIcon(xp >= 100 ? "flame.fill" : "leaf.fill", look: on ? .accent(.amber) : .muted,
                        size: 44, symbolScale: 0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.heading(17)).foregroundStyle(Palette.ink)
                    Text("\(minutes) \(S.minPerDay[lang])")
                        .font(.plain(13)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Text("\(xp) XP").font(.heading(15)).foregroundStyle(Palette.amberDeep)
            }
            .padding(14)
            .modifier(SelectableGlass(selected: on, tint: Palette.amber))
        }
        .buttonStyle(.pressable)
    }

    private func header(title: String, subtitle: String?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            MascotBubble(mood: .happy, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.display(23)).foregroundStyle(Gradients.title)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle).font(.plain(14)).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
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
                    if step == 1, let chosenCourse { state.chooseCourse(chosenCourse) }
                    if step < lastStep {
                        withAnimation { step += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(step == lastStep ? S.start[lang] : S.continueBtn[lang])
                }
                .buttonStyle(.primary(.violet))
                .disabled(step == 1 && chosenCourse == nil)
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
                        MascotBubble(mood: .cheer, size: 120)
                        Text(S.secureDone[lang])
                            .font(.display(24)).foregroundStyle(Palette.ink)
                        Text(S.secureDoneSub[lang])
                            .font(.plain(14)).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.green)
                            Text(state.account.email)
                                .font(.heading(14)).foregroundStyle(Palette.ink)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .glassCapsule(tint: Palette.green)
                    }
                    .padding(.top, 30)
                } else {
                    header(title: S.secureTitle[lang], subtitle: S.secureSub[lang])
                    AccountForm(mode: .signUp, showsMascot: false)
                    if !state.account.isAvailable {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.amberDeep)
                            Text(S.secureNotSetUp[lang])
                                .font(.plain(12)).foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glass(radius: 18, tint: Palette.amber, material: false, shadow: false)
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

    private func selectionMark(_ on: Bool) -> some View {
        ZStack {
            Circle().strokeBorder(on ? Palette.brand : Palette.strokeDeep, lineWidth: 1.8)
            if on {
                Circle().fill(Gradients.primary).padding(3)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
    }
}

/// A glass card that lights up — tinted wash, bright rim, glow — once chosen.
struct SelectableGlass: ViewModifier {
    var selected: Bool
    var tint: Color

    func body(content: Content) -> some View {
        content
            .glass(radius: 24, tint: selected ? tint : nil)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(tint.opacity(0.7), lineWidth: 1.8)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }
}
