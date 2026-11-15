import 'dart:async';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/profile_service.dart';
import '../services/bluetooth_service.dart'; 
import '../services/ai_service.dart';

class BiometricTelemetryPage extends StatefulWidget {
  const BiometricTelemetryPage({super.key});

  @override
  State<BiometricTelemetryPage> createState() => _BiometricTelemetryPageState();
}

class _BiometricTelemetryPageState extends State<BiometricTelemetryPage> {
  final _profileService = ProfileService();
  final _bluetoothService = BluetoothService();
  final _aiService = AIService();

  String _activeMetric = 'HRV'; 
  bool _isAiLoading = false;
  bool _isLoadingData = true;
  
  MedicalAssessment? _aiAssessment; 

  List<Map<String, dynamic>> _rawData = [];
  List<int> _availableDays = [];
  int _selectedDay = 1;

  List<FlSpot> _hrvSpots = [];
  List<FlSpot> _bpmSpots = [];
  List<FlSpot> _spo2Spots = [];
  List<FlSpot> _ecgSpots = [];
  
  double _timeX = 0;
  bool _isLiveData = false;
  StreamSubscription<Map<String, double>>? _liveSubscription;

  String _latestHrv = '--';
  String _latestBpm = '--';
  String _latestSpo2 = '--';

  @override
  void initState() {
    super.initState();
    _loadBiometricData();
    _checkBluetoothConnection();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  void _checkBluetoothConnection() {
    if (_bluetoothService.isConnected) {
      setState(() => _isLiveData = true);
      _startLiveStream();
    }
  }

  void _startLiveStream() {
    _liveSubscription?.cancel();
    
    setState(() {
      _hrvSpots.clear();
      _bpmSpots.clear();
      _spo2Spots.clear();
      _ecgSpots.clear();
      _timeX = 0;
    });

    _liveSubscription = _bluetoothService.getLiveMetricsStream().listen((data) {
      if (!mounted) return;
      setState(() {
        _timeX += 0.1;
        
        final bpm = data['bpm'] ?? 70;
        final hrv = data['hrv'] ?? 60;
        final spo2 = data['spo2'] ?? 95;

        _latestBpm = '${bpm.toStringAsFixed(0)} BPM';
        _latestHrv = hrv.toStringAsFixed(0);
        _latestSpo2 = '${spo2.toStringAsFixed(0)}%';

        _bpmSpots.add(FlSpot(_timeX, bpm));
        _hrvSpots.add(FlSpot(_timeX, hrv));
        _spo2Spots.add(FlSpot(_timeX, spo2));
        _ecgSpots.add(FlSpot(_timeX, bpm > 100 ? 1.5 : 0.5)); 

        if (_bpmSpots.length > 50) _bpmSpots.removeAt(0);
        if (_hrvSpots.length > 50) _hrvSpots.removeAt(0);
        if (_spo2Spots.length > 50) _spo2Spots.removeAt(0);
        if (_ecgSpots.length > 50) _ecgSpots.removeAt(0);
      });
    });
  }

  Future<void> _loadBiometricData() async {
    setState(() => _isLoadingData = true);
    final data = await _profileService.getBiometricData();
    
    if (data.isEmpty) {
      setState(() {
        _isLoadingData = false;
        _hrvSpots = [];
        _bpmSpots = [];
        _spo2Spots = [];
        _latestHrv = '--';
        _latestBpm = '--';
        _latestSpo2 = '--';
      });
      return;
    }

    List<int> days = data.map((e) => (e['day'] as double).toInt()).toSet().toList();
    days.sort();

    setState(() {
      _rawData = data;
      _availableDays = days;
      if (_availableDays.isNotEmpty && !_availableDays.contains(_selectedDay)) {
        _selectedDay = _availableDays.last;
      }
      _filterDataForDay();
      _isLoadingData = false;
    });
  }

  void _filterDataForDay() {
    if (_isLiveData) return;

    List<FlSpot> hrvs = [];
    List<FlSpot> bpms = [];
    List<FlSpot> spo2s = [];

    for (int i = 0; i < _rawData.length; i++) {
      final row = _rawData[i];
      final day = (row['day'] as double).toInt();
      
      if (day != _selectedDay) continue;

      final timeStr = row['time'] as String? ?? '00:00:00';
      final timeParts = timeStr.split(':');
      double hourX = 0.0;
      if (timeParts.length >= 2) {
        hourX = (double.tryParse(timeParts[0]) ?? 0) + ((double.tryParse(timeParts[1]) ?? 0) / 60);
      }

      final h = row['hrv'] as double? ?? 0.0;
      final b = row['bpm'] as double? ?? 0.0;
      final s = row['spo2'] as double? ?? 0.0;

      if (h > 0) hrvs.add(FlSpot(hourX, h));
      if (b > 0) bpms.add(FlSpot(hourX, b));
      if (s > 0) spo2s.add(FlSpot(hourX, s));
    }

    hrvs.sort((a, b) => a.x.compareTo(b.x));
    bpms.sort((a, b) => a.x.compareTo(b.x));
    spo2s.sort((a, b) => a.x.compareTo(b.x));

    setState(() {
      _hrvSpots = hrvs;
      _bpmSpots = bpms;
      _spo2Spots = spo2s;
      
      _latestHrv = hrvs.isNotEmpty ? hrvs.last.y.toStringAsFixed(0) : '--';
      _latestBpm = bpms.isNotEmpty ? '${bpms.last.y.toStringAsFixed(0)} BPM' : '--';
      _latestSpo2 = spo2s.isNotEmpty ? '${spo2s.last.y.toStringAsFixed(0)}%' : '--';
    });
  }

  void _runAIAnalysis() async {
    setState(() => _isAiLoading = true);
    
    String dataContext = "Mission Day: $_selectedDay\nMetric: $_activeMetric\n";
    if (_activeMetric == 'HRV') {
      dataContext += "Data Points (Hour: Value): ${_hrvSpots.map((s) => '${s.x.toInt()}h: ${s.y}ms').join(', ')}";
    } else if (_activeMetric == 'BPM') {
      dataContext += "Data Points (Hour: Value): ${_bpmSpots.map((s) => '${s.x.toInt()}h: ${s.y}bpm').join(', ')}";
    } else {
      dataContext += "Data Points (Hour: Value): ${_spo2Spots.map((s) => '${s.x.toInt()}h: ${s.y}%').join(', ')}";
    }

    try {
      final assessment = await _aiService.analyzeData(dataContext, "Analyze these $_activeMetric readings. Are there any anomalies or physiological concerns?");
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
                'assets/images/biometric telemetry background.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF4A4234)),
              ),
              
              Positioned(
                top: 30, left: 40,
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
                    'BIOMETRIC TELEMETRY',
                    style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                  ),
                ),
              ),

