import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../../../shared/constants/countries.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';

enum OnboardingStep { details, selectTeam, selectDriver, celebration }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.details;
  bool _isLoginMode = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePassword = true;
  CountryTz? _selectedCountry;

  F1Team? _selectedTeam;

  DriverData2026? _primaryDriver;
  DriverData2026? _rivalDriver;
  bool _showAllRivals = false;

  String _registeredName = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _currentStepIndex {
    switch (_step) {
      case OnboardingStep.details: return 0;
      case OnboardingStep.selectTeam: return 1;
      case OnboardingStep.selectDriver: return 2;
      case OnboardingStep.celebration: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _selectedTeam?.primaryColor ?? DS.red;
    return Scaffold(
      backgroundColor: DS.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(accentColor),
            if (!_isLoginMode) _buildStepIndicator(accentColor),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(context, accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: DS.surface0,
        border: Border(bottom: BorderSide(color: DS.outline)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 24, color: DS.red),
          const SizedBox(width: 10),
          Row(children: [
            Text('APEX', style: DS.driverCode(size: 14, color: DS.textPrimary)),
            const SizedBox(width: 4),
            DSWidgets.redBadge('F1', size: 9),
          ]),
          const SizedBox(width: 10),
          Container(width: 1, height: 20, color: DS.outline),
          const SizedBox(width: 10),
          Text(
            _isLoginMode ? 'DRIVER SIGN IN' : 'SUPERLICENSE APPLICATION',
            style: DS.labelCaps(size: 8, color: DS.textMuted),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _isLoginMode = !_isLoginMode;
              _step = OnboardingStep.details;
            }),
            child: DSWidgets.statusChip(
              _isLoginMode ? 'REGISTER' : 'SIGN IN',
              color: DS.teal,
              size: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(Color accentColor) {
    final steps = ['DETAILS', 'TEAM', 'DRIVERS', 'LICENSE'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: DS.surface0,
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final label = e.value;
          final isDone = i < _currentStepIndex;
          final isActive = i == _currentStepIndex;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: isDone || isActive ? accentColor : DS.outline,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: DS.labelCaps(
                          size: 7,
                          color: isActive
                              ? accentColor
                              : isDone
                                  ? DS.textMuted
                                  : DS.surface4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, Color accentColor) {
    switch (_step) {
      case OnboardingStep.details:
        return _buildDetailsStep(context, accentColor);
      case OnboardingStep.selectTeam:
        return _buildTeamStep(context, accentColor);
      case OnboardingStep.selectDriver:
        return _buildDriverStep(context, accentColor);
      case OnboardingStep.celebration:
        return _buildCelebrationStep(context, accentColor);
    }
  }

  // ─── STEP 1: DETAILS ────────────────────────────────────────────────────────

  Widget _buildDetailsStep(BuildContext context, Color accentColor) {
    final authState = ref.watch(authProvider);
    return SingleChildScrollView(
      key: const ValueKey('details'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 3, height: 20, color: accentColor),
            const SizedBox(width: 10),
            Text(
              _isLoginMode ? 'BACK ON TRACK' : 'DRIVER CREDENTIALS',
              style: DS.headline(size: 20),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _isLoginMode
                ? 'Enter your FIA registered credentials.'
                : 'Your personal details for the Superlicense.',
            style: DS.body(size: 12),
          ),
          const SizedBox(height: 24),

          if (!_isLoginMode) ...[
            DSWidgets.inputField(
              label: 'DRIVER NAME',
              hint: 'Your display name',
              controller: _nameCtrl,
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
          ],
          DSWidgets.inputField(
            label: 'EMAIL ADDRESS',
            hint: 'fia@registered.com',
            controller: _emailCtrl,
            prefixIcon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          DSWidgets.inputField(
            label: 'PASSWORD',
            hint: '••••••••',
            controller: _passwordCtrl,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            prefixIcon: Icons.lock_outline,
          ),

          if (!_isLoginMode) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showCountrySheet(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DS.surface2,
                  borderRadius: DS.aeroCorner,
                  border: Border.all(color: DS.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language_outlined, size: 18, color: DS.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _selectedCountry != null
                          ? Row(children: [
                              Text(_selectedCountry!.flag,
                                  style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(_selectedCountry!.name,
                                  style: DS.body(size: 13, color: DS.textPrimary)),
                              const SizedBox(width: 6),
                              Text(
                                _fmtUtc(_selectedCountry!.utcOffset),
                                style: DS.labelCaps(size: 8, color: DS.teal),
                              ),
                            ])
                          : Text('SELECT YOUR COUNTRY',
                              style: DS.labelCaps(size: 9, color: DS.textMuted)),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: DS.textMuted),
                  ],
                ),
              ),
            ),
          ],

          if (authState.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DS.red.withValues(alpha: 0.1),
                borderRadius: DS.aeroCornerSm,
                border: Border.all(color: DS.red.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, size: 14, color: DS.red),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(authState.errorMessage!,
                        style: DS.labelCaps(size: 9, color: DS.red))),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  authState.isLoading ? null : () => _handleDetailsNext(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                elevation: 0,
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : Text(
                      _isLoginMode ? 'AUTHENTICATE ▶' : 'NEXT: SELECT TEAM ▶',
                      style: DS.labelCaps(size: 11, color: Colors.black),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtUtc(double offset) {
    final sign = offset >= 0 ? '+' : '';
    final formatted =
        offset % 1 == 0 ? offset.toInt().toString() : offset.toString();
    return 'UTC$sign$formatted';
  }

  Future<void> _handleDetailsNext(BuildContext context) async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) return;
    if (_isLoginMode) {
      final ok = await ref
          .read(authProvider.notifier)
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (ok && mounted) context.go('/');
    } else {
      if (_nameCtrl.text.trim().isEmpty) return;
      setState(() => _step = OnboardingStep.selectTeam);
    }
  }

  Future<void> _showCountrySheet(BuildContext context) async {
    final searchCtrl = TextEditingController();
    List<CountryTz> filtered = kCountries;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      backgroundColor: DS.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(children: [
                  Container(width: 3, height: 20, color: DS.teal),
                  const SizedBox(width: 10),
                  Text('SELECT COUNTRY', style: DS.headline(size: 15)),
                  const Spacer(),
                  GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close, size: 18, color: DS.textMuted)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchCtrl,
                  style: DS.telemetry(size: 13),
                  onChanged: (v) => ss(() {
                    filtered = kCountries
                        .where((c) =>
                            c.name.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search country...',
                    hintStyle: DS.labelCaps(size: 9, color: DS.textMuted),
                    prefixIcon: Icon(Icons.search, size: 18, color: DS.textMuted),
                    filled: true,
                    fillColor: DS.surface2,
                    border: OutlineInputBorder(
                        borderRadius: DS.aeroCorner,
                        borderSide: BorderSide(color: DS.outline)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: DS.aeroCorner,
                        borderSide: BorderSide(color: DS.outline)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: DS.aeroCorner,
                        borderSide: BorderSide(color: DS.teal)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final isSelected = _selectedCountry?.name == c.name;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedCountry = c);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DS.teal.withValues(alpha: 0.1)
                              : DS.surface2,
                          borderRadius: DS.aeroCornerSm,
                          border: Border.all(
                              color: isSelected
                                  ? DS.teal.withValues(alpha: 0.5)
                                  : DS.outline),
                        ),
                        child: Row(children: [
                          Text(c.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(c.name,
                                  style: DS.body(
                                      size: 13,
                                      color: isSelected
                                          ? DS.teal
                                          : DS.textPrimary))),
                          Text(_fmtUtc(c.utcOffset),
                              style: DS.labelCaps(size: 8, color: DS.textMuted)),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle, size: 16, color: DS.teal)
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ─── STEP 2: SELECT TEAM ─────────────────────────────────────────────────────

  Widget _buildTeamStep(BuildContext context, Color accentColor) {
    return SingleChildScrollView(
      key: const ValueKey('team'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 3, height: 20, color: DS.red),
            const SizedBox(width: 10),
            Text('SELECT CONSTRUCTOR', style: DS.headline(size: 20)),
          ]),
          const SizedBox(height: 4),
          Text('Choose your team allegiance.', style: DS.body(size: 12)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: F1Team.values.length,
            itemBuilder: (_, i) {
              final team = F1Team.values[i];
              final teamData = getTeamData(team.name);
              final isSelected = _selectedTeam == team;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedTeam = team;
                  _primaryDriver = null;
                  _rivalDriver = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? team.primaryColor.withValues(alpha: 0.15)
                        : DS.surface2,
                    borderRadius: DS.aeroCorner,
                    border: Border.all(
                      color: isSelected ? team.primaryColor : DS.outline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (teamData != null)
                        SvgPicture.asset(teamData.logoColorAsset,
                            height: 32,
                            colorFilter: isSelected
                                ? null
                                : const ColorFilter.mode(
                                    Color(0xFFAF8781), BlendMode.srcIn))
                      else
                        Icon(Icons.shield,
                            size: 32,
                            color: isSelected ? team.primaryColor : DS.textMuted),
                      const SizedBox(height: 6),
                      Text(team.name.toUpperCase(),
                          style: DS.labelCaps(
                              size: 7.5,
                              color: isSelected
                                  ? team.primaryColor
                                  : DS.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = OnboardingStep.details),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: DS.outline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                ),
                child:
                    Text('← BACK', style: DS.labelCaps(size: 10, color: DS.textMuted)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _selectedTeam == null
                    ? null
                    : () => setState(() => _step = OnboardingStep.selectDriver),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedTeam?.primaryColor ?? DS.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                  elevation: 0,
                ),
                child: Text('NEXT: PICK DRIVERS ▶',
                    style: DS.labelCaps(size: 10, color: Colors.black)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── STEP 3: SELECT DRIVERS ──────────────────────────────────────────────────

  Widget _buildDriverStep(BuildContext context, Color accentColor) {
    final teamDrivers =
        kDrivers2026List.where((d) => d.team == _selectedTeam!.name).toList();
    final allOthers = kDrivers2026List
        .where((d) => d.name != _primaryDriver?.name)
        .toList();
    final visibleRivals =
        _showAllRivals ? allOthers : allOthers.take(6).toList();
    final authState = ref.watch(authProvider);

    return SingleChildScrollView(
      key: const ValueKey('drivers'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 3, height: 20, color: accentColor),
            const SizedBox(width: 10),
            Text('SELECT DRIVERS', style: DS.headline(size: 20)),
          ]),
          const SizedBox(height: 4),
          Text('Pick your team driver and a rival to track.',
              style: DS.body(size: 12)),
          const SizedBox(height: 20),

          // Section A: team drivers
          Row(children: [
            Container(width: 2, height: 14, color: accentColor),
            const SizedBox(width: 8),
            Text('YOUR TEAM DRIVER',
                style: DS.labelCaps(size: 9, color: accentColor)),
          ]),
          const SizedBox(height: 10),
          Row(
            children: teamDrivers.map((driver) {
              final isSelected = _primaryDriver?.name == driver.name;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _primaryDriver = driver;
                    if (_rivalDriver?.name == driver.name) _rivalDriver = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.12)
                          : DS.surface2,
                      borderRadius: DS.aeroCorner,
                      border: Border.all(
                          color: isSelected ? accentColor : DS.outline,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected ? accentColor : DS.outline,
                                width: 2),
                            color: DS.surface3,
                          ),
                          child: ClipOval(
                            child: Image.asset(driver.portraitAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.person,
                                    color: DS.textMuted)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(driver.code,
                            style: DS.driverCode(
                                size: 14,
                                color: isSelected ? accentColor : DS.textPrimary)),
                        Text(driver.name.split(' ').last,
                            style: DS.body(size: 10, color: DS.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (isSelected) ...[
                          const SizedBox(height: 4),
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: accentColor, shape: BoxShape.circle)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Divider(color: DS.outline, thickness: 1),
          const SizedBox(height: 12),

          // Section B: rival driver
          Row(children: [
            Container(width: 2, height: 14, color: DS.orange),
            const SizedBox(width: 8),
            Text('TRACK RIVAL',
                style: DS.labelCaps(size: 9, color: DS.orange)),
            const SizedBox(width: 6),
            Text('(any team)', style: DS.body(size: 10)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...visibleRivals.map((driver) {
                final isSelected = _rivalDriver?.name == driver.name;
                final tc =
                    getTeamData(driver.team)?.primaryColor ?? DS.textMuted;
                return GestureDetector(
                  onTap: () => setState(() => _rivalDriver = driver),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tc.withValues(alpha: 0.12)
                          : DS.surface2,
                      borderRadius: DS.aeroCornerSm,
                      border: Border.all(
                          color: isSelected ? tc : DS.outline,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: DS.surface3),
                          child: ClipOval(
                            child: Image.asset(driver.portraitAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.person,
                                    size: 18,
                                    color: DS.textMuted)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver.code,
                                style: DS.labelCaps(
                                    size: 10,
                                    color:
                                        isSelected ? tc : DS.textPrimary)),
                            Text(
                                driver.team
                                    .split(' ')
                                    .first
                                    .toUpperCase(),
                                style: DS.labelCaps(
                                    size: 7, color: DS.textMuted)),
                          ],
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 14, color: tc),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              if (!_showAllRivals)
                GestureDetector(
                  onTap: () => setState(() => _showAllRivals = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: DS.surface2,
                      borderRadius: DS.aeroCornerSm,
                      border: Border.all(color: DS.outline),
                    ),
                    child: Text('ALL DRIVERS +',
                        style: DS.labelCaps(size: 9, color: DS.textMuted)),
                  ),
                ),
            ],
          ),

          if (authState.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DS.red.withValues(alpha: 0.1),
                borderRadius: DS.aeroCornerSm,
                border: Border.all(color: DS.red.withValues(alpha: 0.4)),
              ),
              child: Text(authState.errorMessage!,
                  style: DS.labelCaps(size: 9, color: DS.red)),
            ),
          ],

          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    setState(() => _step = OnboardingStep.selectTeam),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: DS.outline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                ),
                child: Text('← BACK',
                    style: DS.labelCaps(size: 10, color: DS.textMuted)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_primaryDriver == null ||
                        _rivalDriver == null ||
                        authState.isLoading)
                    ? null
                    : () => _handleRegister(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                  elevation: 0,
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : Text('ISSUE SUPERLICENSE ▶',
                        style: DS.labelCaps(size: 10, color: Colors.black)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _handleRegister(BuildContext context) async {
    final ok = await ref.read(authProvider.notifier).register(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
          _selectedTeam!.name,
          _primaryDriver!.name,
          country: _selectedCountry?.name,
          rivalDriver: _rivalDriver?.name,
        );
    if (ok && mounted) {
      setState(() {
        _registeredName = _nameCtrl.text.trim();
        _step = OnboardingStep.celebration;
      });
    }
  }

  // ─── STEP 4: CELEBRATION ─────────────────────────────────────────────────────

  Widget _buildCelebrationStep(BuildContext context, Color accentColor) {
    final teamData =
        _selectedTeam != null ? getTeamData(_selectedTeam!.name) : null;
    return SingleChildScrollView(
      key: const ValueKey('celebration'),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [DS.orange, DS.red, DS.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: DS.surface2),
              child: _primaryDriver != null
                  ? ClipOval(
                      child: Image.asset(_primaryDriver!.portraitAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.person, size: 40, color: DS.textMuted)))
                  : Icon(Icons.person, size: 40, color: DS.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          Text('SUPERLICENSE ISSUED',
              style: DS.display(size: 22, color: DS.teal)),
          const SizedBox(height: 4),
          Text('AUTH 100%', style: DS.labelCaps(size: 10, color: DS.orange)),
          const SizedBox(height: 20),
          DSWidgets.leftAccentCard(
            accent: accentColor,
            bgColor: DS.surface1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DRIVER',
                          style: DS.labelCaps(size: 8, color: DS.textMuted)),
                      if (_selectedCountry != null)
                        Text(_selectedCountry!.flag,
                            style: const TextStyle(fontSize: 16)),
                    ]),
                const SizedBox(height: 4),
                Text(_registeredName.toUpperCase(),
                    style: DS.headline(size: 18)),
                const SizedBox(height: 8),
                Row(children: [
                  if (teamData != null) ...[
                    SvgPicture.asset(teamData.logoColorAsset,
                        height: 20,
                        colorFilter:
                            ColorFilter.mode(accentColor, BlendMode.srcIn)),
                    const SizedBox(width: 8),
                  ],
                  Text(_selectedTeam?.name.toUpperCase() ?? '',
                      style: DS.labelCaps(size: 9, color: accentColor)),
                ]),
                if (_primaryDriver != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      '${_primaryDriver!.code} · ${_rivalDriver?.code ?? '--'}',
                      style: DS.telemetry(size: 11, color: DS.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape:
                    RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                elevation: 0,
              ),
              child: Text('ENTER THE PITWALL ▶',
                  style: DS.labelCaps(size: 11, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}
