import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/profile_service.dart';
import '../services/ai_service.dart'; 

class BehavioralDataPage extends StatefulWidget {
  const BehavioralDataPage({super.key});

  @override
  State<BehavioralDataPage> createState() => _BehavioralDataPageState();
}

class _BehavioralDataPageState extends State<BehavioralDataPage> {
  final _profileService = ProfileService();
  final _aiService = AIService(); 
  
  int _missionDuration = 10;
  int _selectedDay = 1;
  Map<int, String> _moods = {};
  
  bool _isAiLoading = false;
  MedicalAssessment? _aiAssessment; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await _profileService.loadProfile();
    final moods = await _profileService.getMoodData();
    
    setState(() {
      _missionDuration = int.tryParse(profile['mission_duration'].toString()) ?? 10;
      _moods = moods;
    });
  }

  Future<void> _uploadData(String dataType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$dataType data uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _runAIAnalysis() async {
    setState(() => _isAiLoading = true);
    
    String dataContext = "Behavioral Analysis for Mission Day $_selectedDay.\n";
    dataContext += "Current Recorded Mood: ${_moods[_selectedDay] ?? 'Not recorded'}\n";
    
    String recentMoods = _moods.entries
        .where((e) => e.key <= _selectedDay && e.key >= _selectedDay - 3)
        .map((e) => 'Day ${e.key}: ${e.value}')
        .join(', ');
    if (recentMoods.isNotEmpty) {
      dataContext += "Recent Mood Trend: $recentMoods\n";
    }
    
    dataContext += "Note: The astronaut has also uploaded Cognitive Performance and Voice Acoustics data files for analysis.\n";

    try {
      final assessment = await _aiService.analyzeData(
        dataContext, 
        "As a flight surgeon, analyze the astronaut's behavioral health based on this data. Provide a brief psychological assessment and any recommendations for the crew."
      );
      
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _aiAssessment = assessment;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
          _aiAssessment = MedicalAssessment(
            assessment: "Error: $e", 
            urgencyLevel: "Caution", 
            immediateActions: [], 
            whyItMatters: ""
          );
        });
      }
    }
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
              Image.asset(
                'assets/images/behavorial_data.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF4A4234)),
              ),
              
              Positioned(
                top: 40, left: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF332200), Color(0xFFD4A843)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'BEHAVIORAL DATA',
                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ),
                ),
              ),

              Positioned(
                top: 140, left: 120, width: 500,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      _buildUploadButton('COGNITIVE PERFORMANCE\nTESTING SCORES', () => _uploadData('Cognitive')),
                      const SizedBox(height: 20),
                      _buildUploadButton('VOICE ACOUSTICS', () => _uploadData('Voice Acoustics')),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 100, right: 100, bottom: 120, width: 350, 
                child: Column(
                  children: [
                    Expanded( 
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E5C4).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _buildMissionDaysGrid(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900.withValues(alpha: 0.7), 
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MOOD:', style: GoogleFonts.montserrat(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const SizedBox(height: 5),
                          Text(
                            _moods[_selectedDay] ?? 'No mood recorded for this day.',
                            style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.5),
                            maxLines: 3, 
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 40, left: 120, right: 500, 
                child: GestureDetector(
                  onTap: (_isAiLoading || _aiAssessment != null) ? null : _runAIAnalysis,
                  child: Container(
                    height: 150, 
                    decoration: BoxDecoration(
                      color: _aiAssessment == null 
                          ? Colors.pink.withValues(alpha: 0.3) 
                          : _aiAssessment!.urgencyLevel == 'Emergency' ? Colors.red.withValues(alpha: 0.85)
                          : _aiAssessment!.urgencyLevel == 'Caution' ? Colors.orange.withValues(alpha: 0.85)
                          : Colors.green.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _isAiLoading 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A843)))
                      : _aiAssessment == null
                        ? Center(child: Text("Gibby Buddy\n\nClick to analyze behavioral data.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14, letterSpacing: 1)))
                        : Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_aiAssessment!.urgencyLevel.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                  const SizedBox(height: 5),
                                  Text(_aiAssessment!.assessment, style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  Text("ACTIONS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ..._aiAssessment!.immediateActions.map((action) => Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text("• $action", style: GoogleFonts.montserrat(color: Colors.white)),
                                  )),
                                  const SizedBox(height: 10),
                                  Text("WHY IT MATTERS:\n${_aiAssessment!.whyItMatters}", style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              Positioned(
                bottom: 40, right: 40,
                child: Row(
                  children: [
                    _buildCircleNavButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const SizedBox(width: 20),
                    _buildCircleNavButton(Icons.arrow_forward_ios, () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF6B5A28)], 
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.black, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionDaysGrid() {
    List<Widget> dayWidgets = [];

    for (int i = 1; i <= _missionDuration; i++) {
      final isSelected = i == _selectedDay;
      final hasMood = _moods.containsKey(i);

      dayWidgets.add(
        GestureDetector(
          onTap: () => setState(() {
            _selectedDay = i;
            _aiAssessment = null;
          }),
          child: Container(
            width: 45,
            height: 45,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD4A843) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: hasMood && !isSelected ? Colors.red : Colors.transparent, width: 2),
            ),
            child: Center(
              child: Text(
                'd$i',
                style: GoogleFonts.montserrat(
                  color: isSelected ? Colors.black : (hasMood ? Colors.red.shade700 : Colors.black87),
                  fontWeight: isSelected || hasMood ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text('MISSION DAYS', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 4)),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 5,
              children: dayWidgets,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleNavButton(IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE8D5A0),
            border: Border.all(color: const Color(0xFFD4A843), width: 3),
          ),
          child: Icon(icon, color: const Color(0xFFD96C6C), size: 24),
        ),
      ),
    );
  }
}