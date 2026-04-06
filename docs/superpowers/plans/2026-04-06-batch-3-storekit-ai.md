# Batch 3: StoreKit 2 + Cloudflare Workers AI + Dynamic Suggestions Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real subscription purchases via StoreKit 2, AI coach powered by Cloudflare Workers AI (Llama 3.1 8B), and context-aware suggestion pills.

**Architecture:**
- Cloudflare Worker (`iwalk-coach`) handles AI requests — iOS posts to it via URLSession.
- `StoreKitManager` (new) owns all purchase logic; `PaywallViewModel` delegates to it.
- `CoachAPIClient` (new) is a thin URLSession wrapper; `CoachViewModel` calls it and falls back to local responses on failure.

**Tech Stack:** StoreKit 2 (Swift), Cloudflare Workers AI (`@cf/meta/llama-3.1-8b-instruct`), Wrangler CLI, URLSession

---

## File Map

| Action | File |
|--------|------|
| Create | `iwalk-coach/` — Cloudflare Worker project (outside iOS folder) |
| Create | `iWalk AI/Config/AppConfig.swift` — Worker URL constant |
| Create | `iWalk AI/Services/StoreKitManager.swift` |
| Create | `iWalk AI/Services/CoachAPIClient.swift` |
| Modify | `iWalk AI/ViewModels/PaywallViewModel.swift` — integrate StoreKitManager |
| Modify | `iWalk AI/Views/PaywallView.swift` — show real loading/error states |
| Modify | `iWalk AI/ViewModels/CoachViewModel.swift` — real AI + dynamic suggestions |
| Modify | `iWalk AI/iWalk_AIApp.swift` — start StoreKit transaction listener |

---

## Task 1: Create Cloudflare Worker

This task runs outside Xcode. Requires `wrangler` CLI (`npm install -g wrangler`).

- [ ] **Step 1: Create Worker project**

```bash
cd /Users/kanshao/dev
mkdir iwalk-coach && cd iwalk-coach
wrangler init --no-delegate-c3
```

When prompted: choose "no" for git, "yes" for TypeScript, "no" for deploy.

- [ ] **Step 2: Replace `wrangler.toml` content**

```toml
name = "iwalk-coach"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[ai]
binding = "AI"
```

- [ ] **Step 3: Replace `src/index.ts` with the Worker code**

```typescript
export interface Env {
  AI: Ai;
}

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

interface RequestBody {
  messages: ChatMessage[];
  context: {
    steps: number;
    streak: number;
    goal: number;
    userName?: string;
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    let body: RequestBody;
    try {
      body = await request.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const { messages, context } = body;
    const { steps, streak, goal, userName = "there" } = context;

    const progressPct = goal > 0 ? Math.round((steps / goal) * 100) : 0;
    const systemPrompt = `You are a friendly and motivating walking coach for iWalk AI. 
Keep responses concise (2-3 sentences max). Be specific and actionable.
User context: ${steps.toLocaleString()} steps today (${progressPct}% of ${goal.toLocaleString()} goal), ${streak}-day streak.
Name: ${userName}. Always respond in the same language as the user's message.`;

    // Keep only last 10 messages to control tokens
    const recentMessages = messages.slice(-10);

    try {
      const response = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
        messages: [
          { role: "system", content: systemPrompt },
          ...recentMessages,
        ],
        max_tokens: 200,
      });

      const reply = (response as { response?: string }).response ?? "Keep walking — you're doing great!";

      return new Response(JSON.stringify({ reply }), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    } catch (err) {
      return new Response(
        JSON.stringify({ reply: "Connection issue. Keep up the great work!" }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }
  },
};
```

- [ ] **Step 4: Deploy the Worker**

```bash
cd /Users/kanshao/dev/iwalk-coach
wrangler deploy
```

Expected output includes: `Published iwalk-coach` and a URL like `https://iwalk-coach.<your-subdomain>.workers.dev`

Copy the Worker URL — you'll need it in Task 2.

- [ ] **Step 5: Test the Worker**

```bash
curl -X POST https://iwalk-coach.<your-subdomain>.workers.dev \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "How many more steps should I take today?"}],
    "context": {"steps": 6500, "streak": 5, "goal": 10000, "userName": "Alex"}
  }'
```

Expected: `{"reply": "..."}` with a helpful coaching response.

- [ ] **Step 6: Commit Worker code**

```bash
cd /Users/kanshao/dev/iwalk-coach
git init
git add -A
git commit -m "feat: iwalk-coach Cloudflare Worker with Llama 3.1 8B"
```

---

## Task 2: iOS Config + CoachAPIClient

**Files:**
- Create: `iWalk AI/Config/AppConfig.swift`
- Create: `iWalk AI/Services/CoachAPIClient.swift`

- [ ] **Step 1: Create `AppConfig.swift`**

