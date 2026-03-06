import SwiftUI

// MARK: - MODELS

/// Difficulty level for each subject
enum SubjectDifficulty: String, Codable, CaseIterable {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var weight: Double {
        switch self {
        case .easy:   return 1.0
        case .medium: return 2.0
        case .hard:   return 3.0
        }
    }

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .yellow
        case .hard:   return .red
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard:   return "bolt.fill"
        }
    }
}

/// A subject the student wants to study
struct StudySubject: Identifiable, Codable {
    var id         = UUID()
    var name:      String
    var difficulty: SubjectDifficulty
    var color:     String  // stored as hex or named color for serialization
}

/// A single Pomodoro slot in the plan
struct PomodoroSlot: Identifiable, Codable {
    var id                = UUID()
    var subject:          String
    var pomodoroSessions: Int
    var difficulty:       SubjectDifficulty
}

/// A full day's study plan
struct DailyStudyPlan: Identifiable, Codable {
    var id     = UUID()
    var day:   String
    var slots: [PomodoroSlot]

    var totalSessions: Int { slots.reduce(0) { $0 + $1.pomodoroSessions } }
    var totalMinutes: Int  { totalSessions * 30 } // 25 study + 5 break
}

/// The full weekly plan
struct WeeklyStudyPlan: Codable {
    var days:           [DailyStudyPlan]
    var hoursPerDay:    Double
    var generatedDate:  String
}

// MARK: - SUBJECT COLORS
// Predefined palette for subjects
private let subjectColorPalette: [(name: String, color: Color)] = [
    ("indigo",  .indigo),
    ("blue",    .blue),
    ("teal",    .teal),
    ("green",   .green),
    ("orange",  .orange),
    ("pink",    .pink),
    ("purple",  .purple),
    ("red",     .red),
    ("cyan",    .cyan),
    ("mint",    .mint),
]

private func colorForSubject(_ name: String) -> Color {
    let idx = abs(name.hashValue) % subjectColorPalette.count
    return subjectColorPalette[idx].color
}

// MARK: - PLAN GENERATOR

/// Generates a balanced weekly study plan using Pomodoro sessions
struct StudyPlanGenerator {

    /// Generate a 7-day study plan
    /// - Parameters:
    ///   - subjects: list of subjects with difficulty
    ///   - hoursPerDay: available study hours per day
    ///   - prioritySubject: optional subject name to receive extra weight
    /// - Returns: a WeeklyStudyPlan
    static func generate(
        subjects: [StudySubject],
        hoursPerDay: Double,
        prioritySubject: String? = nil
    ) -> WeeklyStudyPlan {
        guard !subjects.isEmpty, hoursPerDay > 0 else {
            return WeeklyStudyPlan(days: [], hoursPerDay: hoursPerDay,
                                   generatedDate: todayKey())
        }

        let days = ["Monday", "Tuesday", "Wednesday", "Thursday",
                     "Friday", "Saturday", "Sunday"]

        // Total pomodoro sessions per day (each session = 30 min)
        let sessionsPerDay = max(1, Int(hoursPerDay * 2))

        // Calculate weights: difficulty + priority bonus
        let weights: [(subject: StudySubject, weight: Double)] = subjects.map { s in
            var w = s.difficulty.weight
            if let priority = prioritySubject,
               s.name.lowercased() == priority.lowercased() {
                w *= 1.5 // 50% boost for priority subject
            }
            return (subject: s, weight: w)
        }

        let totalWeight = weights.reduce(0.0) { $0 + $1.weight }

        // Build each day's plan
        var dailyPlans: [DailyStudyPlan] = []

        for (dayIdx, dayName) in days.enumerated() {
            _ = sessionsPerDay // total sessions for the day
            var slots: [PomodoroSlot] = []

            // Allocate sessions proportionally to weights
            var allocations: [(subject: StudySubject, sessions: Int)] = []

            for (_, entry) in weights.enumerated() {
                let proportion = entry.weight / totalWeight
                var sessions = Int(round(Double(sessionsPerDay) * proportion))

                // Ensure at least 1 session for each subject
                if sessions == 0 { sessions = 1 }

                allocations.append((subject: entry.subject, sessions: sessions))
            }

            // Normalize to fit sessionsPerDay
            let totalAllocated = allocations.reduce(0) { $0 + $1.sessions }
            if totalAllocated != sessionsPerDay {
                let diff = sessionsPerDay - totalAllocated
                // Add/remove from the highest-weight subject
                if let maxIdx = allocations.indices.max(by: {
                    weights[$0].weight < weights[$1].weight
                }) {
                    allocations[maxIdx].sessions = max(1, allocations[maxIdx].sessions + diff)
                }
            }

            // Rotate subject order each day for variety
            let rotated = rotate(allocations, by: dayIdx)

            for alloc in rotated {
                if alloc.sessions > 0 {
                    slots.append(PomodoroSlot(
                        subject: alloc.subject.name,
                        pomodoroSessions: alloc.sessions,
                        difficulty: alloc.subject.difficulty
                    ))
                }
            }

            dailyPlans.append(DailyStudyPlan(day: dayName, slots: slots))
        }

        return WeeklyStudyPlan(
            days: dailyPlans,
            hoursPerDay: hoursPerDay,
            generatedDate: todayKey()
        )
    }

