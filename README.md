# 🟣 ZAZNAMITY — RECORD • TRACK • FOCUS

> **Secure Financial Tracker & Predictive Outlook Engine**

**Zaznamity** is an advanced, privacy-first personal finance application built with Flutter and Dart. Engineered around local data persistence, predictive runway analytics, and dynamic cashflow forecasting, Zaznamity helps users answer critical forward-looking financial questions: *"Will I be okay?"*, *"How long is my runway?"*, and *"What will my liquid position be next month?"*

---

## 🌟 Key Functional Architecture & Widget Suite

Zaznamity is modularized into dedicated analytics cards, data input sheets, visualization panels, and privacy wrappers:

### 🔮 1. Forward Forecasting & Runway Engine
* **`future_metrics_card.dart`**: Forward-looking financial outlook computing Future Flow, liquid balances, projected prognosis at target dates, and Runway Depletion dates (color-coded risk based on 30/90/365-day burn rate modeling).
* **`future_analytics_card.dart`**: Detailed forward analytics breakdown by categories, upcoming recurring bills, and projected future cash distribution.
* **`what_if_scenario_card.dart`**: Interactive head-to-head comparison tool allowing users to simulate life scenarios (e.g., career changes, major purchases, recurring subscriptions) and evaluate immediate impacts on cash velocity and depletion.

### 🧠 2. Smart Insights & Committed Expense Engine
* **`smart_insights_card.dart`**: Weighted Financial Health Score (10–100) combining savings rate, emergency runway, budget adherence, and debt load. Features automated alerts for price hikes, discretionary budget breakers, and emergency reserve deficits.
* **`summary_metrics_card.dart`**: High-level overview card presenting consolidated balances, current month net cash flows, and key performance indicators.
* **`budget_progress_card.dart`**: Dynamic tracking of category spend limits against actual historical burn.

### 🎯 3. Savings Goals & Allocation Management
* **`savings_goals_card.dart`**: Target date pace evaluation, monthly installment requirements, milestone notifications (25%, 50%, 75%, 100%), and single-tap goal disbursement/funding.
* **`savings_chart_card.dart`**: Graphical visualization of savings accumulation over time.
* **`liabilities_card.dart`**: Comprehensive tracking of outstanding debts, monthly installments, and payoff timelines.

### 📊 4. Visual Analytics & Cash Flow Diagrams
* **`sankey_flow_card.dart`**: Dynamic flow diagram illustrating income sources, pool distributions, and expense allocations.
* **`liquid_trend_chart.dart` & `monthly_cashflow_trend_card.dart`**: Interactive historical cashflow velocity trends powered by `fl_chart`.
* **`pools_analytics_card.dart`**: Deep-dive analytics into liquid vs. non-liquid asset pools (`checking`, `cash`, `savings`).
* **`income_expenses_by_labels_card.dart` & `selected_label_focus_card.dart`**: Label/Category breakdown charts and focused sub-analytics.

### 🔒 5. Privacy, Security & Data Management
* **`privacy_service.dart` & `masked_amount.dart`**: Global discretionary privacy system utilizing `ValueNotifier` and `SharedPreferences` to mask sensitive numbers with `••••••` across all UI widgets. Automatically restored upon app relaunch.
* **`csv_import_mapper_dialog.dart`**: Dialog tool for mapping external CSV bank statements into Zaznamity transactions.
* **`transfer_funds_card.dart` & `new_zaznam_card.dart`**: Rapid transaction creation, scheduling, and inter-pool fund transfers.

---

## 📂 Project Structure

```
zaznamity/
├── assets/                       # Branding logos and splash graphics
│   ├── ZaznamityLogoFULL.jpg
│   ├── ZaznamityLogo_only2white.png
│   └── solid_purple.png
├── lib/
│   ├── main.dart                 # Application lifecycle, auth lock, and initialization
│   ├── models/                   # TransactionModel, LabelModel, SavingsGoalModel, etc.
│   ├── screens/                  # Top-level screen components (DashboardScreen)
│   ├── services/                 # Local persistence and global utilities
│   │   ├── database_helper.dart  # SQLite persistence engine
│   │   ├── notification_service.dart # Local scheduled notifications
│   │   ├── privacy_service.dart  # Reactive state persistence for Privacy Mode
│   │   └── snackbar_notification.dart # Customized alert toasts
│   └── widgets/                  # Modular UI cards, charts, and input sheets
│       ├── app_settings_card.dart
│       ├── bottom_card_nav_bar.dart
│       ├── budget_progress_card.dart
│       ├── calendar_card.dart
│       ├── csv_import_mapper_dialog.dart
│       ├── dashboard_section.dart
│       ├── future_analytics_card.dart
│       ├── future_metrics_card.dart
│       ├── income_expenses_by_labels_card.dart
│       ├── liabilities_card.dart
│       ├── liquid_trend_chart_card.dart
│       ├── masked_amount.dart
│       ├── monthly_cashflow_trend_card.dart
│       ├── new_zaznam_card.dart
│       ├── pools_analytics_card.dart
│       ├── sankey_flow_card.dart
│       ├── savings_chart_card.dart
│       ├── savings_goals_card.dart
│       ├── selected_label_focus_card.dart
│       ├── smart_insights_card.dart
│       ├── summary_metrics_card.dart
│       ├── title_card.dart
│       ├── transaction_history_card.dart
│       ├── transfer_funds_card.dart
│       ├── what_if_scenario_card.dart
│       └── settings/             # Dynamic setting forms & sheets
├── pubspec.yaml                  # Dependency definitions & asset manifest
└── README.md
```

---

## 📦 Dependencies & Tech Stack

Zaznamity is built with Flutter (SDK `^3.13.4`) leveraging key production packages:

| Library | Purpose |
| :--- | :--- |
| **`sqflite`** | On-device SQLite database storage |
| **`shared_preferences`** | Persistent preferences (Themes, Primary Currency, Privacy Mode) |
| **`provider`** | Reactive state management |
| **`fl_chart`** | Interactive data visualization and financial trend charts |
| **`local_auth`** | Biometric security (Fingerprint / Face ID) and PIN code protection |
| **`pdf` / `printing`** | Financial report generation and document export |
| **`flutter_local_notifications`** | Scheduled reminders and milestone notifications |
| **`speech_to_text`** | Hands-free voice transaction input support |

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: `>=3.13.4`
* **Dart SDK**: `>=3.0.0`
* **Android Studio / Xcode** (for build tools and emulators)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/whitenight21/zaznamity.git
   cd zaznamity
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Service Initializations in `main.dart`:**
   Ensure `PrivacyService` and `NotificationService` initialize before app startup:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await PrivacyService.instance.init();
     await NotificationService.init();
     runApp(const ZaznamityApp());
   }
   ```

4. **Launch Application:**
   ```bash
   flutter run
   ```

---

## 🔒 Privacy & Security Model

* **Offline-First Storage:** All transaction data, account pool balances, and savings goals reside locally in an encrypted SQLite database via `DatabaseHelper`.
* **Biometric Guard:** App lifecycle state shifts (background/pause) automatically trigger passcode or biometric re-authentication via `local_auth`.
* **Zero Cloud Dependence:** Analytical health metrics and forecasting models are calculated exclusively on-device.

---

## 📜 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for complete details.
