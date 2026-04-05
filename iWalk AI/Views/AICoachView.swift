import SwiftUI

struct AICoachView: View {
    @State private var vm = CoachViewModel()
    @Environment(\.streakVM) private var streakVM

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    AppHeader()

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
                            Text("I've analyzed your recent activity.")
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

                    // Recommendation Cards
                    AnimatedCard(delay: 0.3) {
                        VStack(spacing: 14) {
                            ForEach(vm.recommendations) { rec in
                                InfoCard(backgroundColor: rec.backgroundColor.opacity(0.3)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: rec.icon)
                                                .foregroundStyle(rec.iconColor)
                                            Text(rec.title)
                                                .font(IWFont.titleMedium())
                                                .foregroundStyle(Color.iwOnSurface)
                                            Spacer()
                                            Image(systemName: vm.expandedRecommendationId == rec.id ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.iwOutline)
                                        }
                                        Text(rec.description)
                                            .font(IWFont.bodyMedium())
                                            .foregroundStyle(Color.iwOutline)

                                        if vm.expandedRecommendationId == rec.id {
                                            Divider()
                                            Text(rec.detailedInfo)
                                                .font(IWFont.bodyMedium())
                                                .foregroundStyle(Color.iwOnSurfaceVariant)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { vm.toggleRecommendation(rec) }
                            }
                        }
                    }

                    // Chat Section
                    if !vm.showChat {
                        // Suggestion Chips
                        AnimatedCard(delay: 0.4) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Ask about walking benefits")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Color.iwOnSurface)

                                VStack(spacing: 10) {
                                    ForEach(vm.suggestions) { suggestion in
                                        Button {
                                            vm.sendSuggestion(suggestion)
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "bubble.left.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Color.iwPrimary)
                                                Text(suggestion.text)
                                                    .font(IWFont.bodyMedium())
                                                    .foregroundStyle(Color.iwOnSurfaceVariant)
                                                    .lineLimit(1)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.iwOutline)
                                            }
                                            .padding(14)
                                            .background(Color.iwSurfaceContainerLowest)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                        }
                                    }
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

                            // Quick suggestions after chat starts
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vm.suggestions) { suggestion in
                                        Button {
                                            vm.sendSuggestion(suggestion)
                                        } label: {
                                            Text(suggestion.text)
                                                .font(IWFont.labelMedium())
                                                .foregroundStyle(Color.iwPrimary)
                                                .lineLimit(1)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Color.iwPrimaryFixed.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .id("chatBottom")
                    }

                    // Nature Insight Card
                    AnimatedCard(delay: vm.showChat ? 0 : 0.5) {
                        InfoCard(backgroundColor: .iwPrimary) {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Walking in nature reduces stress by 40% more effectively than urban walking.")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(.white)
                                Text("Consider finding a nearby park or trail for your next walk.")
                                    .font(IWFont.bodyMedium())
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }

                    // Chat Input
                    if vm.showChat {
                        Spacer().frame(height: 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, vm.showChat ? 80 : 100)
            }
            .onChange(of: vm.messages.count) {
                withAnimation {
                    proxy.scrollTo("chatBottom", anchor: .bottom)
                }
            }
        }
        .background(Color.iwSurface)
        .overlay(alignment: .bottom) {
            if vm.showChat {
                ChatInputBar(text: $vm.inputText) {
                    vm.sendMessage(vm.inputText)
                }
                .padding(.bottom, 90)
            }
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
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask your AI coach...", text: $text)
                .font(IWFont.bodyMedium())
                .padding(12)
                .background(Color.iwSurfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit { onSend() }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.iwOutline : Color.iwPrimary)
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
