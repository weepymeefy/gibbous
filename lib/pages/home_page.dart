import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/profile_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _massCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _selectedGender = '';
  String _massUnit = 'kg';
  String _heightUnit = 'cm';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _massCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndGo(String route) async {
    if (_nameCtrl.text.trim().isEmpty ||
        _selectedGender.isEmpty ||
        _ageCtrl.text.trim().isEmpty ||
        _massCtrl.text.trim().isEmpty ||
        _heightCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill in all fields.',
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFFD4A843),
      ));
      return;
    }
    setState(() => _loading = true);
    await ProfileService().saveProfile({
      'name': _nameCtrl.text.trim(),
      'gender': _selectedGender,
      'age': _ageCtrl.text.trim(),
      'body_mass': '${_massCtrl.text.trim()} $_massUnit',
      'height': '${_heightCtrl.text.trim()} $_heightUnit',
    });
    setState(() => _loading = false);
    if (mounted) Navigator.pushReplacementNamed(context, route);
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
              // Background with GIBBOUS title
              Image.asset(
                'assets/images/homepage bg with title.png',
                fit: BoxFit.cover,
              ),

              // Centered form + arrow
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Form card
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Card background
                        Image.asset(
                          'assets/images/cream transparent text box big.png',
                          width: 320,
                          fit: BoxFit.fitWidth,
                        ),
                        // Fields
                        SizedBox(
                          width: 270,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 20),
                              Text(
                                'PRE MISSION DETAILS',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF3D2200),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _field(_nameCtrl, 'NAME'),
                              const SizedBox(height: 7),
                              _genderField(),
                              const SizedBox(height: 7),
                              _field(_ageCtrl, 'AGE',
                                  type: TextInputType.number),
                              const SizedBox(height: 7),
                              _unitField(
                                _massCtrl,
                                'BODY MASS',
                                _massUnit,
                                ['kg', 'lbs'],
                                (v) => setState(() => _massUnit = v),
                              ),
                              const SizedBox(height: 7),
                              _unitField(
                                _heightCtrl,
                                'HEIGHT',
                                _heightUnit,
                                ['cm', 'in'],
                                (v) => setState(() => _heightUnit = v),
                              ),
                              const SizedBox(height: 14),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _saveAndGo('/settings'),
                                  child: Text(
                                    'ADD BASELINE DATA',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8B4513),
                                      letterSpacing: 1.5,
                                      decoration: TextDecoration.underline,
                                      decorationColor:
                                          const Color(0xFF8B4513),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 40),

                    // Arrow button
                    _loading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFD4A843))
                        : MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _saveAndGo('/dashboard'),
                              child: Image.asset(
                                'assets/images/next page button.png',
                                width: 85,
                                height: 85,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Plain field
  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType type = TextInputType.text}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/cream text box opaque small.png',
          width: 260,
          height: 34,
          fit: BoxFit.fill,
        ),
        SizedBox(
          width: 240,
          height: 34,
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF2A1500),
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                color: const Color(0xFF8A7050),
                letterSpacing: 2,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // Field with kg/lbs or cm/in toggle
  Widget _unitField(
    TextEditingController ctrl,
    String hint,
    String selectedUnit,
    List<String> units,
    Function(String) onChanged,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/cream text box opaque small.png',
          width: 260,
          height: 34,
          fit: BoxFit.fill,
        ),
        SizedBox(
          width: 240,
          height: 34,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF2A1500),
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF8A7050),
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              ...units.map((u) {
                final sel = u == selectedUnit;
                return GestureDetector(
                  onTap: () => onChanged(u),
                  child: Container(
                    margin: const EdgeInsets.only(right: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFD4A843)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      u,
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? const Color(0xFF1A0F00)
                            : const Color(0xFF8A7050),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Gender dropdown
  Widget _genderField() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/cream text box opaque small.png',
          width: 260,
          height: 34,
          fit: BoxFit.fill,
        ),
        SizedBox(
          width: 240,
          height: 34,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender.isEmpty ? null : _selectedGender,
              isExpanded: true,
              hint: Center(
                child: Text(
                  'GENDER',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF8A7050),
                    letterSpacing: 2,
                  ),
                ),
              ),
              icon: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFF8A7050), size: 16),
              ),
              dropdownColor: const Color(0xFFE8D5A0),
              borderRadius: BorderRadius.circular(10),
              items: ['MALE', 'FEMALE']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Center(
                          child: Text(g,
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFF2A1500),
                                letterSpacing: 2,
                              )),
                        ),
                      ))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedGender = val ?? ''),
            ),
          ),
        ),
      ],
    );
  }
}