Replace `<your-subdomain>` with the actual subdomain from the deployment in Task 1.

```swift
import Foundation

enum AppConfig {
    /// Cloudflare Workers AI coach endpoint
    static let coachWorkerURL = URL(string: "https://iwalk-coach.<your-subdomain>.workers.dev")!
}
```

- [ ] **Step 2: Create `CoachAPIClient.swift`**

```swift
import Foundation

struct CoachAPIClient {
    struct CoachContext: Encodable {
        let steps: Int
        let streak: Int
        let goal: Int
        let userName: String
    }

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let messages: [ChatMessage]
        let context: CoachContext
    }

    private struct ResponseBody: Decodable {
        let reply: String
    }

    private let session = URLSession.shared

    func sendMessage(
        history: [ChatMessage],
        context: CoachContext
    ) async throws -> String {
        var request = URLRequest(url: AppConfig.coachWorkerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = RequestBody(messages: history, context: context)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.reply
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Config/AppConfig.swift" \
        "iWalk AI/Services/CoachAPIClient.swift"
git commit -m "feat: AppConfig + CoachAPIClient for Cloudflare Workers AI"
```

---

## Task 3: Integrate Real AI into CoachViewModel

**Files:**
- Modify: `iWalk AI/ViewModels/CoachViewModel.swift`

- [ ] **Step 1: Add `CoachAPIClient` and convert `CoachMessage` to API format**

In `CoachViewModel.swift`, add the API client as a stored property after `private let healthKit`:

```swift
private let apiClient = CoachAPIClient()
```

- [ ] **Step 2: Replace `enqueueAssistantResponse()` with real API call**

Replace the existing `enqueueAssistantResponse(_:)` private method with:

```swift
private func enqueueAssistantResponse(for userText: String) {
    pendingResponseCount += 1
    isTyping = true

    Task {
        // Build message history for API (last 10 messages)
        let apiHistory = messages.suffix(10).map {
            CoachAPIClient.ChatMessage(
                role: $0.isUser ? "user" : "assistant",
                content: $0.content
            )
        }

        let context = CoachAPIClient.CoachContext(
            steps: todaySteps,
            streak: streak.currentStreak,
            goal: goalSteps,
            userName: user.name
        )

        let reply: String
        do {
            reply = try await apiClient.sendMessage(history: apiHistory, context: context)
        } catch {
            // Graceful fallback to local response
            reply = generateResponse(for: userText)
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            self.messages.append(CoachMessage.assistantMessage(reply))
        }
        self.pendingResponseCount = max(self.pendingResponseCount - 1, 0)
        self.isTyping = self.pendingResponseCount > 0
        self.persistMessages()
        self.refreshDynamicSuggestions()
    }
}
```

- [ ] **Step 3: Update `sendMessage()` to call the new method**

In `sendMessage()`, replace `enqueueAssistantResponse(response)` at the end with:

```swift
enqueueAssistantResponse(for: trimmed)
```

Remove the `matchedSuggestion` lookup since the AI will handle all responses naturally:

