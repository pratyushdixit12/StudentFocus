import SwiftUI
import UserNotifications

// MARK: - THEME
struct AppTheme {
    static let accent       = Color.orange
    static let card         = Color(.secondarySystemBackground)
    static let secondaryText = Color(.secondaryLabel)
}

// MARK: - MODELS

struct Habit: Identifiable, Codable {
    var id   = UUID()
    var name: String
    var icon: String
    var category: HabitCategory
    var completed: Bool
    var streak: Int
    var reminderTime: Date?
    var completionHistory: [String] = []
}

enum HabitCategory: String, Codable, CaseIterable {
    case health = "Health", study = "Study", fitness = "Fitness"
    case mindfulness = "Mindfulness", other = "Other"

    var icon: String {
        switch self {
        case .health:      return "heart.fill"
        case .study:       return "book.fill"
        case .fitness:     return "figure.walk"
        case .mindfulness: return "brain.head.profile"
        case .other:       return "star.fill"
        }
    }
    var color: Color {
        switch self {
        case .health:      return .red
        case .study:       return .blue
        case .fitness:     return .green
        case .mindfulness: return .purple
        case .other:       return .orange
        }
    }
}

struct FocusSession: Codable {
    var date:  String   // "yyyy-MM-dd"
    var count: Int
}

enum ReflectionRating: String, CaseIterable {
    case good             = "Good 😊"
    case average          = "Average 😐"
    case needsImprovement = "Needs Improvement 😔"
}

// NEW: Task per session
struct SessionTask: Identifiable, Codable {
    var id        = UUID()
    var title:    String
    var isDone:   Bool = false
    var date:     String   // "yyyy-MM-dd"
}

// NEW: Leaderboard entry
struct LeaderboardEntry: Identifiable, Codable {
    var id      = UUID()
    var name:   String
    var avatar: String   // SF Symbol name
    var weekSessions: Int
    var weekHabits:   Int

    var score: Int { weekSessions * 10 + weekHabits * 5 }
}

// MARK: - Session Note (study log)
struct SessionNote: Identifiable, Codable {
    var id         = UUID()
    var date:      String        // "yyyy-MM-dd"
    var timestamp: Date = Date()
    var learned:   String        // what the student understood
    var confusing: String        // what needs more review (optional)
    var sessionNum: Int          // which session number of the day
}

// MARK: - XP Level System
enum XPLevel: Int, CaseIterable, Codable {
    case beginner = 0
    case scholar  = 1
    case focused  = 2
    case elite    = 3
    case legend   = 4

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .scholar:  return "Scholar"
        case .focused:  return "Focused"
        case .elite:    return "Elite"
        case .legend:   return "Legend"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .scholar:  return "book.closed.fill"
        case .focused:  return "brain.head.profile"
        case .elite:    return "bolt.fill"
        case .legend:   return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .gray
        case .scholar:  return .blue
        case .focused:  return .green
        case .elite:    return .orange
        case .legend:   return Color(red: 1, green: 0.84, blue: 0)
        }
    }

    var xpRequired: Int {
        switch self {
        case .beginner: return 0
        case .scholar:  return 100
        case .focused:  return 300
        case .elite:    return 700
        case .legend:   return 1500
        }
    }

    var nextLevel: XPLevel? {
        XPLevel(rawValue: self.rawValue + 1)
    }

    var xpForNext: Int? {
        nextLevel?.xpRequired
    }
}

// MARK: - Study Milestones
struct StudyMilestone: Identifiable, Codable {
    var id:         UUID   = UUID()
    var hours:      Int
    var achieved:   Bool   = false
    var achievedOn: String = ""     // "yyyy-MM-dd" when unlocked
    var icon:       String          // emoji string
    var title:      String
    var subtitle:   String
}

// MARK: - VIEW MODEL
class AppViewModel: ObservableObject {

    // Existing
    @Published var habits:           [Habit]          = []
    @Published var focusSessions:    [FocusSession]   = []
    @Published var dailyFocusGoal:   Int              = 4
    @Published var todayReflection:  ReflectionRating? = nil
    @Published var showReflection                     = false

    // Tasks & Leaderboard
    @Published var sessionTasks:     [SessionTask]    = []
    @Published var leaderboard:      [LeaderboardEntry] = []

    // Session Notes
    @Published var sessionNotes:     [SessionNote]    = []
    @Published var showNoteSheet:    Bool             = false
    @Published var pendingNoteSessionNum: Int         = 1

