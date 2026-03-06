import SwiftUI
import UserNotifications

// MARK: - POMODORO VIEW
// Features: Break Cycle, Focus Mode (Do Not Disturb), Task List, Focus Score, Motivational Messages
struct PomodoroView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    // Timer state
    @State private var timeRemaining  = 25 * 60
    @State private var running        = false
    @State private var sessionsDone   = 0
    @State private var phase: PomodoroPhase = .focus

    // UI state
    @State private var focusMode      = false
    @State private var showMotivation = false
    @State private var motivationMsg  = ""
    @State private var showGoalPicker = false
    @State private var tempGoal       = 4

    // Task list state
    @State private var showTaskSheet   = false
    @State private var newTaskText     = ""
    @FocusState private var taskFieldFocused: Bool

    // DND state
    @State private var dndEnabled     = false
    @State private var showDNDInfo    = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Phase Enum
    enum PomodoroPhase {
        case focus, shortBreak, longBreak

        var label: String {
            switch self { case .focus: return "Focus"; case .shortBreak: return "Short Break"; case .longBreak: return "Long Break" }
        }
        var duration: Int {
            switch self { case .focus: return 25 * 60; case .shortBreak: return 5 * 60; case .longBreak: return 15 * 60 }
        }
        var color: Color {
            switch self { case .focus: return .orange; case .shortBreak: return .green; case .longBreak: return .blue }
        }
        var icon: String {
            switch self { case .focus: return "brain.head.profile"; case .shortBreak: return "cup.and.saucer.fill"; case .longBreak: return "bed.double.fill" }
        }
    }

    let motivationMessages = [
        "Great job! Keep going 💪",
        "Consistency builds success 🚀",
        "You're unstoppable! ⚡",
        "One session closer to your goal 🎯",
        "Deep work = big results 🔥",
        "Focus is a superpower 🧠",
        "Another brick in the wall of success 🏆"
    ]

    var progress: CGFloat {
        CGFloat(timeRemaining) / CGFloat(phase.duration)
    }

    var todayTasks: [SessionTask] { vm.todayTasks() }
    var doneTasks:  Int           { todayTasks.filter { $0.isDone }.count }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if focusMode {
                focusModeScreen
            } else {
                normalScreen
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
            Button("Continue 💪") { }
        } message: {
            Text(motivationMsg)
        }
        .sheet(isPresented: $showGoalPicker) { goalSheet }
        .sheet(isPresented: $showTaskSheet)  { taskSheet  }
        .navigationTitle("Focus Timer")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if vm.showXPGain {
                XPToastView(xp: vm.lastXPGain)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: vm.showXPGain)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTaskSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(AppTheme.accent)
                        if todayTasks.count > 0 {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Normal Screen
    var normalScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Phase tabs
                phaseTabBar

                // Focus Score strip
                focusScoreStrip

                // Timer circle
                timerCircle
                    .padding(.vertical, 8)

                // Session dots
                sessionDots

                // Control buttons
                controlButtons

                // DND Toggle
                dndToggle

                // Task preview strip
                taskPreviewStrip

                // Goal setter link
                Button {
                    tempGoal = vm.dailyFocusGoal
                    showGoalPicker = true
                } label: {
                    Label("Daily Goal: \(vm.dailyFocusGoal) sessions", systemImage: "flag.fill")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.secondaryText)
                }

                // Focus mode button
                Button {
                    withAnimation(.easeInOut) {
                        focusMode = true
                        if !running { running = true }
                        if dndEnabled { scheduleDNDReminder() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                        Text("Enter Focus Mode")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.indigo.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.indigo.opacity(0.5), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    // MARK: - Focus Mode Screen (distraction-free)
    var focusModeScreen: some View {
        VStack(spacing: 0) {
            // Top: minimal info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(phase.color)
                    Text("Session \(sessionsDone + 1) of \(vm.dailyFocusGoal)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                if dndEnabled {
                    Label("DND On", systemImage: "bell.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Spacer()

            // Big timer
            timerCircle

            Spacer()

            // Current task if any
            if let currentTask = todayTasks.first(where: { !$0.isDone }) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.orange.opacity(0.7))
                    Text("Working on: \(currentTask.title)")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
            }

            // Controls
            controlButtons
                .padding(.horizontal, 28)

            Spacer()

            // Exit button
            Button {
                withAnimation(.easeInOut) { focusMode = false }
            } label: {
                Text("Exit Focus Mode")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 32)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.02, blue: 0.0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Sub-components

    var phaseTabBar: some View {
        HStack(spacing: 8) {
            ForEach([PomodoroPhase.focus, .shortBreak, .longBreak], id: \.label) { p in
                HStack(spacing: 5) {
                    Image(systemName: p.icon)
                        .font(.system(size: 10))
                    Text(p.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(phase.label == p.label ? p.color.opacity(0.25) : Color.white.opacity(0.06))
                .foregroundColor(phase.label == p.label ? p.color : .white.opacity(0.4))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(phase.label == p.label ? p.color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: phase.label)
            }
        }
    }

    var focusScoreStrip: some View {
        let score = vm.focusScore()
        let color = vm.focusScoreColor()

        return HStack(spacing: 14) {
            // Score
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(color)
                    .font(.system(size: 13))
                Text("Score: \(score)/100")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.15))
            .cornerRadius(20)

            // Sessions today
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                Text("\(vm.todaySessionCount()) / \(vm.dailyFocusGoal) today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(20)

            Spacer()
        }
    }

    var timerCircle: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(phase.color.opacity(running ? 0.06 : 0.02))
                .frame(width: 300, height: 300)

            // Track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 14)
                .frame(width: 250, height: 250)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [phase.color, phase.color.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 250, height: 250)
                .animation(.linear(duration: 1), value: timeRemaining)

            // Inner content
            VStack(spacing: 6) {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 56, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Circle()
                        .fill(running ? phase.color : Color.white.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: running)
                    Text(running ? phase.label : "Paused")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(running ? phase.color : .white.opacity(0.4))
                }
            }
        }
        .frame(width: 300, height: 300)
    }

    var sessionDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < sessionsDone % 4 ? AppTheme.accent : Color.white.opacity(0.15))
                    .frame(width: i < sessionsDone % 4 ? 20 : 10, height: 6)
                    .animation(.spring(response: 0.4), value: sessionsDone)
            }
        }
    }

    var controlButtons: some View {
        HStack(spacing: 16) {
            // Reset
            Button {
                running = false
                timeRemaining = phase.duration
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            // Play / Pause
            Button {
                running.toggle()
                if running && dndEnabled { scheduleDNDReminder() }
            } label: {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(colors: [phase.color, phase.color.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: phase.color.opacity(0.4), radius: running ? 12 : 4, y: 4)
                    .animation(.spring(response: 0.3), value: running)
            }

            // Skip
            Button {
                sessionComplete()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Do Not Disturb Toggle
    var dndToggle: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(dndEnabled ? Color.red.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 40, height: 40)
                Image(systemName: dndEnabled ? "bell.slash.fill" : "bell.fill")
                    .foregroundColor(dndEnabled ? .red : .white.opacity(0.5))
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Do Not Disturb")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(dndEnabled ? "Notifications silenced during sessions" : "Tap to silence notifications")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $dndEnabled)
                .tint(.red)
                .onChange(of: dndEnabled) { enabled in
                    if enabled { showDNDInfo = true }
                }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(dndEnabled ? Color.red.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .alert("Do Not Disturb", isPresented: $showDNDInfo) {
            Button("Got it") { }
        } message: {
            Text("Focus Mode will send you a notification reminder when your session ends. During the session, stay focused and avoid other apps!")
        }
    }

    // MARK: - Task Preview Strip
    var taskPreviewStrip: some View {
        Button {
            showTaskSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "list.bullet.clipboard.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Session Tasks")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if todayTasks.isEmpty {
                        Text("Add tasks for this session")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.secondaryText)
                    } else {
                        Text("\(doneTasks)/\(todayTasks.count) completed")
                            .font(.system(size: 11))
                            .foregroundColor(doneTasks == todayTasks.count && todayTasks.count > 0 ? .green : AppTheme.secondaryText)
                    }
                }

                Spacer()

                // Mini task dots
                if !todayTasks.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(todayTasks.prefix(4)) { task in
                            Circle()
                                .fill(task.isDone ? Color.green : Color.white.opacity(0.2))
                                .frame(width: 7, height: 7)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Task Sheet
    var taskSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Add task input
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))

                        TextField("Add a task for this session...", text: $newTaskText)
                            .focused($taskFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { addTask() }
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.white)

                        if !newTaskText.isEmpty {
                            Button(action: addTask) {
                                Text("Add")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.orange)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if todayTasks.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.15))
                            Text("No tasks yet")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Add what you want to accomplish\nin this focus session")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.2))
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } else {
                        // Task list
                        List {
                            Section {
                                ForEach(todayTasks) { task in
                                    taskRow(task: task)
                                        .listRowBackground(Color.white.opacity(0.05))
                                        .listRowSeparator(.hidden)
                                }
                                .onDelete { indexSet in
                                    indexSet.forEach { i in
                                        vm.deleteTask(id: todayTasks[i].id)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Today's Tasks")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .textCase(.uppercase)
                                    Spacer()
                                    Text("\(doneTasks)/\(todayTasks.count) done")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(doneTasks == todayTasks.count ? .green : .orange)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Session Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showTaskSheet = false }
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { taskFieldFocused = true }
    }

    func taskRow(task: SessionTask) -> some View {
        HStack(spacing: 12) {
            Button {
                vm.toggleTask(id: task.id)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.isDone ? .green : .white.opacity(0.3))
                    .animation(.spring(response: 0.3), value: task.isDone)
            }

            Text(task.title)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(task.isDone ? .white.opacity(0.35) : .white)
                .strikethrough(task.isDone, color: .white.opacity(0.35))
                .animation(.easeInOut(duration: 0.2), value: task.isDone)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Goal Sheet
    var goalSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How many sessions do you want to complete today?")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                Stepper("Goal: \(tempGoal) sessions", value: $tempGoal, in: 1...12)
                    .padding()
                    .background(AppTheme.card)
                    .cornerRadius(14)

                Button("Save Goal") {
                    vm.saveGoal(tempGoal)
                    showGoalPicker = false
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent)
                .foregroundColor(.black)
                .cornerRadius(14)
                .font(.system(size: 16, weight: .semibold, design: .rounded))

                Spacer()
            }
            .padding(24)
            .navigationTitle("Daily Focus Goal")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers
    func sessionComplete() {
        running = false
        if phase == .focus {
            vm.recordFocusSession() // records session, awards XP, checks milestones, triggers note sheet
            sessionsDone += 1
            motivationMsg = motivationMessages.randomElement()!
            phase = sessionsDone % 4 == 0 ? .longBreak : .shortBreak
            if dndEnabled { sendSessionCompleteNotification() }
        } else {
            phase = .focus
        }
        timeRemaining = phase.duration
    }

    func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    func addTask() {
        vm.addTask(title: newTaskText)
        newTaskText = ""
    }

    // DND: schedule a local notification when session ends
    func scheduleDNDReminder() {
        let content   = UNMutableNotificationContent()
        content.title = "⏰ Session Complete!"
        content.body  = "Great work! Time for a break. You've earned it 🎉"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(phase.duration), repeats: false)
        let request = UNNotificationRequest(identifier: "dnd_reminder_\(UUID())", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendSessionCompleteNotification() {
        let content   = UNMutableNotificationContent()
        content.title = "✅ Pomodoro Done!"
        content.body  = motivationMessages.randomElement()!
        content.sound = .default
        let trigger   = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request   = UNNotificationRequest(identifier: "session_done_\(UUID())", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
