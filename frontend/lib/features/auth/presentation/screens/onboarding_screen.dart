import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../../../shared/constants/countries.dart';

enum OnboardingStep { selectTeam, selectCountry, auth, celebration }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _currentStep = OnboardingStep.selectTeam;
  F1Team? _tempSelectedTeam;
  CountryTz? _selectedCountry;
  bool _isLoginMode = false;
  String _countrySearch = '';
  bool _obscurePassword = true;
  String _registeredName = '';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _countrySearchController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == OnboardingStep.selectTeam) {
      if (_tempSelectedTeam == null) return;
      setState(() => _currentStep = OnboardingStep.selectCountry);
    } else if (_currentStep == OnboardingStep.selectCountry) {
      setState(() => _currentStep = OnboardingStep.auth);
    }
  }

  void _backStep() {
    if (_currentStep == OnboardingStep.auth) {
      setState(() => _currentStep = OnboardingStep.selectCountry);
    } else if (_currentStep == OnboardingStep.selectCountry) {
      setState(() => _currentStep = OnboardingStep.selectTeam);
    }
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final teamName = _tempSelectedTeam?.name ?? 'Ferrari';

    bool success = false;
    if (_isLoginMode) {
      success = await ref.read(authProvider.notifier).login(email, password);
      if (success && mounted) context.go('/');
    } else {
      success = await ref.read(authProvider.notifier).register(
        email, password, name, teamName, '',
        country: _selectedCountry?.name,
      );
      if (success && mounted) {
        setState(() {
          _registeredName = name.isNotEmpty ? name : email.split('@').first;
          _currentStep = OnboardingStep.celebration;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final accent = _tempSelectedTeam?.primaryColor ?? DS.red;

    return Scaffold(
      backgroundColor: DS.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildStep(authState, accent),
        ),
      ),
    );
  }

  Widget _buildStep(AuthState authState, Color accent) {
    switch (_currentStep) {
      case OnboardingStep.selectTeam:
        return _TeamSelectStep(
          key: const ValueKey('team'),
          selectedTeam: _tempSelectedTeam,
          onTeamSelected: (t) => setState(() => _tempSelectedTeam = t),
          onNext: _nextStep,
        );
      case OnboardingStep.selectCountry:
        return _CountrySelectStep(
          key: const ValueKey('country'),
          selectedCountry: _selectedCountry,
          searchQuery: _countrySearch,
          searchController: _countrySearchController,
          accent: accent,
          onCountrySelected: (c) => setState(() => _selectedCountry = c),
          onSearchChanged: (v) => setState(() => _countrySearch = v),
          onNext: _nextStep,
          onBack: _backStep,
        );
      case OnboardingStep.auth:
        return _AuthStep(
          key: ValueKey('auth_$_isLoginMode'),
          isLoginMode: _isLoginMode,
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          nameController: _nameController,
          obscurePassword: _obscurePassword,
          selectedTeam: _tempSelectedTeam,
          selectedCountry: _selectedCountry,
          accent: accent,
          isLoading: authState.isLoading,
          errorMessage: authState.errorMessage,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          onToggleMode: () => setState(() => _isLoginMode = !_isLoginMode),
          onBack: _backStep,
          onSubmit: _submitAuth,
          onTeamChanged: (t) => setState(() => _tempSelectedTeam = t),
          onCountryTap: () => setState(() => _currentStep = OnboardingStep.selectCountry),
        );
      case OnboardingStep.celebration:
        return _CelebrationStep(
          key: const ValueKey('celebration'),
          driverName: _registeredName,
          team: _tempSelectedTeam,
          country: _selectedCountry,
          onEnter: () => context.go('/'),
        );
    }
  }
}

// ─── STEP 1 — TEAM SELECT ────────────────────────────────────────────────────

class _TeamSelectStep extends StatelessWidget {
  final F1Team? selectedTeam;
  final void Function(F1Team) onTeamSelected;
  final VoidCallback onNext;

  const _TeamSelectStep({
    super.key,
    required this.selectedTeam,
    required this.onTeamSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: DS.red,
                  borderRadius: DS.aeroCornerSm,
                ),
                child: Text('APEX', style: DS.driverCode(size: 12, color: DS.redText)),
              ),
              const SizedBox(width: 6),
              DSWidgets.redBadge('F1'),
            ],
          ),
          const SizedBox(height: 20),
          Text('CHOOSE YOUR', style: DS.labelCaps(size: 11, color: DS.textMuted)),
          const SizedBox(height: 4),
          Text('ALLEGIANCE', style: DS.display(size: 28)),
          const SizedBox(height: 4),
          Text(
            'Select your constructor. This sets your Pitwall theme and feed priority.',
            style: DS.body(size: 12),
          ),
          const SizedBox(height: 20),
          // Team grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.9,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: F1Team.values.length,
            itemBuilder: (context, i) {
              final team = F1Team.values[i];
              final isSelected = selectedTeam == team;
              final tc = team.primaryColor;
              // Get team abbreviation
              final teamData = kTeams2026[team.name];
              final chassis = teamData?.chassis ?? '';
              final teamCode = _teamCode(team);
              return GestureDetector(
                onTap: () => onTeamSelected(team),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? tc.withValues(alpha: 0.1) : DS.surface1,
                    borderRadius: DS.aeroCorner,
                    border: Border.all(
                      color: isSelected ? tc : DS.outline,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: tc,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(teamCode,
                                      style: DS.driverCode(size: 13, color: isSelected ? tc : DS.textPrimary)),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: tc, size: 14),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(team.name, style: DS.body(size: 10, color: DS.textVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (chassis.isNotEmpty)
                                Text(chassis, style: DS.labelCaps(size: 8, color: DS.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: GestureDetector(
              onTap: selectedTeam != null ? onNext : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedTeam != null ? DS.red : DS.surface3,
                  borderRadius: DS.aeroCorner,
                ),
                alignment: Alignment.center,
                child: Text(
                  'CONFIRM ALLEGIANCE  →',
                  style: DS.driverCode(
                    size: 14,
                    color: selectedTeam != null ? DS.redText : DS.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _teamCode(F1Team team) {
    switch (team) {
      case F1Team.ferrari: return 'SF';
      case F1Team.mclaren: return 'MCL';
      case F1Team.mercedes: return 'AMG';
      case F1Team.redBull: return 'RBR';
      case F1Team.alpine: return 'ALP';
      case F1Team.astonMartin: return 'AMR';
      case F1Team.williams: return 'WIL';
      case F1Team.haas: return 'HAS';
      case F1Team.audi: return 'ADI';
      case F1Team.rb: return 'VCARB';
      case F1Team.cadillac: return 'CAD';
    }
  }
}

// ─── STEP 2 — COUNTRY SELECT ─────────────────────────────────────────────────

class _CountrySelectStep extends StatelessWidget {
  final CountryTz? selectedCountry;
  final String searchQuery;
  final TextEditingController searchController;
  final Color accent;
  final void Function(CountryTz) onCountrySelected;
  final void Function(String) onSearchChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _CountrySelectStep({
    super.key,
    required this.selectedCountry,
    required this.searchQuery,
    required this.searchController,
    required this.accent,
    required this.onCountrySelected,
    required this.onSearchChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = kCountries
        .where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        // Header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(Icons.chevron_left_rounded, color: accent, size: 26),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RACE CONTROL TIME SYNC',
                        style: DS.labelCaps(size: 9, color: DS.textMuted)),
                    Text('SELECT YOUR LOCATION', style: DS.headline(size: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: DS.surface2,
              borderRadius: DS.aeroCorner,
              border: Border.all(color: DS.outline),
            ),
            child: TextField(
              controller: searchController,
              style: DS.telemetry(size: 13),
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'SEARCH CIRCUIT NATION...',
                hintStyle: DS.telemetry(size: 12, color: DS.textMuted),
                prefixIcon: const Icon(Icons.search, color: DS.textMuted, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final c = filtered[i];
              final isSelected = selectedCountry?.name == c.name;
              return GestureDetector(
                onTap: () => onCountrySelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.08) : DS.surface1,
                    borderRadius: DS.aeroCorner,
                    border: Border.all(
                      color: isSelected ? accent : DS.outline,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(c.name, style: DS.headlineMd(size: 13)),
                      ),
                      DSWidgets.statusChip(
                        'UTC${c.utcOffset >= 0 ? '+' : ''}${c.utcOffset == c.utcOffset.truncateToDouble() ? c.utcOffset.toInt() : c.utcOffset} ${c.abbr}',
                        color: isSelected ? accent : DS.teal,
                        size: 8,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_rounded, color: accent, size: 16),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Continue button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: GestureDetector(
              onTap: onNext,
              child: Container(
                decoration: BoxDecoration(
                  color: DS.red,
                  borderRadius: DS.aeroCorner,
                ),
                alignment: Alignment.center,
                child: Text(
                  selectedCountry != null
                      ? 'SYNC ${selectedCountry!.name.toUpperCase()}  →'
                      : 'SKIP — SET LATER  →',
                  style: DS.driverCode(size: 13, color: DS.redText),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── STEP 3 — AUTH (LOGIN + REGISTER) ────────────────────────────────────────

class _AuthStep extends StatelessWidget {
  final bool isLoginMode;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final bool obscurePassword;
  final F1Team? selectedTeam;
  final CountryTz? selectedCountry;
  final Color accent;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final void Function(F1Team) onTeamChanged;
  final VoidCallback onCountryTap;

  const _AuthStep({
    super.key,
    required this.isLoginMode,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.obscurePassword,
    required this.selectedTeam,
    required this.selectedCountry,
    required this.accent,
    required this.isLoading,
    required this.errorMessage,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onBack,
    required this.onSubmit,
    required this.onTeamChanged,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    return isLoginMode ? _buildLogin(context) : _buildRegister(context);
  }

  Widget _buildLogin(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero section ──────────────────────────────────────────────────
          _LoginHero(),
          // ── Form card ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DS.surface1,
                      borderRadius: DS.aeroCorner,
                      border: Border.all(color: DS.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left bar
                        Container(
                          height: 2,
                          width: 32,
                          color: DS.red,
                          margin: const EdgeInsets.only(bottom: 10),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('AUTHENTICATE DRIVER',
                                style: DS.headline(size: 16)),
                            DSWidgets.statusChip('SEC-LVL 1',
                                color: DS.surface4),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter paddock credentials to synchronize live pitwall telemetry.',
                          style: DS.body(size: 12),
                        ),
                        const SizedBox(height: 16),
                        // Email
                        DSWidgets.inputField(
                          label: 'EMAIL IDENTIFIER // MONO ID',
                          rightLabel: 'SYS_ID',
                          controller: emailController,
                          prefixIcon: Icons.mail_outline_rounded,
                          hint: 'driver@scuderia.f1',
                          keyboardType: TextInputType.emailAddress,
                          underlineColor: DS.red,
                          validator: (v) => v == null || v.isEmpty || !v.contains('@')
                              ? 'Valid email required' : null,
                        ),
                        const SizedBox(height: 14),
                        // Password
                        DSWidgets.inputField(
                          label: 'SECURITY TELEMETRY CODE // PASSKEY',
                          rightLabel: 'ENC_256',
                          controller: passwordController,
                          isPassword: true,
                          obscureText: obscurePassword,
                          onToggleObscure: onToggleObscure,
                          prefixIcon: Icons.lock_outline_rounded,
                          hint: '••••••••••••',
                          underlineColor: DS.orange,
                          validator: (v) => v == null || v.length < 6
                              ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 10),
                        // Remember + forgot
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('REMEMBER DRIVER ID',
                                style: DS.labelCaps(size: 9, color: DS.textMuted)),
                            Text('LOST PASSKEY?',
                                style: DS.labelCaps(size: 9, color: DS.orange)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Error message
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DS.red.withValues(alpha: 0.1),
                              borderRadius: DS.aeroCornerSm,
                              border: Border.all(
                                  color: DS.red.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: DS.red, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(errorMessage!,
                                        style: DS.body(
                                            size: 11, color: DS.red))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // CTA button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: GestureDetector(
                            onTap: isLoading ? null : onSubmit,
                            child: Container(
                              decoration: BoxDecoration(
                                color: DS.red,
                                borderRadius: DS.aeroCorner,
                              ),
                              alignment: Alignment.center,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: DS.redText))
                                  : Text('SIGN IN TO PITWALL  →',
                                      style: DS.driverCode(
                                          size: 14, color: DS.redText)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Biometric divider
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: DS.outline, height: 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('OR BIOMETRIC AUTH',
                                  style: DS.labelCaps(
                                      size: 8, color: DS.textMuted)),
                            ),
                            Expanded(
                                child: Divider(color: DS.outline, height: 1)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Fingerprint
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: DS.tealDark.withValues(alpha: 0.3),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12)),
                                  border: Border.all(
                                      color: DS.teal.withValues(alpha: 0.4)),
                                ),
                                child: const Icon(Icons.fingerprint_rounded,
                                    color: DS.teal, size: 30),
                              ),
                              const SizedBox(height: 6),
                              Text('TOUCH FOR INSTANT PADDOCK ACCESS',
                                  style: DS.labelCaps(
                                      size: 8, color: DS.textMuted)),
                              Text('BIOMETRIC_SENSOR // ACTIVE',
                                  style: DS.labelCaps(
                                      size: 8, color: DS.teal)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Register link
                        Center(
                          child: Column(
                            children: [
                              Text('Unregistered telemetry stream?',
                                  style: DS.body(size: 12)),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: onToggleMode,
                                child: Text(
                                  'REGISTER FIA SUPERLICENSE  ↗',
                                  style: DS.driverCode(
                                      size: 13, color: DS.orange),
                                ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildRegister(BuildContext context) {
    final String passwordVal = passwordController.text;
    final int strength = passwordVal.isEmpty
        ? 0
        : passwordVal.length < 6
            ? 1
            : passwordVal.length < 10
                ? 2
                : passwordVal.length < 14
                    ? 3
                    : 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DS.surface1,
                borderRadius: DS.aeroCorner,
                border: Border.all(color: DS.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DSWidgets.statusChip('FIA DIGITAL CREDENTIAL  |  CLASS A-SPEC'),
                      Text('#SL-2026', style: DS.telemetry(size: 11, color: DS.orange)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                          width: 3, height: 32, color: DS.red,
                          margin: const EdgeInsets.only(right: 10)),
                      Text('APEX SUPERLICENSE', style: DS.display(size: 22)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('STAGE 01 // DRIVER PROFILE REGISTRATION',
                      style: DS.labelCaps(size: 9, color: DS.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Credentials form ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DS.surface1,
                borderRadius: DS.aeroCorner,
                border: Border.all(color: DS.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PILOT BIOMETRIC IDENTIFIERS',
                          style: DS.labelCaps(size: 9, color: DS.teal)),
                      Text('FIELDS: REQUIRED',
                          style: DS.labelCaps(size: 9, color: DS.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DSWidgets.inputField(
                    label: 'DRIVER FULL NAME',
                    rightLabel: 'REG. NOMENCLATURE',
                    controller: nameController,
                    prefixIcon: Icons.person_outline_rounded,
                    hint: 'Alexander Vance',
                    underlineColor: DS.teal,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 14),
                  DSWidgets.inputField(
                    label: 'PADDOCK COMM EMAIL',
                    rightLabel: 'ENCRYPTED FEED',
                    controller: emailController,
                    prefixIcon: Icons.wifi_rounded,
                    hint: 'driver@paddock.f1',
                    keyboardType: TextInputType.emailAddress,
                    underlineColor: DS.red,
                    validator: (v) =>
                        v == null || v.isEmpty || !v.contains('@')
                            ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 14),
                  // Password with strength bar
                  DSWidgets.inputField(
                    label: 'TELEMETRY ACCESS KEY',
                    rightLabel: 'ENTROPY: ${_strengthLabel(strength)}',
                    controller: passwordController,
                    isPassword: true,
                    obscureText: obscurePassword,
                    onToggleObscure: onToggleObscure,
                    prefixIcon: Icons.lock_outline_rounded,
                    hint: '••••••••••••',
                    underlineColor: DS.orange,
                    validator: (v) =>
                        v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 6),
                  // Strength bar
                  Row(
                    children: List.generate(4, (i) {
                      Color segColor = i < strength ? DS.teal : DS.surface4;
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: segColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (strength > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${_strengthPct(strength)}% HARDENED',
                          style: DS.labelCaps(size: 8, color: DS.teal),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Country sync ──────────────────────────────────────────────
            GestureDetector(
              onTap: onCountryTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DS.surface1,
                  borderRadius: DS.aeroCorner,
                  border: Border.all(color: DS.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: DS.teal, size: 14),
                            const SizedBox(width: 6),
                            Text('RACE CONTROL TIME SYNC',
                                style: DS.labelCaps(size: 9, color: DS.teal)),
                          ],
                        ),
                        Text('GPS DETECTED',
                            style: DS.labelCaps(size: 9, color: DS.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (selectedCountry != null) ...[
                      Row(
                        children: [
                          Text(selectedCountry!.flag,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedCountry!.name,
                                    style: DS.headlineMd(size: 14)),
                                DSWidgets.statusChip(
                                    '+${selectedCountry!.utcOffset > 0 ? '' : ''}${selectedCountry!.utcOffset.toString()} ${selectedCountry!.abbr} // AUTO-SYNC CIRCUITS',
                                    color: DS.teal,
                                    size: 8),
                              ],
                            ),
                          ),
                          Text('CHANGE  ›',
                              style: DS.labelCaps(size: 9, color: DS.orange)),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('No location selected',
                              style: DS.body(size: 12, color: DS.textMuted)),
                          Text('SELECT  ›',
                              style: DS.labelCaps(size: 9, color: DS.orange)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── Error message ─────────────────────────────────────────────
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DS.red.withValues(alpha: 0.1),
                  borderRadius: DS.aeroCornerSm,
                  border:
                      Border.all(color: DS.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: DS.red, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(errorMessage!, style: DS.body(size: 11, color: DS.red))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            // ── FIA terms ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DS.tealDark.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    border:
                        Border.all(color: DS.teal.withValues(alpha: 0.6)),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: DS.teal, size: 12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I agree to the FIA Trackside Data Regulations and Live Telemetry Broadcast terms. CODE: FIA-APPX-2026-V4 // INCL. GPS, SENSOR LOGGING & TELEMETRY FEEDS',
                    style: DS.body(size: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── CTA button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: GestureDetector(
                onTap: isLoading ? null : onSubmit,
                child: Container(
                  decoration: BoxDecoration(
                    color: DS.red,
                    borderRadius: DS.aeroCorner,
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: DS.redText))
                      : Text('ISSUE SUPERLICENSE & ENTER  →',
                          style: DS.driverCode(size: 13, color: DS.redText)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: onToggleMode,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                          text: 'Already racing on the grid?  ',
                          style: DS.body(size: 12)),
                      TextSpan(
                          text: 'SIGN IN  →',
                          style: DS.driverCode(size: 12, color: DS.orange)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _strengthLabel(int s) {
    switch (s) {
      case 1: return 'WEAK';
      case 2: return 'NOMINAL';
      case 3: return 'STRONG';
      case 4: return 'OPTIMAL';
      default: return 'PENDING';
    }
  }

  String _strengthPct(int s) {
    switch (s) {
      case 1: return '28';
      case 2: return '56';
      case 3: return '78';
      case 4: return '96';
      default: return '0';
    }
  }
}

// ─── LOGIN HERO HEADER ────────────────────────────────────────────────────────

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: DS.surface0),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Stack(
        children: [
          // Dot-grid background
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          // Track curve SVG (simulated with CustomPainter)
          Positioned.fill(
            child: CustomPaint(painter: _TrackCurvePainter()),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top status bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DSWidgets.statusChip('● PIT ACCESS ENCRYPTED // TLS 1.3',
                      color: DS.teal),
                  Row(
                    children: [
                      Text('GATE: P-04  ',
                          style: DS.telemetry(size: 9, color: DS.textMuted)),
                      Text('LIVE',
                          style: DS.telemetry(
                              size: 9, color: DS.orange)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // FIA portal label
              Row(
                children: [
                  Container(
                      width: 2, height: 14, color: DS.red,
                      margin: const EdgeInsets.only(right: 8)),
                  Text('FIA TELEMETRY PORTAL // PRO PASS',
                      style: DS.labelCaps(size: 9, color: DS.textVariant)),
                ],
              ),
              const SizedBox(height: 6),
              Text('BACK ON TRACK', style: DS.display(size: 28)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('DRIVER SIGN IN',
                      style: DS.driverCode(size: 12, color: DS.red)),
                  Text('  ///  ',
                      style:
                          DS.telemetry(size: 11, color: DS.textMuted)),
                  Text('SESSION: FP2 SYNC',
                      style: DS.telemetry(
                          size: 10, color: DS.textVariant)),
                ],
              ),
              const SizedBox(height: 16),
              // Telemetry speed-strip + latency
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 16, height: 4,
                          color: DS.red, margin: const EdgeInsets.only(right: 3)),
                      Container(
                          width: 10, height: 4,
                          color: DS.orange,
                          margin: const EdgeInsets.only(right: 3)),
                      Container(width: 6, height: 4, color: DS.teal),
                    ],
                  ),
                  Text('SERVER LATENCY: 14MS // SECTOR 1-3 LINKED',
                      style: DS.labelCaps(size: 7, color: DS.textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE4E1E7).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const spacing = 8.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrackCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width, size.height * 0.1);
    path.cubicTo(
      size.width * 0.65, size.height * 0.05,
      size.width * 0.35, size.height * 0.3,
      size.width * 0.42, size.height * 0.65,
    );
    path.cubicTo(
      size.width * 0.5, size.height * 0.9,
      size.width * 0.15, size.height * 0.9,
      -10, size.height,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [DS.orange, DS.red, DS.teal],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint..color = paint.color.withValues(alpha: 0.35));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── STEP 4 — CELEBRATION ─────────────────────────────────────────────────────

class _CelebrationStep extends StatefulWidget {
  final String driverName;
  final F1Team? team;
  final CountryTz? country;
  final VoidCallback onEnter;

  const _CelebrationStep({
    super.key,
    required this.driverName,
    required this.team,
    required this.country,
    required this.onEnter,
  });

  @override
  State<_CelebrationStep> createState() => _CelebrationStepState();
}

class _CelebrationStepState extends State<_CelebrationStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.team?.primaryColor ?? DS.red;
    final teamName = widget.team?.name ?? 'Formula 1';
    final teamData = widget.team != null ? kTeams2026[teamName] : null;
    final chassis = teamData?.chassis ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status ticker ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DS.surface0,
              borderRadius: DS.aeroCornerSm,
              border: Border.all(color: DS.outline),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: DS.teal
                              .withValues(alpha: 0.4 + 0.6 * _pulseCtrl.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CREDENTIAL VERIFIED // ENCRYPTED LINK ESTABLISHED',
                        style: DS.labelCaps(size: 8, color: DS.teal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DSWidgets.statusChip('#SL-2026-A${Random().nextInt(900) + 100}', size: 7),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_tethering,
                            color: DS.teal, size: 11),
                        const SizedBox(width: 4),
                        Text('LATENCY: ',
                            style: DS.telemetry(size: 9, color: DS.textVariant)),
                        Text('11ms',
                            style: DS.telemetry(size: 9, color: DS.teal)
                                .copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Text('NODE: PADDOCK_VIP // 52.67.108.4',
                        style: DS.telemetry(size: 8, color: DS.textVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Hero celebration card ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: DS.surface1,
              borderRadius: DS.aeroCorner,
              border: Border.all(color: DS.outline),
            ),
            child: Stack(
              children: [
                // AUTH 100% ribbon (top-right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: ClipRect(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: OverflowBox(
                        maxWidth: 120,
                        maxHeight: 120,
                        child: Transform.rotate(
                          angle: pi / 4,
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            color: DS.red,
                            child: Text(
                              'AUTH 100%',
                              textAlign: TextAlign.center,
                              style: DS.labelCaps(size: 7, color: DS.redText),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Shield icon with glow
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) {
                          return Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DS.surface0,
                              border: Border.all(
                                  color: DS.teal
                                      .withValues(alpha: 0.3 + 0.4 * _pulseCtrl.value)),
                            ),
                            child: const Icon(Icons.security_rounded,
                                color: DS.red, size: 36),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DSWidgets.redBadge('STAGE COMPLETE'),
                          const SizedBox(width: 8),
                          DSWidgets.statusChip(
                              'CLASS A-SPEC // TRACKSIDE ACCESS',
                              color: DS.teal, size: 8),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('SUPERLICENSE ISSUED',
                          style: DS.headline(size: 20),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                                text: 'Welcome to the Pitwall, ',
                                style: DS.body(size: 13)),
                            TextSpan(
                                text: 'Driver ${widget.driverName}',
                                style: DS.body(size: 13,
                                    color: DS.textPrimary)
                                    .copyWith(fontWeight: FontWeight.w600)),
                            TextSpan(
                                text:
                                    '. Your credential is authenticated on the global telemetry mesh.',
                                style: DS.body(size: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Digital credential card ────────────────────────────────────
          DSWidgets.leftAccentCard(
            accent: tc,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FIA FEDERATION INTERNATIONALE',
                              style: DS.labelCaps(size: 8, color: DS.textMuted)),
                          Text('APEX F1 DIGITAL CREDENTIAL',
                              style: DS.headlineMd(size: 13)),
                        ],
                      ),
                    ),
                    DSWidgets.statusChip('ACTIVE S26', color: DS.teal),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: tc.withValues(alpha: 0.2),
                      child: Text(
                        widget.driverName.isNotEmpty
                            ? widget.driverName.substring(0, 1).toUpperCase()
                            : 'D',
                        style: DS.driverCode(size: 20, color: tc),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DRIVER ASSIGNMENT',
                              style: DS.labelCaps(size: 8, color: DS.textMuted)),
                          Text(widget.driverName.toUpperCase(),
                              style: DS.driverCode(size: 16)),
                          Row(
                            children: [
                              if (widget.country != null)
                                Text('${widget.country!.flag}  ',
                                    style: const TextStyle(fontSize: 12)),
                              Text(teamName,
                                  style: DS.body(size: 11, color: tc)),
                            ],
                          ),
                          if (chassis.isNotEmpty)
                            Text(chassis,
                                style: DS.labelCaps(size: 8, color: DS.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_3x3_rounded,
                            color: DS.textMuted, size: 12),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SECURITY PROTOCOL',
                                style: DS.labelCaps(size: 7, color: DS.textMuted)),
                            Text('256-BIT CRYPTO TOKEN',
                                style: DS.labelCaps(size: 7, color: DS.textVariant)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            color: DS.teal, size: 12),
                        const SizedBox(width: 4),
                        Text('CHIP ACTIVE',
                            style: DS.labelCaps(size: 8, color: DS.teal)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Privileges grid ───────────────────────────────────────────
          Text('SYSTEM PRIVILEGES ALLOCATED',
              style: DS.labelCaps(size: 9, color: DS.textMuted)),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: [
              _PrivilegeTile(
                icon: Icons.bar_chart_rounded,
                label: 'LIVE PITWALL TELEMETRY',
                status: 'UNRESTRICTED',
                dotColor: DS.green,
              ),
              _PrivilegeTile(
                icon: Icons.radio_rounded,
                label: 'TEAM RADIO STREAM',
                status: 'UNFILTERED COMMS',
                dotColor: DS.orange,
              ),
              _PrivilegeTile(
                icon: Icons.bar_chart_sharp,
                label: 'PREDICTOR LEAGUE',
                status: '100 PTS SEED',
                dotColor: DS.green,
              ),
              _PrivilegeTile(
                icon: Icons.psychology_rounded,
                label: 'AI STRATEGIST (GEMINI)',
                status: 'ARMED & SYNCED',
                dotColor: DS.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ── Enter CTA ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: GestureDetector(
              onTap: widget.onEnter,
              child: Container(
                decoration: BoxDecoration(
                  color: DS.red,
                  borderRadius: DS.aeroCorner,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.login_rounded,
                        color: DS.redText, size: 18),
                    const SizedBox(width: 10),
                    Text('ENTER THE PITWALL',
                        style: DS.driverCode(size: 14, color: DS.redText)),
                    Text('  SESSION READY  →',
                        style: DS.telemetry(size: 12, color: DS.redText)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Ghost buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: DS.aeroCornerSm,
                    border: Border.all(color: DS.outline),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: DS.textMuted, size: 14),
                      const SizedBox(width: 6),
                      Text('SAVE TO WALLET',
                          style: DS.labelCaps(size: 8, color: DS.textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: DS.aeroCornerSm,
                    border: Border.all(color: DS.outline),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_outlined,
                          color: DS.textMuted, size: 14),
                      const SizedBox(width: 6),
                      Text('SHARE CREDENTIAL',
                          style: DS.labelCaps(size: 8, color: DS.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom ticker
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: DS.surface0,
            child: Row(
              children: [
                Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: DS.green, shape: BoxShape.circle),
                    margin: const EdgeInsets.only(right: 8)),
                Expanded(
                  child: Text(
                    'LAS VEGAS CIRCUIT // NEXT SESSION GREEN LIGHT IN 11D 14H 22M',
                    style: DS.labelCaps(size: 8, color: DS.teal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivilegeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color dotColor;

  const _PrivilegeTile({
    required this.icon,
    required this.label,
    required this.status,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DS.surface2,
        borderRadius: DS.aeroCornerSm,
        border: Border.all(color: DS.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DS.textMuted, size: 14),
              const Spacer(),
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle)),
            ],
          ),
          const Spacer(),
          Text(label,
              style: DS.labelCaps(size: 7, color: DS.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(status,
              style: DS.headlineMd(size: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
