import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/profile_service.dart';
import '../services/ai_service.dart'; 

class EnvironmentalTelemetryPage extends StatefulWidget {
  const EnvironmentalTelemetryPage({super.key});

  @override
  State<EnvironmentalTelemetryPage> createState() => _EnvironmentalTelemetryPageState();
}

class _EnvironmentalTelemetryPageState extends State<EnvironmentalTelemetryPage> {
  final _profileService = ProfileService();
  final _aiService = AIService(); 
  
  List<Map<String, dynamic>> _allData = [];
  List<String> _customEnvironments = [];
  List<int> _availableDays = [];
  
  String _selectedLocation = 'All Locations';
  int _selectedDay = 1; 
  String? _activeMetric;
  
  bool _isAiLoading = false;
  bool _isLoadingData = true;
  MedicalAssessment? _aiAssessment; 

  final Map<String, String> _metrics = {
    'co2': 'AMBIENT CO₂ LEVELS',
    'o2': 'O₂ PARTIAL PRESSURE (MMHG)',
    'noise': 'AMBIENT NOISE (DECIBALS)',
    'temp': 'CABIN TEMP (°C)',
    'humidity': 'RELATIVE HUMIDITY (%)',
    'radiation': 'RADIATION DOSE (MGY/H)',
    'airflow': 'AIRFLOW VELOCITY (M/S)',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    
    final data = await _profileService.getEnvironmentalData();
    final profile = await _profileService.loadProfile();
    
    List<String> customEnvs = [];
    if (profile['environments'] != null) {
      customEnvs = (profile['environments'] as List).map((e) => e.toString()).toList();
    }

    List<int> days = data.map((e) => (e['day'] as double).toInt()).toSet().toList();
    days.sort();
    
    setState(() {
      _allData = data;
      _customEnvironments = customEnvs;
      _availableDays = days;
      
      if (_availableDays.isNotEmpty && !_availableDays.contains(_selectedDay)) {
        _selectedDay = _availableDays.last; 
      }
      
      _isLoadingData = false;
    });
  }

  List<String> get _locations {
    final dataLocs = _allData.map((e) => e['location'].toString()).toSet().toList();
    final allLocs = {...dataLocs, ..._customEnvironments}.toList();
    allLocs.sort();
    return ['All Locations', ...allLocs];
  }

  double _parseTimeToHours(String timeStr) {
    try {
      final cleanStr = timeStr.trim().toLowerCase();
      if (cleanStr.isEmpty) return 0.0;
      
      final decimalTime = double.tryParse(cleanStr);
      if (decimalTime != null) {
        if (decimalTime >= 0 && decimalTime <= 1.0) return decimalTime * 24.0; 
        return decimalTime; 
      }
      
      bool isPm = cleanStr.contains('pm');
      final timeOnly = cleanStr.replaceAll('am', '').replaceAll('pm', '').trim();
      final parts = timeOnly.split(':');
      
      if (parts.length >= 2) {
        double hour = double.tryParse(parts[0].trim()) ?? 0.0;
        double minute = double.tryParse(parts[1].trim()) ?? 0.0;
        
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0; 
        
        return hour + (minute / 60.0);
      }
    } catch (e) {
      debugPrint('Error parsing time: $timeStr -> $e');
    }
    return 0.0;
  }

  List<FlSpot> _getSpotsForMetric(String metricKey) {
    List<FlSpot> spots = [];
    for (var row in _allData) {
      final rowDay = (row['day'] as double).toInt();
      final rowLoc = row['location'].toString();
      
      if (rowDay == _selectedDay && (_selectedLocation == 'All Locations' || rowLoc == _selectedLocation)) {
        final x = _parseTimeToHours(row['time'].toString());
        final y = row[metricKey] as double? ?? 0.0;
        spots.add(FlSpot(x, y));
      }
    }
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  void _runAIAnalysis() async {
    if (_activeMetric == null) return;
    setState(() => _isAiLoading = true);
    
    final spots = _getSpotsForMetric(_activeMetric!);
    String dataContext = "Location: $_selectedLocation\nDay: $_selectedDay\nMetric: ${_metrics[_activeMetric]}\n";
    dataContext += "Data Points (Time: Value): ${spots.map((s) => '${s.x.toStringAsFixed(1)}h: ${s.y}').join(', ')}";

    try {
      final assessment = await _aiService.analyzeData(
        dataContext, 
        "Analyze this environmental telemetry. Are there any life-support anomalies (like high CO2, dangerous radiation, or extreme noise) that could affect astronaut health?"
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
                'assets/images/environmental telemetry background.png',
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
                    'ENVIRONMENTAL TELEMETRY',
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
                              int idx = _availableDays.indexOf(_selectedDay);
                              if (idx > 0) setState(() {
                                _selectedDay = _availableDays[idx - 1];
                                _aiAssessment = null;
                              });
                            },
                          ),
                          Text('DAY $_selectedDay', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.black),
                            onPressed: () {
                              if (_availableDays.isEmpty) return;
                              int idx = _availableDays.indexOf(_selectedDay);
                              if (idx >= 0 && idx < _availableDays.length - 1) setState(() {
                                _selectedDay = _availableDays[idx + 1];
                                _aiAssessment = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 15),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(color: const Color(0xFFFDD835), borderRadius: BorderRadius.circular(20)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLocation,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                          dropdownColor: const Color(0xFFF2E5C4),
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                          items: _locations.map((String loc) => DropdownMenuItem<String>(value: loc, child: Text(loc))).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) setState(() {
                              _selectedLocation = newValue;
                              _aiAssessment = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 120, left: 40, bottom: 40, width: 350,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: _metrics.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildMenuButton(entry.value, entry.key),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_activeMetric != null)
                Positioned(
                  top: 120, left: 420, right: 100, bottom: 40,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFFC4B48A), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          _metrics[_activeMetric]!,
                          style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Expanded(
                        flex: 3,
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
                        flex: 1, 
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
                                ? Center(
                                    child: Text(
                                      "Gibby Buddy\n\nSelect a location and metric to analyze.", 
                                      textAlign: TextAlign.center, 
                                      style: GoogleFonts.montserrat(fontSize: 15, color: Colors.black87)
                                    )
                                  )
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

  Widget _buildMenuButton(String label, String key) {
    bool isActive = _activeMetric == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeMetric = key;
          _aiAssessment = null; 
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isActive ? const LinearGradient(colors: [Color(0xFFD4A843), Color(0xFFF2E5C4)]) : null,
          color: isActive ? null : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.black : Colors.white,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
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

  Widget _buildChart() {
    final spots = _getSpotsForMetric(_activeMetric!);
    
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No data for Day $_selectedDay at $_selectedLocation.', 
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(color: Colors.black54)
        )
      );
    }

    double minY = spots.map((s) => s.y).reduce(min) - 2;
    double maxY = spots.map((s) => s.y).reduce(max) + 2;
    if (minY < 0) minY = 0; 

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
              minX: 0, maxX: 24, 
              minY: minY, maxY: maxY, 
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: (maxY - minY) / 5, 
                verticalInterval: 4, 
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1),
                getDrawingVerticalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 45, 
                    getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.black54, fontSize: 10)),
                  )
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    interval: 4, 
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text('${hour.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                      );
                    },
                  )
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true, 
                  color: Colors.green,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => Colors.black87,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final hour = spot.x.toInt();
                      final minute = ((spot.x - hour) * 60).round();
                      final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                      
                      return LineTooltipItem(
                        'Time: $timeStr\nValue: ${spot.y.toStringAsFixed(1)}',
                        GoogleFonts.montserrat(color: Colors.white, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}