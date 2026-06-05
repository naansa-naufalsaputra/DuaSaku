# Requirements: Smart Parser Orchestrator & Dynamic Contextual Geofencing

This document specifies the requirements, technical constraints, and acceptance criteria for two major enhancements in the **DuaSaku** application: the **Smart Parser Orchestrator** and **Dynamic Contextual Geofencing**.

---

## 1. Feature 1: Smart Parser Orchestrator (Graceful ML Fallback)

### 1.1 Objective
Enhance the robustness and reliability of the offline smart text input feature by introducing an intelligent orchestrator that manages different NLP parsing strategies. The app currently depends directly on the TensorFlow Lite model (`TfliteTransactionParserService` - Level 3), which can fail to initialize or execute on low-end devices, unsupported CPU architectures, or when memory is highly constrained. The orchestrator will provide a graceful fallback to the rule-based regex/fuzzy matching parser (`LocalTransactionParserService` - Level 1) and offer user settings for engine customization.

### 1.2 Functional Requirements
1. **Fallback Logic (Adapter Pattern):**
   - The orchestrator must implement `TransactionParserServiceInterface`.
   - By default, it must attempt to parse using the `TfliteTransactionParserService` (Level 3).
   - If the TFLite parser fails to initialize (e.g., missing binary, loading error), times out during initialization (threshold: 3 seconds), or throws an exception during inference, the orchestrator must instantly catch the exception, log the failure, and fallback to `LocalTransactionParserService` (Level 1) to return a parsed transaction structure.
2. **User Preferences (Engine Modes):**
   - Provide three parser modes configurable from the Settings/Profile screen:
     - **Auto (Default):** TFLite with automatic fallback to Regex/Fuzzy on failure.
     - **Akurasi Tinggi (High Accuracy):** Exclusively uses TFLite. Throws errors or alerts the user if TFLite cannot run.
     - **Hemat Daya (Battery/Memory Saver):** Exclusively uses the lightweight Regex/Fuzzy parser to minimize CPU and memory footprint.
   - Persist this preference in `SharedPreferences`.

### 1.3 Technical Constraints
* **Latency Guarantee:** In "Auto" mode, TFLite initialization must not delay parsing by more than 3 seconds. The fallback trigger must be swift and unnoticeable to the user (sub-100ms switch time).
* **Robustness:** A failure in the ML engine must *never* crash the app or prevent the user from saving a transaction manually or using the NLP entry bar.

### 1.4 Acceptance Criteria
- [ ] Swapping the engine mode in Settings changes the active parser immediately.
- [ ] If the `.tflite` model file is missing or corrupted, NLP parsing still completes successfully using regex matching.
- [ ] Handled fallback events are captured and logged to the global error logger for developer diagnostics.

---

## 2. Feature 2: Dynamic Contextual Geofencing (Location-Based Hotspots)

### 2.1 Objective
Transform the static, hardcoded geofencing alert system (currently hardcoded to Semarang Simpang Lima) into an intelligent, contextual, and offline location-based spending warning system that automatically adapts to the user's spending habits.

### 2.2 Functional Requirements
1. **Transaction Location Tracking:**
   - Add optional double fields `latitude` and `longitude` to the `Transactions` table.
   - On the transaction creation sheet, allow users to capture their current GPS location using `geolocator` (if permission is granted) or leave it empty.
2. **Offline Hotspot Clustering:**
   - Implement an offline, lightweight clustering algorithm (e.g., basic distance threshold grouping) that runs in a background task (WorkManager) or after a transaction is saved.
   - Define a **Spending Hotspot** as a cluster containing at least **3 transactions** or a cluster where total expenses exceed a configurable threshold (e.g., Rp 500,000) within the last 30 days.
   - Identify the top 5 hotspots based on transaction density and spending magnitude.
3. **Dynamic Geofence Registration:**
   - Periodically update the registered geofence zones in `GeofenceService` with the coordinates of the identified top 5 hotspots (using a default radius of 150 meters).
   - Automatically unregister old geofences when hotspots change.
4. **Contextual Alerting:**
   - When the user enters a registered hotspot zone, trigger a local notification:
     - *Title:* "⚠️ Pengingat Belanja di [Nama Lokasi/Kategori]!"
     - *Body:* "Anda telah memasuki salah satu area pengeluaran tersering Anda. Tetap hemat!"
   - Implement a cooldown of **6 hours** per hotspot to avoid notification spamming.

### 2.3 Technical Constraints
* **Battery Efficiency:** Location tracking for geofencing must use Android's Geofencing API or iOS's Significant Location Change service rather than continuous high-accuracy GPS tracking, minimizing battery drain.
* **Drift Schema Migration:** Upgrading the schema requires a seamless migration from v8 to v9. The migration must preserve all existing transaction data, setting `latitude` and `longitude` to `null` for old records.
* **Privacy:** All location data must remain strictly on-device in the local SQLite database (`duasaku_offline.sqlite`). No coordinates should ever be uploaded to external servers.

### 2.4 Acceptance Criteria
- [ ] Upgrading the application successfully migrates the Drift database schema to version 9 without data loss.
- [ ] Geofencing zones update dynamically when new transactions with locations are added and meet the hotspot criteria.
- [ ] Entering a hotspot triggers a notification only once within a 6-hour period.
- [ ] Users can toggle location tracking on/off entirely from the Settings screen.