    // XP System
    @Published var totalXP:          Int              = 0
    @Published var showXPGain:       Bool             = false
    @Published var lastXPGain:       Int              = 0

    // Milestones
    @Published var milestones:       [StudyMilestone] = []
    @Published var showMilestone:    Bool             = false
    @Published var lastMilestone:    StudyMilestone?  = nil

    // UserDefaults keys
    private let habitsKey       = "habits_v2"
    private let sessionsKey     = "focus_sessions"
    private let goalKey         = "daily_focus_goal"
    private let reflectionKey   = "today_reflection"
    private let tasksKey        = "session_tasks"
    private let leaderboardKey  = "leaderboard"
    private let notesKey        = "session_notes"
    private let xpKey           = "total_xp"
    private let milestonesKey   = "study_milestones"

    // XP reward definitions
    static let xpRewards: [(action: String, xp: Int)] = [
        ("Complete a focus session", 25),
        ("Complete a habit", 5),
        ("Write a session note", 10),
        ("Unlock a milestone", 50)
    ]

    init() {
        loadHabits()
        loadSessions()
        loadTasks()
        loadLeaderboard()
        loadNotes()
        loadMilestones()
        totalXP = UserDefaults.standard.integer(forKey: xpKey)
        dailyFocusGoal = UserDefaults.standard.integer(forKey: goalKey) == 0
            ? 4 : UserDefaults.standard.integer(forKey: goalKey)
        if let raw = UserDefaults.standard.string(forKey: reflectionKey + todayKey()),
           let r = ReflectionRating(rawValue: raw) { todayReflection = r }
        requestNotificationPermission()
        resetHabitsIfNewDay()
    }

    // MARK: - Date Helpers
    func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    func dateKey(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Habits
    func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: habitsKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        } else {
            habits = [
                Habit(name: "Water",  icon: "drop.fill",   category: .health,  completed: false, streak: 3),
                Habit(name: "Study",  icon: "book.fill",   category: .study,   completed: false, streak: 5),
                Habit(name: "Steps",  icon: "figure.walk", category: .fitness, completed: false, streak: 2)
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
            awardXP(amount: 5) // XP for completing a habit
        } else {
            habits[index].completionHistory.removeAll { $0 == today }
            habits[index].streak = max(0, calculateStreak(for: habits[index]))
        }
        saveHabits()
    }

    func calculateStreak(for habit: Habit) -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var streak = 0
        var date = Date()
        while true {
            let key = f.string(from: date)
            if habit.completionHistory.contains(key) {
                streak += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else { break }
        }
        return streak
    }

    func resetHabitsIfNewDay() {
        let lastReset = UserDefaults.standard.string(forKey: "last_reset_date") ?? ""
        let today = todayKey()
        if lastReset != today {
            for i in habits.indices { habits[i].completed = false }
            saveHabits()
            UserDefaults.standard.set(today, forKey: "last_reset_date")
        }
    }

