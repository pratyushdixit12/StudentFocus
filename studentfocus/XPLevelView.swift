import SwiftUI

// MARK: - XP LEVEL VIEW
// Full-screen view showing XP progress, level roadmap, and how to earn XP.

struct XPLevelView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var animateRing    = false
    @State private var animateBar     = false
    @State private var animateIn      = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [vm.currentLevel.color.opacity(0.18), Color.clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {

                    // MARK: Hero Card — Ring + XP
                    heroCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateIn)

                    // MARK: XP Rewards Card
                    xpRewardsCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateIn)

                    // MARK: Level Roadmap Card
                    levelRoadmapCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: animateIn)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .navigationTitle("XP & Level")
        .onAppear {
            animateIn = true
            // Delayed ring animation for dramatic effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1.2)) { animateRing = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.8)) { animateBar = true }
            }
        }
    }

    // MARK: - Hero Card
    var heroCard: some View {
        let level = vm.currentLevel
        let progress = vm.progressToNextLevel

        return VStack(spacing: 20) {
            // Animated circular progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 130, height: 130)

                // Progress arc
                Circle()
                    .trim(from: 0, to: animateRing ? CGFloat(progress) : 0)
                    .stroke(
                        LinearGradient(
                            colors: [level.color, level.color.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)

                // Center content
                VStack(spacing: 4) {
                    Image(systemName: level.icon)
                        .font(.system(size: 28))
                        .foregroundColor(level.color)
                    Text(level.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(level.color)
                }
            }

            // XP count
            Text("\(vm.totalXP) XP")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Next level info
            if let next = level.nextLevel {
                Text("\(vm.xpNeededForNext) XP to \(next.title)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(level.color)
            } else {
                Text("Max Level Reached! 👑")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1, green: 0.84, blue: 0))
            }

            // Full-width progress bar
            VStack(spacing: 6) {
                HStack {
                    Text(level.title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(level.color)
                    Spacer()
                    if let next = level.nextLevel {
                        Text(next.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(colors: [level.color, level.color.opacity(0.6)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: animateBar ? geo.size.width * CGFloat(progress) : 0, height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(level.color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - XP Rewards Card
    var xpRewardsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 15))
                Text("How to Earn XP")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            ForEach(Array(AppViewModel.xpRewards.enumerated()), id: \.offset) { idx, reward in
                if idx > 0 {
                    Divider().background(Color.white.opacity(0.06))
                }

                HStack {
                    Image(systemName: rewardIcon(for: idx))
                        .foregroundColor(rewardColor(for: idx))
                        .font(.system(size: 14))
                        .frame(width: 28)

                    Text(reward.action)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text("+\(reward.xp) XP")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    func rewardIcon(for index: Int) -> String {
        ["timer", "checkmark.circle", "note.text", "trophy"][index]
    }

    func rewardColor(for index: Int) -> Color {
        [.orange, .green, .indigo, Color(red: 1, green: 0.84, blue: 0)][index]
    }

    // MARK: - Level Roadmap Card
    var levelRoadmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 15))
                Text("Level Roadmap")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: 0) {
                ForEach(Array(XPLevel.allCases.enumerated()), id: \.element) { idx, level in
                    let isUnlocked = vm.totalXP >= level.xpRequired
                    let isCurrent  = vm.currentLevel == level

                    HStack(spacing: 14) {
                        // Vertical line + icon circle
                        VStack(spacing: 0) {
                            if idx > 0 {
                                Rectangle()
                                    .fill(isUnlocked ? level.color.opacity(0.5) : Color.white.opacity(0.08))
                                    .frame(width: 2, height: 16)
                            }

                            ZStack {
                                Circle()
                                    .fill(isUnlocked ? level.color.opacity(0.2) : Color.white.opacity(0.06))
                                    .frame(width: 38, height: 38)
                                if isUnlocked {
                                    Circle()
                                        .stroke(level.color.opacity(0.5), lineWidth: 2)
                                        .frame(width: 38, height: 38)
                                }
                                Image(systemName: level.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(isUnlocked ? level.color : .white.opacity(0.2))
                            }

                            if idx < XPLevel.allCases.count - 1 {
                                Rectangle()
                                    .fill(isUnlocked ? level.color.opacity(0.3) : Color.white.opacity(0.08))
                                    .frame(width: 2, height: 16)
                            }
                        }

                        // Level info
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(level.title)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(isUnlocked ? .white : .white.opacity(0.35))

                                if isCurrent {
                                    Text("CURRENT")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(level.color)
                                        .cornerRadius(6)
                                }
                            }

                            Text("\(level.xpRequired) XP required")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(AppTheme.secondaryText)
                        }

                        Spacer()

                        // Status icon
                        Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isUnlocked ? .green : .white.opacity(0.15))
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(x: animateIn ? 0 : -20)
                    .animation(.spring(response: 0.5).delay(0.4 + Double(idx) * 0.08), value: animateIn)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - XP TOAST VIEW
// Floating overlay capsule showing XP earned. Used as .overlay(alignment: .top).

struct XPToastView: View {
    let xp: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 14))
            Text("+\(xp) XP")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(
                    Capsule()
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: .yellow.opacity(0.25), radius: 12, y: 4)
        )
    }
}
