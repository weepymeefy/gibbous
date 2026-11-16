
# Gibbous: Application Tutorial

### Step 1: Download Sample Data (For Testing)
1. Go to the Gibbous GitHub repository.
2. Navigate to the `/sample_data` folder.
3. Download all the `.csv` files (e.g., `test_body_mass.csv`, `test_biometric.csv`, etc.) to a folder on your computer.

### Step 2: Onboarding & Setup
1. Launch the application (`gibbous.exe`).
2. **Page 1:** Enter your name, select your gender, and pick your date of birth.
3. **Page 2:** Set your mission duration (e.g., 15 days).
4. **Page 3:** Select the modules/locations you will be active in (e.g., Harmony Module, Kibo).
5. **Page 4:** Select the specific metrics you want the app to remind you to log (e.g., Body Mass, Nutrition). Set your preferred alarm time.
6. **Page 5:** Click **START** to begin Day 0 of the mission.

### Step 3: Uploading Data
1. From the Dashboard, click the **Settings** icon (top left).
2. Locate the metric you want to upload data for (e.g., Sleep, Biometric, Environmental).
3. Click the **+ (Upload)** button next to the metric.
4. Select the corresponding `.csv` file from the sample data you downloaded earlier. *(The app will automatically parse the columns and save it to the local database).*
5. Once uploaded, click the **Home** icon (top right) to return to the Dashboard.

### Step 4: Viewing the Dashboard
1. The Dashboard will automatically refresh and display your uploaded data.
2. Use the **DAY** button (red, top right) to toggle between different mission days and see how your metrics change.
3. Click on **BODY COMPOSITION** or **HEIGHT** to view detailed trend lines across the mission.
4. Click on **SLEEP**, **MOVEMENT**, or **NUTRITION** to view daily breakdowns (pie charts and bar graphs).
5. Click on the **RADIATION** or **MICROGRAVITY** boxes to view environmental exposure trends.

### Step 5: Using the AI Flight Surgeon (Gibby Buddy)
1. Look at the large box on the left side of the Dashboard labeled **"Gibby Buddy insights..."**.
2. Click the box to open the AI prompt dialog.
3. Type a question or click **ASK** to analyze your uploaded data (e.g., *"Compare my sleep and movement."*).
4. The AI will return a structured assessment:
   * **Urgency Level:** Normal (Green), Caution (Yellow), or Emergency (Red).
   * **Assessment:** A brief medical diagnosis.
   * **Actions:** A checklist of immediate steps to take.
   * **Why It Matters:** The physiological rationale.
5. Click **ACCEPT** to pin the AI's assessment to your Dashboard.

### Step 6: Testing the Alarm System
1. Go to **Settings** > **Time & Date**.
2. Toggle **PLAY ALARM AT CHOSEN TIME** to ON.
3. Click the blue **"SET ALARM TO +1 MINUTE (TEST)"** button.
4. Click **SAVE**.
5. Return to the Dashboard and wait 1 minute.
6. A visual "MISSION REMINDER" pop-up will appear, listing the specific metrics you selected during onboarding.

### Step 7: Deep-Dive Telemetry Pages
Click on the telemetry links from the Dashboard to access specialized views:
*   **Biometric Telemetry:** View ECG waveforms, HRV, BPM, and SpO2 levels.
*   **Biomarker Registry:** Track bone density, T-cell activity, and stress hormones.
*   **Environmental Telemetry:** Monitor cabin CO2, O2, temperature, and noise.
*   **Behavioral Data:** Log your daily mood and analyze psychological trends.
