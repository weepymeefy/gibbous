import 'dart:async';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/profile_service.dart';
import '../services/ai_service.dart'; 
import 'settings.dart';
import 'biometric_telemetry.dart'; 
import 'biomarker_registry.dart';
import 'environmental_telemetry.dart';
import 'behavioral_data.dart'; 

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  final _profileService = ProfileService();
  final _aiService = AIService(); 
  
  String _gender = 'Female';
  int _missionDuration = 10;
  int _currentDay = 0;
  bool _isDayManuallySelected = false;

  String _activePanel = ''; 
  
  int _waterMl = 0;
  String _waterType = 'Standard (250ml)';

  MedicalAssessment? _aiAssessment; 
  String _moodText = 'TODAY IM\nFEELING...';

  List<Map<String, dynamic>> _bodyMassData = [];
  List<Map<String, dynamic>> _heightData = [];
  List<Map<String, dynamic>> _sleepData = [];
  List<Map<String, dynamic>> _movementData = [];
  List<Map<String, dynamic>> _nutritionData = [];
  List<Map<String, dynamic>> _menstrualData = [];
  
  List<Map<String, dynamic>> _microgravityData = [];
  List<Map<String, dynamic>> _radiationData = [];

  Timer? _metTimer;
  Timer? _clockTimer;
  Timer? _refreshTimer; 
  String _metText = '00:00:00';
  String _timezone = 'UTC'; 
  String _currentTime = '00:00:00'; 
  DateTime _missionStartTime = DateTime.now();

  bool _alarmEnabled = false;
  int _alarmHour = 8;
  int _alarmMinute = 0;
  List<String> _alarmMetrics = [];
  String _lastAlarmTriggeredTime = ''; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _loadProfileAndStartMET();
    _loadAllData();
    _startClock();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadAllData();
      _loadAlarmSettings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllData(); 
      _loadAlarmSettings();
    }
  }

  Future<void> _loadProfileAndStartMET() async {
    final profile = await _profileService.loadProfile();
    if (profile.isNotEmpty) {
      setState(() {
        _gender = profile['gender'] ?? 'Female';
        _missionDuration = int.tryParse(profile['mission_duration'].toString()) ?? 10;
        _timezone = profile['timezone'] ?? 'UTC'; 
        final startStr = profile['mission_start_time'];
        if (startStr != null) _missionStartTime = DateTime.parse(startStr.toString());
      });
    }
    _loadAlarmSettings();
    _startMETClock();
  }

  Future<void> _loadAlarmSettings() async {
    final profile = await _profileService.loadProfile();
    if (profile.isNotEmpty && mounted) {
      setState(() {
        _alarmEnabled = profile['alarm_enabled'] ?? false;
        _alarmHour = int.tryParse(profile['alarm_hour']?.toString() ?? '8') ?? 8;
        _alarmMinute = int.tryParse(profile['alarm_minute']?.toString() ?? '0') ?? 0;
        _alarmMetrics = List<String>.from(profile['alarms'] ?? []);
      });
    }
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now(); 
      
      setState(() {
        _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });

      String currentMinuteStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      String alarmMinuteStr = '${_alarmHour.toString().padLeft(2, '0')}:${_alarmMinute.toString().padLeft(2, '0')}';

      if (_alarmEnabled && currentMinuteStr == alarmMinuteStr && _lastAlarmTriggeredTime != currentMinuteStr) {
        _lastAlarmTriggeredTime = currentMinuteStr;
        debugPrint("🚨 ALARM TRIGGERED at $currentMinuteStr! Metrics: $_alarmMetrics");
        _showVisualAlarm();
      }
    });
  }

  void _showVisualAlarm() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFFF2E5C4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE57373), width: 6),
              boxShadow: [
                BoxShadow(color: const Color(0xFFE57373).withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 15)
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alarm, size: 90, color: Color(0xFFD4A843)),
                const SizedBox(height: 20),
                Text(
                  'MISSION REMINDER', 
                  style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF2A1500), letterSpacing: 2)
                ),
                const SizedBox(height: 10),
                Text(
                  'It is time to log your data for Day $_currentDay.', 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("REQUIRED MEASUREMENTS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: Colors.black54)),
                      const SizedBox(height: 10),
                      // ✅ FIXED: Wrapped ternary in a list and used spread operator
                      ...(_alarmMetrics.isEmpty 
                        ? [Text("• General Check-in", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87))]
                        : _alarmMetrics.map((metric) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                const SizedBox(width: 10),
                                Expanded(child: Text(metric, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87))),
                              ],
                            ),
                          )).toList()),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A843),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: Text('ACKNOWLEDGE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAllData() async {
    final bodyMass = await _profileService.getBodyMassData();
    final height = await _profileService.getHeightData();
    final sleep = await _profileService.getSleepData();
    final movement = await _profileService.getMovementData();
    final nutrition = await _profileService.getNutritionData();
    final menstrual = await _profileService.getWomensHealthData();
    final microgravity = await _profileService.getMicrogravityData(); 
    final radiation = await _profileService.getRadiationData(); 

    if (mounted) {
      setState(() {
        _bodyMassData = bodyMass;
        _heightData = height;
        _sleepData = sleep;
        _movementData = movement;
        _nutritionData = nutrition;
        _menstrualData = menstrual;
        _microgravityData = microgravity;
        _radiationData = radiation;
      });
    }
  }

  void _startMETClock() {
    _metTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final diff = DateTime.now().difference(_missionStartTime);
        final hours = diff.inHours.toString().padLeft(2, '0');
        final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
        _metText = '$hours:$mins:$secs';
        
        if (!_isDayManuallySelected && diff.inDays <= _missionDuration) {
           _currentDay = diff.inDays;
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metTimer?.cancel();
    _clockTimer?.cancel(); 
    _refreshTimer?.cancel(); 
    super.dispose();
  }

  List<Map<String, dynamic>> _filterByCurrentDay(List<Map<String, dynamic>> data) {
    return data.where((item) => (item['day'] as num?)?.toInt() == _currentDay).toList();
  }

  double _parseHour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0.0;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return (double.tryParse(parts[0]) ?? 0.0) + ((double.tryParse(parts[1]) ?? 0.0) / 60);
    }
    return 0.0;
  }

  void _showDaySelector() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF2E5C4),
          title: Text('Select Mission Day', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400, height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _missionDuration + 1,
              itemBuilder: (context, index) {
                final isCurrent = index == _currentDay;
                return GestureDetector(
                  onTap: () { 
                    setState(() {
                      _currentDay = index; 
                      _isDayManuallySelected = true;
                    }); 
                    Navigator.pop(context); 
                  },
                  child: Container(
                    decoration: BoxDecoration(color: isCurrent ? const Color(0xFFD4A843) : Colors.black12, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('D$index', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : Colors.black))),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showMoodDialog() {
    final moodCtrl = TextEditingController(text: _moodText == 'TODAY IN\nFEELING' ? '' : _moodText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2E5C4),
        title: Text('How are you feeling today?', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(controller: moodCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Enter keywords...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
          TextButton(
            onPressed: () async {
              final text = moodCtrl.text.toUpperCase();
              setState(() => _moodText = text); 
              await _profileService.logMood(_currentDay, text); 
              if (!mounted) return;
              Navigator.pop(context); 
            },
            child: Text('SAVE', style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAIDialog() {
    final promptCtrl = TextEditingController();
    MedicalAssessment? dialogAssessment;
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E5C4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Ask Gibby Buddy', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                height: 400, 
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogAssessment == null && !dialogLoading) ...[
                        TextField(
                          controller: promptCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'E.g., Compare my sleep and movement...', border: OutlineInputBorder()),
                        ),
                      ] else if (dialogAssessment != null) ...[
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: dialogAssessment!.urgencyLevel == 'Emergency' ? Colors.red.shade100
                                 : dialogAssessment!.urgencyLevel == 'Caution' ? Colors.orange.shade100
                                 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8), 
                            border: Border.all(color: Colors.black12)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dialogAssessment!.urgencyLevel.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              const SizedBox(height: 10),
                              Text(dialogAssessment!.assessment, style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 15),
                              Text("ACTIONS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black87)),
                              ...dialogAssessment!.immediateActions.map((a) => Text("• $a", style: GoogleFonts.montserrat(fontSize: 13))),
                              const SizedBox(height: 15),
                              Text("WHY IT MATTERS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text(dialogAssessment!.whyItMatters, style: GoogleFonts.montserrat(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      if (dialogLoading) ...[
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(color: Color(0xFFD4A843)),
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
                if (dialogAssessment == null && !dialogLoading)
                  TextButton(
                    onPressed: () async {
                      if (promptCtrl.text.isEmpty) return;
                      setDialogState(() => dialogLoading = true);
                      
                      String contextData = "Astronaut Mission Day: $_currentDay. Gender: $_gender.\n";
                      contextData += "Today's Mood: $_moodText\n";
                      
                      final currentBodyMass = _filterByCurrentDay(_bodyMassData);
                      final currentSleep = _filterByCurrentDay(_sleepData);
                      final currentMovement = _filterByCurrentDay(_movementData);

                      if (currentBodyMass.isNotEmpty) {
                        contextData += "Latest Body Mass: ${currentBodyMass.last['mass']} kg\n";
                      }
                      if (currentSleep.isNotEmpty) {
                        contextData += "Recent Sleep Stages: ${currentSleep.take(5).map((e) => e['stage']).join(', ')}\n";
                      }
                      if (currentMovement.isNotEmpty) {
                        double steps = currentMovement.fold(0.0, (sum, item) => sum + ((item['steps'] as num?)?.toDouble() ?? 0.0));
                        contextData += "Total Recorded Steps: ${steps.toInt()}\n";
                      }

                      try {
                        final response = await _aiService.analyzeData(contextData, promptCtrl.text);
                        if (mounted) {
                          setDialogState(() {
                            dialogAssessment = response;
                            dialogLoading = false;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() {
                            dialogAssessment = MedicalAssessment(assessment: "Error: $e", urgencyLevel: "Caution", immediateActions: [], whyItMatters: "");
                            dialogLoading = false;
                          });
                        }
                      }
                    },
                    child: Text('ASK', style: GoogleFonts.montserrat(color: const Color(0xFFD4A843), fontWeight: FontWeight.bold)),
                  ),
                if (dialogAssessment != null && !dialogLoading) ...[
                  TextButton(
                    onPressed: () {
                      setState(() => _aiAssessment = dialogAssessment);
                      Navigator.pop(context);
                    },
                    child: Text('ACCEPT', style: GoogleFonts.montserrat(color: const Color(0xFFD4A843), fontWeight: FontWeight.bold)),
                  ),
                ]
              ],
            );
          }
        );
      },
    );
  }

  void _showLogBodyCompDialog() {
    final methodCtrl = TextEditingController();
    final massCtrl = TextEditingController();
    final changeCtrl = TextEditingController();
    final leanCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final boneCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2E5C4),
        title: Text('Log Body Composition', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(methodCtrl, 'Mass Method (e.g. SLAMM)'),
                _buildTextField(massCtrl, 'Body Mass (kg)'),
                _buildTextField(changeCtrl, 'Change From Baseline (kg)'),
                _buildTextField(leanCtrl, 'Lean Mass (kg)'),
                _buildTextField(fatCtrl, 'Fat Mass (kg)'),
                _buildTextField(boneCtrl, 'Bone Density Delta (%)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
          TextButton(
            onPressed: () async {
              await _profileService.logBodyMass(_currentDay, methodCtrl.text, 
                double.tryParse(massCtrl.text) ?? 0, double.tryParse(changeCtrl.text) ?? 0, 
                double.tryParse(leanCtrl.text) ?? 0, double.tryParse(fatCtrl.text) ?? 0, double.tryParse(boneCtrl.text) ?? 0);
              if (!mounted) return;
              Navigator.pop(context);
              _loadAllData();
            },
            child: Text('SAVE', style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogHeightDialog() {
    final standingCtrl = TextEditingController();
    final deltaCtrl = TextEditingController();
    final sittingCtrl = TextEditingController();
    final discCtrl = TextEditingController();
    final painCtrl = TextEditingController();
    final suitCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2E5C4),
        title: Text('Log Height', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(standingCtrl, 'Standing Stature (cm)'),
                _buildTextField(deltaCtrl, 'Stature Delta (cm)'),
                _buildTextField(sittingCtrl, 'Sitting Stature (cm)'),
                _buildTextField(discCtrl, 'Intervertebral Disc Expansion (%)'),
                _buildTextField(painCtrl, 'Spinal Pain Rating (0-10)'),
                _buildTextField(suitCtrl, 'Spacesuit Fit Clearance (mm)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
          TextButton(
            onPressed: () async {
              await _profileService.logHeight(_currentDay, 
                double.tryParse(standingCtrl.text) ?? 0, double.tryParse(deltaCtrl.text) ?? 0, 
                double.tryParse(sittingCtrl.text) ?? 0, double.tryParse(discCtrl.text) ?? 0, 
                double.tryParse(painCtrl.text) ?? 0, double.tryParse(suitCtrl.text) ?? 0);
              if (!mounted) return;
              Navigator.pop(context);
              _loadAllData();
            },
            child: Text('SAVE', style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogMovementDialog() {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);
    
    final stepsCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final intensityCtrl = TextEditingController();
    final metsCtrl = TextEditingController();
    final contextCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E5C4),
              title: Text('Log Movement', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Start Time:', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: startTime);
                              if (picked != null) setDialogState(() => startTime = picked);
                            },
                            child: Text(startTime.format(context), style: GoogleFonts.montserrat(color: Colors.blue)),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('End Time:', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: endTime);
                              if (picked != null) setDialogState(() => endTime = picked);
                            },
                            child: Text(endTime.format(context), style: GoogleFonts.montserrat(color: Colors.blue)),
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildTextField(stepsCtrl, 'Steps'),
                      _buildTextField(calCtrl, 'Calories Burned (kcal)'),
                      _buildTextField(floorCtrl, 'Floor Ascent Equiv'),
                      _buildTextField(intensityCtrl, 'Activity Intensity'),
                      _buildTextField(metsCtrl, 'METs'),
                      _buildTextField(contextCtrl, 'Operational Context'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
                TextButton(
                  onPressed: () async {
                    await _profileService.logMovement(_currentDay, startTime.format(context), endTime.format(context), 
                      double.tryParse(stepsCtrl.text) ?? 0, double.tryParse(calCtrl.text) ?? 0, 
                      double.tryParse(floorCtrl.text) ?? 0, intensityCtrl.text, double.tryParse(metsCtrl.text) ?? 0, contextCtrl.text);
                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadAllData();
                  },
                  child: Text('SAVE', style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showLogNutritionDialog() {
    final foodCtrl = TextEditingController();
    final kcalCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final fiberCtrl = TextEditingController();
    final sodiumCtrl = TextEditingController();
    final potassiumCtrl = TextEditingController();
    final calciumCtrl = TextEditingController();
    final magnesiumCtrl = TextEditingController();
    final ironCtrl = TextEditingController();
    final zincCtrl = TextEditingController();
    final vitACtrl = TextEditingController();
    final vitCCtrl = TextEditingController();
    final vitDCtrl = TextEditingController();
    final vitECtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2E5C4),
        title: Text('Log Nutrition', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(foodCtrl, 'Space Food Item'),
                _buildTextField(kcalCtrl, 'Calories (kcal)'),
                Row(
                  children: [
                    Expanded(child: _buildTextField(proteinCtrl, 'Protein (g)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(carbsCtrl, 'Carbs (g)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(fatCtrl, 'Fat (g)')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(fiberCtrl, 'Fiber (g)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(sodiumCtrl, 'Sodium (mg)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(potassiumCtrl, 'Potassium (mg)')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(calciumCtrl, 'Calcium (mg)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(magnesiumCtrl, 'Magnesium (mg)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(ironCtrl, 'Iron (mg)')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(zincCtrl, 'Zinc (mg)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(vitACtrl, 'Vit A (mcg)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(vitCCtrl, 'Vit C (mg)')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(vitDCtrl, 'Vit D (mcg)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(vitECtrl, 'Vit E (mg)')),
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox()), 
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
          TextButton(
            onPressed: () async {
              await _profileService.logNutrition(_currentDay, foodCtrl.text, 
                double.tryParse(kcalCtrl.text) ?? 0, double.tryParse(proteinCtrl.text) ?? 0, 
                double.tryParse(carbsCtrl.text) ?? 0, double.tryParse(fatCtrl.text) ?? 0, 
                double.tryParse(fiberCtrl.text) ?? 0, double.tryParse(sodiumCtrl.text) ?? 0, 
                double.tryParse(potassiumCtrl.text) ?? 0, double.tryParse(calciumCtrl.text) ?? 0, 
                double.tryParse(magnesiumCtrl.text) ?? 0, double.tryParse(ironCtrl.text) ?? 0, 
                double.tryParse(zincCtrl.text) ?? 0, double.tryParse(vitACtrl.text) ?? 0, 
                double.tryParse(vitCCtrl.text) ?? 0, double.tryParse(vitDCtrl.text) ?? 0, double.tryParse(vitECtrl.text) ?? 0);
              if (!mounted) return;
              Navigator.pop(context);
              _loadAllData();
            },
            child: Text('SAVE', style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogWomensHealthDialog() {
    String selectedStatus = 'Suppressed'; 
    final counterCtrl = TextEditingController();
    final estrogenCtrl = TextEditingController();
    final progestCtrl = TextEditingController();
    final symptomCtrl = TextEditingController();
    final hemoCtrl = TextEditingController();
    final plasmaCtrl = TextEditingController();
    final fluidCtrl = TextEditingController();
    final impactCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E5C4),
              title: Text('Log Womens Health', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedStatus,
                            items: ['Suppressed', 'Active'].map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text('Tracking Status: $value', style: GoogleFonts.montserrat(fontSize: 14)));
                            }).toList(),
                            onChanged: (newValue) { if (newValue != null) setDialogState(() => selectedStatus = newValue); },
                          ),
                        ),
                      ),
                      _buildTextField(counterCtrl, 'Active Countermeasure'),
                      _buildTextField(estrogenCtrl, 'Estrogen (pg/mL)'),
                      _buildTextField(progestCtrl, 'Progesterone (ng/mL)'),
                      _buildTextField(symptomCtrl, 'Symptom Log'),
                      _buildTextField(hemoCtrl, 'Hemoglobin (g/dL)'),
                      _buildTextField(plasmaCtrl, 'Plasma Iron (mcg/dL)'),
                      _buildTextField(fluidCtrl, 'Fluid Balance (ml)'),
                      _buildTextField(impactCtrl, 'Operational Impact'),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54))),
                TextButton(
                  onPressed: () async {
                    await _profileService.logWomensHealth(
                      _currentDay, selectedStatus, counterCtrl.text, 
                      double.tryParse(estrogenCtrl.text) ?? 0, double.tryParse(progestCtrl.text) ?? 0, 
                      symptomCtrl.text, double.tryParse(hemoCtrl.text) ?? 0, double.tryParse(plasmaCtrl.text) ?? 0, 
                      fluidCtrl.text, impactCtrl.text
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadAllData();
                  },
                  child: Text('SAVE', style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.montserrat(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, filled: true, fillColor: Colors.white70,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 1400, height: 860,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/dashboard background.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: const Color(0xFF4A4234))),

              Positioned(
                left: 40, top: 40,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD4A843), width: 3)),
                      child: Text(_metText, style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFD4A843), letterSpacing: 2)),
                    ),
                    const SizedBox(width: 20),
                    IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.settings, color: Color(0xFFD4A843), size: 45)),
                  ],
                ),
              ),

              Positioned(
                top: 50, left: 0, right: 0,
                child: Center(child: Text('dashboard', style: GoogleFonts.montserrat(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white))),
              ),

              Positioned(
                right: 40, top: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_timezone TIME', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD4A843), letterSpacing: 1.5)),
                    Text(_currentTime, style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                  ],
                ),
              ),

              Positioned(
                left: 40, top: 180,
                child: SizedBox(
                  width: 250,
                  child: Column(
                    children: [
                      GestureDetector(onTap: () => setState(() => _activePanel = 'body_comp'), child: _buildGreyButton('BODY COMPOSITION')),
                      const SizedBox(height: 15),
                      GestureDetector(onTap: () => setState(() => _activePanel = 'height'), child: _buildGreyButton('HEIGHT')),
                      const SizedBox(height: 25),
                      GestureDetector(
                        onTap: _showAIDialog,
                        child: Container(
                          height: 250, width: double.infinity, 
                          decoration: BoxDecoration(
                            color: _aiAssessment == null 
                                ? const Color(0xFFF2E5C4).withValues(alpha: 0.85)
                                : _aiAssessment!.urgencyLevel == 'Emergency' ? Colors.red.withValues(alpha: 0.85)
                                : _aiAssessment!.urgencyLevel == 'Caution' ? Colors.orange.withValues(alpha: 0.85)
                                : Colors.green.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(15),
                              child: Center(
                                child: _aiAssessment == null 
                                  ? Text('Gibby Buddy insights...', textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14, height: 1.5))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(_aiAssessment!.urgencyLevel.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                        const SizedBox(height: 10),
                                        Text(_aiAssessment!.assessment, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                      ],
                                    )
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 320, right: 350, top: 140, bottom: 40,
                child: _activePanel.isEmpty ? _buildNormalGrid() : _buildNestedView(),
              ),

              Positioned(
                right: 40, top: 140,
                child: SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _showDaySelector,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          decoration: BoxDecoration(color: const Color(0xFFE57373), borderRadius: BorderRadius.circular(30)),
                          child: Text('DAY _${_currentDay}_', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      GestureDetector(
                        onTap: _showMoodDialog,
                        child: Container(
                          height: 160, width: 160,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDD835)),
                          child: Center(child: Text(_moodText, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 14))),
                        ),
                      ),
                      const SizedBox(height: 40),
                      GestureDetector(onTap: () => setState(() => _activePanel = 'radiation'), child: _buildRedBox('RADIATION')),
                      const SizedBox(height: 15),
                      GestureDetector(onTap: () => setState(() => _activePanel = 'microgravity'), child: _buildRedBox('MICROGRAVITY')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalGrid() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildGridButton('SLEEP', 'sleep'), const SizedBox(width: 20), _buildGridButton('MOVEMENT', 'movement'),
        ]),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildGridButton('NUTRITION', 'nutrition'), const SizedBox(width: 20), 
          _buildGridButton('MENSTRUAL CYCLE', 'menstrual', disabled: _gender != 'Female'),
        ]),
        const SizedBox(height: 30),
        _buildTelemetryLink('BIOMETRIC TELEMETRY', '/biometric'),
        const SizedBox(height: 12),
        _buildTelemetryLink('BIOMARKER REGISTRY', '/biomarker'),
        const SizedBox(height: 12),
        _buildTelemetryLink('ENVIRONMENTAL TELEMETRY', '/environmental'),
        const SizedBox(height: 12),
        _buildTelemetryLink('BEHAVIORAL DATA', '/behavioral'),
      ],
    );
  }

  Widget _buildNestedView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E5C4).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_activePanel.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _activePanel = '')),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _activePanel == 'body_comp' ? _buildBodyCompContent()
                 : _activePanel == 'height' ? _buildHeightContent()
                 : _activePanel == 'sleep' ? _buildSleepContent()
                 : _activePanel == 'movement' ? _buildMovementContent()
                 : _activePanel == 'nutrition' ? _buildNutritionContent()
                 : _activePanel == 'radiation' ? _buildRadiationContent()
                 : _activePanel == 'microgravity' ? _buildMicrogravityContent()
                 : _buildMenstrualContent(),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _spots(List<Map<String, dynamic>> data, String xKey, String yKey) {
    if (data.isEmpty) return [const FlSpot(0, 0)];
    return data.map((item) {
      final x = (item[xKey] as num?)?.toDouble() ?? 0.0;
      final y = (item[yKey] as num?)?.toDouble() ?? 0.0;
      return FlSpot(x, y);
    }).toList();
  }

  Widget _buildBodyCompContent() {
    final chartData = _bodyMassData; 

    final double? baselineMass = chartData.isNotEmpty 
        ? (chartData.first['mass'] as num?)?.toDouble() 
        : null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(20)),
              child: Text(
                'BASELINE MASS: ${baselineMass != null ? '${baselineMass.toStringAsFixed(1)} KG' : 'N/A'}', 
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showLogBodyCompDialog,
              icon: const Icon(Icons.add), label: const Text('LOG BODY COMP'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A843), foregroundColor: Colors.black),
            )
          ],
        ),
        const SizedBox(height: 15),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.blue, 'Mass'),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.orange, 'Lean Mass'),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.green, 'Fat Mass'),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: chartData.isEmpty 
            ? Center(child: Text('No Data', style: GoogleFonts.montserrat()))
            : Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
                child: LineChart(
                  key: ValueKey('body_${chartData.length}'),
                  LineChartData(
                    minY: 0, maxY: 100, 
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)), 
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 10, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(spots: _spots(chartData, 'day', 'mass'), isCurved: false, color: Colors.blue, barWidth: 2, dotData: const FlDotData(show: true)),
                      LineChartBarData(spots: _spots(chartData, 'day', 'lean'), isCurved: false, color: Colors.orange, barWidth: 2, dotData: const FlDotData(show: true)),
                      LineChartBarData(spots: _spots(chartData, 'day', 'fat'), isCurved: false, color: Colors.green, barWidth: 2, dotData: const FlDotData(show: true)),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeightContent() {
    final chartData = _heightData; 

    final double? baselineHeight = chartData.isNotEmpty 
        ? (chartData.first['standing'] as num?)?.toDouble() 
        : null;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(20)),
              child: Text(
                'BASELINE HEIGHT: ${baselineHeight != null ? '${baselineHeight.toStringAsFixed(1)} CM' : 'N/A'}', 
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showLogHeightDialog,
              icon: const Icon(Icons.add), label: const Text('LOG HEIGHT'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A843), foregroundColor: Colors.black),
            )
          ],
        ),
        const SizedBox(height: 15),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.blue, 'Standing'),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.orange, 'Sitting'),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: chartData.isEmpty 
            ? Center(child: Text('No Data', style: GoogleFonts.montserrat()))
            : Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
                child: LineChart(
                  key: ValueKey('height_${chartData.length}'),
                  LineChartData(
                    minY: 80, maxY: 200, 
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20), 
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)), 
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 10, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)))),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(spots: _spots(chartData, 'day', 'standing'), isCurved: false, color: Colors.blue, barWidth: 2, dotData: const FlDotData(show: true)),
                      LineChartBarData(spots: _spots(chartData, 'day', 'sitting'), isCurved: false, color: Colors.orange, barWidth: 2, dotData: const FlDotData(show: true)),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSleepContent() {
    final filteredData = _filterByCurrentDay(_sleepData); 

    int awakeCount = 0;
    int remCount = 0;
    int lightCount = 0;
    int deepCount = 0;

    for (var row in filteredData) {
      final stage = row['stage']?.toString().toLowerCase() ?? '';
      if (stage.contains('awake')) {
        awakeCount++;
      } else if (stage.contains('rem')) {
        remCount++;
      } else if (stage.contains('light')) {
        lightCount++;
      } else if (stage.contains('deep')) {
        deepCount++;
      }
    }

    final total = awakeCount + remCount + lightCount + deepCount;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sleep Architecture (Day $_currentDay)', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: total == 0 
            ? Center(child: Text('No Data for Day $_currentDay', style: GoogleFonts.montserrat()))
            : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      key: ValueKey('sleep_${filteredData.length}'),
                      PieChartData(
                        sectionsSpace: 2, centerSpaceRadius: 60,
                        sections: [
                          PieChartSectionData(value: deepCount.toDouble(), color: Colors.indigo, title: '${((deepCount/total)*100).toInt()}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          PieChartSectionData(value: lightCount.toDouble(), color: Colors.blueAccent, title: '${((lightCount/total)*100).toInt()}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          PieChartSectionData(value: remCount.toDouble(), color: Colors.purpleAccent, title: '${((remCount/total)*100).toInt()}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          PieChartSectionData(value: awakeCount.toDouble(), color: Colors.redAccent, title: '${((awakeCount/total)*100).toInt()}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(Colors.indigo, 'Deep Sleep'),
                        const SizedBox(height: 10),
                        _buildLegendItem(Colors.blueAccent, 'Light Sleep'),
                        const SizedBox(height: 10),
                        _buildLegendItem(Colors.purpleAccent, 'REM Sleep'),
                        const SizedBox(height: 10),
                        _buildLegendItem(Colors.redAccent, 'Awake'),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildMovementContent() {
    final filteredData = _filterByCurrentDay(_movementData); 

    double totalSteps = filteredData.fold(0.0, (sum, item) => sum + ((item['steps'] as num?)?.toDouble() ?? 0.0));
    double totalCalories = totalSteps * 0.04;

    filteredData.sort((a, b) => _parseHour(a['start']).compareTo(_parseHour(b['start'])));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Movement (Day $_currentDay)', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              onPressed: _showLogMovementDialog,
              icon: const Icon(Icons.add), label: const Text('LOG ACTIVITY'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A843), foregroundColor: Colors.black),
            )
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child: filteredData.isEmpty 
            ? Center(child: Text('No Data for Day $_currentDay', style: GoogleFonts.montserrat()))
            : Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
                child: LineChart(
                  key: ValueKey('move_${filteredData.length}'),
                  LineChartData(
                    minX: 0, maxX: 24, 
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(show: true, drawVerticalLine: true, verticalInterval: 4),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => Colors.black87,
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final item = filteredData[barSpot.spotIndex];
                            return LineTooltipItem(
                              'Time: ${item['start']}\n'
                              'Steps: ${item['steps']}\n'
                              'Calories: ${((item['steps'] as num) * 0.04).toStringAsFixed(0)} kcal\n'
                              'Intensity: ${item['intensity']}\n'
                              'METs: ${item['mets']}',
                              GoogleFonts.montserrat(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.left,
                            );
                          }).toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 4,
                          getTitlesWidget: (value, meta) => Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: filteredData.map((e) {
                          return FlSpot(_parseHour(e['start']), (e['steps'] as num?)?.toDouble() ?? 0.0);
                        }).toList(), 
                        isCurved: true, 
                        color: Colors.blue, 
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMiniStatBox('${totalSteps.toInt()} STEPS\nCUMULATED'),
            _buildMiniStatBox('${totalCalories.toInt()} KCAL\nBURNT'),
          ],
        )
      ],
    );
  }
  
  Widget _buildNutritionContent() {
    final filteredData = _filterByCurrentDay(_nutritionData); 

    double totalCarbs = filteredData.fold<double>(0.0, (sum, item) => sum + ((item['carbs'] as num?)?.toDouble() ?? 0.0));
    double totalProtein = filteredData.fold<double>(0.0, (sum, item) => sum + ((item['protein'] as num?)?.toDouble() ?? 0.0));
    double totalFat = filteredData.fold<double>(0.0, (sum, item) => sum + ((item['fat'] as num?)?.toDouble() ?? 0.0));
    
    double totalCals = filteredData.fold<double>(0.0, (sum, item) => sum + ((item['calories'] as num?)?.toDouble() ?? 0.0));
    double burnedCals = 250; 
    double leftCals = totalCals > burnedCals ? totalCals - burnedCals : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blueAccent),
                const SizedBox(width: 5),
                Text('$_waterMl mL', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _waterType,
                      items: ['Standard (250ml)', 'Suit Drink (950ml)'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value, style: GoogleFonts.montserrat(fontSize: 12)));
                      }).toList(),
                      onChanged: (newValue) => setState(() => _waterType = newValue!),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () { setState(() { _waterMl += _waterType == 'Standard (250ml)' ? 250 : 950; }); },
                ),
                const SizedBox(width: 10),
                Text('Fluids', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showLogNutritionDialog,
              icon: const Icon(Icons.add), label: const Text('LOG MEALS'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A843), foregroundColor: Colors.black),
            )
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child: filteredData.isEmpty 
            ? Center(child: Text('No Data for Day $_currentDay', style: GoogleFonts.montserrat()))
            : Row(
                key: ValueKey('nut_${filteredData.length}'),
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2, centerSpaceRadius: 0,
                              sections: [
                                PieChartSectionData(value: totalCarbs, color: Colors.blue, title: 'Carbs\n${totalCarbs.toInt()}', radius: 80, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
                                PieChartSectionData(value: totalProtein, color: Colors.purple, title: 'Protein\n${totalProtein.toInt()}', radius: 80, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
                                PieChartSectionData(value: totalFat, color: Colors.orange, title: 'Fat\n${totalFat.toInt()}', radius: 80, titleStyle: const TextStyle(fontSize: 12, color: Colors.black)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(Colors.blue, 'Carbs'),
                            const SizedBox(width: 10),
                            _buildLegendItem(Colors.purple, 'Protein'),
                            const SizedBox(width: 10),
                            _buildLegendItem(Colors.orange, 'Fat'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 150,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2, centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(value: totalCals, color: Colors.pinkAccent, title: '', radius: 40),
                                PieChartSectionData(value: burnedCals, color: Colors.purpleAccent, title: '', radius: 40),
                                PieChartSectionData(value: leftCals, color: Colors.grey.shade300, title: '', radius: 40),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(Colors.pinkAccent, 'Intake'),
                            const SizedBox(width: 5),
                            _buildLegendItem(Colors.purpleAccent, 'Burnt'),
                            const SizedBox(width: 5),
                            _buildLegendItem(Colors.grey.shade300, 'Left'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildMenstrualContent() {
    final chartData = _menstrualData; 

    String status = chartData.isNotEmpty ? (chartData.last['status']?.toString().toUpperCase() ?? 'UNKNOWN') : 'UNKNOWN';
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(20)),
              child: Text('TRACKING STATUS: $status', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ElevatedButton.icon(
              onPressed: _showLogWomensHealthDialog,
              icon: const Icon(Icons.add), label: const Text('LOG STATUS'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A843), foregroundColor: Colors.black),
            )
          ],
        ),
        const SizedBox(height: 15),
        Text('Monthly Hormone Chart', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Expanded(
          child: chartData.isEmpty 
            ? Center(child: Text('No Data', style: GoogleFonts.montserrat()))
            : Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
                child: LineChart(
                  key: ValueKey('menstrual_${chartData.length}'),
                  LineChartData(
                    minX: 0, maxX: _missionDuration.toDouble(), minY: 0, maxY: 200, 
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(show: true, drawVerticalLine: true, horizontalInterval: 50), 
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)), 
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, interval: 4, 
                          getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(spots: _spots(chartData, 'day', 'estrogen'), isCurved: true, color: Colors.cyan, barWidth: 3, dotData: const FlDotData(show: true)),
                      LineChartBarData(spots: _spots(chartData, 'day', 'progesterone'), isCurved: true, color: Colors.pink, barWidth: 3, dotData: const FlDotData(show: true)),
                    ],
                  ),
                ),
              ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.cyan, 'Estrogen'),
            const SizedBox(width: 20),
            _buildLegendItem(Colors.pink, 'Progesterone'),
          ],
        ),
      ],
    );
  }

  Widget _buildMicrogravityContent() {
    final filteredData = _filterByCurrentDay(_microgravityData); 

    bool hasValidData = filteredData.isNotEmpty && filteredData.any((e) => (e['rms'] as num?) != null);
    
    if (!hasValidData) {
      return Center(child: Text('No Data for Day $_currentDay', style: GoogleFonts.montserrat()));
    }

    filteredData.sort((a, b) => _parseHour(a['time']).compareTo(_parseHour(b['time'])));

    List<FlSpot> rmsSpots = [];
    List<FlSpot> peakSpots = [];
    
    for (int i = 0; i < filteredData.length; i++) {
      final hourX = _parseHour(filteredData[i]['time']);
      rmsSpots.add(FlSpot(hourX, (filteredData[i]['rms'] as num?)?.toDouble() ?? 0.0));
      peakSpots.add(FlSpot(hourX, (filteredData[i]['peak'] as num?)?.toDouble() ?? 0.0));
    }

    double maxY = 30.0;
    if (filteredData.isNotEmpty) {
       maxY = filteredData.map((e) => (e['peak'] as num?)?.toDouble() ?? 0.0).reduce(max) + 5;
       if (maxY <= 5) maxY = 30.0; 
    }

    return Column(
      children: [
        Text('Vibratory RMS vs Transient Peak (Day $_currentDay)', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 5.0,
              child: SizedBox(
                width: 1200,
                height: 500,
                child: Padding(
                  padding: const EdgeInsets.only(right: 40, top: 20, bottom: 10),
                  child: LineChart(
                    LineChartData(
                      minY: 0, maxY: maxY,
                      minX: 0, maxX: 24, 
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true, 
                        drawVerticalLine: true,
                        verticalInterval: 4,
                        horizontalInterval: maxY / 5, 
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, 
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                          )
                        ),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 4, getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10));
                        })),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(spots: rmsSpots, isCurved: true, preventCurveOverShooting: true, color: Colors.blue, barWidth: 3, dotData: const FlDotData(show: true)),
                        LineChartBarData(spots: peakSpots, isCurved: true, preventCurveOverShooting: true, color: Colors.red, barWidth: 3, dotData: const FlDotData(show: true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadiationContent() {
    final filteredData = _filterByCurrentDay(_radiationData); 

    bool hasValidData = filteredData.isNotEmpty && filteredData.any((e) => (e['dose'] as num?) != null);

    if (!hasValidData) {
      return Center(child: Text('No Data for Day $_currentDay', style: GoogleFonts.montserrat()));
    }

    filteredData.sort((a, b) => _parseHour(a['time']).compareTo(_parseHour(b['time'])));

    List<FlSpot> doseSpots = [];
    for (int i = 0; i < filteredData.length; i++) {
      final hourX = _parseHour(filteredData[i]['time']);
      doseSpots.add(FlSpot(hourX, (filteredData[i]['dose'] as num?)?.toDouble() ?? 0.0));
    }

    double minY = 10.0;
    double maxY = 15.0;
    if (filteredData.isNotEmpty) {
       minY = filteredData.map((e) => (e['dose'] as num?)?.toDouble() ?? 0.0).reduce(min) - 1;
       maxY = filteredData.map((e) => (e['dose'] as num?)?.toDouble() ?? 0.0).reduce(max) + 1;
    }

    return Column(
      children: [
        Text('Daily Radiation Dose (Day $_currentDay)', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 5.0,
              child: SizedBox(
                width: 1200,
                height: 500,
                child: Padding(
                  padding: const EdgeInsets.only(right: 40, top: 20, bottom: 10),
                  child: LineChart(
                    LineChartData(
                      minY: minY, maxY: maxY,
                      minX: 0, maxX: 24, 
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true, 
                        drawVerticalLine: true,
                        verticalInterval: 4,
                        horizontalInterval: (maxY - minY) / 5, 
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, 
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                          )
                        ),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 4, getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10));
                        })),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(spots: doseSpots, isCurved: true, preventCurveOverShooting: true, color: Colors.purple, barWidth: 3, dotData: const FlDotData(show: true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreyButton(String label) {
    return Container(
      height: 55, width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFA8A9AD), borderRadius: BorderRadius.circular(8)), 
      child: Center(child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14, letterSpacing: 1.5))),
    );
  }

  Widget _buildGridButton(String label, String panelKey, {bool disabled = false}) {
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : () => setState(() => _activePanel = panelKey),
        child: Container(
          width: 200, height: 55,
          decoration: BoxDecoration(
            color: disabled ? Colors.grey.shade800.withValues(alpha: 0.6) : const Color(0xFFF2E5C4), 
            borderRadius: BorderRadius.circular(8),
            border: disabled ? Border.all(color: Colors.white24) : null,
          ),
          child: Center(
            child: Text(
              label, 
              textAlign: TextAlign.center, 
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold, 
                color: disabled ? Colors.grey.shade400 : const Color(0xFF2A1500), 
                fontSize: 12
              )
            )
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryLink(String label, String route) {
    return GestureDetector(
      onTap: () { 
        if (route == '/biometric') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BiometricTelemetryPage()));
        } else if (route == '/biomarker') { 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BiomarkerRegistryPage()));
        } else if (route == '/environmental') { 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const EnvironmentalTelemetryPage()));
        } else if (route == '/behavioral') { 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BehavioralDataPage()));
        }
      }, 
      child: Container(
        width: 420, height: 55,
        decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF2A1500), letterSpacing: 1.5, fontSize: 13))),
      ),
    );
  }

  Widget _buildRedBox(String label) {
    return Container(
      height: 60, width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFE57373), borderRadius: BorderRadius.circular(8)), 
      child: Center(child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF2A1500), fontSize: 12))),
    );
  }

  Widget _buildMiniStatBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(20)),
      child: Text(text, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}