import SwiftUI
import UserNotifications

// MARK: - THEME
struct AppTheme {
    static let accent = Color.orange
    static let card = Color(.secondarySystemBackground)
    static let secondaryText = Color(.secondaryLabel)
}

// MARK: - MODELS

struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String
    var category: HabitCategory
    var completed: Bool
    var streak: Int
    var reminderTime: Date?
    var completionHistory: [String] = [] // "yyyy-MM-dd" strings
}

enum HabitCategory: String, Codable, CaseIterable {
    case health = "Health"
    case study = "Study"
    case fitness = "Fitness"
    case mindfulness = "Mindfulness"
    case other = "Other"

    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .study: return "book.fill"
        case .fitness: return "figure.walk"
        case .mindfulness: return "brain.head.profile"
        case .other: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .health: return .red
        case .study: return .blue
        case .fitness: return .green
        case .mindfulness: return .purple
        case .other: return .orange
        }
    }
}

struct FocusSession: Codable {
    var date: String // "yyyy-MM-dd"
    var count: Int
}

enum ReflectionRating: String, CaseIterable {
    case good = "Good 😊"
    case average = "Average 😐"
    case needsImprovement = "Needs Improvement 😔"
}

// MARK: - VIEW MODEL
class AppViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var focusSessions: [FocusSession] = []
    @Published var dailyFocusGoal: Int = 4
    @Published var todayReflection: ReflectionRating? = nil
    @Published var showReflection = false

    private let habitsKey = "habits_v2"
    private let sessionsKey = "focus_sessions"
    private let goalKey = "daily_focus_goal"
    private let reflectionKey = "today_reflection"

    init() {
        loadHabits()
        loadSessions()
        dailyFocusGoal = UserDefaults.standard.integer(forKey: goalKey) == 0 ? 4 : UserDefaults.standard.integer(forKey: goalKey)
        if let raw = UserDefaults.standard.string(forKey: reflectionKey + todayKey()),
           let r = ReflectionRating(rawValue: raw) {
            todayReflection = r
        }
        requestNotificationPermission()
        resetHabitsIfNewDay()
    }

    func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Habits
    func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: habitsKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        } else {
            habits = [
                Habit(name: "Water", icon: "drop.fill", category: .health, completed: false, streak: 3),
                Habit(name: "Study", icon: "book.fill", category: .study, completed: false, streak: 5),
                Habit(name: "Steps", icon: "figure.walk", category: .fitness, completed: false, streak: 2)
            ]
        }
    }

    func saveHabits() {
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: habitsKey)
        }
    }

    func toggleHabit(at index: Int) {
        let today = todayKey()
        habits[index].completed.toggle()
        if habits[index].completed {
            if !habits[index].completionHistory.contains(today) {
                habits[index].completionHistory.append(today)
            }
            habits[index].streak = calculateStreak(for: habits[index])
        } else {
            habits[index].completionHistory.removeAll { $0 == today }
            habits[index].streak = max(0, calculateStreak(for: habits[index]))
        }
        saveHabits()
    }

    func calculateStreak(for habit: Habit) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var streak = 0
        var date = Date()
        while true {
            let key = f.string(from: date)
            if habit.completionHistory.contains(key) {
                streak += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }
        return streak
    }

    func resetHabitsIfNewDay() {
        let lastReset = UserDefaults.standard.string(forKey: "last_reset_date") ?? ""
        let today = todayKey()
        if lastReset != today {
            for i in habits.indices {
                habits[i].completed = false
            }
            saveHabits()
            UserDefaults.standard.set(today, forKey: "last_reset_date")
        }
    }

    func weeklyCompletions(for habit: Habit) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var count = 0
        for offset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            if habit.completionHistory.contains(f.string(from: date)) { count += 1 }
        }
        return count
    }

    func heatmapData(for habit: Habit) -> [Bool] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return (0..<30).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            return habit.completionHistory.contains(f.string(from: date))
        }
    }

    // MARK: - Focus Sessions
    func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            focusSessions = decoded
        }
    }

    func saveSessions() {
        if let data = try? JSONEncoder().encode(focusSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    func recordFocusSession() {
        let today = todayKey()
        if let idx = focusSessions.firstIndex(where: { $0.date == today }) {
            focusSessions[idx].count += 1
        } else {
            focusSessions.append(FocusSession(date: today, count: 1))
        }
        saveSessions()
    }

    func todaySessionCount() -> Int {
        focusSessions.first(where: { $0.date == todayKey() })?.count ?? 0
    }

    func yesterdaySessionCount() -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let yesterday = f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        return focusSessions.first(where: { $0.date == yesterday })?.count ?? 0
    }

    func weekSessionCount() -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var total = 0
        for offset in 0..<7 {
            let d = f.string(from: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!)
            total += focusSessions.first(where: { $0.date == d })?.count ?? 0
        }
        return total
    }

    func saveGoal(_ goal: Int) {
        dailyFocusGoal = goal
        UserDefaults.standard.set(goal, forKey: goalKey)
    }

    // MARK: - Reflection
    func saveReflection(_ r: ReflectionRating) {
        todayReflection = r
        UserDefaults.standard.set(r.rawValue, forKey: reflectionKey + todayKey())
    }

    // MARK: - Notifications
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleNotification(for habit: Habit) {
        guard let time = habit.reminderTime else { return }
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder 🔔"
        content.body = "Don't forget: \(habit.name)"
        content.sound = .default
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: habit.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - ROOT
struct ContentView: View {
    @StateObject private var vm = AppViewModel()

    var body: some View {
        DashboardView(username: "Student")
            .environmentObject(vm)
            .preferredColorScheme(.dark)
    }
}

// MARK: - DASHBOARD
struct DashboardView: View {
    let username: String
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    // Daily Focus Goal Progress
                    dailyGoalCard

                    NavigationLink { PomodoroView().environmentObject(vm) } label: {
                        dashboardCard(title: "Pomodoro Timer", icon: "timer", subtitle: "\(vm.todaySessionCount()) sessions today")
                    }

                    NavigationLink { HabitTrackerView().environmentObject(vm) } label: {
                        dashboardCard(title: "Habit Tracker", icon: "chart.pie.fill",
                                      subtitle: "\(vm.habits.filter { $0.completed }.count)/\(vm.habits.count) habits done")
                    }

                    NavigationLink { FocusHistoryView().environmentObject(vm) } label: {
                        dashboardCard(title: "Focus History", icon: "clock.arrow.circlepath", subtitle: "\(vm.weekSessionCount()) sessions this week")
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $vm.showReflection) {
                DailyReflectionView().environmentObject(vm)
            }
            .onAppear {
                checkEndOfDay()
            }
        }
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Welcome back")
                    .foregroundColor(AppTheme.secondaryText)
                Text("\(username) 👋")
                    .font(.title.bold())
            }
            Spacer()
            NavigationLink { ProfileView(username: username).environmentObject(vm) } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(AppTheme.accent)
            }
        }
    }

    var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎯 Daily Focus Goal")
                    .font(.headline)
                Spacer()
                Text("\(vm.todaySessionCount()) / \(vm.dailyFocusGoal)")
                    .font(.headline)
                    .foregroundColor(AppTheme.accent)
            }
            ProgressView(value: Double(min(vm.todaySessionCount(), vm.dailyFocusGoal)),
                         total: Double(vm.dailyFocusGoal))
                .accentColor(AppTheme.accent)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .cornerRadius(4)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func dashboardCard(title: String, icon: String, subtitle: String = "") -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundColor(AppTheme.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func checkEndOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 20 && vm.todayReflection == nil {
            vm.showReflection = true
        }
    }
}