```swift
func sendMessage(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let userMsg = CoachMessage.userMessage(trimmed)
    withAnimation(.easeInOut(duration: 0.2)) {
        messages.append(userMsg)
        showChat = true
    }
    inputText = ""
    persistMessages()
    enqueueAssistantResponse(for: trimmed)
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 5: Commit**

```bash
git add "iWalk AI/ViewModels/CoachViewModel.swift"
git commit -m "feat: AI coach uses Cloudflare Workers AI with local fallback"
```

---

## Task 4: Dynamic Suggestion Pills

**Files:**
- Modify: `iWalk AI/ViewModels/CoachViewModel.swift`

- [ ] **Step 1: Add `refreshDynamicSuggestions()` method**

Add this method to `CoachViewModel.swift` (replaces the hardcoded `suggestions = CoachSuggestion.mockSuggestions`):

```swift
func refreshDynamicSuggestions() {
    let hour = Calendar.current.component(.hour, from: .now)
    let progressPct = goalSteps > 0 ? Double(todaySteps) / Double(goalSteps) : 0

    var newSuggestions: [CoachSuggestion] = []

    // Suggestion 1: progress-based
    if progressPct >= 1.0 {
        newSuggestions.append(CoachSuggestion(
            text: "目标达成！今天成绩怎么样？",
            aiResponse: ""
        ))
    } else if progressPct < 0.3 && hour >= 14 {
        let needed = stepsRemaining
        newSuggestions.append(CoachSuggestion(
            text: "现在出门走 20 分钟？",
            aiResponse: ""
        ))
        _ = needed // suppress warning
    } else {
        newSuggestions.append(CoachSuggestion(
            text: "还差 \(stepsRemaining.formatted()) 步达标，怎么加？",
            aiResponse: ""
        ))
    }

    // Suggestion 2: streak-based
    if streak.currentStreak >= 7 {
        newSuggestions.append(CoachSuggestion(
            text: "连续 \(streak.currentStreak) 天了，今天冲个人记录？",
            aiResponse: ""
        ))
    } else if streak.isAtRisk && streak.currentStreak > 0 {
        newSuggestions.append(CoachSuggestion(
            text: "今天还差 \(streakStepsRemaining.formatted()) 步保连续",
            aiResponse: ""
        ))
    } else {
        newSuggestions.append(CoachSuggestion(
            text: "如何提高步行效率？",
            aiResponse: ""
        ))
    }

    // Suggestion 3: time-based
    switch hour {
    case 5..<10:
        newSuggestions.append(CoachSuggestion(text: "晨走有什么好处？", aiResponse: ""))
    case 12..<14:
        newSuggestions.append(CoachSuggestion(text: "午饭后散步多久合适？", aiResponse: ""))
    case 20..<23:
        newSuggestions.append(CoachSuggestion(text: "睡前散步会影响睡眠吗？", aiResponse: ""))
    default:
        newSuggestions.append(CoachSuggestion(text: "今天感觉怎么样？", aiResponse: ""))
    }

    suggestions = newSuggestions
}
```

- [ ] **Step 2: Call `refreshDynamicSuggestions()` on init and context refresh**

In `CoachViewModel.init()`, replace or add alongside the existing `refreshRecommendations()`:

```swift
init() {
    loadMessages()
    refreshRecommendations()
    refreshDynamicSuggestions()
}
```

In `refreshContext(streak:)`, add at the end:

```swift
refreshDynamicSuggestions()
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/ViewModels/CoachViewModel.swift"
git commit -m "feat: dynamic context-aware suggestion pills in AI coach"
```

---

## Task 5: StoreKit 2 Manager

**Files:**
- Create: `iWalk AI/Services/StoreKitManager.swift`

**Prerequisites:** Configure two subscription products in App Store Connect:
- Product ID: `kanshaous.iwalk.weekly` (Weekly, $2.99)
- Product ID: `kanshaous.iwalk.yearly` (Annual, $39.99)

For local testing without App Store Connect, create a StoreKit configuration file in Xcode:
- File > New > File > StoreKit Configuration File → `iWalkStore.storekit`
- Add two auto-renewable subscriptions matching the product IDs above

- [ ] **Step 1: Create `StoreKitManager.swift`**

```swift
import StoreKit
import SwiftUI

@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var errorMessage: String?

    private let productIDs = ["kanshaous.iwalk.weekly", "kanshaous.iwalk.yearly"]
    private var transactionListenerTask: Task<Void, Error>?

    private init() {
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Could not load products. Check your connection."
        }
        isLoading = false
        await updatePurchasedProducts()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                isLoading = false
                return true
            case .userCancelled:
                isLoading = false
                return false
            case .pending:
                isLoading = false
                return false
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }

    // MARK: - Helpers

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }
        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
```

- [ ] **Step 2: Build to verify StoreKit compiles**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Services/StoreKitManager.swift"
git commit -m "feat: StoreKit 2 manager with purchase, restore, and transaction listener"
```

---

## Task 6: Integrate StoreKit into PaywallViewModel and PaywallView

**Files:**
- Modify: `iWalk AI/ViewModels/PaywallViewModel.swift`
- Modify: `iWalk AI/Views/PaywallView.swift`
- Modify: `iWalk AI/iWalk_AIApp.swift`

- [ ] **Step 1: Update `PaywallViewModel` to use `StoreKitManager`**

Replace the entire `PaywallViewModel.swift` content:

```swift
import SwiftUI
import StoreKit

enum PricingPlan: String, CaseIterable, Identifiable {
    case weekly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .yearly: "Annual"
        }
    }

    var price: String {
        switch self {
        case .weekly: "$2.99"
        case .yearly: "$0.77"
        }
    }

    var period: String { "/week" }

    var perWeekPrice: String? {
        switch self {
        case .weekly: nil
        case .yearly: "$39.99/yr billed annually"
        }
    }

    var savingsBadge: String? {
        switch self {
        case .weekly: nil
        case .yearly: "SAVE 74%"
        }
    }

    var productID: String {
        switch self {
        case .weekly: "kanshaous.iwalk.weekly"
        case .yearly: "kanshaous.iwalk.yearly"
        }
    }
}

@Observable
final class PaywallViewModel {
    var selectedPlan: PricingPlan = .yearly
    var showRetentionOffer = false
    var retentionPrice = "$29.99/year"
    var purchaseError: String?

    private let hasShownRetentionKey = "iw_has_shown_retention"

    var isPurchasing: Bool { StoreKitManager.shared.isLoading }
    var isPremium: Bool { StoreKitManager.shared.isPremium }

    let features: [(icon: String, title: String, description: String)] = [
        ("brain.head.profile", "AI Health Insights", "Personalized health analysis powered by AI"),
        ("figure.walk", "Smart Walking Coach", "Real-time coaching that adapts to your pace"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Deep health trends and projections"),
        ("trophy.fill", "Challenges & Badges", "Compete with friends and earn achievements"),
        ("heart.text.clipboard", "Health Reports", "Weekly AI-generated wellness reports"),
    ]

    let socialProof = "Join 25,000+ walkers already improving their health"

    func loadProducts() async {
        await StoreKitManager.shared.loadProducts()
    }

    func purchase() async -> Bool {
        purchaseError = nil
        let storeKit = StoreKitManager.shared
        guard let product = storeKit.products.first(where: { $0.id == selectedPlan.productID }) else {
            purchaseError = "Product not available. Please try again."
            return false
        }
        let success = await storeKit.purchase(product)
        if let error = storeKit.errorMessage {
            purchaseError = error
        }
        return success
    }

    func restore() async {
        purchaseError = nil
        await StoreKitManager.shared.restore()
        if let error = StoreKitManager.shared.errorMessage {
            purchaseError = error
        }
    }

    func dismiss() {
        let hasShown = UserDefaults.standard.bool(forKey: hasShownRetentionKey)
        if !hasShown && !isPremium {
            UserDefaults.standard.set(true, forKey: hasShownRetentionKey)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showRetentionOffer = true
            }
        }
    }

    func declineRetention() {
        showRetentionOffer = false
    }
}
```

- [ ] **Step 2: Update `PaywallView` to use async purchase**

In `PaywallView.swift`, find the "Start Free Trial" CTA button and update it to call `async` purchase:

```swift
// Find the purchase button (look for vm.purchase() call) and replace with:
Button {
    Task {
        let success = await vm.purchase()
        if success {
            dismiss()
        }
    }
} label: {
    if vm.isPurchasing {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
    } else {
        Text("Start 7-Day Free Trial")
            .font(IWFont.labelLarge())
            .foregroundStyle(.white)
    }
}
.frame(maxWidth: .infinity)
.frame(height: 54)
.background(Color.iwPrimary)
.clipShape(Capsule())
.disabled(vm.isPurchasing)
```

Add error display below the CTA button:
```swift
if let error = vm.purchaseError {
    Text(error)
        .font(IWFont.labelSmall())
        .foregroundStyle(Color.iwError)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
}
```

Update the Restore button:
```swift
Button("Restore") {
    Task { await vm.restore() }
}
```

Add `.task` to load products on appear:
```swift
.task {
    await vm.loadProducts()
}
```

- [ ] **Step 3: Start transaction listener in app entry point**

In `iWalk_AIApp.swift`, add to the `init()` or `body`:

```swift
// In the App struct, add:
init() {
    // Start StoreKit transaction listener at launch
    _ = StoreKitManager.shared
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 5: Commit**

```bash
git add "iWalk AI/ViewModels/PaywallViewModel.swift" \
        "iWalk AI/Views/PaywallView.swift" \
        "iWalk AI/iWalk_AIApp.swift"
git commit -m "feat: PaywallView integrated with real StoreKit 2 purchase flow"
```

---

## Verification Checklist

After all tasks complete:

- [ ] Cloudflare Worker deploys successfully and returns AI responses
- [ ] `curl` test to Worker URL returns `{"reply": "..."}` with relevant coaching text
- [ ] Build succeeds without errors or new warnings
- [ ] AI Coach sends real requests to Cloudflare Worker
- [ ] When Worker is unreachable, Coach falls back gracefully to local responses (no crash)
- [ ] Suggestion pills change based on step count, streak, and time of day
- [ ] After sending a message, suggestion pills refresh with new context-aware options
- [ ] StoreKit manager loads products (use `.storekit` config file for simulator testing)
- [ ] Purchase flow shows ProgressView during processing
- [ ] Restore purchases button calls `AppStore.sync()`
- [ ] Retention offer only shows once (UserDefaults flag)
- [ ] Purchase error message displays when purchase fails

---

## Notes

### StoreKit Local Testing

To test StoreKit in Simulator without App Store Connect approval:
1. In Xcode: File > New > File > StoreKit Configuration File → save as `iWalkStore.storekit`
2. Add two Auto-Renewable Subscriptions with the product IDs above
3. In scheme settings: Run > Options > StoreKit Configuration → select `iWalkStore.storekit`
4. Use Debug > StoreKit > Manage Transactions to simulate purchases

### Cloudflare Worker URL

After deployment, update `AppConfig.coachWorkerURL` with the actual Worker URL from `wrangler deploy` output.