    func weeklyCompletions(for habit: Habit) -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var count = 0
        for offset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            if habit.completionHistory.contains(f.string(from: date)) { count += 1 }
        }
        return count
    }

    func heatmapData(for habit: Habit) -> [Bool] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
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
        updateMyLeaderboardScore()
        awardXP(amount: 25)
        checkMilestones()

        // Trigger note sheet after short delay
        pendingNoteSessionNum = todaySessionCount()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.showNoteSheet = true
        }
    }

    func todaySessionCount() -> Int {
        focusSessions.first(where: { $0.date == todayKey() })?.count ?? 0
    }

    func yesterdaySessionCount() -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let y = f.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        return focusSessions.first(where: { $0.date == y })?.count ?? 0
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

    func totalSessionsAllTime() -> Int {
        focusSessions.reduce(0) { $0 + $1.count }
    }

    // Productivity graph data — last 14 days
    func last14DaysData() -> [(label: String, count: Int)] {
        let f   = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let lbl = DateFormatter(); lbl.dateFormat = "d/M"
        return (0..<14).reversed().map { offset in
            let date  = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let key   = f.string(from: date)
            let count = focusSessions.first(where: { $0.date == key })?.count ?? 0
            return (label: lbl.string(from: date), count: count)
        }
    }

    func saveGoal(_ goal: Int) {
        dailyFocusGoal = goal
        UserDefaults.standard.set(goal, forKey: goalKey)
    }

    // MARK: - Focus Score (0–100)
    func focusScore() -> Int {
        let sessionScore  = min(40, Int(Double(todaySessionCount()) / Double(max(1, dailyFocusGoal)) * 40))
        let habitTotal    = habits.count
        let habitDone     = habits.filter { $0.completed }.count
        let habitScore    = habitTotal == 0 ? 0 : Int(Double(habitDone) / Double(habitTotal) * 40)
        let maxStreak     = habits.map { $0.streak }.max() ?? 0
        let streakScore   = min(20, maxStreak * 2)
        return sessionScore + habitScore + streakScore
    }

    func focusScoreLabel() -> String {
        let s = focusScore()
        switch s {
        case 80...100: return "Excellent 🔥"
        case 60...79:  return "Great 💪"
        case 40...59:  return "Good 👍"
        case 20...39:  return "Fair 📈"
        default:       return "Just Starting 🌱"
        }
    }

    func focusScoreColor() -> Color {
        let s = focusScore()
        switch s {
        case 80...100: return .green
        case 60...79:  return .orange
        case 40...59:  return .yellow
        default:       return .red
        }
    }

    // MARK: - Session Tasks
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([SessionTask].self, from: data) {
            sessionTasks = decoded
        }
    }

    func saveTasks() {
        if let data = try? JSONEncoder().encode(sessionTasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }

    func todayTasks() -> [SessionTask] {
        sessionTasks.filter { $0.date == todayKey() }
    }

    func addTask(title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let task = SessionTask(title: title.trimmingCharacters(in: .whitespaces), date: todayKey())
        sessionTasks.append(task)
        saveTasks()
    }

    func toggleTask(id: UUID) {
        if let idx = sessionTasks.firstIndex(where: { $0.id == id }) {
            sessionTasks[idx].isDone.toggle()
            saveTasks()
        }
    }

    func deleteTask(id: UUID) {
        sessionTasks.removeAll { $0.id == id }
        saveTasks()
    }

    // MARK: - Leaderboard
    func loadLeaderboard() {
        if let data = UserDefaults.standard.data(forKey: leaderboardKey),
           let decoded = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) {
            leaderboard = decoded
        } else {
            leaderboard = [
                LeaderboardEntry(name: "You",    avatar: "person.fill",           weekSessions: weekSessionCount(), weekHabits: habits.filter { $0.completed }.count),
                LeaderboardEntry(name: "Aisha",  avatar: "person.fill.checkmark", weekSessions: 18, weekHabits: 5),
                LeaderboardEntry(name: "Rahul",  avatar: "person.crop.circle",    weekSessions: 14, weekHabits: 4),
                LeaderboardEntry(name: "Priya",  avatar: "person.circle.fill",    weekSessions: 22, weekHabits: 6),
                LeaderboardEntry(name: "Carlos", avatar: "figure.stand",          weekSessions: 10, weekHabits: 3)
            ]
            saveLeaderboard()
        }
    }

    func saveLeaderboard() {
        if let data = try? JSONEncoder().encode(leaderboard) {
            UserDefaults.standard.set(data, forKey: leaderboardKey)
        }
    }

    func updateMyLeaderboardScore() {
        if let idx = leaderboard.firstIndex(where: { $0.name == "You" }) {
            leaderboard[idx].weekSessions = weekSessionCount()
            leaderboard[idx].weekHabits   = habits.filter { $0.completed }.count
            saveLeaderboard()
        }
    }

    var sortedLeaderboard: [LeaderboardEntry] {
        leaderboard.sorted { $0.score > $1.score }
    }

    // MARK: - Reflection
    func saveReflection(_ r: ReflectionRating) {
        todayReflection = r
        UserDefaults.standard.set(r.rawValue, forKey: reflectionKey + todayKey())
    }

    // MARK: - Session Notes (Study Log)
    func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([SessionNote].self, from: data) {
            sessionNotes = decoded
        }
    }

    func saveNotes() {
        if let data = try? JSONEncoder().encode(sessionNotes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    func addNote(learned: String, confusing: String, sessionNum: Int) {
        let note = SessionNote(
            date: todayKey(),
            timestamp: Date(),
            learned: learned.trimmingCharacters(in: .whitespacesAndNewlines),
            confusing: confusing.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionNum: sessionNum
        )
        sessionNotes.insert(note, at: 0) // newest first
        saveNotes()
        awardXP(amount: 10) // bonus XP for writing a note
    }

    func deleteNote(id: UUID) {
        sessionNotes.removeAll { $0.id == id }
        saveNotes()
    }

    func notesForDate(_ dateStr: String) -> [SessionNote] {
        sessionNotes.filter { $0.date == dateStr }
    }

    var groupedNotes: [(date: String, notes: [SessionNote])] {
        let grouped = Dictionary(grouping: sessionNotes, by: { $0.date })
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, notes: $0.value) }
    }

    // MARK: - XP & Level System
    var currentLevel: XPLevel {
        XPLevel.allCases.reversed().first { totalXP >= $0.xpRequired } ?? .beginner
    }

    var progressToNextLevel: Double {
        guard let nextXP = currentLevel.xpForNext else { return 1.0 }
        return min(1.0, max(0, Double(totalXP - currentLevel.xpRequired)
                              / Double(nextXP - currentLevel.xpRequired)))
    }

    var xpNeededForNext: Int {
        guard let nextXP = currentLevel.xpForNext else { return 0 }
        return max(0, nextXP - totalXP)
    }

    func awardXP(amount: Int) {
        let oldLevel = currentLevel
        totalXP += amount
        UserDefaults.standard.set(totalXP, forKey: xpKey)
        lastXPGain = amount
        withAnimation(.spring(response: 0.4)) { showXPGain = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation { self?.showXPGain = false }
        }
        if currentLevel != oldLevel {
            sendLevelUpNotification()
        }
    }

    func sendLevelUpNotification() {
        let content   = UNMutableNotificationContent()
        content.title = "🎉 Level Up!"
        content.body  = "You are now a \(currentLevel.title)! Keep going 🚀"
        content.sound = .default
        let trigger   = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request   = UNNotificationRequest(identifier: "level_up_\(UUID())", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Study Hours & Milestones
    func totalStudyHours() -> Double {
        Double(totalSessionsAllTime()) * 25.0 / 60.0
    }

    func loadMilestones() {
        if let data = UserDefaults.standard.data(forKey: milestonesKey),
           let decoded = try? JSONDecoder().decode([StudyMilestone].self, from: data) {
            milestones = decoded
        } else {
            // Seed with default milestones
            milestones = [
                StudyMilestone(hours: 10,  icon: "🌱", title: "First Steps",     subtitle: "10 hours of focused study"),
                StudyMilestone(hours: 25,  icon: "📖", title: "Bookworm",        subtitle: "25 hours of focused study"),
                StudyMilestone(hours: 50,  icon: "🔥", title: "On Fire",         subtitle: "50 hours of focused study"),
                StudyMilestone(hours: 100, icon: "⚡️", title: "Century Scholar", subtitle: "100 hours of focused study"),
                StudyMilestone(hours: 200, icon: "🏆", title: "Elite Student",   subtitle: "200 hours of focused study"),
                StudyMilestone(hours: 500, icon: "👑", title: "Legendary",       subtitle: "500 hours of focused study")
            ]
            saveMilestones()
        }
    }

    func saveMilestones() {
        if let data = try? JSONEncoder().encode(milestones) {
            UserDefaults.standard.set(data, forKey: milestonesKey)
        }
    }

    func checkMilestones() {
        let hours = totalStudyHours()
        for i in milestones.indices {
            if !milestones[i].achieved && hours >= Double(milestones[i].hours) {
                milestones[i].achieved = true
                milestones[i].achievedOn = todayKey()
                saveMilestones()
                lastMilestone = milestones[i]
                awardXP(amount: 50) // bonus for milestone
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.showMilestone = true
                }
            }
        }
    }

    var nextMilestoneTarget: StudyMilestone? {
        milestones.first { !$0.achieved }
    }

    var progressToNextMilestone: Double {
        guard let next = nextMilestoneTarget else { return 1.0 }
        // Find last achieved milestone hours (or 0 if none)
        let prev = milestones.last(where: { $0.achieved })?.hours ?? 0
        let target = Double(next.hours - prev)
        let progress = totalStudyHours() - Double(prev)
        return target > 0 ? min(1.0, max(0, progress / target)) : 1.0
    }

    // MARK: - Notifications
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleNotification(for habit: Habit) {
        guard let time = habit.reminderTime else { return }
        let content   = UNMutableNotificationContent()
        content.title = "Habit Reminder 🔔"
        content.body  = "Don't forget: \(habit.name)"
        content.sound = .default
        let comps     = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger   = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request   = UNNotificationRequest(identifier: habit.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

