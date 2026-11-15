import 'dart:async';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/profile_service.dart'; 
import '../services/ai_service.dart'; 

class BiomarkerRegistryPage extends StatefulWidget {
  const BiomarkerRegistryPage({super.key});

  @override
  State<BiomarkerRegistryPage> createState() => _BiomarkerRegistryPageState();
}

class _BiomarkerRegistryPageState extends State<BiomarkerRegistryPage> {
  final _profileService = ProfileService();
  final _aiService = AIService(); 
  
  String? _activeBiomarker; 
  bool _isAiLoading = false;
  bool _isLoadingData = true;
  MedicalAssessment? _aiAssessment; 

  List<Map<String, dynamic>> _rawData = [];
  List<int> _availableDays = [];
  int _selectedDay = 0; 

  List<FlSpot> _lumbarSpineSpots = [];
  List<FlSpot> _trochanterHipSpots = [];
  List<FlSpot> _tCellSpots = [];
  
  List<FlSpot> _cortisolSpots = [];
  List<FlSpot> _ckSpots = [];
  List<FlSpot> _calciumSpots = [];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_rawData.isEmpty) setState(() => _isLoadingData = true);
    
    final data = await _profileService.getBiomarkerData();
    
    List<int> days = data.map((e) => (e['day'] as double).toInt()).toSet().toList();
    days.sort();

    if (mounted) {
      setState(() {
        _rawData = data;
        _availableDays = days;
        _filterData();
        _isLoadingData = false;
      });
    }
  }

  void _filterData() {
    List<FlSpot> lumbar = [];
    List<FlSpot> hip = [];
    List<FlSpot> tCell = [];
    List<FlSpot> cortisol = [];
    List<FlSpot> ck = [];
    List<FlSpot> calcium = [];

    if (_rawData.isNotEmpty) {
      for (var row in _rawData) {
        final day = (row['day'] as double).toInt();
        
        if (_selectedDay != 0 && day != _selectedDay) continue;

        if ((row['bone_lumbar'] as double) > 0) lumbar.add(FlSpot(day.toDouble(), row['bone_lumbar']));
        if ((row['bone_hip'] as double) > 0) hip.add(FlSpot(day.toDouble(), row['bone_hip']));
        if ((row['t_cell'] as double) > 0) tCell.add(FlSpot(day.toDouble(), row['t_cell']));
        if ((row['cortisol'] as double) > 0) cortisol.add(FlSpot(day.toDouble(), row['cortisol']));
        if ((row['creatine_kinase'] as double) > 0) ck.add(FlSpot(day.toDouble(), row['creatine_kinase']));
        if ((row['serum_calcium'] as double) > 0) calcium.add(FlSpot(day.toDouble(), row['serum_calcium']));
      }
    } 

    setState(() {
      _lumbarSpineSpots = lumbar;
      _trochanterHipSpots = hip;
      _tCellSpots = tCell;
      _cortisolSpots = cortisol;
      _ckSpots = ck;
      _calciumSpots = calcium;
    });
  }

  void _runAIAnalysis() async {
    setState(() => _isAiLoading = true);
    
    String dataContext = "Biomarker: $_activeBiomarker\nTimeframe: ${_selectedDay == 0 ? 'Entire Mission' : 'Day $_selectedDay'}\n";
    
    if (_activeBiomarker == 'BONE_DENSITY') {
      dataContext += "Lumbar Spine (% baseline): ${_lumbarSpineSpots.map((s) => 'D${s.x.toInt()}: ${s.y}%').join(', ')}\n";
      dataContext += "Trochanter Hip (% baseline): ${_trochanterHipSpots.map((s) => 'D${s.x.toInt()}: ${s.y}%').join(', ')}";
    } else if (_activeBiomarker == 'T_CELL_ACTIVITY') {
      dataContext += "T-Cell Activity: ${_tCellSpots.map((s) => 'D${s.x.toInt()}: ${s.y}%').join(', ')}";
    } else if (_activeBiomarker == 'CORTISOL') {
      dataContext += "Cortisol: ${_cortisolSpots.map((s) => 'D${s.x.toInt()}: ${s.y} mcg/dL').join(', ')}";
    } else if (_activeBiomarker == 'CK') {
      dataContext += "Creatine Kinase: ${_ckSpots.map((s) => 'D${s.x.toInt()}: ${s.y} U/L').join(', ')}";
    } else if (_activeBiomarker == 'CALCIUM') {
      dataContext += "Serum Calcium: ${_calciumSpots.map((s) => 'D${s.x.toInt()}: ${s.y} mg/dL').join(', ')}";
    }

    try {
      final assessment = await _aiService.analyzeData(dataContext, "As a flight surgeon, analyze these $_activeBiomarker readings. Is this a normal response to microgravity?");
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
                'assets/images/biomarker registry background.png', 
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
                    'BIOMARKER REGISTRY',
                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ),
                ),
              ),

              Positioned(
                top: 40, right: 100,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, color: Color(0xFFD4A843), size: 28),
                      tooltip: 'Reload Data',
                    ),
                    const SizedBox(width: 10),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFD4A843), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.black),
                            onPressed: () {
                              if (_availableDays.isEmpty) return;
                              if (_selectedDay == 0) return;
                              int idx = _availableDays.indexOf(_selectedDay);
                              setState(() {
                                _selectedDay = idx > 0 ? _availableDays[idx - 1] : 0;
                                _aiAssessment = null;
                              });
                              _filterData();
                            },
                          ),
                          Text(
                            _selectedDay == 0 ? 'ALL DAYS' : 'DAY $_selectedDay', 
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.black),
                            onPressed: () {
                              if (_availableDays.isEmpty) return;
                              setState(() {
                                if (_selectedDay == 0) {
                                  _selectedDay = _availableDays.first;
                                } else {
                                  int idx = _availableDays.indexOf(_selectedDay);
                                  if (idx >= 0 && idx < _availableDays.length - 1) {
                                    _selectedDay = _availableDays[idx + 1];
                                  }
                                }
                                _aiAssessment = null;
                              });
                              _filterData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_activeBiomarker != null)
                Positioned(
                  top: 100, left: 40, bottom: 40, width: 450,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFFC4B48A), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          _activeBiomarker!.replaceAll('_', ' '), 
                          style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(10)),
                          clipBehavior: Clip.hardEdge,
                          child: _isLoadingData 
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A843)))
                            : _buildChart(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: (_isAiLoading || _aiAssessment != null) ? null : _runAIAnalysis,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _aiAssessment == null 
                                  ? const Color(0xFFF2E5C4).withValues(alpha: 0.95) 
                                  : _aiAssessment!.urgencyLevel == 'Emergency' ? Colors.red.withValues(alpha: 0.85)
                                  : _aiAssessment!.urgencyLevel == 'Caution' ? Colors.orange.withValues(alpha: 0.85)
                                  : Colors.green.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: _isAiLoading 
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A843)))
                              : _aiAssessment == null
                                ? Center(child: Text("Gibby Buddy\n\nClick to analyze the uploaded data.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 15, color: Colors.black87)))
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
                    ],
                  ),
                ),

              Positioned(
                top: 120, right: 100, width: 350,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuButton('BONE DENSITY', 'BONE_DENSITY'),
                      const SizedBox(height: 10),
                      _buildMenuButton('T CELL ACTIVITY', 'T_CELL_ACTIVITY'),
                      const SizedBox(height: 10),
                      _buildMenuButton('CORTISOL', 'CORTISOL'),
                      const SizedBox(height: 10),
                      _buildMenuButton('CREATINE KINASE', 'CK'),
                      const SizedBox(height: 10),
                      _buildMenuButton('SERUM CALCIUM', 'CALCIUM'),
                    ],
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

  Widget _buildMenuButton(String label, String type) {
    bool isActive = _activeBiomarker == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeBiomarker = type;
          _aiAssessment = null;
        });
      },
      child: Container(
        height: 45, width: double.infinity,
        decoration: BoxDecoration(color: isActive ? const Color(0xFFD4A843) : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(25)),
        child: Center(child: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF2A1500) : Colors.white, fontSize: 13, letterSpacing: 1))),
      ),
    );
  }

  Widget _buildCircleNavButton(IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE8D5A0), border: Border.all(color: const Color(0xFFD4A843), width: 3)),
          child: Icon(icon, color: const Color(0xFFD96C6C), size: 24),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_activeBiomarker == 'BONE_DENSITY') return _buildLineChart(_lumbarSpineSpots, _trochanterHipSpots, Colors.blue, Colors.orange, false);
    if (_activeBiomarker == 'T_CELL_ACTIVITY') return _buildLineChart(_tCellSpots, [], Colors.blue, Colors.transparent, true);
    if (_activeBiomarker == 'CORTISOL') return _buildLineChart(_cortisolSpots, [], Colors.orange, Colors.transparent, false);
    if (_activeBiomarker == 'CK') return _buildLineChart(_ckSpots, [], Colors.red, Colors.transparent, false);
    if (_activeBiomarker == 'CALCIUM') return _buildLineChart(_calciumSpots, [], Colors.green, Colors.transparent, false);
    return const SizedBox();
  }

  Widget _buildLineChart(List<FlSpot> spots1, List<FlSpot> spots2, Color color1, Color color2, bool showLabels) {
    if (spots1.isEmpty && spots2.isEmpty) {
      return Center(child: Text('No Data Available for ${_selectedDay == 0 ? "Mission" : "Day $_selectedDay"}', style: GoogleFonts.montserrat(color: Colors.black54)));
    }

    List<FlSpot> allSpots = [...spots1, ...spots2];
    double minY = allSpots.map((s) => s.y).reduce(min);
    double maxY = allSpots.map((s) => s.y).reduce(max);
    
    double padding = (maxY - minY) * 0.1;
    if (padding == 0) padding = 5;
    minY = minY - padding;
    maxY = maxY + padding;

    double minX = allSpots.map((s) => s.x).reduce(min);
    double maxX = allSpots.map((s) => s.x).reduce(max);
    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }

    return InteractiveViewer(
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
              minX: minX, maxX: maxX, minY: minY, maxY: maxY, 
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true, 
                drawVerticalLine: true, 
                horizontalInterval: (maxY - minY) / 5, 
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1), 
                getDrawingVerticalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1)
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.black54, fontSize: 10)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 10, getTitlesWidget: (value, meta) {
                  if (showLabels) {
                    const labels = ['Base', 'FD14', 'FD30', 'FD90', 'R+1', 'R+30'];
                    int index = value.toInt();
                    if (index >= 0 && index < labels.length) return Padding(padding: const EdgeInsets.only(top: 5), child: Text(labels[index], style: const TextStyle(color: Colors.black54, fontSize: 9)));
                    return const SizedBox();
                  }
                  return Padding(padding: const EdgeInsets.only(top: 5), child: Text('D${value.toInt()}', style: const TextStyle(color: Colors.black54, fontSize: 10)));
                })),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots1, 
                  isCurved: true, 
                  preventCurveOverShooting: true,
                  color: color1, 
                  barWidth: 3, 
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: color1.withValues(alpha: 0.1)),
                ),
                if (spots2.isNotEmpty)
                  LineChartBarData(
                    spots: spots2, 
                    isCurved: true, 
                    preventCurveOverShooting: true,
                    color: color2, 
                    barWidth: 3, 
                    dotData: const FlDotData(show: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}