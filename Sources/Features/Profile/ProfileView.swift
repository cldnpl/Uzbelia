import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var state
    @Environment(DialogPresenter.self) private var dialogs
    @State private var showCourses = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StatsHeader()
                TabHeader(eyebrow: S.profileEyebrow[state.native], title: S.profileHeadline[state.native])
                identity
                statsGrid
                weekChart
                courseProgress
                AccountSection()
                settings
                dangerZone
            }
            .padding(.horizontal, Metrics.hPad)
            .padding(.top, 6)
            .padding(.bottom, Metrics.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .background(AuroraBackground(mood: .profile))
        .sheet(isPresented: $showCourses) {
            CoursePickerSheet().auroraSheet()
        }
    }

    // MARK: - Sections

    private var identity: some View {
        HStack(spacing: 16) {
            MascotBubble(mood: state.streak > 0 ? .cheer : .happy, size: 78)
            VStack(alignment: .leading, spacing: 7) {
                Text("\(state.target.name) course")
                    .font(.display(20)).foregroundStyle(Palette.ink)
                HStack(spacing: 7) {
                    FlagBadge(language: state.native, size: 24)
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.inkFaint)
                    FlagBadge(language: state.target, size: 24)
                    GlassChip(text: "\(currentLevel.label) · \(currentLevel.blurb[state.native])",
                              tint: Palette.brand)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glass(radius: 28)
    }

    private var currentLevel: CEFR { state.studyLevel }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statBox(icon: "flame.fill", accent: .amber, value: "\(state.streak)", label: S.statsStreak[state.native])
            statBox(icon: "bolt.fill", accent: .purple, value: "\(state.xp)", label: S.statsXP[state.native])
            statBox(icon: "book.fill", accent: .green, value: "\(state.wordsLearned)", label: S.statsWords[state.native])
            statBox(icon: "graduationcap.fill", accent: .sky, value: currentLevel.label, label: S.statsLevel[state.native])
        }
    }

    private func statBox(icon: String, accent: UnitAccent, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            OrbIcon(icon, accent: accent, size: 44, symbolScale: 0.4)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.display(21)).foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(label).font(.plain(11.5)).foregroundStyle(Palette.inkSoft).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .glass(radius: 24)
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: S.weekActivity[state.native].uppercased())
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(0..<7, id: \.self) { i in
                    let day = AppState.dayKey(daysAgo: 6 - i)
                    let xp = xpFor(day)
                    let ratio = min(1.0, Double(xp) / Double(max(20, state.settings.dailyGoal)))
                    VStack(spacing: 6) {
                        Text(xp > 0 ? "\(xp)" : "")
                            .font(.heading(9.5)).foregroundStyle(Palette.inkSoft)
                        Capsule()
                            .fill(xp > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [Violet.v300, Palette.brand],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Palette.locked))
                            .frame(width: 22, height: max(10, 86 * ratio))
                            .shadow(color: xp > 0 ? Palette.brand.opacity(0.3) : .clear, radius: 6, y: 3)
                        Text(weekdayLabel(daysAgo: 6 - i))
                            .font(.heading(10.5))
                            .foregroundStyle(i == 6 ? Palette.brand : Palette.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .glass(radius: 26)
        }
    }

    private func xpFor(_ day: String) -> Int {
        state.historySnapshot.first { $0.day == day }?.xp ?? 0
    }

    private func weekdayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEEE"
        return f.string(from: date).uppercased()
    }

    private var courseProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: S.courseProgress[state.native].uppercased())
            VStack(spacing: 14) {
                ForEach(CEFR.allCases) { lvl in
                    let ids = state.nodeIDs(for: lvl)
                    let done = ids.filter { state.isCompleted($0) }.count
                    let total = max(1, ids.count)
                    let open = state.isLevelUnlocked(lvl)
                    HStack(spacing: 12) {
                        Text(lvl.label).font(.heading(13)).foregroundStyle(open ? .white : Palette.inkFaint)
                            .frame(width: 38, height: 28)
                            .background {
                                if open { Capsule().fill(Gradients.primary) } else { Capsule().fill(Palette.locked) }
                            }
                        ProgressBar(value: Double(done) / Double(total), tint: Palette.brand, height: 8)
                        Text("\(done)/\(total)").font(.heading(12)).monospacedDigit()
                            .foregroundStyle(Palette.inkSoft).frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .glass(radius: 26)
        }
    }

    private var settings: some View {
        @Bindable var st = state
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: S.settingsTitle[state.native].uppercased())

            // the lessons
            VStack(spacing: 2) {
                toggleRow(S.speakingOn[state.native], icon: "mic.fill", accent: .speaking,
                          isOn: Binding(get: { st.settings.speakingExercises },
                                        set: { st.settings.speakingExercises = $0 }))
                toggleRow(S.listeningOn[state.native], icon: "headphones", accent: .listening,
                          isOn: Binding(get: { st.settings.listeningExercises },
                                        set: { st.settings.listeningExercises = $0 }))
                toggleRow(S.wordHintsOn[state.native], icon: "hand.tap.fill", accent: .reading,
                          isOn: Binding(get: { st.settings.wordHints },
                                        set: { st.settings.wordHints = $0 }))

                // a hold she set from inside a lesson, with a way out of it
                snoozeRow(st, skill: .speaking, label: S.onHoldSpeaking[state.native])
                snoozeRow(st, skill: .listening, label: S.onHoldListening[state.native])

                divider

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        rowIcon("tortoise.fill", accent: .purple)
                        Text(S.speechRate[state.native]).font(.body(15)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(Int(st.settings.speechRate * 100))%")
                            .font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                    }
                    Slider(value: Binding(get: { st.settings.speechRate },
                                          set: { st.settings.speechRate = $0 }), in: 0.25...0.6)
                        .tint(Palette.brand)
                        .padding(.leading, 48)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
            .padding(.vertical, 8)
            .glass(radius: 26)

            // the day
            VStack(spacing: 2) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        rowIcon("target", accent: .purple)
                        Text(S.dailyGoal[state.native]).font(.body(15)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(st.settings.dailyGoal) XP").font(.heading(12.5)).foregroundStyle(Palette.inkSoft)
                    }
                    GlassSegmented(selection: Binding(get: { st.settings.dailyGoal },
                                                      set: { st.settings.dailyGoal = $0 }),
                                   options: [20, 50, 100, 150]) { "\($0)" }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)

                divider

                toggleRow(S.reminder[state.native], icon: "bell.fill", accent: .purple,
                          isOn: Binding(get: { st.settings.reminderOn },
                                        set: { on in
                                            st.settings.reminderOn = on
                                            syncReminder(enabled: on)
                                        }))
                if st.settings.reminderOn {
                    DatePicker(S.reminderTime[state.native],
                               selection: Binding(
                                    get: {
                                        Calendar.current.date(from: DateComponents(
                                            hour: st.settings.reminderHour,
                                            minute: st.settings.reminderMinute)) ?? .now
                                    },
                                    set: { date in
                                        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        st.settings.reminderHour = c.hour ?? 19
                                        st.settings.reminderMinute = c.minute ?? 0
                                        syncReminder(enabled: true)
                                    }),
                               displayedComponents: .hourAndMinute)
                        .font(.body(15))
                        .foregroundStyle(Palette.ink)
                        .padding(.leading, 60).padding(.trailing, 14).padding(.vertical, 4)
                }

                divider

                toggleRow(S.soundsOn[state.native], icon: "speaker.wave.2.fill", accent: .purple,
                          isOn: Binding(get: { st.settings.sounds },
                                        set: { st.settings.sounds = $0; Feedback.soundsEnabled = $0 }))
                toggleRow(S.hapticsOn[state.native], icon: "iphone.radiowaves.left.and.right", accent: .purple,
                          isOn: Binding(get: { st.settings.haptics },
                                        set: { st.settings.haptics = $0; Feedback.hapticsEnabled = $0 }))
            }
            .padding(.vertical, 8)
            .glass(radius: 26)
        }
    }

    private var divider: some View {
        Divider().overlay(Palette.stroke).padding(.horizontal, 14).padding(.vertical, 4)
    }

    private func rowIcon(_ icon: String, accent: UnitAccent) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(accent.deep)
            .frame(width: 36, height: 36)
            .glassCircle(tint: accent.main, material: false, shadow: false)
    }

    @ViewBuilder
    private func snoozeRow(_ st: AppState, skill: Skill, label: String) -> some View {
        if st.isSnoozed(skill) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.amberDeep)
                Text("\(label) \(st.snoozeMinutesLeft(skill)) \(S.minutesShort[state.native])")
                    .font(.plain(13.5)).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Button {
                    Feedback.tap(); st.wakeUp(skill)
                } label: {
                    Text(S.resumeNow[state.native])
                        .font(.heading(12.5)).foregroundStyle(Palette.brand)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCapsule(tint: Palette.amber, material: false, shadow: false)
            .padding(.horizontal, 12).padding(.vertical, 3)
        }
    }

    private func syncReminder(enabled: Bool) {
        if enabled {
            let hour = state.settings.reminderHour
            let minute = state.settings.reminderMinute
            let lang = state.target
            let streak = state.streak
            Task { await Reminders.schedule(hour: hour, minute: minute, language: lang, streak: streak) }
        } else {
            Reminders.cancel()
        }
    }

    private func toggleRow(_ title: String, icon: String, accent: UnitAccent, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                rowIcon(icon, accent: accent)
                Text(title).font(.body(15)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.glass)
        .padding(.horizontal, 14).padding(.vertical, 6)
    }

    private var dangerZone: some View {
        VStack(spacing: 10) {
            Button {
                Feedback.tap()
                showCourses = true
            } label: {
                Label(S.changeCourse[state.native], systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(.glass)

            Button {
                Feedback.tap()
                dialogs.present(GlassDialog(
                    title: S.resetTitle[state.native], message: S.resetMsg[state.native],
                    confirm: S.confirm[state.native], cancel: S.cancel[state.native],
                    destructive: true, icon: "arrow.counterclockwise") { state.resetEverything() })
            } label: {
                Label(S.resetTitle[state.native], systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.glass(nil, text: Palette.redDeep))
        }
        .padding(.top, 4)
    }
}

extension AppState {
    var historySnapshot: [DaySnapshot] { s.history }
}

/// Another course, or back to one already started. Nothing is reset: the course she
/// leaves keeps every lesson and every word, ready for when she comes back.
struct CoursePickerSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: S.changeCourse[state.native],
                        subtitle: "Your progress in every course is kept.") { dismiss() }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Language.courses.filter { ContentStore.hasCourse($0) }) { course in
                        let current = course == state.target
                        Button {
                            Feedback.pop()
                            state.chooseCourse(course)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                FlagOrb(language: course, size: 50)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name).font(.heading(17)).foregroundStyle(Palette.ink)
                                    Text(course.endonym).font(.plain(13.5)).foregroundStyle(Palette.inkSoft)
                                }
                                Spacer(minLength: 0)
                                if current {
                                    GlassChip(text: "Current", icon: "checkmark", tint: Palette.brandDeep)
                                }
                            }
                            .padding(14)
                            .glass(radius: 24, tint: current ? Palette.brand : nil)
                        }
                        .buttonStyle(.pressable)
                        .disabled(current)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Metrics.hPad)
        .padding(.top, 18)
    }
}
