import SwiftUI

// MARK: - ROOT
struct ContentView: View {
    @StateObject private var vm = AppViewModel()

    var body: some View {
        DashboardView(username: "Student")
            .environmentObject(vm)
            .preferredColorScheme(.dark)
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

#Preview {
    ContentView()
}
