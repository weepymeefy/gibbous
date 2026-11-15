# Gibbous - AI Astronaut Health & Telemetry Hub

**Short Description:** 
Gibbous is an intelligent, desktop-based health and telemetry dashboard designed for astronauts in isolated, extreme environments. Built with Flutter, it ingests physiological and environmental data to generate dynamic visualizations and features an AI-powered Flight Surgeon ("Gibby Buddy") that provides structured, real-time medical triage. With an immersive sci-fi UI and offline-first architecture, Gibbous bridges the gap between raw telemetry and actionable medical advice for mission success.

---

Gibbous acts as a centralized hub that ingests complex physiological and environmental data, generating dynamic visualizations and providing AI-driven medical triage. 

## Key Features

*   **Gibby Buddy (AI Flight Surgeon):** Integrates with the OpenRouter API (utilizing Llama 3 models). Users can analyze uploaded mission data. The AI returns strict JSON data which is parsed into color-coded visual blocks (Normal, Caution, Emergency) outlining immediate actions and physiological rationale.
*   **Comprehensive Telemetry Dashboards:** Tracks Biometrics (ECG, HRV, SpO2, BPM), Biomarkers (Bone Density, T-Cell), Environmental (CO2, O2, Temp), Microgravity, and Radiation.
*   **Real Excel Data Ingestion:** The app is built to handle real-world data. It includes a robust parsing pipeline that supports both `.xlsx` (Excel) and `.csv` files, with built-in fallback mechanisms to handle missing columns, string-to-double conversions, and format variations without crashing.
*   **Context-Aware Visual Alarms:** A custom pop-up system that reminds astronauts to log specific metrics (e.g., Body Mass, Nutrition) at user-defined times.
*   **Offline-First Architecture:** All data is stored locally (profile.json & logs.json), ensuring the app functions 100% offline, only requiring internet for the AI analysis.
*   **Immersive UI/UX:** High-contrast, sci-fi-inspired aesthetic designed to reduce cognitive load during high-stress scenarios.

---

## Data Map

Here is the comprehensive structure of the data handled by Gibbous, including the specific units used:

**1. Main Health Data (User Logged / Excel Uploaded)**
*   **Sleep**
    *   Stages: Categorical (Deep, Light, REM, Awake)
    *   Wake Episodes: minutes (min)
    *   Ambient Noise: decibels (dB)
    *   Cabin CO2: millimeters of mercury (mmHg)
*   **Movement**
    *   Steps: count
    *   Calories Burned: kilocalories (kcal)
    *   Floor Ascent: count
    *   Intensity: Categorical (Low, Moderate, High)
    *   METs: Metabolic Equivalents (unitless)
*   **Nutrition**
    *   Calories: kilocalories (kcal)
    *   Macros (Protein, Carbs, Fat, Fiber): grams (g)
    *   Minerals (Sodium, Potassium, Calcium, Magnesium): milligrams (mg)
    *   Vitamins (A): micrograms RAE (mcg RAE)
    *   Vitamins (C, D, E): micrograms/milligrams (mcg/mg)
    *   Fluids: milliliters (mL)
*   **Menstrual Cycle**
    *   Estrogen: picograms per milliliter (pg/mL)
    *   Progesterone: nanograms per milliliter (ng/mL)
    *   Hemoglobin: grams per deciliter (g/dL)
    *   Plasma Iron: micrograms per deciliter (mcg/dL)

**2. Telemetry Data (Simulated Bluetooth / Excel Uploaded)**
*   **Biometric**
    *   ECG: Waveform (millivolts / mV)
    *   HRV (Heart Rate Variability): milliseconds (ms)
    *   SpO2: percentage (%)
    *   BPM: beats per minute (bpm)
*   **Biomarker Registry**
    *   Bone Density (Lumbar Spine, Hip): percentage of baseline (%)
    *   T-Cell Activity: percentage (%)
    *   Cortisol: micrograms per deciliter (mcg/dL)
    *   Creatine Kinase: Units per liter (U/L)
    *   Serum Calcium: milligrams per deciliter (mg/dL)
*   **Environmental**
    *   O2 & CO2 Partial Pressure: millimeters of mercury (mmHg)
    *   Cabin Temp: degrees Celsius (°C)
    *   Relative Humidity: percentage (%)
    *   Airflow Velocity: meters per second (m/s)
    *   Radiation Dose: microgray per hour (µGy/h)
*   **Microgravity**
    *   Quasi-Steady Accel: standard gravity (g)
    *   Vibratory RMS / Transient Peak: milli-gravity (mg)
    *   Dominant Frequency: Hertz (Hz)
*   **Radiation**
    *   Dose: millisieverts (mSv)

**3. System & Profile Data**
*   Profile: Name, Gender, Birthday, Mission Duration
*   Time & Date: Timezone, MET (HH:MM:SS)
*   Alarms: Selected Metrics, Alarm Time, Alarm Enabled

---

## Tech Stack

*   **Language:** Dart
*   **Framework:** Flutter (Windows Desktop & Web)
*   **Libraries:** fl_chart (visualizations), excel, archive, xml (parsing), http (API requests), file_picker, google_fonts.
*   **AI Integration:** OpenRouter API (Llama 3 models) using a JSON-structured prompt system.
*   **Data Simulation:** Python (generated realistic hourly mission data based on NASA open science data).
*   **Hardware Scaffold:** Simulated Bluetooth Low Energy (BLE) for live sensor connections.

---

## How to Run (For Judges)

We have compiled the application into a standalone Windows executable for testing purposes.

1. Go to the **"Releases"** tab on the right side of this GitHub repository.
2. Download the `Gibbous_Windows_Release.zip` file.
3. Extract the ZIP file to a folder on your computer. (Ensure the executable and the accompanying data folder are extracted together).
4. Double-click `gibbous.exe` to launch the app. 

*(Note: The AI API key is pre-configured in this build, so the AI features will function immediately).*

---

## How to Test the App

1. **Onboarding:** Launch the app. Enter a name, select your gender, set mission duration to "15" days, and set an alarm time.
2. **Upload Data:** Go to the Settings page. Use the + buttons to upload real `.xlsx` or `.csv` files. You can use the sample files provided in the `/sample_data` folder of this repository.
3. **View Dashboard:** Return to the Dashboard. You will see charts populated with the uploaded data. Use the red DAY button to toggle between different mission days.
4. **Trigger AI:** Click the "Gibby Buddy insights..." box on the left to ask the AI to analyze your data.
5. **Test Alarm:** Go to Settings -> Time & Date. Use the "SET ALARM TO +1 MINUTE" button to test the visual pop-up alarm.

---

## NASA Data Sources Used

The data structures and simulated metrics in this project were modeled after the following NASA resources:
*   [NASA Open Science Data Repository (OSDR)](https://osdr.nasa.gov/bio/)
*   [NASA Life Sciences Data Archive (LSDA)](https://lsda.jsc.nasa.gov/)
*   [SpaceX Inspiration4 Crew Data (Nature, 2024)](https://www.nature.com/articles/s41586-024-07648-x)

---

## Development Credits

This project was built for the NASA Space Apps Challenge. 

*   **Lead Developer:** Miftah
*   **Designer:** Ahnaf# 
