import SwiftUI

// MARK: - SESSION NOTE SHEET VIEW
// Shown as a sheet after every Pomodoro focus session completes.
// Students reflect on what they learned and what's confusing.

struct SessionNoteSheetView: View {
    let sessionNum: Int
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var learned   = ""
    @State private var confusing = ""
    @State private var animateIn = false
    @FocusState private var focusedField: NoteField?

    enum NoteField { case learned, confusing }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.indigo.opacity(0.18), Color.clear],
                    center: .top, startRadius: 0, endRadius: 380
                ).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // MARK: Header — celebration
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.indigo.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "note.text")
                                    .font(.system(size: 32))
                                    .foregroundColor(.indigo)
                            }
                            .scaleEffect(animateIn ? 1 : 0.5)
                            .opacity(animateIn ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateIn)

                            Text("Session \(sessionNum) Complete! 🎉")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 16)
                                .animation(.spring(response: 0.5).delay(0.18), value: animateIn)

                            Text("Take a moment to reflect on your study session")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .opacity(animateIn ? 1 : 0)
                                .animation(.spring(response: 0.5).delay(0.24), value: animateIn)

                            // XP reminder badge
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12))
                                Text("+10 XP for writing a note")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.12))
                            .cornerRadius(20)
                            .opacity(animateIn ? 1 : 0)
                            .animation(.spring(response: 0.5).delay(0.3), value: animateIn)
                        }
                        .padding(.top, 10)

                        // MARK: Learned field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                                Text("What did I learn?")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $learned)
                                    .focused($focusedField, equals: .learned)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 80, maxHeight: 120)
                                    .padding(12)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(focusedField == .learned ? Color.yellow.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                                    )

                                if learned.isEmpty {
                                    Text("I understood how...")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(.white.opacity(0.2))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(0.35), value: animateIn)

                        // MARK: Confusing field (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                Text("What's still confusing?")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("optional")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.white.opacity(0.3))
                            }

                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $confusing)
                                    .focused($focusedField, equals: .confusing)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 60, maxHeight: 100)
                                    .padding(12)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(focusedField == .confusing ? Color.red.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                                    )

                                if confusing.isEmpty {
                                    Text("I need to review...")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(.white.opacity(0.2))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(0.4), value: animateIn)

                        // MARK: Save button
                        Button {
                            vm.addNote(learned: learned, confusing: confusing, sessionNum: sessionNum)
                            learned = ""
                            confusing = ""
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                Text("Save Note (+10 XP)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                learned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.indigo, .purple],
                                                 startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(learned.isEmpty ? .white.opacity(0.3) : .white)
                            .cornerRadius(16)
                        }
                        .disabled(learned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 24)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.45), value: animateIn)

                        // MARK: Skip button
                        Button {
                            dismiss()
                        } label: {
                            Text("Skip for now")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeIn.delay(0.5), value: animateIn)

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .onAppear {
            animateIn = true
            // Auto-focus learned field after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .learned
            }
        }
    }
}

// MARK: - STUDY LOG VIEW
// Browse all session notes grouped by date, with search and collapsible sections.

struct StudyLogView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var searchText  = ""
    @State private var expandedDates: Set<String> = []
    @State private var animateIn   = false

    // Filter notes by search text
    var filteredGroups: [(date: String, notes: [SessionNote])] {
        let groups = vm.groupedNotes
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return groups
        }
        let query = searchText.lowercased()
        return groups.compactMap { group in
            let matches = group.notes.filter {
                $0.learned.lowercased().contains(query) ||
                $0.confusing.lowercased().contains(query)
            }
            return matches.isEmpty ? nil : (date: group.date, notes: matches)
        }
    }

    // Stats
    var totalNotes: Int { vm.sessionNotes.count }
    var daysWithNotes: Int { Set(vm.sessionNotes.map { $0.date }).count }
    var notesWithConfusing: Int { vm.sessionNotes.filter { !$0.confusing.isEmpty }.count }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.indigo.opacity(0.12), Color.clear],
                center: .top, startRadius: 0, endRadius: 380
            ).ignoresSafeArea()

            if vm.sessionNotes.isEmpty {
                // MARK: Empty state
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Stats strip
                        statsStrip
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 16)
                            .animation(.spring(response: 0.5).delay(0.1), value: animateIn)

                        // Search bar
                        searchBar
                            .opacity(animateIn ? 1 : 0)
                            .animation(.spring(response: 0.5).delay(0.18), value: animateIn)

                        // Notes grouped by date
                        ForEach(Array(filteredGroups.enumerated()), id: \.element.date) { idx, group in
                            dateGroupSection(group: group, index: idx)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Study Log 📓")
        .onAppear {
            animateIn = true
            // Auto-expand today's group
            expandedDates.insert(vm.todayKey())
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.15))
            Text("No Notes Yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
            Text("Complete a focus session and write\na note to start your study log")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Stats Strip
    var statsStrip: some View {
        HStack {
            statColumn(value: "\(totalNotes)", label: "Total Notes")
            Divider().frame(height: 30)
            statColumn(value: "\(daysWithNotes)", label: "Days")
            Divider().frame(height: 30)
            statColumn(value: "\(notesWithConfusing)", label: "To Review")
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
    }

    func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Search Bar
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.4))
                .font(.system(size: 15))
            TextField("Search notes...", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
    }

    // MARK: - Date Group
    func dateGroupSection(group: (date: String, notes: [SessionNote]), index: Int) -> some View {
        let isExpanded = expandedDates.contains(group.date)
        let isToday = group.date == vm.todayKey()

        return VStack(spacing: 0) {
            // Header — tap to expand/collapse
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded {
                        expandedDates.remove(group.date)
                    } else {
                        expandedDates.insert(group.date)
                    }
                }
            } label: {
                HStack {
                    Text(formatDateHeader(group.date))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if isToday {
                        Text("Today")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }

                    Spacer()

                    Text("\(group.notes.count) note\(group.notes.count == 1 ? "" : "s")")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.secondaryText)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.vertical, 10)
            }

            // Notes
            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(group.notes) { note in
                        noteCard(note)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 16)
        .animation(.spring(response: 0.5).delay(0.2 + Double(index) * 0.06), value: animateIn)
    }

    // MARK: - Note Card
    func noteCard(_ note: SessionNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Session badge + time
            HStack {
                Text("Session \(note.sessionNum)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.3))
                    .cornerRadius(8)

                Spacer()

                Text(formatTimestamp(note.timestamp))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
            }

            // Learned section
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 13))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Learned")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text(note.learned)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            // Confusing section (only if not empty)
            if !note.confusing.isEmpty {
                Divider().background(Color.white.opacity(0.08))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Review Later")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.red.opacity(0.7))
                        Text(note.confusing)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .contextMenu {
            Button(role: .destructive) {
                vm.deleteNote(id: note.id)
            } label: {
                Label("Delete Note", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers
    func formatDateHeader(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "EEEE, MMM d, yyyy"
        return display.string(from: date)
    }

    func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