    /// Rotate array by offset for day variety
    private static func rotate<T>(_ array: [T], by offset: Int) -> [T] {
        guard !array.isEmpty else { return array }
        let n = array.count
        let shift = offset % n
        return Array(array[shift...]) + Array(array[..<shift])
    }

    private static func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - STUDY PLANNER VIEW

struct StudyPlannerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var subjects:        [StudySubject] = []
    @State private var hoursPerDay:     Double = 3.0
    @State private var prioritySubject: String = ""
    @State private var weeklyPlan:      WeeklyStudyPlan? = nil
    @State private var showAddSubject   = false
    @State private var animateIn        = false
    @State private var animatePlan      = false
    @State private var selectedDay:     String? = nil

    // Persistence keys
    private let subjectsKey = "study_planner_subjects"
    private let planKey     = "study_planner_plan"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.orange.opacity(0.14), Color.clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    // MARK: Subjects Section
                    subjectsSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)
                        .animation(.spring(response: 0.5).delay(0.1), value: animateIn)

                    // MARK: Hours per day
                    hoursSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 16)
                        .animation(.spring(response: 0.5).delay(0.18), value: animateIn)

                    // MARK: Priority Subject
                    if !subjects.isEmpty {
                        prioritySection
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 16)
                            .animation(.spring(response: 0.5).delay(0.24), value: animateIn)
                    }

                    // MARK: Generate Button
                    generateButton
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.3), value: animateIn)

                    // MARK: Weekly Plan
                    if let plan = weeklyPlan {
                        planSummaryCard(plan: plan)
                            .opacity(animatePlan ? 1 : 0)
                            .offset(y: animatePlan ? 0 : 20)
                            .animation(.spring(response: 0.6).delay(0.1), value: animatePlan)

                        ForEach(Array(plan.days.enumerated()), id: \.element.id) { idx, day in
                            dayCard(day: day, index: idx)
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Study Planner 📅")
        .sheet(isPresented: $showAddSubject) {
            AddSubjectSheet(subjects: $subjects, onSave: saveSubjects)
        }
        .onAppear {
            loadSubjects()
            loadPlan()
            animateIn = true
        }
    }

    // MARK: - Subjects Section
    var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Subjects", systemImage: "books.vertical.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showAddSubject = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }
            }

            if subjects.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.15))
                        Text("Add subjects to get started")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                // Subject chips
                FlowLayout(spacing: 8) {
                    ForEach(subjects) { subject in
                        subjectChip(subject)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func subjectChip(_ subject: StudySubject) -> some View {
        HStack(spacing: 6) {
            Image(systemName: subject.difficulty.icon)
                .font(.system(size: 11))
                .foregroundColor(subject.difficulty.color)
            Text(subject.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text(subject.difficulty.rawValue)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))

            Button {
                subjects.removeAll { $0.id == subject.id }
                saveSubjects()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(colorForSubject(subject.name).opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForSubject(subject.name).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Hours Section
    var hoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Study Hours / Day", systemImage: "clock.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(String(format: "%.1f", hoursPerDay))h")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("(\(Int(hoursPerDay * 2)) sessions)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
            }

            Slider(value: $hoursPerDay, in: 0.5...8.0, step: 0.5)
                .tint(.orange)

            HStack {
                Text("30 min")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.secondaryText)
                Spacer()
                Text("8 hours")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    // MARK: - Priority Section
    var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Priority Subject (optional)", systemImage: "star.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("Gets 50% extra study sessions")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "None" option
                    priorityPill(name: "None", isSelected: prioritySubject.isEmpty)
                        .onTapGesture { prioritySubject = "" }

                    ForEach(subjects) { s in
                        priorityPill(name: s.name, isSelected: prioritySubject == s.name)
                            .onTapGesture { prioritySubject = s.name }
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func priorityPill(name: String, isSelected: Bool) -> some View {
        Text(name)
            .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.orange : Color.white.opacity(0.08))
            .cornerRadius(12)
    }

    // MARK: - Generate Button
    var generateButton: some View {
        Button {
            withAnimation(.spring(response: 0.5)) {
                weeklyPlan = StudyPlanGenerator.generate(
                    subjects: subjects,
                    hoursPerDay: hoursPerDay,
                    prioritySubject: prioritySubject.isEmpty ? nil : prioritySubject
                )
                savePlan()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.6)) { animatePlan = true }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18))
                Text("Generate Study Plan")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                subjects.isEmpty
                ? LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                 startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [.orange, Color(red: 1, green: 0.5, blue: 0)],
                                 startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(subjects.isEmpty ? .white.opacity(0.3) : .black)
            .cornerRadius(16)
        }
        .disabled(subjects.isEmpty)
    }

    // MARK: - Plan Summary Card
    func planSummaryCard(plan: WeeklyStudyPlan) -> some View {
        let totalSessions = plan.days.reduce(0) { $0 + $1.totalSessions }
        let totalHours = Double(totalSessions) * 0.5

        return VStack(spacing: 14) {
            HStack {
                Text("📅 Your Weekly Plan")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation { animatePlan = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        weeklyPlan = StudyPlanGenerator.generate(
                            subjects: subjects,
                            hoursPerDay: hoursPerDay,
                            prioritySubject: prioritySubject.isEmpty ? nil : prioritySubject
                        )
                        savePlan()
                        withAnimation(.spring(response: 0.6)) { animatePlan = true }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }

            HStack(spacing: 0) {
                summaryItem(value: "\(totalSessions)", label: "Sessions", icon: "timer")
                Divider().frame(height: 32)
                summaryItem(value: String(format: "%.1fh", totalHours), label: "Study Time", icon: "clock")
                Divider().frame(height: 32)
                summaryItem(value: "\(subjects.count)", label: "Subjects", icon: "books.vertical")
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    func summaryItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.7))
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Day Card
    func dayCard(day: DailyStudyPlan, index: Int) -> some View {
        let isExpanded = selectedDay == day.day

        return VStack(spacing: 0) {
            // Day header — tap to expand
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedDay = isExpanded ? nil : day.day
                }
            } label: {
                HStack {
                    // Day name with circle
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(isExpanded ? 0.25 : 0.1))
                            .frame(width: 36, height: 36)
                        Text(String(day.day.prefix(2)))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(isExpanded ? .orange : .white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.day)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(day.totalSessions) sessions · \(day.totalMinutes) min")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText)
                    }

                    Spacer()

                    // Mini subject dots
                    if !isExpanded {
                        HStack(spacing: 4) {
                            ForEach(day.slots) { slot in
                                Circle()
                                    .fill(colorForSubject(slot.subject))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }

            // Expanded content
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(day.slots) { slot in
                        slotRow(slot: slot, totalDaySessions: day.totalSessions)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .opacity(animatePlan ? 1 : 0)
        .offset(y: animatePlan ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.15 + Double(index) * 0.06), value: animatePlan)
    }

    func slotRow(slot: PomodoroSlot, totalDaySessions: Int) -> some View {
        let proportion = totalDaySessions > 0
            ? Double(slot.pomodoroSessions) / Double(totalDaySessions)
            : 0

        return HStack(spacing: 12) {
            // Subject color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(colorForSubject(slot.subject))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(slot.subject)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    // Difficulty badge
                    HStack(spacing: 3) {
                        Image(systemName: slot.difficulty.icon)
                            .font(.system(size: 8))
                        Text(slot.difficulty.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(slot.difficulty.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(slot.difficulty.color.opacity(0.15))
                    .cornerRadius(6)
                }

                // Session bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForSubject(slot.subject).opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(proportion), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Session count
            VStack(spacing: 1) {
                Text("\(slot.pomodoroSessions)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(colorForSubject(slot.subject))
                Text(slot.pomodoroSessions == 1 ? "session" : "sessions")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
            }

            // Time
            Text("\(slot.pomodoroSessions * 25)m")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Persistence
    func saveSubjects() {
        if let data = try? JSONEncoder().encode(subjects) {
            UserDefaults.standard.set(data, forKey: subjectsKey)
        }
    }

    func loadSubjects() {
        if let data = UserDefaults.standard.data(forKey: subjectsKey),
           let decoded = try? JSONDecoder().decode([StudySubject].self, from: data) {
            subjects = decoded
        }
    }

    func savePlan() {
        if let plan = weeklyPlan, let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: planKey)
        }
    }

    func loadPlan() {
        if let data = UserDefaults.standard.data(forKey: planKey),
           let decoded = try? JSONDecoder().decode(WeeklyStudyPlan.self, from: data) {
            weeklyPlan = decoded
            animatePlan = true
        }
    }
}

// MARK: - ADD SUBJECT SHEET

struct AddSubjectSheet: View {
    @Binding var subjects: [StudySubject]
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name       = ""
    @State private var difficulty = SubjectDifficulty.medium
    @State private var animateIn  = false
    @FocusState private var nameFocused: Bool

    // Preset subject suggestions
    private let suggestions = [
        "Mathematics", "Physics", "Chemistry", "Biology",
        "English", "History", "Computer Science", "Economics",
        "Geography", "Literature", "Psychology", "Art"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.orange.opacity(0.15), Color.clear],
                    center: .top, startRadius: 0, endRadius: 350
                ).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        subjectNameField
                        quickSuggestionsSection
                        difficultyPickerSection
                        addButtonSection
                        currentSubjectsList
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Add Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.orange)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            animateIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFocused = true
            }
        }
    }

    // MARK: - Subject Name Field
    var subjectNameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subject Name")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            TextField("e.g. Mathematics", text: $name)
                .focused($nameFocused)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.07))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(nameFocused ? Color.orange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.1), value: animateIn)
    }

    // MARK: - Quick Suggestions
    var quickSuggestionsSection: some View {
        let filtered = suggestions.filter { s in
            !subjects.contains(where: { $0.name == s })
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(filtered, id: \.self) { suggestion in
                    suggestionButton(suggestion)
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.18), value: animateIn)
    }

    func suggestionButton(_ suggestion: String) -> some View {
        let isSelected = name == suggestion
        return Button {
            name = suggestion
        } label: {
            Text(suggestion)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.orange : Color.white.opacity(0.08))
                .cornerRadius(10)
        }
    }

    // MARK: - Difficulty Picker
    var difficultyPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Difficulty Level")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 10) {
                ForEach(SubjectDifficulty.allCases, id: \.self) { diff in
                    difficultyButton(diff)
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.24), value: animateIn)
    }

    func difficultyButton(_ diff: SubjectDifficulty) -> some View {
        let isSelected = difficulty == diff
        let multiplier = diff == .easy ? "1x" : diff == .medium ? "2x" : "3x"

        return Button {
            difficulty = diff
        } label: {
            VStack(spacing: 6) {
                Image(systemName: diff.icon)
                    .font(.system(size: 20))
                    .foregroundColor(diff.color)

                Text(diff.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                Text(multiplier)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(diff.color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? diff.color.opacity(0.15) : Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? diff.color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Add Button
    var addButtonSection: some View {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nameIsEmpty = trimmed.isEmpty
        let bgColor: AnyShapeStyle = nameIsEmpty
            ? AnyShapeStyle(Color.gray.opacity(0.2))
            : AnyShapeStyle(LinearGradient(colors: [.orange, Color(red: 1, green: 0.5, blue: 0)],
                                           startPoint: .leading, endPoint: .trailing))

        return Button {
            guard !nameIsEmpty else { return }
            guard !subjects.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
            subjects.append(StudySubject(name: trimmed, difficulty: difficulty, color: "auto"))
            onSave()
            name = ""
            difficulty = .medium
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add Subject")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(bgColor)
            .foregroundColor(nameIsEmpty ? .white.opacity(0.3) : .black)
            .cornerRadius(16)
        }
        .disabled(nameIsEmpty)
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.5).delay(0.3), value: animateIn)
    }

    // MARK: - Current Subjects List
    @ViewBuilder
    var currentSubjectsList: some View {
        if !subjects.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Added Subjects (\(subjects.count))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)

                ForEach(subjects) { subject in
                    subjectRow(subject)
                }
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.5).delay(0.35), value: animateIn)
        }
    }

    func subjectRow(_ subject: StudySubject) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(colorForSubject(subject.name))
                .frame(width: 8, height: 8)
            Text(subject.name)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: subject.difficulty.icon)
                    .font(.system(size: 10))
                Text(subject.difficulty.rawValue)
                    .font(.system(size: 11))
            }
            .foregroundColor(subject.difficulty.color)

            Button {
                subjects.removeAll { $0.id == subject.id }
                onSave()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - FLOW LAYOUT (for subject chips)
// Simple horizontal wrapping layout for tags/chips

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x,
                                               y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews)
    -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat  = 0
        var rowHeight: CGFloat  = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxHeight = max(maxHeight, y + rowHeight)
        }

        return (positions, CGSize(width: maxWidth, height: maxHeight))
    }
}
