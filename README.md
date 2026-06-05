# 📱 DuaSaku — Personal Finance Companion

<div align="center">

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.12.0-blue.svg?logo=flutter&style=for-the-badge)](https://flutter.dev)
[![Platform Support](https://img.shields.io/badge/Platform-Android-green.svg?logo=android&style=for-the-badge)](https://android.com)
[![Architecture](https://img.shields.io/badge/Architecture-Clean--Riverpod-orange?style=for-the-badge)](#-architecture)
[![Local First](https://img.shields.io/badge/Privacy-Local--First-success?logo=skype&style=for-the-badge)](#-security--privacy)

**DuaSaku** is a private, intelligent, and fluid personal finance companion app. Built using Flutter, it features stunning liquid-glass visual styles, real-time sensor-driven animations, and a multi-level offline transaction parser powered by on-device Machine Learning.

[Explore Features](#-key-features) • [Tech Stack](#-tech-stack) • [Architecture](#-architecture) • [Getting Started](#-getting-started)

</div>

---

## 🚀 Key Features

### 1. 🌀 Premium Liquid Parallax Mesh Gradients
DuaSaku breaks away from boring flat UIs with **Liquid Mesh Gradients** that react fluidly to the physical world:
* **Gyroscope-Driven Parallax**: Integrates with device accelerometer sensors using a low-pass filter to tilt and warp background glow blobs as you tilt your phone.
* **Continuous Floating Fallback**: Smooth, organic, mathematical floating animations when physical sensors are unavailable or flat.
* **Premium Glassmorphism**: Tailored, harmonious color palettes (cyan, teal, dark modes) using overlay blends for a premium feel.

### 2. 🤖 Hybrid On-Device Smart Parser (Level 1-3 Pipeline)
DuaSaku automatically parses transaction messages and notifications locally without sending any data to external servers:
```
[Notification/SMS] ──► [Level 3: TFLite NLP Classifier] (Deep learning prediction)
                           │ (if failed)
                           ▼
                       [Level 2: Naive Bayes ML Fallback] (Probability classification)
                           │ (if failed)
                           ▼
                       [Level 1: Regex Engine] (Optimized pattern extraction)
```
* **Level 3 (NLP)**: TensorFlow Lite classifier parses raw text into transactional structures.
* **Level 2 (Lite ML)**: A highly efficient Naive Bayes model trained with local word frequency tables for zero-latency offline parsing.
* **Level 1 (Regex)**: Enhanced Regex matchers with word-boundary checks to safely parse numerical inputs, prepositions, and shorthand amounts (e.g. `k`, `jt`).

### 3. 🔒 Local-First Architecture
* **Drift Database (SQLite)**: Fully relational, reactive, and localized storage.
* **Zero Telemetry**: Your financial records, accounts, and targets stay entirely on your device.
* **Secure Storage**: Sensitive preferences and keys encrypted using `flutter_secure_storage`.

### 4. 📊 Gorgeous Interactive Analytics
* Interactive pie, bar, and line charts powered by `fl_chart`.
* Custom shimmers (`shimmer`, `skeletonizer`) and micro-animations (`flutter_animate`) for tactile, responsive UI.

---

## 🛠️ Tech Stack

* **Core**: [Flutter](https://flutter.dev) (Dart SDK `^3.12.0`)
* **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod` for declarative state-sharing)
* **Local Database**: [Drift](https://drift.simonbinder.eu/) (Reactive SQLite ORM)
* **Navigation**: [Go Router](https://pub.dev/packages/go_router)
* **On-Device ML**: [TFLite Flutter](https://pub.dev/packages/tflite_flutter), `google_mlkit_text_recognition`
* **Animations**: [Lottie](https://pub.dev/packages/lottie), [Flutter Animate](https://pub.dev/packages/flutter_animate)
* **Real-time Sensors**: [Sensors Plus](https://pub.dev/packages/sensors_plus)

---

## 📐 Architecture

DuaSaku is designed around clean architecture principles to isolate business rules from external frameworks:

```
lib/
├── core/
│   ├── theme/           # Premium styles, Liquid Parallax backgrounds
│   ├── utils/           # Extractors, local helper services
│   └── routing/         # GoRouter declaration & route maps
├── features/
│   ├── transactions/    # Transaction domain, Smart Parser services (TFLite/Naive Bayes)
│   ├── accounts/        # User accounts, wallets management
│   └── statistics/      # fl_chart integration & trends
```

* **Separation of Concerns**: UI components interact only with Riverpod providers, which orchestrate domain services.
* **Service Orchestration**: Complex pipelines like the Smart Parser are encapsulated in orchestrator modules with structured fallbacks.

---

## 🏁 Getting Started

### Prerequisites
* Flutter SDK (`>= 3.12.0`)
* Android Studio / VS Code with Flutter extension
* Android SDK 21+ (for physical device / emulator)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/naansa-naufalsaputra/DuaSaku.git
   cd duasaku_app
   ```

2. **Set up Environment Variables**:
   Create a `.env` file in the root directory:
   ```env
   # Add your environment variables here if required
   API_KEY=your_mock_key_here
   ```

3. **Get dependencies**:
   ```bash
   flutter pub get
   ```

4. **Generate Drift Database Code**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Run the application**:
   ```bash
   flutter run
   ```

### Running Tests
DuaSaku is fully tested with high coverage for its parsing engines and helper scripts:
```bash
flutter test
```

---

## 🤝 Contributing
Contributions are what make the open source community such an amazing place to learn, inspire, and create.
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.
