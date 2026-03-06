import SwiftUI

// MARK: - DASHBOARD VIEW
struct DashboardView: View {
    let username: String
    @EnvironmentObject var vm: AppViewModel
    @State private var showShareCard = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    headerSection
                    focusScoreWidget
                    xpLevelCompact
                    milestonesCompact
                    dailyGoalCard
                    productivityGraphWidget
                    navigationCards
                    leaderboardWidget
                    shareProgressButton

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $vm.showReflection) {
                DailyReflectionView().environmentObject(vm)
            }
            .sheet(isPresented: $showShareCard) {
                ShareProgressCardView().environmentObject(vm)
            }
            .sheet(isPresented: $vm.showNoteSheet) {
                SessionNoteSheetView(sessionNum: vm.pendingNoteSessionNum)
                    .environmentObject(vm)
            }
            .fullScreenCover(isPresented: $vm.showMilestone) {
                if let m = vm.lastMilestone {
                    MilestoneCelebrationView(milestone: m)
                }
            }
            .overlay(alignment: .top) {
                if vm.showXPGain {
                    XPToastView(xp: vm.lastXPGain)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.4), value: vm.showXPGain)
                }
            }
            .onAppear { checkEndOfDay() }
        }
    }

    // MARK: - Header
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText())
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
                Text("\(username) 👋")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            NavigationLink {
                ProfileView(username: username).environmentObject(vm)
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.2))
                        .frame(width: 46, height: 46)
                    Text(String(username.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Focus Score Widget
    var focusScoreWidget: some View {
        let score = vm.focusScore()
        let color = vm.focusScoreColor()
        let label = vm.focusScoreLabel()

        return ZStack {
            // Background gradient card
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )

            HStack(spacing: 20) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)
                        .animation(.spring(response: 1.0), value: score)

                    VStack(spacing: 0) {
                        Text("\(score)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/100")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Focus Score")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                    Text(label)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    // Breakdown mini labels
                    HStack(spacing: 8) {
                        scoreChip(icon: "timer", value: "\(vm.todaySessionCount())s", color: .orange)
                        scoreChip(icon: "checkmark.circle.fill", value: "\(vm.habits.filter { $0.completed }.count)h", color: .green)
                        scoreChip(icon: "flame.fill", value: "\(vm.habits.map { $0.streak }.max() ?? 0)d", color: .red)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    func scoreChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Daily Goal Card
    var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily Focus Goal", systemImage: "flag.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(vm.todaySessionCount()) / \(vm.dailyFocusGoal)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(colors: [.orange, .yellow],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(
                            width: geo.size.width * CGFloat(min(vm.todaySessionCount(), vm.dailyFocusGoal)) / CGFloat(max(1, vm.dailyFocusGoal)),
                            height: 8
                        )
                        .animation(.spring(response: 0.6), value: vm.todaySessionCount())
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    // MARK: - Productivity Graph Widget
    var productivityGraphWidget: some View {
        let data     = vm.last14DaysData()
        let maxCount = max(1, data.map { $0.count }.max() ?? 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Productivity", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("14 days")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }

            // Bar chart
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(data.indices, id: \.self) { i in
                    let item   = data[i]
                    let height = max(4, CGFloat(item.count) / CGFloat(maxCount) * 80)
                    let isToday = i == data.count - 1

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                isToday
                                ? LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
                                : LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)],
                                                 startPoint: .bottom, endPoint: .top)
                            )
                            .frame(height: height)
                            .animation(.spring(response: 0.5).delay(Double(i) * 0.03), value: height)

                        // Show label every 3rd day
                        if i % 3 == 0 || isToday {
                            Text(item.label)
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.secondaryText)
                        } else {
                            Text(" ")
                                .font(.system(size: 8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            // Summary row
            HStack(spacing: 16) {
                graphStat(label: "Today",     value: "\(vm.todaySessionCount())")
                graphStat(label: "This Week", value: "\(vm.weekSessionCount())")
                graphStat(label: "Best Day",  value: "\(data.map { $0.count }.max() ?? 0)")
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func graphStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.accent)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Navigation Cards
    var navigationCards: some View {
        VStack(spacing: 12) {
            NavigationLink {
                PomodoroView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "Pomodoro Timer",
                    icon:     "timer",
                    subtitle: "\(vm.todaySessionCount()) sessions · \(vm.todayTasks().filter { $0.isDone }.count)/\(vm.todayTasks().count) tasks",
                    color:    .orange
                )
            }

            NavigationLink {
                HabitTrackerView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "Habit Tracker",
                    icon:     "chart.pie.fill",
                    subtitle: "\(vm.habits.filter { $0.completed }.count)/\(vm.habits.count) habits done today",
                    color:    .blue
                )
            }

            NavigationLink {
                FocusHistoryView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "Focus History",
                    icon:     "clock.arrow.circlepath",
                    subtitle: "\(vm.weekSessionCount()) sessions this week",
                    color:    .purple
                )
            }

            NavigationLink {
                StudyLogView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "Study Log",
                    icon:     "note.text",
                    subtitle: "\(vm.sessionNotes.count) notes · \(String(format: "%.1f", vm.totalStudyHours()))h studied",
                    color:    .cyan
                )
            }

            NavigationLink {
                XPLevelView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "XP & Level",
                    icon:     vm.currentLevel.icon,
                    subtitle: "\(vm.currentLevel.title) · \(vm.totalXP) XP",
                    color:    vm.currentLevel.color
                )
            }

            NavigationLink {
                MilestonesView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "Milestones",
                    icon:     "trophy.fill",
                    subtitle: "\(vm.milestones.filter { $0.achieved }.count)/\(vm.milestones.count) badges · \(String(format: "%.1f", vm.totalStudyHours()))h",
                    color:    .yellow
                )
            }

            NavigationLink {
                StudyPlannerView().environmentObject(vm)
            } label: {
                dashboardCard(
                    title:    "Study Planner",
                    icon:     "calendar.badge.clock",
                    subtitle: "AI-powered weekly schedule",
                    color:    .mint
                )
            }
        }
    }

    func dashboardCard(title: String, icon: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    // MARK: - Leaderboard Widget
    var leaderboardWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Leaderboard", systemImage: "trophy.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("This Week")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
            }

            VStack(spacing: 10) {
                ForEach(Array(vm.sortedLeaderboard.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    leaderboardRow(entry: entry, rank: index + 1)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func leaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        let isMe = entry.name == "You"
        return HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.2))
                    .frame(width: 30, height: 30)
                if rank <= 3 {
                    Text(rankEmoji(rank))
                        .font(.system(size: 15))
                } else {
                    Text("\(rank)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(rankColor(rank))
                }
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(isMe ? AppTheme.accent.opacity(0.25) : Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: entry.avatar)
                    .font(.system(size: 15))
                    .foregroundColor(isMe ? AppTheme.accent : .white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: isMe ? .bold : .medium, design: .rounded))
                    .foregroundColor(isMe ? AppTheme.accent : .white)
                Text("\(entry.weekSessions) sessions · \(entry.weekHabits) habits")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            Text("\(entry.score)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(isMe ? AppTheme.accent : .white.opacity(0.8))
        }
        .padding(10)
        .background(isMe ? AppTheme.accent.opacity(0.08) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMe ? AppTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    func rankEmoji(_ rank: Int) -> String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; default: return "🥉" }
    }

    func rankColor(_ rank: Int) -> Color {
        switch rank { case 1: return .yellow; case 2: return .gray; case 3: return .orange; default: return .white.opacity(0.4) }
    }

    // MARK: - Share Progress Button
    var shareProgressButton: some View {
        Button {
            showShareCard = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Share Progress")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Show off your stats to friends")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    // MARK: - Helpers
    func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:     return "Good evening,"
        }
    }

    func checkEndOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 20 && vm.todayReflection == nil { vm.showReflection = true }
    }

    // MARK: - XP Level Compact Widget
    var xpLevelCompact: some View {
        let level = vm.currentLevel
        let progress = vm.progressToNextLevel

        return NavigationLink {
            XPLevelView().environmentObject(vm)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.2))
                        .frame(width: 46, height: 46)
                    Image(systemName: level.icon)
                        .font(.system(size: 20))
                        .foregroundColor(level.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(level.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(level.color)
                        Spacer()
                        Text("\(vm.totalXP) XP")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [level.color, level.color.opacity(0.6)],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        }
                    }
                    .frame(height: 5)

                    if let next = level.nextLevel {
                        Text("\(vm.xpNeededForNext) XP to \(next.title)")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.secondaryText)
                    } else {
                        Text("Max level reached! 👑")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 1, green: 0.84, blue: 0))
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(level.color.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Milestones Compact Widget
    var milestonesCompact: some View {
        let earned = vm.milestones.filter { $0.achieved }.count
        let progress = vm.progressToNextMilestone

        return NavigationLink {
            MilestonesView().environmentObject(vm)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Milestones", systemImage: "trophy.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(earned)/\(vm.milestones.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.yellow)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                }

                // Emoji badges row
                HStack(spacing: 8) {
                    ForEach(vm.milestones) { m in
                        Text(m.icon)
                            .font(.system(size: 20))
                            .opacity(m.achieved ? 1.0 : 0.25)
                            .grayscale(m.achieved ? 0 : 1)
                    }
                    Spacer()
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.yellow, .orange],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(progress), height: 5)
                    }
                }
                .frame(height: 5)

                if let next = vm.nextMilestoneTarget {
                    Text("Next: \(next.icon) \(next.title) (\(next.hours)h)")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

// MARK: - SHARE PROGRESS CARD VIEW
struct ShareProgressCardView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("Your Progress Card")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.top, 20)

                        // The card itself
                        progressCard
                            .padding(.horizontal, 24)

                        // Share button
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Card")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.orange, .yellow],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .padding(.horizontal, 24)
                        }

                        Text("Tap Share to send via Messages, Instagram, WhatsApp and more")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Progress Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: ["Check out my Student Focus progress! 🔥\n\n📊 Focus Score: \(vm.focusScore())/100\n⏱ Sessions this week: \(vm.weekSessionCount())\n✅ Habits today: \(vm.habits.filter { $0.completed }.count)/\(vm.habits.count)\n🔥 Best streak: \(vm.habits.map { $0.streak }.max() ?? 0) days\n\nBuilding focus daily with Student Focus App 📚"])
            }
        }
    }

    var progressCard: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.06, blue: 0.0),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(colors: [.orange.opacity(0.6), .yellow.opacity(0.3), .orange.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )

            VStack(spacing: 24) {
                // Header
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(LinearGradient(colors: [.orange, .yellow],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Student Focus")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Weekly Progress")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    Spacer()
                    Text(weekRangeText())
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.secondaryText)
                }

                // Focus Score big
                VStack(spacing: 4) {
                    Text("\(vm.focusScore())")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.orange, .yellow],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text("FOCUS SCORE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText)
                        .tracking(3)
                    Text(vm.focusScoreLabel())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Stats row
                HStack(spacing: 0) {
                    cardStat(value: "\(vm.weekSessionCount())", label: "Sessions", icon: "timer", color: .orange)
                    Divider().frame(height: 40).background(Color.white.opacity(0.1))
                    cardStat(value: "\(vm.habits.filter { $0.completed }.count)/\(vm.habits.count)", label: "Habits", icon: "checkmark.circle.fill", color: .green)
                    Divider().frame(height: 40).background(Color.white.opacity(0.1))
                    cardStat(value: "\(vm.habits.map { $0.streak }.max() ?? 0)d", label: "Best Streak", icon: "flame.fill", color: .red)
                }
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)

                // Mini habit list
                VStack(spacing: 8) {
                    ForEach(vm.habits.prefix(3)) { habit in
                        HStack {
                            Image(systemName: habit.icon)
                                .foregroundColor(habit.category.color)
                                .font(.system(size: 13))
                                .frame(width: 20)
                            Text(habit.name)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(vm.weeklyCompletions(for: habit))/7 days")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(habit.category.color)
                        }
                        .padding(.horizontal, 4)
                    }
                }

                // Footer
                HStack {
                    Text("Built with Student Focus App 📱")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    Text("Keep going! 🚀")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.7))
                }
            }
            .padding(24)
        }
    }

    func cardStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    func weekRangeText() -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let end   = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: end)!
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}

// MARK: - SHARE SHEET (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - DAILY REFLECTION VIEW
struct DailyReflectionView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.accent)
            Text("Daily Reflection")
                .font(.largeTitle.bold())
            Text("How productive was your day?")
                .foregroundColor(AppTheme.secondaryText)

            VStack(spacing: 14) {
                ForEach(ReflectionRating.allCases, id: \.self) { rating in
                    Button {
                        vm.saveReflection(rating)
                        dismiss()
                    } label: {
                        Text(rating.rawValue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(vm.todayReflection == rating ? AppTheme.accent : AppTheme.card)
                            .foregroundColor(vm.todayReflection == rating ? .black : .white)
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal)

            Button("Skip for now") { dismiss() }
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}

