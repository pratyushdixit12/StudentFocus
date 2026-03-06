import SwiftUI

// MARK: - MILESTONES VIEW
// Full-screen view showing study hour milestones, progress, and badges.

struct MilestonesView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var animateIn     = false
    @State private var animateBar    = false
    @State private var animateHero   = false

    var badgesEarned: Int { vm.milestones.filter { $0.achieved }.count }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.yellow.opacity(0.14), Color.clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    // MARK: Hours Hero Card
                    hoursHeroCard
                        .scaleEffect(animateHero ? 1 : 0.9)
                        .opacity(animateHero ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1), value: animateHero)

                    // MARK: Next Milestone Progress
                    nextMilestoneCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6).delay(0.25), value: animateIn)

                    // MARK: All Badges Grid
                    allBadgesSection
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6).delay(0.35), value: animateIn)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Milestones 🏅")
        .onAppear {
            animateIn = true
            animateHero = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.8)) { animateBar = true }
            }
        }
    }

    // MARK: - Hours Hero Card
    var hoursHeroCard: some View {
        let hours = vm.totalStudyHours()
        let sessions = vm.totalSessionsAllTime()

        return HStack(spacing: 0) {
            // Left: big hours number
            VStack(spacing: 4) {
                Text(String(format: "%.1f", hours))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("STUDY HOURS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText)
                    .tracking(1.5)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)
                .background(Color.white.opacity(0.15))

            // Right: mini stats
            VStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text("\(sessions)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Sessions")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(AppTheme.secondaryText)
                }

                VStack(spacing: 2) {
                    Text("\(badgesEarned)/\(vm.milestones.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                    Text("Badges")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(colors: [.yellow.opacity(0.4), .orange.opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Next Milestone Progress Card
    var nextMilestoneCard: some View {
        Group {
            if let next = vm.nextMilestoneTarget {
                let progress = vm.progressToNextMilestone
                let hours = vm.totalStudyHours()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Next Milestone")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(next.icon) \(next.title)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.yellow)
                    }

                    // Progress bar
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 10)
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(colors: [.yellow, .orange],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: animateBar ? geo.size.width * CGFloat(progress) : 0, height: 10)
                            }
                        }
                        .frame(height: 10)

                        HStack {
                            Text(String(format: "%.1f / %d hours", hours, next.hours))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(String(format: "%.0f%%", progress * 100))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    }

                    let remaining = Double(next.hours) - hours
                    Text("Complete \(String(format: "%.1f", max(0, remaining))) more hours to unlock")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            } else {
                // All milestones achieved
                VStack(spacing: 12) {
                    Text("🎉")
                        .font(.system(size: 40))
                    Text("All Milestones Achieved!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 1, green: 0.84, blue: 0))
                    Text("You're a legendary student!")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - All Badges Grid
    var allBadgesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Badges")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(Array(vm.milestones.enumerated()), id: \.element.id) { idx, milestone in
                    badgeCell(milestone: milestone, index: idx)
                }
            }
        }
    }

    func badgeCell(milestone: StudyMilestone, index: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        milestone.achieved
                        ? LinearGradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 70, height: 70)

                if milestone.achieved {
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                        .frame(width: 70, height: 70)
                }

                // Emoji
                Text(milestone.icon)
                    .font(.system(size: 30))
                    .opacity(milestone.achieved ? 1 : 0.3)
                    .grayscale(milestone.achieved ? 0 : 1)

                // Lock badge
                if !milestone.achieved {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .offset(x: 22, y: 22)
                }
            }

            // Title
            Text(milestone.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(milestone.achieved ? .white : .white.opacity(0.35))
                .lineLimit(1)

            // Hours target
            Text("\(milestone.hours)h")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(AppTheme.secondaryText)

            // Achieved date
            if milestone.achieved && !milestone.achievedOn.isEmpty {
                Text(formatShortDate(milestone.achievedOn))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.yellow.opacity(0.7))
            }
        }
        .scaleEffect(animateIn ? 1 : 0.7)
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4 + Double(index) * 0.07), value: animateIn)
    }

    func formatShortDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}

// MARK: - MILESTONE CELEBRATION VIEW
// Full-screen cover shown when a milestone is newly unlocked.

struct MilestoneCelebrationView: View {
    let milestone: StudyMilestone
    @Environment(\.dismiss) var dismiss
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.yellow.opacity(0.25), Color.clear],
                center: .center, startRadius: 0, endRadius: 350
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Large emoji with bounce
                Text(milestone.icon)
                    .font(.system(size: 80))
                    .scaleEffect(animateIn ? 1 : 0.3)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2), value: animateIn)

                Spacer().frame(height: 24)

                // "MILESTONE UNLOCKED!" label
                Text("MILESTONE UNLOCKED!")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .tracking(3)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeIn.delay(0.4), value: animateIn)

                Spacer().frame(height: 16)

                // Milestone title
                Text(milestone.title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.spring(response: 0.6).delay(0.5), value: animateIn)

                Spacer().frame(height: 10)

                // Subtitle
                Text(milestone.subtitle)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.6).delay(0.58), value: animateIn)

                Spacer().frame(height: 24)

                // XP badge
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("+50 XP 🎉")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(24)
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.65), value: animateIn)

                Spacer()

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text("Awesome! 🙌")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.yellow, .orange],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
                .animation(.spring(response: 0.6).delay(0.75), value: animateIn)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { animateIn = true }
    }
}
