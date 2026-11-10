import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _driverController;
  late TextEditingController _passwordController;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Figma Notification Toggles
  bool _notifyFlags = true;
  bool _notifyRadio = true;
  bool _notifyPit = true;
  bool _notifyNews = false;

  // Figma Units & Display Preferences
  bool _isCelsius = true;
  bool _isKph = true;
  bool _comfortableTiming = false;
  bool _reduceMotion = false;
  bool _highContrast = false;

  // Figma Experience Toggles
  bool _haptics = true;
  bool _dataSaver = false;
  bool _autoPlayRadio = true;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.name ?? '');
    _driverController = TextEditingController(text: authState.favouriteDriver ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _driverController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await ref.read(authProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          favouriteDriver: _driverController.text.trim(),
          newPassword: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) {
          _successMessage = 'Profile updated successfully!';
          _passwordController.clear();
        } else {
          _errorMessage = ref.read(authProvider).errorMessage ?? 'Failed to update profile';
        }
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141419),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Formula1',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
        _successMessage = null;
      });
      final success = await ref.read(authProvider.notifier).deleteAccount();
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          context.go('/onboarding');
        } else {
          setState(() {
            _errorMessage = ref.read(authProvider).errorMessage ?? 'Failed to delete account';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final currentTeam = themeState.selectedTeam;

    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: DSAppBar(
        subtitle: 'PIT LANE SETTINGS',
        isLive: false,
        latencyMs: '12',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            DSWidgets.leftAccentCard(
              accent: accentColor,
              bgColor: DS.surface1,
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: DS.aeroCornerSm,
                      border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (authState.name?.isNotEmpty == true ? authState.name![0] : 'A').toUpperCase(),
                      style: DS.display(size: 20, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authState.name ?? 'DRIVER', style: DS.headline(size: 15)),
                        Text(authState.email ?? '', style: DS.body(size: 11)),
                        const SizedBox(height: 4),
                        DSWidgets.statusChip(authState.favouriteTeam ?? 'F1 TEAM', color: accentColor, size: 8),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 18, color: DS.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 12, color: DS.teal),
                  const SizedBox(width: 4),
                  Text('APEX TELEMETRY PRO', style: DS.labelCaps(size: 8, color: DS.teal)),
                  const Spacer(),
                  Text('VIP PADDOCK PASS', style: DS.labelCaps(size: 8, color: DS.orange)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---------------------------------------------------
            // SECTION 1: FAVORITE TEAM
            // ---------------------------------------------------
            _buildSectionHeader(
              'Favorite Team',
              currentTeam.name.toUpperCase(),
              accentColor,
            ),
            const SizedBox(height: 10),

            // Horizontal scrolling team pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Neutral pill
                  GestureDetector(
                    onTap: () {
                      ref.read(themeProvider.notifier).selectTeam(F1Team.ferrari);
                      ref.read(authProvider.notifier).updateFavouriteTeam('Neutral');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141419),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF202028),
                          width: 1.2,
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('—', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text(
                            'NEUTRAL',
                            style: TextStyle(
                              fontFamily: 'Formula1Wide',
                              fontSize: 7.5,
                              color: Color(0xFF8F909A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // All 11 2026 constructors
                  ...F1Team.values.map((team) {
                    final isSelected = currentTeam == team;
                    final teamMeta = getTeamData(team.name);
                    final mark = teamMeta?.slug.substring(0, 2).toUpperCase() ?? team.name.substring(0, 2).toUpperCase();

                    return GestureDetector(
                      onTap: () {
                        ref.read(themeProvider.notifier).selectTeam(team);
                        ref.read(authProvider.notifier).updateFavouriteTeam(team.name);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? team.primaryColor.withValues(alpha: 0.18)
                              : const Color(0xFF141419),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? team.primaryColor : const Color(0xFF202028),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mark,
                              style: TextStyle(
                                fontFamily: 'Formula1Wide',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? team.primaryColor : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              team.name.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 8,
                                color: isSelected ? team.primaryColor : const Color(0xFF8F909A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your team color personalizes selected states and highlights without changing safety-critical flag colors.',
              style: TextStyle(color: Color(0xFF8F909A), fontSize: 11, height: 1.35),
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------
            // SECTION 2: RACE NOTIFICATIONS
            // ---------------------------------------------------
            _buildSectionHeader('Race Notifications', 'DEVICE', const Color(0xFF00E5FF)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    'Flag changes',
                    'Red flags, safety cars and cautions',
                    _notifyFlags,
                    (val) => setState(() => _notifyFlags = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'Team radio',
                    'New messages from selected drivers',
                    _notifyRadio,
                    (val) => setState(() => _notifyRadio = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'Pit stops',
                    'Strategy calls and pit windows',
                    _notifyPit,
                    (val) => setState(() => _notifyPit = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'Paddock news',
                    'Breaking stories and technical analysis',
                    _notifyNews,
                    (val) => setState(() => _notifyNews = val),
                    accentColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------
            // SECTION 3: UNITS & DISPLAY
            // ---------------------------------------------------
            _buildSectionHeader('Units & Display', 'METRIC', const Color(0xFFFFD600)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Column(
                children: [
                  // Temperature Unit Switch
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temperature',
                              style: TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Weather and track conditions',
                              style: TextStyle(color: Color(0xFF8F909A), fontSize: 11),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F13),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF202028)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildUnitPill('°C', _isCelsius, () => setState(() => _isCelsius = true)),
                              _buildUnitPill('°F', !_isCelsius, () => setState(() => _isCelsius = false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),

                  // Speed Unit Switch
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speed',
                              style: TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Onboard telemetry speeds',
                              style: TextStyle(color: Color(0xFF8F909A), fontSize: 11),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F13),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF202028)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildUnitPill('KM/H', _isKph, () => setState(() => _isKph = true)),
                              _buildUnitPill('MPH', !_isKph, () => setState(() => _isKph = false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),

                  _buildToggleRow(
                    'Comfortable timing',
                    'Increase timing tower row height',
                    _comfortableTiming,
                    (val) => setState(() => _comfortableTiming = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'Reduce motion',
                    'Disable live pulses and waveform motion',
                    _reduceMotion,
                    (val) => setState(() => _reduceMotion = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'High contrast',
                    'Strengthen borders and secondary copy',
                    _highContrast,
                    (val) => setState(() => _highContrast = val),
                    accentColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------
            // SECTION 4: EXPERIENCE
            // ---------------------------------------------------
            _buildSectionHeader('Experience', 'ON DEVICE', const Color(0xFF00E676)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    'Haptic feedback',
                    'Tactile response for race alerts and sector times',
                    _haptics,
                    (val) => setState(() => _haptics = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'Data saver',
                    'Reduce nonessential image loading on mobile networks',
                    _dataSaver,
                    (val) => setState(() => _dataSaver = val),
                    accentColor,
                  ),
                  const Divider(color: Color(0xFF202028), height: 1),
                  _buildToggleRow(
                    'Auto-play radio',
                    'Animate new radio messages as received',
                    _autoPlayRadio,
                    (val) => setState(() => _autoPlayRadio = val),
                    accentColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------
            // SECTION 5: USER PROFILE & ACCOUNT
            // ---------------------------------------------------
            _buildSectionHeader('User Account', 'PROFILE', Colors.white70),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00E676)),
                        ),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(color: Color(0xFF8F909A), fontSize: 12),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF202028))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'New Password (leave empty to keep current)',
                        labelStyle: const TextStyle(color: Color(0xFF8F909A), fontSize: 12),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF202028))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
                      ),
                      validator: (val) {
                        if (val != null && val.isNotEmpty && val.length < 6) {
                          return 'Password must be at least 6 characters long';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                              )
                            : const Text(
                                'SAVE PROFILE',
                                style: TextStyle(
                                  fontFamily: 'Formula1Wide',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Logout & Delete Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/onboarding');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF202028)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text(
                      'LOG OUT',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _deleteAccount,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text(
                      'DELETE ACCOUNT',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------
            // SECTION 7: ABOUT CARD
            // ---------------------------------------------------
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF202028)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'A',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APEX F1 · PROTOTYPE 1.0',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 9,
                            color: Color(0xFF8F909A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'SIMULATED DATA DISCLOSURE',
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Timing, standings, predictions and radio streams are illustrative. Not affiliated with Formula 1.',
                          style: TextStyle(color: Color(0xFF8F909A), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String meta, Color metaColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Formula1',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: metaColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            meta,
            style: TextStyle(
              fontFamily: 'Formula1Wide',
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: metaColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color activeColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Formula1',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF8F909A), fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildUnitPill(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Formula1Wide',
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: isSelected ? const Color(0xFF09090C) : const Color(0xFF8F909A),
          ),
        ),
      ),
    );
  }
}
