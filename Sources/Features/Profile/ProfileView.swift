import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var state
    @State private var showReset = false
    @State private var showCourseSwitch = false
    @State private var aiTest: AITestState = .idle
    @State private var cacheBump = 0

    enum AITestState: Equatable {
        case idle, running, ok(String), failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            StatsHeader()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identity
                    statsGrid
                    weekChart
                    courseProgress
                    AccountSection()
                    if state.unlimited { giftCard } else { shop }
                    settings
                    dangerZone
                }
                .padding(.horizontal, Metrics.hPad)
                .padding(.bottom, 30)
            }
        }
        .background(Palette.bg)
        .alert(S.resetTitle[state.native], isPresented: $showReset) {
            Button(S.cancel[state.native], role: .cancel) {}
            Button(S.confirm[state.native], role: .destructive) { state.resetEverything() }
        } message: { Text(S.resetMsg[state.native]) }
        .alert(S.changeCourse[state.native], isPresented: $showCourseSwitch) {
            Button(S.cancel[state.native], role: .cancel) {}
            Button(S.confirm[state.native], role: .destructive) { state.resetEverything() }
        } message: {
            Text(state.native == .it
                 ? "Per cambiare corso ricominciamo da capo. I progressi attuali verranno persi."
                 : "Kursni o'zgartirish uchun boshidan boshlaymiz. Joriy yutuqlar yo'qoladi.")
        }
    }

    // MARK: - Sections

    private var identity: some View {
        HStack(spacing: 14) {
            Mascot(mood: state.streak > 0 ? .cheer : .happy, size: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(state.native == .it ? "Corso di uzbeko" : "Italyan tili kursi")
                    .font(.heading(19)).foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    FlagBadge(language: state.native, size: 24)
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .black))
                        .foregroundStyle(Palette.inkFaint)
                    FlagBadge(language: state.target, size: 24)
                }
                Text("\(currentLevel.label) · \(currentLevel.blurb[state.native])")
                    .font(.plain(13)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var currentLevel: CEFR {
        CEFR.allCases.last { state.isLevelUnlocked($0) && state.completion(of: $0) > 0 }
            ?? CEFR.allCases.first { state.isLevelUnlocked($0) } ?? .a1
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statBox(icon: "flame.fill", tint: Palette.amber, value: "\(state.streak)", label: S.statsStreak[state.native])
            statBox(icon: "bolt.fill", tint: Palette.brand, value: "\(state.xp)", label: S.statsXP[state.native])
            statBox(icon: "book.fill", tint: Palette.green, value: "\(state.wordsLearned)", label: S.statsWords[state.native])
            statBox(icon: "graduationcap.fill", tint: Palette.purple, value: currentLevel.label, label: S.statsLevel[state.native])
        }
    }

    private func statBox(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 19, weight: .black)).foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.display(19)).foregroundStyle(Palette.ink)
                Text(label).font(.plain(11.5)).foregroundStyle(Palette.inkSoft).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.stroke, lineWidth: 2))
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: S.weekActivity[state.native].uppercased())
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let day = AppState.dayKey(daysAgo: 6 - i)
                    let xp = xpFor(day)
                    let ratio = min(1.0, Double(xp) / Double(max(20, state.settings.dailyGoal)))
                    VStack(spacing: 5) {
                        Text(xp > 0 ? "\(xp)" : "")
                            .font(.plain(9.5)).foregroundStyle(Palette.inkFaint)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(xp > 0 ? Palette.amber : Palette.locked)
                            .frame(height: max(8, 70 * ratio))
                        Text(weekdayLabel(daysAgo: 6 - i))
                            .font(.plain(10)).foregroundStyle(Palette.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.stroke, lineWidth: 2))
        }
    }

    private func xpFor(_ day: String) -> Int {
        state.historySnapshot.first { $0.day == day }?.xp ?? 0
    }

    private func weekdayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let f = DateFormatter()
        f.locale = Locale(identifier: state.native == .it ? "it_IT" : "uz_Latn_UZ")
        f.dateFormat = "EEEEE"
        return f.string(from: date).uppercased()
    }

    private var courseProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: S.courseProgress[state.native].uppercased())
            VStack(spacing: 12) {
                ForEach(CEFR.allCases) { lvl in
                    let ids = state.nodeIDs(for: lvl)
                    let done = ids.filter { state.isCompleted($0) }.count
                    let total = max(1, ids.count)
                    HStack(spacing: 12) {
                        Text(lvl.label).font(.heading(13)).foregroundStyle(.white)
                            .frame(width: 34, height: 26)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(state.isLevelUnlocked(lvl) ? Palette.brand : Palette.inkFaint))
                        ProgressBar(value: Double(done) / Double(total), tint: Palette.green, height: 12)
                        Text("\(done)/\(total)").font(.plain(12)).monospacedDigit()
                            .foregroundStyle(Palette.inkSoft).frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.stroke, lineWidth: 2))
        }
    }

    private var giftCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                Image(systemName: "infinity")
                    .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                    .offset(x: 13, y: 11)
            }
            .frame(width: 48, height: 48)
            .background(Circle().fill(LinearGradient(colors: [Palette.pink, Palette.red],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 2) {
                Text(S.unlimitedRes[state.native])
                    .font(.heading(16)).foregroundStyle(Palette.ink)
                Text(state.native == .it
                     ? "Studia quanto vuoi: gli errori non ti fermano mai."
                     : "Xohlagancha o'qing: xatolar sizni to'xtatmaydi.")
                    .font(.plain(12.5)).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .stroke(Palette.pink.opacity(0.35), lineWidth: 2))
    }

    private var shop: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: S.shop[state.native].uppercased())
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill").font(.system(size: 18, weight: .black))
                        .foregroundStyle(Palette.red)
                        .frame(width: 38, height: 38).background(Circle().fill(Palette.redSoft))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(S.refill[state.native]).font(.heading(15)).foregroundStyle(Palette.ink)
                        Text("\(state.hearts)/\(AppState.heartCap)").font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Button {
                        Feedback.pop(); _ = state.refillHearts(costingGems: true)
                    } label: { Text("100 💎").font(.heading(13)) }
                    .buttonStyle(.chunky(Palette.red, Palette.redDeep, height: 38, stretch: false))
                    .disabled(state.gems < 100 || state.hearts == AppState.heartCap)
                    .opacity(state.gems < 100 || state.hearts == AppState.heartCap ? 0.45 : 1)
                }
                Divider().overlay(Palette.stroke)
                HStack(spacing: 12) {
                    Image(systemName: "snowflake").font(.system(size: 18, weight: .black))
                        .foregroundStyle(Palette.brand)
                        .frame(width: 38, height: 38).background(Circle().fill(Palette.brand.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(S.buyFreeze[state.native]).font(.heading(15)).foregroundStyle(Palette.ink)
                        Text("\(S.freezeOwned[state.native]): \(state.freezes)")
                            .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Button {
                        Feedback.pop(); _ = state.buyFreeze()
                    } label: { Text("200 💎").font(.heading(13)) }
                    .buttonStyle(.chunky(Palette.brand, Palette.brandDeep, height: 38, stretch: false))
                    .disabled(state.gems < 200 || state.freezes >= 2)
                    .opacity(state.gems < 200 || state.freezes >= 2 ? 0.45 : 1)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.stroke, lineWidth: 2))
        }
    }

    private var settings: some View {
        @Bindable var st = state
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: S.settingsTitle[state.native].uppercased())
            VStack(spacing: 4) {
                toggleRow(S.soundsOn[state.native], icon: "speaker.wave.2.fill",
                          isOn: Binding(get: { st.settings.sounds },
                                        set: { st.settings.sounds = $0; Feedback.soundsEnabled = $0 }))
                toggleRow(S.hapticsOn[state.native], icon: "iphone.radiowaves.left.and.right",
                          isOn: Binding(get: { st.settings.haptics },
                                        set: { st.settings.haptics = $0; Feedback.hapticsEnabled = $0 }))
                toggleRow(S.speakingOn[state.native], icon: "mic.fill",
                          isOn: Binding(get: { st.settings.speakingExercises },
                                        set: { st.settings.speakingExercises = $0 }))
                toggleRow(S.wordHintsOn[state.native], icon: "hand.tap.fill",
                          isOn: Binding(get: { st.settings.wordHints },
                                        set: { st.settings.wordHints = $0 }))
                toggleRow(S.freshPhrases[state.native], icon: "wand.and.sparkles",
                          isOn: Binding(get: { st.settings.freshPhrases },
                                        set: { st.settings.freshPhrases = $0 }))
                Text(S.freshPhrasesSub[state.native])
                    .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14).padding(.bottom, 2)
                toggleRow(S.listeningOn[state.native], icon: "ear.fill",
                          isOn: Binding(get: { st.settings.listeningExercises },
                                        set: { st.settings.listeningExercises = $0 }))

                // a hold she set from inside a lesson, with a way out of it
                snoozeRow(st, skill: .speaking, label: S.onHoldSpeaking[state.native])
                snoozeRow(st, skill: .listening, label: S.onHoldListening[state.native])

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(S.speechRate[state.native], systemImage: "tortoise.fill")
                            .font(.body(15)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(Int(st.settings.speechRate * 100))%")
                            .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    }
                    Slider(value: Binding(get: { st.settings.speechRate },
                                          set: { st.settings.speechRate = $0 }), in: 0.25...0.6)
                        .tint(Palette.brand)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                toggleRow(S.unlimitedRes[state.native], icon: "infinity",
                          isOn: Binding(get: { st.settings.unlimitedResources },
                                        set: { st.settings.unlimitedResources = $0 }))
                toggleRow(S.reminder[state.native], icon: "bell.fill",
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
                        .padding(.horizontal, 12).padding(.vertical, 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(S.dailyGoal[state.native], systemImage: "target")
                            .font(.body(15)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(st.settings.dailyGoal) XP").font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    }
                    Picker("", selection: Binding(get: { st.settings.dailyGoal },
                                                  set: { st.settings.dailyGoal = $0 })) {
                        Text("20").tag(20); Text("50").tag(50); Text("100").tag(100); Text("150").tag(150)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                Divider().overlay(Palette.stroke)

                aiSection(st)

                Divider().overlay(Palette.stroke)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(S.voiceInfo[state.native], systemImage: "waveform")
                            .font(.body(14)).foregroundStyle(Palette.ink)
                        Spacer()
                    }
                    Text(SpeechService.shared.voiceDescription(for: state.target))
                        .font(.plain(12)).foregroundStyle(Palette.inkSoft)
                    if SpeechService.shared.usesApproximateVoice(for: state.target) {
                        Text(S.approximateVoice[state.native])
                            .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if SpeechService.shared.hasRealVoice(for: state.target) {
                        Label(S.realVoice[state.native], systemImage: "checkmark.seal.fill")
                            .font(.heading(11.5)).foregroundStyle(Palette.green)
                            .fixedSize(horizontal: false, vertical: true)
                        if RecognizerService.shared.usesOnDevice(for: state.target) {
                            Label(S.onDeviceEars[state.native], systemImage: "waveform.badge.mic")
                                .font(.heading(11.5)).foregroundStyle(Palette.green)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 8) {
                            Text(S.voiceCached[state.native] + " " + cacheLabel)
                                .font(.plain(11)).foregroundStyle(Palette.inkFaint)
                            Button {
                                Feedback.tap(); VoiceCache.empty(); cacheBump += 1
                            } label: {
                                Text(S.emptyVoiceCache[state.native])
                                    .font(.heading(11)).foregroundStyle(Palette.brand)
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous).stroke(Palette.stroke, lineWidth: 2))
        }
    }

    @ViewBuilder
    private func snoozeRow(_ st: AppState, skill: Skill, label: String) -> some View {
        if st.isSnoozed(skill) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.amberDeep)
                    .frame(width: 26)
                Text("\(label) \(st.snoozeMinutesLeft(skill)) \(S.minutesShort[state.native])")
                    .font(.plain(13.5)).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Button {
                    Feedback.tap(); st.wakeUp(skill)
                } label: {
                    Text(S.resumeNow[state.native])
                        .font(.heading(12)).foregroundStyle(Palette.brand)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.amber.opacity(0.14)))
            .padding(.horizontal, 12)
        }
    }

    /// Recomputed when the cache is emptied, so the figure on screen is never stale.
    private var cacheLabel: String {
        _ = cacheBump
        let bytes = VoiceCache.size
        guard bytes > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    @ViewBuilder
    private func aiSection(_ st: AppState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(S.aiTitle[state.native], systemImage: "sparkles")
                .font(.body(14)).foregroundStyle(Palette.ink)

            if st.aiIsBuiltIn {
                Label(S.aiBuiltIn[state.native], systemImage: "checkmark.seal.fill")
                    .font(.heading(12)).foregroundStyle(Palette.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("", selection: Binding(get: { st.settings.aiProvider },
                                          set: { st.settings.aiProvider = $0; aiTest = .idle })) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.label[state.native]).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            if st.settings.aiProvider != .none {
                SecureField(S.aiKeyField[state.native],
                            text: Binding(get: { st.settings.aiKey },
                                          set: { st.settings.aiKey = $0; aiTest = .idle }))
                    .font(.plain(13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Palette.bg))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.stroke, lineWidth: 1.5))

                Text("\(S.aiKeyWhere[state.native]) \(st.settings.aiProvider.console) · \(st.settings.aiProvider.keyPrefixHint)")
                    .font(.plain(11.5)).foregroundStyle(Palette.brand)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button {
                        Feedback.tap()
                        runAITest(provider: st.settings.aiProvider, key: st.settings.aiKey)
                    } label: {
                        Text(aiTest == .running ? S.aiTesting[state.native] : S.aiTest[state.native])
                            .font(.heading(13))
                    }
                    .buttonStyle(.chunky(Palette.purple, Palette.purpleDeep, height: 38, stretch: false))
                    .disabled(st.settings.aiKey.trimmingCharacters(in: .whitespaces).isEmpty
                              || aiTest == .running)

                    switch aiTest {
                    case .ok(let reply):
                        VStack(alignment: .leading, spacing: 1) {
                            Label(S.aiWorks[state.native], systemImage: "checkmark.circle.fill")
                                .font(.heading(12)).foregroundStyle(Palette.green)
                            Text(reply).font(.plain(10.5)).foregroundStyle(Palette.inkFaint)
                                .lineLimit(2)
                        }
                    case .failed(let message):
                        Text(message)
                            .font(.plain(11)).foregroundStyle(Palette.red)
                            .fixedSize(horizontal: false, vertical: true)
                    default:
                        EmptyView()
                    }
                    Spacer(minLength: 0)
                }
            }

            Text(st.aiProvider == .none ? S.aiNote[state.native] : S.aiFreeHint[state.native])
                .font(.plain(11.5)).foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func runAITest(provider: AIProvider, key: String) {
        aiTest = .running
        Task {
            do {
                let reply = try await AIClient.test(provider: provider, key: key)
                await MainActor.run { aiTest = .ok(reply) }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run { aiTest = .failed(message) }
            }
        }
    }

    private func syncReminder(enabled: Bool) {
        if enabled {
            let hour = state.settings.reminderHour
            let minute = state.settings.reminderMinute
            let lang = state.native
            let streak = state.streak
            Task { await Reminders.schedule(hour: hour, minute: minute, language: lang, streak: streak) }
        } else {
            Reminders.cancel()
        }
    }

    private func toggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon).font(.body(15)).foregroundStyle(Palette.ink)
        }
        .tint(Palette.green)
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var dangerZone: some View {
        VStack(spacing: 10) {
            Button { Feedback.tap(); showCourseSwitch = true } label: {
                Text(S.changeCourse[state.native])
            }
            .buttonStyle(.chunkyGhost)

            Button { Feedback.tap(); showReset = true } label: {
                Text(S.resetTitle[state.native]).foregroundStyle(Palette.red)
            }
            .buttonStyle(.chunky(Palette.card, Palette.strokeDeep, text: Palette.red))
        }
        .padding(.top, 4)
    }
}

extension AppState {
    var historySnapshot: [DaySnapshot] { s.history }
}
