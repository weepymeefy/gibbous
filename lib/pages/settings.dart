import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_ble/universal_ble.dart'; 
import '../services/profile_service.dart';
import '../services/bluetooth_service.dart'; 
import 'dashboard.dart';
import 'onboarding.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profileService = ProfileService();
  final _bluetoothService = BluetoothService();
  
  String _name = '';
  String _gender = '';
  String _age = '';

  bool _showMET = true;
  bool _showTimezone = false;
  String _selectedTimezone = 'UTC';
  TimeOfDay _alarmTime = const TimeOfDay(hour: 8, minute: 0);
  bool _alarmEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();
    if (profile.isNotEmpty) {
      setState(() {
        _name = profile['name'] ?? 'Astronaut';
        _gender = profile['gender'] ?? 'Female';
        
        final dobString = profile['birthday'];
        if (dobString != null) {
          final dob = DateTime.parse(dobString);
          final now = DateTime.now();
          int age = now.year - dob.year;
          if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          _age = age.toString();
        }

        _showMET = profile['show_met'] ?? true;
        _showTimezone = profile['show_timezone'] ?? false;
        _selectedTimezone = profile['timezone'] ?? 'UTC';
        _alarmEnabled = profile['alarm_enabled'] ?? false;
        
        if (profile['alarm_hour'] != null && profile['alarm_minute'] != null) {
          _alarmTime = TimeOfDay(
            hour: int.tryParse(profile['alarm_hour'].toString()) ?? 8, 
            minute: int.tryParse(profile['alarm_minute'].toString()) ?? 0
          );
        }
      });
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _pickFile(String metricKey, String displayName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'fit', 'tcx', 'gpx'],
      );

      if (result != null && result.files.single.path != null) {
        final profile = await _profileService.loadProfile();
        profile[metricKey] = result.files.single.path!;
        await _profileService.saveProfile(profile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$displayName file added to profile!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showConnectDialog(String metricName) {
    if (metricName == 'BIOMETRIC TELEMETRY') {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF2E5C4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('Select Biometric Type', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCategoryButton('ECG', () {
                  Navigator.pop(context); 
                  _startBluetoothScan('ECG Sensor'); 
                }),
                _buildCategoryButton('HRV', () {
                  Navigator.pop(context);
                  _startBluetoothScan('HRV Sensor');
                }),
                _buildCategoryButton('SpO₂', () {
                  Navigator.pop(context);
                  _startBluetoothScan('SpO2 Sensor');
                }),
                _buildCategoryButton('BPM', () {
                  Navigator.pop(context);
                  _startBluetoothScan('BPM Sensor');
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: GoogleFonts.montserrat(color: Colors.black54, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      );
    } else {
      _startBluetoothScan('$metricName Sensor');
    }
  }

  Widget _buildCategoryButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A843),
          minimumSize: const Size(double.infinity, 45),
        ),
        child: Text(label, style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _startBluetoothScan(String targetDeviceName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF2E5C4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD4A843)),
            const SizedBox(height: 20),
            Text("Scanning for $targetDeviceName...", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      List<BleDevice> foundDevices = [];
      final subscription = _bluetoothService.scanForDevices().listen((device) {
        if (!foundDevices.any((d) => d.deviceId == device.deviceId)) {
          foundDevices.add(device);
        }
      });

      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();
      await _bluetoothService.stopScan();

      if (!mounted) return;
      Navigator.pop(context); 

      if (foundDevices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Bluetooth devices found nearby.'), backgroundColor: Colors.orange),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF2E5C4),
            title: Text('Select Physical Device', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: foundDevices.length,
                itemBuilder: (context, index) {
                  final device = foundDevices[index];
                  final displayName = (device.name == null || device.name!.isEmpty) ? "Unknown Device" : device.name!;
                  
                  return ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    title: Text(displayName, style: GoogleFonts.montserrat()),
                    subtitle: Text(device.deviceId, style: const TextStyle(fontSize: 10)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _connectToDevice(device);
                    },
                  );
                },
              ),
            ),
          );
        },
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _connectToDevice(BleDevice device) async {
    try {
      await _bluetoothService.connect(device);
      
      if (mounted) {
        final displayName = (device.name == null || device.name!.isEmpty) ? "Device" : device.name!;
        
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E5C4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 30),
                  const SizedBox(width: 10),
                  Text('Connected!', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Successfully connected to $displayName.\n\nYou can now view live data in the Telemetry pages.',
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK', style: GoogleFonts.montserrat(color: const Color(0xFFD4A843), fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
        setState(() {}); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTimeAndDateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF2E5C4).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('TIME & DATE SETTINGS', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black87)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleRow('MET', _showMET, (val) {
                      setDialogState(() => _showMET = val);
                      setState(() => _showMET = val);
                  }),
                  const Divider(),
                  _buildToggleRow('TIMEZONE', _showTimezone, (val) {
                      setDialogState(() => _showTimezone = val);
                      setState(() => _showTimezone = val);
                  }),
                  if (_showTimezone)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8)),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          underline: const SizedBox(),
                          value: _selectedTimezone,
                          items: ['UTC', 'EST (UTC-5)', 'CST (UTC-6)', 'PST (UTC-8)', 'GMT (UTC+0)']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => _selectedTimezone = val);
                              setState(() => _selectedTimezone = val);
                            }
                          },
                        ),
                      ),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ALARM TIME', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _alarmTime);
                          if (picked != null) {
                            setDialogState(() => _alarmTime = picked);
                            setState(() => _alarmTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                          child: Text(_alarmTime.format(context), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildToggleRow('PLAY ALARM AT CHOSEN TIME', _alarmEnabled, (val) {
                      setDialogState(() => _alarmEnabled = val);
                      setState(() => _alarmEnabled = val);
                  }),
                  // ✅ ADDED A TEST BUTTON
                  TextButton(
                    onPressed: () {
                      final testTime = DateTime.now().add(const Duration(minutes: 1));
                      setDialogState(() {
                        _alarmTime = TimeOfDay(hour: testTime.hour, minute: testTime.minute);
                        _alarmEnabled = true;
                      });
                      setState(() {
                        _alarmTime = TimeOfDay(hour: testTime.hour, minute: testTime.minute);
                        _alarmEnabled = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Test Alarm set for ${_alarmTime.format(context)} (1 min from now).'), backgroundColor: Colors.blue)
                      );
                    },
                    child: Text('SET ALARM TO +1 MINUTE (TEST)', style: GoogleFonts.montserrat(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CLOSE', style: GoogleFonts.montserrat(color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () async {
                    final profile = await _profileService.loadProfile();
                    profile['show_met'] = _showMET;
                    profile['show_timezone'] = _showTimezone;
                    profile['timezone'] = _selectedTimezone;
                    profile['alarm_hour'] = _alarmTime.hour;
                    profile['alarm_minute'] = _alarmTime.minute;
                    profile['alarm_enabled'] = _alarmEnabled;
                    
                    await _profileService.saveProfile(profile);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Time & Date preferences saved!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: Text('SAVE', style: GoogleFonts.montserrat(color: const Color(0xFFD4A843), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
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
                'assets/images/settings background.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF4A4234)),
              ),

              Positioned(
                left: 120, top: 40, bottom: 40,
                child: SizedBox(
                  width: 250,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const CircleAvatar(
                          radius: 60,
                          backgroundColor: Color(0xFF2A1500),
                          child: Icon(Icons.person, size: 80, color: Colors.white),
                        ),
                        const SizedBox(height: 30),
                        _buildProfileField('NAME', _name),
                        const SizedBox(height: 12),
                        _buildProfileField('GENDER', _gender),
                        const SizedBox(height: 12),
                        _buildProfileField('AGE', _age),
                        const SizedBox(height: 40),
                        _buildGreyButton('BODY COMP', 'body_comp_source_file'),
                        const SizedBox(height: 15),
                        _buildGreyButton('HEIGHT', 'height_source_file'),
                        
                        const SizedBox(height: 40),
                        
                        GestureDetector(
                          onTap: _showTimeAndDateDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1500),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'TIME &\nDATE', 
                              textAlign: TextAlign.center, 
                              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        ElevatedButton(
                          onPressed: () async {
                            bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFFF2E5C4),
                                title: Text('Reset App?', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                                content: Text('This will delete all your profile data, uploaded files, and logs. Are you sure?', style: GoogleFonts.montserrat()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.black54)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text('RESET', style: GoogleFonts.montserrat(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _profileService.clearAllAppData();
                              if (!context.mounted) return;
                              
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const OnboardingPage()), 
                                (Route<dynamic> route) => false,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('RESET APP DATA', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 450, right: 40, top: 40, bottom: 40,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A843),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('SETTINGS', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF2A1500), letterSpacing: 2)),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E5C4).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildConnectorRow('SLEEP', true, 'sleep_source_file')),
                                const SizedBox(width: 15),
                                Expanded(child: _buildConnectorRow('MOVEMENT', true, 'movement_source_file')),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(child: _buildConnectorRow('NUTRITION', true, 'nutrition_source_file')),
                                const SizedBox(width: 15),
                                Expanded(child: _buildConnectorRow('MENSTRUAL\nCYCLE', true, 'menstrual_source_file')),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: _buildConnectorRow('BIOMETRIC TELEMETRY', false, 'biometric_source_file')),
                                const SizedBox(width: 15),
                                const SizedBox(width: 180), 
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(child: _buildConnectorRow('BIOMARKER REGISTRY', false, 'biomarker_source_file')),
                                const SizedBox(width: 15),
                                _buildRedBox('RADIATION', 'radiation_source_file'),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(child: _buildConnectorRow('ENVIRONMENTAL TELEMETRY', false, 'environmental_source_file')),
                                const SizedBox(width: 15),
                                _buildRedBox('ALTERED\nGRAVITY', 'microgravity_source_file'),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(child: _buildConnectorRow('BEHAVIORAL DATA', false, 'behavioral_source_file')),
                                const SizedBox(width: 15),
                                const SizedBox(width: 180),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 40, right: 40,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {}, 
                      icon: const Icon(Icons.settings, color: Color(0xFFD4A843), size: 45),
                    ),
                    const SizedBox(width: 15),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToDashboard,
                        borderRadius: BorderRadius.circular(30),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: const Icon(Icons.home, color: Color(0xFFD4A843), size: 45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 40, right: 40,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goToDashboard,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8D5A0),
                        border: Border.all(color: const Color(0xFFD4A843), width: 3),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFD96C6C), size: 30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Container(
      height: 45,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFF2E5C4), borderRadius: BorderRadius.circular(8)),
      child: Center(
        child: Text(
          value.isEmpty ? label : value,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: value.isEmpty ? Colors.black54 : Colors.black, letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _buildGreyButton(String label, String fileKey) {
    return GestureDetector(
      onTap: () => _pickFile(fileKey, label),
      child: Container(
        height: 50, width: double.infinity,
        decoration: BoxDecoration(color: const Color(0xFFA8A9AD), borderRadius: BorderRadius.circular(8)), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
        Switch(
          value: value, 
          onChanged: onChanged, 
          activeThumbColor: const Color(0xFFD4A843),
        ),
      ],
    );
  }

  Widget _buildConnectorRow(String label, bool isGridItem, String fileKey) {
    final bgColor = isGridItem ? const Color(0xFFE8D5A0) : const Color(0xFFD4A843);
    final displayName = label.replaceAll('\n', ' '); 
    final isConnected = _bluetoothService.isConnected;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(10),
        border: isConnected ? Border.all(color: Colors.green, width: 2) : null, 
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _pickFile(fileKey, displayName),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2A1500), size: 20),
            tooltip: 'Upload File',
          ),
          IconButton(
            onPressed: () => _showConnectDialog(displayName),
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.link,
              color: isConnected ? Colors.green.shade800 : const Color(0xFF2A1500), 
              size: 20
            ),
            tooltip: 'Connect Device',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2A1500), letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedBox(String label, String fileKey) {
    final displayName = label.replaceAll('\n', ' ');
    return Container(
      width: 180, height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFFE57373), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _pickFile(fileKey, displayName),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2A1500), size: 20),
            tooltip: 'Upload File',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.link, color: Color(0xFF2A1500), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2A1500), letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}