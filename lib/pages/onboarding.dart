import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/profile_service.dart';
import 'settings.dart'; 

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _nameCtrl = TextEditingController();
  String _gender = 'Female';
  DateTime _birthday = DateTime(1991, 10, 14);

  final _daysCtrl = TextEditingController(text: '10');

  final List<String> _selectedEnvs = [];
  final List<String> _availableEnvs = [
    'Harmony Module', 'Destiny Lab', 'Node 3 Exercise', 'Kibo Module', 'Unity Galley'
  ];
  final _customEnvCtrl = TextEditingController();

  final List<String> _selectedAlarms = [];
  final List<String> _availableAlarms = [
    'Body Mass / Composition', 'Height Measurement', 'Cognitive Performance', 'Nutrition Log'
  ];
  TimeOfDay _alarmTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _daysCtrl.dispose();
    _customEnvCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _startMission() async {
    if (_nameCtrl.text.isEmpty || _daysCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in Name and Duration')));
      return;
    }

    // ✅ FIXED: Saving exact hour/min and enabling the alarm properly
    final profileData = {
      'name': _nameCtrl.text.trim(),
      'gender': _gender,
      'birthday': _birthday.toIso8601String(),
      'mission_duration': int.tryParse(_daysCtrl.text) ?? 10,
      'environments': _selectedEnvs,
      'alarms': _selectedAlarms,
      'alarm_hour': _alarmTime.hour,
      'alarm_minute': _alarmTime.minute,
      'alarm_enabled': _selectedAlarms.isNotEmpty, 
    };

    await ProfileService().saveProfile(profileData);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
    }
  }

  void _addCustomEnv() {
    final newEnv = _customEnvCtrl.text.trim();
    if (newEnv.isNotEmpty && !_availableEnvs.contains(newEnv)) {
      setState(() {
        _availableEnvs.add(newEnv);
        _selectedEnvs.add(newEnv); 
        _customEnvCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 1400,
          height: 860,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/homepage bg with title.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF4A4234)),
              ),
              
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                  _buildPage5Start(),
                ],
              ),

              Positioned(
                bottom: 40, right: 40,
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      _buildNavButton(Icons.arrow_back_ios_new, _prevPage),
                    const SizedBox(width: 20),
                    if (_currentPage < 4)
                      _buildNavButton(Icons.arrow_forward_ios, _nextPage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFFF2E5C4).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PRE MISSION DETAILS', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
            const SizedBox(height: 25),
            TextField(
              controller: _nameCtrl, 
              decoration: InputDecoration(
                hintText: 'NAME', 
                filled: true, 
                fillColor: Colors.white70, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20)
              )
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              items: ['Male', 'Female'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _gender = v!),
              decoration: InputDecoration(
                filled: true, 
                fillColor: Colors.white70, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20)
              ),
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _birthday, firstDate: DateTime(1900), lastDate: DateTime.now());
                if (picked != null) {
                  setState(() => _birthday = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(30)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BIRTHDAY: ${DateFormat('yyyy-MM-dd').format(_birthday)}', style: GoogleFonts.montserrat(color: Colors.black87)),
                    const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage2() {
    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: const Color(0xFFF2E5C4).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('YOUR GIBBOUS JOURNEY\nWILL LAST', textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
            const SizedBox(height: 25),
            TextField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true, 
                fillColor: Colors.white70, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)
              ),
            ),
            const SizedBox(height: 10),
            Text('DAYS', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPage3() {
    return Center(
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: const Color(0xFFF2E5C4).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PLEASE ENTER ALL THE\nENVIRONMENTS/LOCATIONS\nYOU WILL BE ACTIVE IN:', textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 15)),
            const SizedBox(height: 25),
            Wrap(
              spacing: 15, runSpacing: 15,
              alignment: WrapAlignment.center,
              children: _availableEnvs.map((env) {
                final isSelected = _selectedEnvs.contains(env);
                return FilterChip(
                  label: Text(env),
                  labelStyle: GoogleFonts.montserrat(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  selected: isSelected,
                  selectedColor: const Color(0xFFD4A843),
                  checkmarkColor: Colors.black,
                  backgroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedEnvs.add(env);
                      } else {
                        _selectedEnvs.remove(env);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customEnvCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add custom environment...',
                      filled: true,
                      fillColor: Colors.white70,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onSubmitted: (_) => _addCustomEnv(),
                  ),
                ),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: _addCustomEnv,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFFD4A843), shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.black, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text('THIS CAN BE CHANGED FROM SETTINGS', style: GoogleFonts.montserrat(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPage4() {
    return Center(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: const Color(0xFFF2E5C4).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SELECT ALL MEASUREMENTS\nYOU WANT GIBBOUS ALARM FOR:', textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 15)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10, runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _availableAlarms.map((alarm) {
                final isSelected = _selectedAlarms.contains(alarm);
                return FilterChip(
                  label: Text(alarm),
                  labelStyle: GoogleFonts.montserrat(fontSize: 12),
                  selected: isSelected,
                  selectedColor: const Color(0xFFD4A843),
                  checkmarkColor: Colors.black,
                  backgroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedAlarms.add(alarm);
                      } else {
                        _selectedAlarms.remove(alarm);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            Text('PLEASE SET YOUR PREFERRED\nTIME FOR ALARM:', textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 14)),
            const SizedBox(height: 15),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _alarmTime);
                if (picked != null) {
                  setState(() => _alarmTime = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(30)),
                child: Text(
                  _alarmTime.format(context), 
                  style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage5Start() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 350,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.rocket_launch, size: 100, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(height: 20),
                Text(
                  'CLICKING START WILL BEGIN\nDAY 0 OF THE MISSION.\n\nANY AND ALL LOGS YOU TAKE\nWILL BE USED TO CALCULATE\nYOUR BASELINE.\n\nWHEN TOGGLE THE STATUS TO\nSTART MISSION AND SELECT\nENVIRONMENT.',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
          GestureDetector(
            onTap: _startMission,
            child: Text(
              'START', 
              style: GoogleFonts.montserrat(fontSize: 100, fontWeight: FontWeight.bold, color: const Color(0xFFFDD835), letterSpacing: 5),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE8D5A0),
            border: Border.all(color: const Color(0xFFD4A843), width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))
            ]
          ),
          child: Icon(icon, color: const Color(0xFFD96C6C), size: 24),
        ),
      ),
    );
  }
}