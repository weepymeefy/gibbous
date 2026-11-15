import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  Future<String> get _dataFolder async {
    final appData = Platform.environment['APPDATA'] ?? '';
    final dir = Directory('$appData\\gibbous');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> get _profilePath async => '${await _dataFolder}\\profile.json';
  Future<String> get _logFilePath async => '${await _dataFolder}\\logs.json';
  Future<String> _excelPath(String name) async => '${await _dataFolder}\\gibbous_$name.xlsx';

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final file = File(await _profilePath);
    if (profile['mission_start_time'] == null) {
      profile['mission_start_time'] = DateTime.now().toIso8601String();
    }
    await file.writeAsString(jsonEncode(profile));
    await _createExcelFile(profile); 
  }

  Future<Map<String, dynamic>> loadProfile() async {
    try {
      final file = File(await _profilePath);
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> loadLogs() async {
    final file = File(await _logFilePath);
    if (!await file.exists()) {
      final initialLogs = {
        'Body Mass': [],
        'Height': [],
        'Sleep': [],
        'Movement': [],
        'Nutrition': [],
        'Womens Health': [],
        'Biomarker': [], 
        'Environmental': [], 
        'Mood': [], 
        'Microgravity': [], 
        'Radiation': [], 
      };
      await file.writeAsString(jsonEncode(initialLogs));
      return initialLogs;
    }
    try {
      final data = jsonDecode(await file.readAsString());
      return Map<String, dynamic>.from(data);
    } catch (e) {
      return {};
    }
  }

  Future<void> _appendLog(String sheetName, Map<String, dynamic> row) async {
    final logs = await loadLogs();
    if (!logs.containsKey(sheetName)) {
      logs[sheetName] = [];
    }
    logs[sheetName].add(row);
    final file = File(await _logFilePath);
    await file.writeAsString(jsonEncode(logs));
  }

  Future<void> _createExcelFile(Map<String, dynamic> profile) async {
    final name = profile['name']?.toString() ?? 'user';
    final path = await _excelPath(name.toLowerCase().replaceAll(' ', '_'));
    final file = File(path);
    if (await file.exists()) return; 

    final excel = Excel.createExcel();
    excel['Personal Data'].appendRow([TextCellValue('Name'), TextCellValue(name)]);
    excel['Personal Data'].appendRow([TextCellValue('Gender'), TextCellValue(profile['gender'] ?? '')]);
    excel['Personal Data'].appendRow([TextCellValue('Birthday'), TextCellValue(profile['birthday'] ?? '')]);
    excel['Body Mass'].appendRow([TextCellValue('Mission Day'), TextCellValue('Measurement Date'), TextCellValue('Mass Method'), TextCellValue('Body Mass (kg)'), TextCellValue('Change From Baseline (kg)'), TextCellValue('Lean Mass Est (kg)'), TextCellValue('Fat Mass Est (kg)'), TextCellValue('Bone Mineral Density Delta (%)')]);
    excel['Height'].appendRow([TextCellValue('Mission Day'), TextCellValue('Standing Stature (cm)'), TextCellValue('Stature Delta (cm)'), TextCellValue('Sitting Stature (cm)'), TextCellValue('Intervertebral Disc Expansion (%)'), TextCellValue('Spinal Pain Rating (0–10)'), TextCellValue('Spacesuit Fit Clearance (mm)')]);
    excel['Womens Health'].appendRow([TextCellValue('Mission Day'), TextCellValue('Date'), TextCellValue('Tracking Status'), TextCellValue('Active Countermeasure'), TextCellValue('Estrogen Marker (pg/mL)'), TextCellValue('Progesterone Marker (ng/mL)'), TextCellValue('Symptom Log'), TextCellValue('Hemoglobin (g/dL)'), TextCellValue('Plasma Iron (mcg/dL)'), TextCellValue('Fluid Balance (ml)'), TextCellValue('Operational Impact')]);
    excel['Movement'].appendRow([TextCellValue('Mission Day'), TextCellValue('Date'), TextCellValue('Start Time (GMT)'), TextCellValue('End Time (GMT)'), TextCellValue('Steps'), TextCellValue('Calories Burned (kcal)'), TextCellValue('Floor Ascent Equiv'), TextCellValue('Activity Intensity'), TextCellValue('METs'), TextCellValue('Operational Context')]);
    excel['Sleep'].appendRow([TextCellValue('Mission Day'), TextCellValue('Date'), TextCellValue('Start Time (GMT)'), TextCellValue('End Time (GMT)'), TextCellValue('Actigraphy Movement Score'), TextCellValue('Inferred Sleep Stage'), TextCellValue('Wake Episodes (min)'), TextCellValue('Ambient Noise (dB)'), TextCellValue('Cabin CO2 (mmHg)'), TextCellValue('Notes / Observations')]);
    excel['Nutrition'].appendRow([TextCellValue('Mission Day'), TextCellValue('Date'), TextCellValue('Space Food Item'), TextCellValue('Calories (kcal)'), TextCellValue('Protein (g)'), TextCellValue('Carbs (g)'), TextCellValue('Fat (g)'), TextCellValue('Fiber (g)'), TextCellValue('Sodium (mg)'), TextCellValue('Potassium (mg)'), TextCellValue('Calcium (mg)'), TextCellValue('Magnesium (mg)'), TextCellValue('Iron (mg)'), TextCellValue('Zinc (mg)'), TextCellValue('Vit A (mcg RAE)'), TextCellValue('Vit C (mg)'), TextCellValue('Vit D (mcg)'), TextCellValue('Vit E (mg)')]);
    excel['Biometric'].appendRow([TextCellValue('Mission Day'), TextCellValue('Timestamp (GMT)'), TextCellValue('Heart Rate (bpm)'), TextCellValue('HRV (ms)'), TextCellValue('Active SpO2 (%)')]);
    excel['Biomarker'].appendRow([TextCellValue('Mission Day'), TextCellValue('Lumbar Spine (%)'), TextCellValue('Trochanter Hip (%)'), TextCellValue('T Cell Activity (%)'), TextCellValue('Serum Calcium (mg/dL)'), TextCellValue('Plasma Iron (mcg/dL)'), TextCellValue('Cortisol (mcg/dL)'), TextCellValue('Creatine Kinase (U/L)')]);
    excel['Environmental'].appendRow([TextCellValue('Mission Day'), TextCellValue('Date'), TextCellValue('Timestamp (GMT)'), TextCellValue('Module Location'), TextCellValue('O₂ Partial Pressure (mmHg)'), TextCellValue('CO₂ Partial Pressure (mmHg)'), TextCellValue('Ambient Noise (dB)'), TextCellValue('Cabin Temp (°C)'), TextCellValue('Relative Humidity (%)'), TextCellValue('Radiation Dose (µGy/h)'), TextCellValue('Airflow Velocity (m/s)')]);
    excel['Mood'].appendRow([TextCellValue('Mission Day'), TextCellValue('Mood Text')]);
    
    excel['Microgravity'].appendRow([
      TextCellValue('Mission Day'), 
      TextCellValue('Timestamp (GMT)'), 
      TextCellValue('Module Location'), 
      TextCellValue('Quasi-Steady Accel (g)'), 
      TextCellValue('Vibratory RMS (mg)'), 
      TextCellValue('Transient Peak (mg)'), 
      TextCellValue('Dominant Freq (Hz)'), 
      TextCellValue('Activity')
    ]);

    excel['Radiation'].appendRow([
      TextCellValue('Mission Day'), 
      TextCellValue('Timestamp (GMT)'), 
      TextCellValue('Module Location'), 
      TextCellValue('Dose (mSv)'), 
      TextCellValue('Activity')
    ]);

    excel.delete('Sheet1');
    final fileBytes = excel.save();
    if (fileBytes != null) { await File(path).writeAsBytes(fileBytes); }
  }

  Future<List<Map<String, dynamic>>> _readFromExcel(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];

      if (filePath.toLowerCase().endsWith('.csv') || filePath.toLowerCase().endsWith('.txt')) {
        final csvString = await file.readAsString();
        final lines = const LineSplitter().convert(csvString);
        if (lines.isEmpty) return [];

        final delimiter = lines[0].contains('\t') ? '\t' : ',';

        List<Map<String, dynamic>> rows = [];
        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          final values = lines[i].split(delimiter);
          Map<String, dynamic> rowData = {};
          for (int j = 0; j < values.length; j++) {
            final val = values[j].trim();
            final num = double.tryParse(val);
            rowData[j.toString()] = num ?? val;
          }
          rows.add(rowData);
        }
        return rows;
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      List<String> sharedStrings = [];
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedStringsFile != null) {
        final content = utf8.decode(sharedStringsFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        for (var node in doc.findAllElements('t')) { sharedStrings.add(node.innerText); }
      }

      ArchiveFile? sheetFile;
      for (var f in archive.files) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) { sheetFile = f; break; }
      }
      if (sheetFile == null) return [];

      final content = utf8.decode(sheetFile.content as List<int>);
      final doc = XmlDocument.parse(content);
      List<Map<String, dynamic>> rows = [];
      
      for (var rowNode in doc.findAllElements('row')) {
        final cells = rowNode.findElements('c').toList();
        final Map<String, dynamic> rowData = {};
        for (var cell in cells) {
          final cellRef = cell.getAttribute('r') ?? ''; 
          final colLetter = cellRef.replaceAll(RegExp(r'[0-9]'), '');
          final colIndex = _columnLetterToInt(colLetter);
          final type = cell.getAttribute('t');
          String? val;
          final vNode = cell.findElements('v').firstOrNull;
          if (vNode != null) { val = vNode.innerText; } 
          else {
            final isNode = cell.findElements('is').firstOrNull;
            if (isNode != null) { final tNode = isNode.findElements('t').firstOrNull; if (tNode != null) val = tNode.innerText; }
          }
          if (val != null) {
            if (type == 's') {
              final idx = int.tryParse(val);
              if (idx != null && idx < sharedStrings.length) { rowData[colIndex.toString()] = sharedStrings[idx]; }
            } else {
              final num = double.tryParse(val);
              if (num != null) { rowData[colIndex.toString()] = num; } else { rowData[colIndex.toString()] = val; }
            }
          }
        }
        if (rowData.isNotEmpty) rows.add(rowData);
      }
      if (rows.isNotEmpty) rows.removeAt(0); 
      return rows;
    } catch (e) { 
      debugPrint('Error parsing $filePath: $e'); 
      return []; 
    }
  }

  int _columnLetterToInt(String col) {
    int result = 0;
    for (int i = 0; i < col.length; i++) { result = result * 26 + (col.codeUnitAt(i) - 64); }
    return result - 1;
  }

  double _parseDouble(dynamic cell) {
    try { 
      if (cell == null) return 0.0; 
      if (cell is num) return cell.toDouble(); 
      return double.tryParse(cell.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0; 
    } catch (e) { return 0.0; }
  }

  String _parseString(dynamic cell) {
    try { if (cell == null) return ''; return cell.toString(); } catch (e) { return ''; }
  }

  Future<List<Map<String, dynamic>>> _readSheet(String sheetName) async {
    final profile = await loadProfile();
    final logs = await loadLogs();
    
    List<Map<String, dynamic>> combinedData = [];
    
    String? uploadedPath;
    if (sheetName == 'Body Mass') uploadedPath = profile['body_comp_source_file'];
    if (sheetName == 'Height') uploadedPath = profile['height_source_file'];
    if (sheetName == 'Sleep') uploadedPath = profile['sleep_source_file'];
    if (sheetName == 'Movement') uploadedPath = profile['movement_source_file'];
    if (sheetName == 'Nutrition') uploadedPath = profile['nutrition_source_file'];
    if (sheetName == 'Womens Health') uploadedPath = profile['menstrual_source_file'];
    if (sheetName == 'Biometric') uploadedPath = profile['biometric_source_file']; 
    if (sheetName == 'Biomarker') uploadedPath = profile['biomarker_source_file'];
    if (sheetName == 'Environmental') uploadedPath = profile['environmental_source_file']; 
    
    if (sheetName == 'Microgravity') uploadedPath = profile['microgravity_source_file'];
    if (sheetName == 'Radiation') uploadedPath = profile['radiation_source_file'];

    if (uploadedPath != null && uploadedPath.isNotEmpty) {
       combinedData.addAll(await _readFromExcel(uploadedPath));
    }
    
    if (logs.containsKey(sheetName)) {
      for (var logItem in logs[sheetName]) {
        combinedData.add(Map<String, dynamic>.from(logItem));
      }
    }
    
    combinedData.sort((a, b) {
      final aDay = double.tryParse(a['0']?.toString() ?? '0') ?? 0.0;
      final bDay = double.tryParse(b['0']?.toString() ?? '0') ?? 0.0;
      return aDay.compareTo(bDay);
    });
    
    return combinedData;
  }

  Future<List<Map<String, dynamic>>> getBodyMassData() async {
    final raw = await _readSheet('Body Mass');
    return raw.map((r) => { 'day': _parseDouble(r['0']), 'mass': _parseDouble(r['3']), 'lean': _parseDouble(r['5']), 'fat': _parseDouble(r['6']), }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getHeightData() async {
    final raw = await _readSheet('Height');
    return raw.map((r) => { 'day': _parseDouble(r['0']), 'standing': _parseDouble(r['1']), 'sitting': _parseDouble(r['3']), }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getSleepData() async {
    final raw = await _readSheet('Sleep');
    return raw.map((r) => { 'day': _parseDouble(r['0']), 'stage': _parseString(r['5']).isEmpty ? 'Awake' : _parseString(r['5']), 'wake': _parseDouble(r['6']), 'noise': _parseDouble(r['7']), }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getMovementData() async {
    final raw = await _readSheet('Movement');
    return raw.map((r) => {
      'day': _parseDouble(r['0']),
      'start': _parseString(r['2']),
      'end': _parseString(r['3']),
      'steps': _parseDouble(r['4']),
      'calories': _parseDouble(r['5']),
      'floor': _parseDouble(r['6']),
      'intensity': _parseString(r['7']),
      'mets': _parseDouble(r['8']),
      'context': _parseString(r['9']),
    }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getNutritionData() async {
    final raw = await _readSheet('Nutrition');
    return raw.map((r) => { 'day': _parseDouble(r['0']), 'calories': _parseDouble(r['3']), 'protein': _parseDouble(r['4']), 'carbs': _parseDouble(r['5']), 'fat': _parseDouble(r['6']), }).toList();
  }
  
  Future<List<Map<String, dynamic>>> getWomensHealthData() async {
    final raw = await _readSheet('Womens Health');
    return raw.map((r) => { 'day': _parseDouble(r['0']), 'status': _parseString(r['2']), 'estrogen': _parseDouble(r['4']), 'progesterone': _parseDouble(r['5']), }).toList();
  }

  Future<List<Map<String, dynamic>>> getBiometricData() async {
    final raw = await _readSheet('Biometric');
    return raw.map((r) => { 
      'day': _parseDouble(r['0']), 
      'time': _parseString(r['1']), 
      'bpm': _parseDouble(r['2']), 
      'hrv': _parseDouble(r['3']), 
      'spo2': _parseDouble(r['4']), 
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getBiomarkerData() async {
    final raw = await _readSheet('Biomarker');
    return raw.map((r) => { 
      'day': _parseDouble(r['0']), 
      'bone_lumbar': _parseDouble(r['1']), 
      'bone_hip': _parseDouble(r['2']), 
      't_cell': _parseDouble(r['3']), 
      'serum_calcium': _parseDouble(r['4']), 
      'plasma_iron': _parseDouble(r['5']), 
      'cortisol': _parseDouble(r['6']), 
      'creatine_kinase': _parseDouble(r['7']), 
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getEnvironmentalData() async {
    final raw = await _readSheet('Environmental');
    return raw.map((r) => { 
      'day': _parseDouble(r['0']), 
      'date': _parseString(r['1']), 
      'time': _parseString(r['2']), 
      'location': _parseString(r['3']), 
      'o2': _parseDouble(r['4']), 
      'co2': _parseDouble(r['5']), 
      'noise': _parseDouble(r['6']), 
      'temp': _parseDouble(r['7']), 
      'humidity': _parseDouble(r['8']), 
      'radiation': _parseDouble(r['9']), 
      'airflow': _parseDouble(r['10']), 
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMicrogravityData() async {
    final raw = await _readSheet('Microgravity');
    return raw.map((r) => { 
      'day': _parseDouble(r['0']), 
      'time': _parseString(r['1']), 
      'rms': _parseDouble(r['4']), 
      'peak': _parseDouble(r['5']), 
      'activity': _parseString(r['7']), 
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRadiationData() async {
    final raw = await _readSheet('Radiation');
    return raw.map((r) => { 
      'day': _parseDouble(r['0']), 
      'time': _parseString(r['1']), 
      'dose': _parseDouble(r['3']), 
      'activity': _parseString(r['4']), 
    }).toList();
  }

  Future<void> logMood(int day, String moodText) async {
    await _appendLog('Mood', {
      '0': day, 
      '1': moodText
    });
  }

  Future<Map<int, String>> getMoodData() async {
    final raw = await _readSheet('Mood');
    Map<int, String> moods = {};
    for (var row in raw) {
      final day = _parseDouble(row['0']).toInt();
      final mood = _parseString(row['1']);
      if (mood.isNotEmpty) {
        moods[day] = mood;
      }
    }
    return moods;
  }

  Future<void> logNutrition(int day, String foodName, double kcal, double protein, double carbs, double fat, double fiber, double sodium, double potassium, double calcium, double magnesium, double iron, double zinc, double vitA, double vitC, double vitD, double vitE) async {
    await _appendLog('Nutrition', {
      '0': day, '1': DateTime.now().toIso8601String(), '2': foodName, 
      '3': kcal, '4': protein, '5': carbs, '6': fat, '7': fiber,
      '8': sodium, '9': potassium, '10': calcium, '11': magnesium,
      '12': iron, '13': zinc, '14': vitA, '15': vitC, '16': vitD, '17': vitE
    });
  }

  Future<void> logMovement(int day, String startTime, String endTime, double steps, double calories, double floorAscent, String intensity, double mets, String context) async {
    await _appendLog('Movement', {
      '0': day, '1': DateTime.now().toIso8601String(), '2': startTime, '3': endTime,
      '4': steps, '5': calories, '6': floorAscent, '7': intensity, '8': mets, '9': context
    });
  }

  Future<void> logWomensHealth(int day, String status, String countermeasure, double estrogen, double progesterone, String symptom, double hemoglobin, double plasmaIron, String fluidBalance, String impact) async {
    await _appendLog('Womens Health', {
      '0': day, '1': DateTime.now().toIso8601String(), '2': status, '3': countermeasure,
      '4': estrogen, '5': progesterone, '6': symptom, '7': hemoglobin, '8': plasmaIron, '9': fluidBalance, '10': impact
    });
  }

  Future<void> logBodyMass(int day, String method, double mass, double change, double lean, double fat, double boneDensity) async {
    await _appendLog('Body Mass', {
      '0': day, '1': DateTime.now().toIso8601String(), '2': method,
      '3': mass, '4': change, '5': lean, '6': fat, '7': boneDensity
    });
  }

  Future<void> logHeight(int day, double standing, double delta, double sitting, double discExpansion, double painRating, double suitClearance) async {
    await _appendLog('Height', {
      '0': day, '1': standing, '2': delta, '3': sitting, '4': discExpansion, '5': painRating, '6': suitClearance
    });
  }

  Future<void> clearAllAppData() async {
    try {
      final dir = Directory(await _dataFolder);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint("All app data cleared successfully.");
      }
    } catch (e) {
      debugPrint("Error clearing data: $e");
    }
  }
}