// MARK: - POMODORO (with Break Cycle + Focus Mode + Motivational Messages)
struct PomodoroView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var timeRemaining = 25 * 60
    @State private var running = false
    @State private var sessionsDone = 0
    @State private var phase: PomodoroPhase = .focus
    @State private var focusMode = false
    @State private var showMotivation = false
    @State private var motivationMsg = ""
    @State private var showGoalPicker = false
    @State private var tempGoal = 4

    enum PomodoroPhase {
        case focus, shortBreak, longBreak
        var label: String {
            switch self {
            case .focus: return "Focus"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
        var duration: Int {
            switch self {
            case .focus: return 25 * 60
            case .shortBreak: return 5 * 60
            case .longBreak: return 15 * 60
            }
        }
        var color: Color {
            switch self {
            case .focus: return .orange
            case .shortBreak: return .green
            case .longBreak: return .blue
            }
        }
    }

    let messages = [
        "Great job! Keep going 💪",
        "Consistency builds success 🚀",
        "You're unstoppable! ⚡",
        "One session closer to your goal 🎯",
        "Deep work = big results 🔥"
    ]

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var progress: CGFloat {
        CGFloat(timeRemaining) / CGFloat(phase.duration)
    }

    var body: some View {
        ZStack {
            // FOCUS MODE: distraction-free overlay
            if focusMode {
                Color.black.ignoresSafeArea()
                VStack(spacing: 40) {
                    Text(phase.label)
                        .font(.title2)
                        .foregroundColor(phase.color)
                    timerCircle
                    controlButtons
                    Button("Exit Focus Mode") { focusMode = false }
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        // Phase indicator
                        HStack(spacing: 12) {
                            ForEach([PomodoroPhase.focus, .shortBreak, .longBreak], id: \.label) { p in
                                Text(p.label)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(phase.label == p.label ? p.color.opacity(0.3) : Color.clear)
                                    .foregroundColor(phase.label == p.label ? p.color : AppTheme.secondaryText)
                                    .cornerRadius(20)
                            }
                        }

                        timerCircle

                        // Session counter
                        HStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                Circle()
                                    .fill(i < sessionsDone % 4 ? AppTheme.accent : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                            }
                        }

                        controlButtons

                        // Goal setter
                        Button {
                            tempGoal = vm.dailyFocusGoal
                            showGoalPicker = true
                        } label: {
                            Label("Set Daily Goal: \(vm.dailyFocusGoal) sessions", systemImage: "flag.fill")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText)
                        }

                        // Focus mode button
                        Button {
                            focusMode = true
                            if !running { running = true }
                        } label: {
                            Label("Enter Focus Mode", systemImage: "moon.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    .padding()
                }
            }
        }
        .onReceive(timer) { _ in
            guard running else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                sessionComplete()
            }
        }
        .alert("🎉 Session Complete!", isPresented: $showMotivation) {
            Button("Continue") { }
        } message: {
            Text(motivationMsg)
        }
        .sheet(isPresented: $showGoalPicker) {
            goalPickerSheet
        }
        .navigationTitle("Focus Timer")
        .navigationBarTitleDisplayMode(.inline)
    }

    var timerCircle: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timeRemaining)
            VStack(spacing: 4) {
                Text(format(timeRemaining))
                    .font(.system(size: 52, weight: .medium, design: .monospaced))
                Text(phase.label)
                    .font(.caption)
                    .foregroundColor(phase.color)
            }
        }
        .frame(width: 260, height: 260)
    }

    var controlButtons: some View {
        HStack(spacing: 20) {
            Button {
                running = false
                timeRemaining = phase.duration
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }

            Button(running ? "Pause" : "Start") { running.toggle() }
                .frame(width: 140)
                .padding()
                .background(phase.color)
                .foregroundColor(.black)
                .cornerRadius(14)
                .font(.headline)
        }
    }

    var goalPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set your daily focus session goal")
                    .foregroundColor(AppTheme.secondaryText)
                Stepper("Goal: \(tempGoal) sessions", value: $tempGoal, in: 1...12)
                    .padding()
                    .background(AppTheme.card)
                    .cornerRadius(12)
                Button("Save Goal") {
                    vm.saveGoal(tempGoal)
                    showGoalPicker = false
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent)
                .foregroundColor(.black)
                .cornerRadius(14)
                Spacer()
            }
            .padding()
            .navigationTitle("Daily Focus Goal")
        }
    }

    func sessionComplete() {
        running = false
        if phase == .focus {
            vm.recordFocusSession()
            sessionsDone += 1
            motivationMsg = messages.randomElement()!
            showMotivation = true
            phase = sessionsDone % 4 == 0 ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }
        timeRemaining = phase.duration
        running = true
    }

    func format(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - FOCUS HISTORY
struct FocusHistoryView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary cards
                HStack(spacing: 12) {
                    statCard(title: "Today", value: "\(vm.todaySessionCount())")
                    statCard(title: "Yesterday", value: "\(vm.yesterdaySessionCount())")
                    statCard(title: "This Week", value: "\(vm.weekSessionCount())")
                }

                // Weekly bar chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last 7 Days")
                        .font(.headline)
                    weeklyBarChart
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Focus History")
    }

    var weeklyBarChart: some View {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let dayF = DateFormatter(); dayF.dateFormat = "EEE"
        let maxCount = max(1, (0..<7).map { offset -> Int in
            let d = f.string(from: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!)
            return vm.focusSessions.first(where: { $0.date == d })?.count ?? 0
        }.max() ?? 1)

        return HStack(alignment: .bottom, spacing: 10) {
            ForEach((0..<7).reversed(), id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                let key = f.string(from: date)
                let count = vm.focusSessions.first(where: { $0.date == key })?.count ?? 0
                let height = max(4, CGFloat(count) / CGFloat(maxCount) * 120)

                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(count > 0 ? AppTheme.accent : Color.gray.opacity(0.2))
                        .frame(width: 32, height: height)
                    Text(dayF.string(from: date))
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }

    func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(AppTheme.accent)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - HABIT TRACKER
struct HabitTrackerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showAddHabit = false
    @State private var selectedCategory: HabitCategory? = nil

    var filteredHabits: [Habit] {
        if let cat = selectedCategory {
            return vm.habits.filter { $0.category == cat }
        }
        return vm.habits
    }

    var completedCount: Int { vm.habits.filter { $0.completed }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pie chart
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: vm.habits.isEmpty ? 0 : CGFloat(completedCount) / CGFloat(vm.habits.count))
                        .stroke(AppTheme.accent, lineWidth: 14)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: completedCount)
                    VStack {
                        Text("\(completedCount)/\(vm.habits.count)").font(.title.bold())
                        Text("Done").foregroundColor(AppTheme.secondaryText)
                    }
                }
                .frame(width: 160, height: 160)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "All", selected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            filterChip(label: cat.rawValue, selected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                }

                // Habit list
                VStack(spacing: 14) {
                    ForEach(filteredHabits.indices, id: \.self) { i in
                        if let globalIndex = vm.habits.firstIndex(where: { $0.id == filteredHabits[i].id }) {
                            habitRow(index: globalIndex)
                        }
                    }
                }

                // Add habit button
                Button {
                    showAddHabit = true
                } label: {
                    Label("Add Habit", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.accent.opacity(0.15))
                        .foregroundColor(AppTheme.accent)
                        .cornerRadius(14)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Habits")
        .sheet(isPresented: $showAddHabit) {
            AddHabitView().environmentObject(vm)
        }
    }

    func habitRow(index: Int) -> some View {
        let habit = vm.habits[index]
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(habit.category.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: habit.icon)
                    .foregroundColor(habit.category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name).font(.headline)
                HStack(spacing: 6) {
                    Text("🔥 \(habit.streak) day streak")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Text("·")
                        .foregroundColor(AppTheme.secondaryText)
                    Text(habit.category.rawValue)
                        .font(.caption)
                        .foregroundColor(habit.category.color)
                }
            }

            Spacer()

            Button {
                vm.toggleHabit(at: index)
            } label: {
                Image(systemName: habit.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(habit.completed ? AppTheme.accent : .gray)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(18)
    }

    func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? AppTheme.accent : Color.gray.opacity(0.2))
                .foregroundColor(selected ? .black : .white)
                .cornerRadius(20)
        }
    }
}

