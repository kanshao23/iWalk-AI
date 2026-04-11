import SwiftUI
import UIKit

struct AICoachView: View {
    @State private var vm = CoachViewModel()
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.streakVM) private var streakVM

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    AppHeader(showSettings: false)

                    // Profile Greeting
                    AnimatedCard(delay: 0.1) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.iwPrimaryContainer.opacity(0.3))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: vm.user.avatarSystemName)
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color.iwPrimary)
                                )
                            Text("Hello, \(vm.user.name)")
                                .font(IWFont.headlineMedium())
                                .foregroundStyle(Color.iwOnSurface)
                            Text(vm.analysisSubtitle)
                                .font(IWFont.bodyMedium())
                                .foregroundStyle(Color.iwOutline)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Today's Focus
                    AnimatedCard(delay: 0.2) {
                        InfoCard(backgroundColor: .iwPrimaryContainer.opacity(0.12)) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "target")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.iwPrimary)
                                    Text("Today's Focus")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwPrimary)
                                        .textCase(.uppercase)
                                }
                                Text(vm.todaysFocus)
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Color.iwOnSurface)
                                Text(vm.focusDetail)
                                    .font(IWFont.bodyMedium())
                                    .foregroundStyle(Color.iwOutline)
                            }
                        }
                    }

                    // Streak-aware message
                    if let streakMsg = vm.generateStreakMessage(streak: streakVM.streak) {
                        AnimatedCard(delay: 0.25) {
                            InfoCard(backgroundColor: .iwTertiaryFixed.opacity(0.2)) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.iwTertiaryContainer)
                                    Text(streakMsg)
                                        .font(IWFont.bodyMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                }
                            }
                        }
                    }

                    // Redirect explanatory content to Insights
                    AnimatedCard(delay: 0.28) {
                        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.iwPrimary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Need deeper analysis?")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwPrimary)
                                    Text("Open Insights for detailed trends, recommendations, and context behind each suggestion.")
                                        .font(IWFont.bodyMedium())
                                        .foregroundStyle(Color.iwOutline)
                                }
                            }
                        }
                    }

                    // Chat Messages
                    if vm.showChat {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Conversation")
                                .font(IWFont.titleMedium())
                                .foregroundStyle(Color.iwOnSurface)

                            ForEach(vm.messages) { message in
                                ChatBubble(message: message)
                            }

                            if vm.isTyping {
                                HStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Circle()
                                            .fill(Color.iwPrimary)
                                            .frame(width: 8, height: 8)
                                            .scaleEffect(vm.isTyping ? 1 : 0.5)
                                            .animation(
                                                .easeInOut(duration: 0.5)
                                                    .repeatForever()
                                                    .delay(Double(i) * 0.15),
                                                value: vm.isTyping
                                            )
                                    }
                                }
                                .padding(12)
                                .background(Color.iwSurfaceContainerLow)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        .id("chatBottom")
                    }

                    // Medical disclaimer (required for AI health apps, Apple guideline 1.4.1)
                    Text("AI suggestions are for informational purposes only and are not a substitute for professional medical advice, diagnosis, or treatment.")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Spacer().frame(height: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .onChange(of: vm.messages.count) {
                withAnimation {
                    proxy.scrollTo("chatBottom", anchor: .bottom)
                }
            }
        }
        .background(Color.iwSurface)
        .task {
            await vm.refreshContext(streak: streakVM.streak)
        }
        .onChange(of: streakVM.streak) { _, newStreak in
            Task {
                await vm.refreshContext(streak: newStreak)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await vm.refreshContext(streak: streakVM.streak)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatInputBar(
                text: $vm.inputText,
                suggestions: vm.suggestions,
                onSuggestionTap: vm.sendSuggestion
            ) {
                vm.sendMessage(vm.inputText)
            }
            .padding(.bottom, keyboardHeight > 0 ? 0 : 74)
        }
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let screenHeight = UIScreen.main.bounds.height
        let overlap = max(0, screenHeight - endFrame.minY)
        withAnimation(.easeOut(duration: 0.25)) {
            keyboardHeight = overlap
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: CoachMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            Text(message.content)
                .font(IWFont.bodyMedium())
                .foregroundStyle(isUser ? .white : Color.iwOnSurface)
                .padding(14)
                .background(isUser ? Color.iwPrimary : Color.iwSurfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if !isUser { Spacer(minLength: 60) }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - Chat Input Bar

private struct ChatInputBar: View {
    @Binding var text: String
    let suggestions: [CoachSuggestion]
    let onSuggestionTap: (CoachSuggestion) -> Void
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            onSuggestionTap(suggestion)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.iwPrimary)
                                Text(suggestion.text)
                                    .font(IWFont.labelMedium())
                                    .foregroundStyle(Color.iwOnSurfaceVariant)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.iwSurfaceContainerLowest)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask your coach anything...", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .font(IWFont.bodyMedium())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.iwSurfaceContainerLowest)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .onSubmit { onSend() }

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.iwOutline : Color.iwPrimary)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}
