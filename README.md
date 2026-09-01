# ClearTime

**Mindful screen habits for flourishing families.**

ClearTime is a child-first digital wellbeing application built with Flutter. It helps families cultivate healthy screen-time habits through on-device AI coaching, mission-based goal tracking, privacy-preserving usage analytics, and a parent–child collaborative experience — all without sending raw child usage data to the cloud.

Built for the IQOO Hackathon.

---

## ✨ Features

### For Parents
- **Dashboard** — Overview of children, tasks, missions, and reports in one place.
- **Task Assignment** — Create and assign tasks with optional proof-of-completion (photo/video).
- **Reports & Analytics** — Periodic and on-demand reports comparing screen-time trends. Compare reports side-by-side.
- **Triggers** — Configure screen-time trigger rules that fire local notifications.
- **AI Assistant** — On-device AI helps parents understand patterns and suggest coaching actions.
- **Privacy Center** — Transparent controls showing exactly what data stays on-device vs. what is synced.
- **Local AI Control Center** — Manage on-device LLM models, customise prompt templates, run AI diagnostics, and compare prompt outputs.

### For Children
- **Dashboard** — Personalised home with missions, goals, and progress at a glance.
- **Missions** — Gamified screen-time challenges with reward tracking.
- **Goals** — Set and track personal digital-wellbeing goals.
- **Insights** — Visual breakdown of app usage and screen-time patterns (processed locally).
- **AI Coach** — A local, on-device AI companion that nudges, reflects, and motivates.
- **Progress** — Achievement unlocks, streaks, and reward history.
- **Reflection** — Guided daily reflections to build mindful tech habits.

### Core Architecture
- **Privacy-First** — A `PrivacyGuard` enforces at the architectural level that raw usage records, timelines, and reflections **never** leave the device. Only approved, aggregated, anonymised reports can be synced.
- **On-Device AI** — Powered by `llama_cpp_dart` for local LLM inference. Models, prompts, and diagnostics are fully managed in-app. A deterministic fallback service ensures graceful degradation when no model is loaded.
- **Encrypted Local Storage** — Hive + `flutter_secure_storage` for encrypted on-device persistence.
- **Supabase Backend** — Auth (PKCE), realtime mission sync, and approved-report sync. Only the publishable (anon) key is used client-side; service-role keys are never embedded in the app.
- **Role-Based Routing** — Separate parent and child navigation shells with go_router deep-link support (`cleartime://` scheme for auth callbacks and invitations).

---

## 📱 Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅ Primary target |
| iOS      | ✅ Supported |
| Web      | ⚠️ Partial (AI runtime stubbed) |
| macOS / Linux / Windows | 💻 Scaffolded (not the focus) |

**Android permissions:** Internet, Camera, Record Audio (only when child records a video proof), Post Notifications, Package Usage Stats.

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ≥ 3.0) |
| State Management | Riverpod (`flutter_riverpod`) |
| Routing | go_router |
| Backend / Auth | Supabase (`supabase_flutter`, PKCE flow) |
| Local Storage | Hive + `flutter_secure_storage` |
| On-Device AI | `llama_cpp_dart` |
| Push Notifications | Firebase Cloud Messaging (optional) |
| QR / Scanner | `qr_flutter`, `mobile_scanner` |
| UI / Animation | `google_fonts`, `flutter_animate` |
| Testing | `flutter_test`, `mocktail` |

---

## 📁 Project Structure

```
lib/
├── main.dart                     # App entry point
├── core/
│   ├── config/                   # EnvConfig (client-safe env loading)
│   ├── constants/                # App name, routes, deep-link scheme
│   ├── errors/                   # App exceptions
│   ├── platform/                 # Native platform channels (device, usage, notification)
│   ├── privacy/                  # PrivacyGuard, child-report filter, usage-sync guard
│   ├── providers/                # Riverpod providers
│   ├── routing/                  # App router (go_router)
│   ├── security/                 # Authorization service, secure token generator
│   ├── services/                 # Service abstractions (interfaces)
│   ├── theme/                    # Colors, typography, spacing, radius, theme
│   ├── utils/                    # Validators
│   └── widgets/                  # Reusable UI components (button, card, avatar, etc.)
├── data/
│   ├── models/                   # Domain models (usage, missions, goals, reports, etc.)
│   └── repositories/             # Local + Supabase repositories
├── features/
│   ├── authentication/           # Login, OTP verification
│   ├── child/                    # Child dashboard, missions, goals, AI, insights, settings
│   ├── family/                   # Invitation, join family
│   ├── onboarding/               # Onboarding flow
│   ├── parent/                   # Parent dashboard, tasks, reports, triggers, AI, settings
│   ├── shared/                   # Shared widgets (task proof review)
│   └── splash/                   # Splash screen
└── services/
    ├── agent/                    # Autonomous agent engine
    ├── analytics/                # Local analytics, report builders, trigger engine
    ├── coaching/                 # Coaching loop, goal generation, pattern detection
    ├── llm/                      # On-device LLM runtime, prompt engine, model manager
    ├── push/                     # Push notification service
    ├── realtime/                 # Mission realtime sync
    ├── storage/                  # Encrypted device store, proof storage, retention
    └── usage/                    # Android usage data provider & collector
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel, ≥ 3.0)
- Dart SDK ≥ 3.0
- A Supabase project (for auth and backend sync)
- Android Studio / Xcode for device builds

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Tirumala2824/IQOO-ClearTIme.git
   cd IQOO-ClearTIme
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your Supabase URL and publishable (anon) key:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
   ```
   > ⚠️ **Security:** Never put `SUPABASE_SECRET_KEY`, `DATABASE_URL`, or `DIRECT_URL` in the Flutter app. Those are for server-side migration scripts only.

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

The project includes a comprehensive test suite covering privacy guards, AI context isolation, report builders, usage providers, and more.

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
flutter analyze
```

Test structure:
```
test/
├── helpers/          # Test utilities (encrypted store helper)
├── unit/             # Unit tests (35+ test files)
└── widget_test.dart  # Widget smoke test
```

---

## 🔒 Privacy & Security

ClearTime is built with a **privacy-by-design** philosophy:

- **Raw usage data never leaves the device.** The `PrivacyGuard` class enforces this at the architectural level — any attempt to transmit raw `UsageRecord`, `UsageTimelineEntry`, or `DailyReflection` to a cloud service throws a `StateError`.
- **Only approved, aggregated reports** can be synced to Supabase — and only when the parent explicitly approves.
- **Client-side keys only.** The Flutter app uses only the Supabase publishable (anon) key. Service-role keys are never embedded.
- **Encrypted local storage** via Hive + `flutter_secure_storage`.
- **On-device AI inference** — LLM models run locally via `llama_cpp_dart`. No child data is sent to external AI APIs.

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Auth, realtime, database sync |
| `flutter_riverpod` | State management |
| `go_router` | Declarative routing |
| `hive` / `hive_flutter` | Local encrypted storage |
| `flutter_secure_storage` | Secure key-value storage |
| `llama_cpp_dart` | On-device LLM inference |
| `firebase_messaging` | Push notifications (optional) |
| `qr_flutter` / `mobile_scanner` | Family invitation QR codes |
| `flutter_animate` | UI animations |
| `google_fonts` | Typography |

---

## 🤝 Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

Please ensure `flutter analyze` reports zero issues and all tests pass before submitting a PR.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👥 Acknowledgements

Built for the **IQOO Hackathon**.

ClearTime — *Mindful screen habits for flourishing families.*