// MARK: - ADD HABIT
struct AddHabitView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var habitName = ""
    @State private var selectedCategory: HabitCategory = .study
    @State private var enableReminder = false
    @State private var reminderTime = Date()

    let icons = ["star.fill", "leaf.fill", "heart.fill", "brain.head.profile", "sun.max.fill",
                 "drop.fill", "book.fill", "figure.walk", "bed.double.fill", "fork.knife"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Habit name", text: $habitName)
                    .padding()
                    .background(AppTheme.card)
                    .cornerRadius(12)

                // Category picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Category").font(.subheadline).foregroundColor(AppTheme.secondaryText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(HabitCategory.allCases, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    HStack {
                                        Image(systemName: cat.icon)
                                        Text(cat.rawValue)
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == cat ? cat.color.opacity(0.3) : Color.gray.opacity(0.15))
                                    .foregroundColor(selectedCategory == cat ? cat.color : .white)
                                    .cornerRadius(20)
                                }
                            }
                        }
                    }
                }

                // Reminder toggle
                Toggle(isOn: $enableReminder) {
                    Label("Daily Reminder", systemImage: "bell.fill")
                }
                .tint(AppTheme.accent)
                .padding()
                .background(AppTheme.card)
                .cornerRadius(12)

                if enableReminder {
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .padding()
                        .background(AppTheme.card)
                        .cornerRadius(12)
                }

                Button("Add Habit") {
                    if !habitName.isEmpty && vm.habits.count < 10 {
                        var newHabit = Habit(
                            name: habitName,
                            icon: icons.randomElement()!,
                            category: selectedCategory,
                            completed: false,
                            streak: 0
                        )
                        if enableReminder {
                            newHabit.reminderTime = reminderTime
                            vm.scheduleNotification(for: newHabit)
                        }
                        vm.habits.append(newHabit)
                        vm.saveHabits()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(habitName.isEmpty ? Color.gray.opacity(0.3) : AppTheme.accent)
                .foregroundColor(.black)
                .cornerRadius(14)
                .disabled(habitName.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PROFILE
struct ProfileView: View {
    let username: String
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // User card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 70, height: 70)
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                    VStack(alignment: .leading) {
                        Text(username).font(.title2.bold())
                        Text("Consistency Builder 🏆")
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                // Focus summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus Summary").font(.headline)
                    HStack {
                        summaryItem(label: "Today", value: "\(vm.todaySessionCount())", icon: "timer")
                        Divider()
                        summaryItem(label: "This Week", value: "\(vm.weekSessionCount())", icon: "calendar.badge.clock")
                        Divider()
                        summaryItem(label: "Goal", value: "\(vm.dailyFocusGoal)", icon: "flag.fill")
                    }
                    .frame(height: 60)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                // Weekly habit analytics
                VStack(alignment: .leading, spacing: 14) {
                    Text("Weekly Habit Analytics").font(.headline)
                    ForEach(vm.habits) { habit in
                        let days = vm.weeklyCompletions(for: habit)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: habit.icon).foregroundColor(habit.category.color)
                                Text(habit.name)
                                Spacer()
                                Text("\(days)/7 days")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.accent)
                            }
                            ProgressView(value: Double(days), total: 7)
                                .accentColor(habit.category.color)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                // Habit heatmap
                if let first = vm.habits.first {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("30-Day Heatmap").font(.headline)
                        Text(first.name).font(.subheadline).foregroundColor(AppTheme.secondaryText)
                        heatmap(for: first)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }

                // Today's reflection
                if let r = vm.todayReflection {
                    HStack {
                        Text("Today's Reflection:")
                        Spacer()
                        Text(r.rawValue).foregroundColor(AppTheme.accent)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Profile")
    }

    func summaryItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(AppTheme.accent)
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    func heatmap(for habit: Habit) -> some View {
        let data = vm.heatmapData(for: habit)
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 4), count: 10), spacing: 4) {
            ForEach(data.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(data[i] ? AppTheme.accent : Color.gray.opacity(0.2))
                    .frame(width: 20, height: 20)
            }
        }
    }
}

// MARK: - DAILY REFLECTION
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
    }
}