              Positioned(
                top: 30, right: 40,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _loadBiometricData,
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
                              if (idx > 0) {
                                setState(() {
                                  _selectedDay = _availableDays[idx - 1];
                                  _aiAssessment = null;
                                });
                                _filterDataForDay();
                              }
                            },
                          ),
                          Text('DAY $_selectedDay', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.black),
                            onPressed: () {
                              if (_availableDays.isEmpty) return;
                              int idx = _availableDays.indexOf(_selectedDay);
                              if (idx >= 0 && idx < _availableDays.length - 1) {
                                setState(() {
                                  _selectedDay = _availableDays[idx + 1];
                                  _aiAssessment = null;
                                });
                                _filterDataForDay();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 90, left: 40, right: 40, bottom: 100, 
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC4B48A).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBDBDBD),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _activeMetric == 'SPO2' ? 'SPO₂' : _activeMetric,
                                style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3),
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(5)),
                                clipBehavior: Clip.hardEdge, 
                                child: _isLoadingData 
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A843)))
                                  : _buildActiveChart(),
                              ),
                            ),
                            const SizedBox(height: 10),

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
                                      ? Center(child: Text("Gibby Buddy\n\nClick to analyze today's biometric data.", textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 15, color: Colors.black87)))
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
                    ),
                    
                    const SizedBox(width: 40),

                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE5EC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3), width: 2),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        decoration: BoxDecoration(color: const Color(0xFF332200), borderRadius: BorderRadius.circular(20)),
                                        child: Text('ELECTROCARDIOGRAM (ECG)', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                      ),
                                      if (_isLiveData)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                                          child: Text('LIVE', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                        )
                                    ],
                                  ),
                                  Expanded(
                                    child: _isLiveData 
                                      ? InteractiveViewer(
                                          constrained: false,
                                          boundaryMargin: const EdgeInsets.all(20),
                                          minScale: 0.5,
                                          maxScale: 5.0,
                                          child: SizedBox(
                                            width: 1000,
                                            height: 300,
                                            child: LineChart(
                                              LineChartData(
                                                minX: 0, maxX: 5, minY: 0, maxY: 2,
                                                clipData: const FlClipData.all(),
                                                gridData: FlGridData(
                                                  show: true,
                                                  horizontalInterval: 0.5,
                                                  verticalInterval: 0.5,
                                                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.pink.withValues(alpha: 0.3), strokeWidth: 1),
                                                  getDrawingVerticalLine: (value) => FlLine(color: Colors.pink.withValues(alpha: 0.3), strokeWidth: 1),
                                                ),
                                                titlesData: const FlTitlesData(show: false), 
                                                borderData: FlBorderData(show: false),
                                                lineBarsData: [
                                                  LineChartBarData(
                                                    spots: _ecgSpots,
                                                    isCurved: true,
                                                    preventCurveOverShooting: true,
                                                    color: Colors.red.shade800,
                                                    barWidth: 2,
                                                    dotData: const FlDotData(show: false),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.monitor_heart_outlined, size: 50, color: Colors.pinkAccent.withValues(alpha: 0.5)),
                                              const SizedBox(height: 10),
                                              Text("ECG Disconnected", style: GoogleFonts.montserrat(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 14)),
                                              const SizedBox(height: 5),
                                              Text("Connect in Settings to stream live data", style: GoogleFonts.montserrat(color: Colors.black38, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          _buildChevronButton('HEART RATE VARIABILITY (HRV)', _latestHrv, 'HRV'),
                          const SizedBox(height: 10),
                          _buildChevronButton('BLOOD PRESSURE (BPM)', _latestBpm, 'BPM'),
                          const SizedBox(height: 10),
                          _buildChevronButton('OXYGEN SATURATION (SPO₂)', _latestSpo2, 'SPO2'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 30, right: 40,
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

  Widget _buildActiveChart() {
    List<FlSpot> activeSpots;
    double minY = 30, maxY = 90;
    Color lineColor = Colors.black;

    if (_activeMetric == 'HRV') {
      activeSpots = _hrvSpots;
      minY = activeSpots.isNotEmpty ? activeSpots.map((s) => s.y).reduce(min) - 5 : 30;
      maxY = activeSpots.isNotEmpty ? activeSpots.map((s) => s.y).reduce(max) + 5 : 90;
    } else if (_activeMetric == 'BPM') {
      activeSpots = _bpmSpots;
      minY = activeSpots.isNotEmpty ? activeSpots.map((s) => s.y).reduce(min) - 10 : 40;
      maxY = activeSpots.isNotEmpty ? activeSpots.map((s) => s.y).reduce(max) + 10 : 180;
      lineColor = Colors.blue;
    } else {
      activeSpots = _spo2Spots;
      minY = activeSpots.isNotEmpty ? activeSpots.map((s) => s.y).reduce(min) - 2 : 90;
      maxY = activeSpots.isNotEmpty ? activeSpots.map((s) => s.y).reduce(max) + 2 : 100;
      lineColor = Colors.blue;
    }

    if (activeSpots.isEmpty) {
      return Center(child: Text('No Data for Day $_selectedDay', style: GoogleFonts.montserrat(color: Colors.black54)));
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
              minX: 0, maxX: 24, minY: minY, maxY: maxY, 
              clipData: const FlClipData.all(), 
              gridData: FlGridData(
                show: true, 
                drawVerticalLine: true,
                horizontalInterval: (maxY - minY) / 5,
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1),
                getDrawingVerticalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true, 
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 35,
                    getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: const TextStyle(color: Colors.black54, fontSize: 10)),
                  )
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, interval: 6,
                    getTitlesWidget: (value, meta) => Text('${value.toInt()}:00', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                  )
                )
              ),
              borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.black26), left: BorderSide(color: Colors.black26))),
              lineBarsData: [
                LineChartBarData(
                  spots: activeSpots,
                  isCurved: _activeMetric != 'HRV', 
                  preventCurveOverShooting: true,
                  color: lineColor,
                  barWidth: 2,
                  dotData: FlDotData(show: _activeMetric == 'HRV'),
                  belowBarData: _activeMetric == 'SPO2' 
                    ? BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.2))
                    : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChevronButton(String label, String value, String metricKey) {
    bool isActive = _activeMetric == metricKey;

    return GestureDetector(
      onTap: () => setState(() {
        _activeMetric = metricKey;
        _aiAssessment = null;
      }),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              height: 50, 
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFD4A843) : const Color(0xFF1A1A1A), 
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold, 
                    color: isActive ? const Color(0xFF2A1500) : Colors.white, 
                    fontSize: 14, 
                    letterSpacing: 1
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          Expanded(
            flex: 1,
            child: ClipPath(
              clipper: ChevronClipper(),
              child: Container(
                height: 50, 
                decoration: BoxDecoration(
                  color: _isLiveData ? Colors.green.shade400 : const Color(0xFFD4A843)
                ), 
                child: Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Center(
                    child: Text(
                      value,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChevronClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width - 20, 0); 
    path.lineTo(size.width, size.height / 2); 
    path.lineTo(size.width - 20, size.height); 
    path.lineTo(0, size.height); 
    path.lineTo(0, 0); 
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}