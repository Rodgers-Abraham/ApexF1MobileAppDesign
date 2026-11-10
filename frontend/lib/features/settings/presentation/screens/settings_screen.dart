import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/constants/f1_data.dart';
import '../../../../shared/constants/countries.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  bool _showAllTeams = false;
  bool _showAllDrivers = false;

  bool _notifyRaceWeekend = true;
  bool _notifyQualifying = true;
  bool _notifyPredictionLock = true;
  bool _notifyTeamRadio = false;
  bool _isCelsius = true;
  bool _isKph = true;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _fmtOffset(double offset) {
    final sign = offset >= 0 ? '+' : '-';
    final abs = offset.abs();
    final h = abs.truncate();
    final m = ((abs - h) * 60).round();
    return m == 0 ? '$sign$h' : '$sign$h:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    final success = await ref
        .read(authProvider.notifier)
        .updateProfile(name: _nameController.text.trim());
    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) {
          _successMessage = 'PROFILE UPDATED';
        } else {
          _errorMessage =
              ref.read(authProvider).errorMessage ?? 'UPDATE FAILED';
        }
      });
    }
  }

  Future<void> _showChangePasswordSheet() async {
    final newPwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      backgroundColor: DS.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 3, height: 20, color: DS.red),
                  const SizedBox(width: 10),
                  Text('CHANGE SECURITY KEY', style: DS.headline(size: 15)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close, size: 18, color: DS.textMuted),
                  ),
                ]),
                const SizedBox(height: 20),
                if (sheetError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DS.red.withValues(alpha: 0.1),
                      borderRadius: DS.aeroCornerSm,
                      border: Border.all(color: DS.red.withValues(alpha: 0.4)),
                    ),
                    child: Text(sheetError!,
                        style: DS.labelCaps(size: 9, color: DS.red)),
                  ),
                  const SizedBox(height: 12),
                ],
                StatefulBuilder(
                  builder: (c, ss) => TextField(
                    controller: newPwCtrl,
                    obscureText: obscureNew,
                    style: DS.telemetry(size: 13),
                    decoration: InputDecoration(
                      labelText: 'NEW PASSWORD',
                      labelStyle: DS.labelCaps(size: 9, color: DS.textMuted),
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
                          borderSide: BorderSide(color: DS.red)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: DS.textMuted),
                        onPressed: () => ss(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (c, ss) => TextField(
                    controller: confirmCtrl,
                    obscureText: obscureConfirm,
                    style: DS.telemetry(size: 13),
                    decoration: InputDecoration(
                      labelText: 'CONFIRM PASSWORD',
                      labelStyle: DS.labelCaps(size: 9, color: DS.textMuted),
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
                          borderSide: BorderSide(color: DS.red)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: DS.textMuted),
                        onPressed: () =>
                            ss(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DS.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: DS.aeroCorner),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (newPwCtrl.text.length < 6) {
                        setSheetState(() => sheetError =
                            'PASSWORD MUST BE AT LEAST 6 CHARACTERS');
                        return;
                      }
                      if (newPwCtrl.text != confirmCtrl.text) {
                        setSheetState(
                            () => sheetError = 'PASSWORDS DO NOT MATCH');
                        return;
                      }
                      try {
                        await FirebaseAuth.instance.currentUser!
                            .updatePassword(newPwCtrl.text);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          setState(() => _successMessage = 'PASSWORD UPDATED');
                        }
                      } catch (_) {
                        setSheetState(() => sheetError =
                            'UPDATE FAILED — SIGN OUT AND SIGN BACK IN');
                      }
                    },
                    child: Text('CONFIRM NEW PASSWORD',
                        style: DS.labelCaps(size: 10, color: DS.redText)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    newPwCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _showCountryPicker() async {
    final searchCtrl = TextEditingController();
    List<CountryTz> filtered = List.from(kCountries);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      backgroundColor: DS.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
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
                      child: Icon(Icons.close, size: 18, color: DS.textMuted),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: searchCtrl,
                    style: DS.telemetry(size: 13),
                    onChanged: (val) {
                      setSheetState(() {
                        filtered = kCountries
                            .where((c) => c.name
                                .toLowerCase()
                                .contains(val.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search country...',
                      hintStyle: DS.labelCaps(size: 9, color: DS.textMuted),
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: DS.textMuted),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final country = filtered[i];
                      final currentCountry = ref.read(authProvider).country;
                      final isSelected = currentCountry == country.name;
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref
                              .read(authProvider.notifier)
                              .updateProfile(country: country.name);
                          if (mounted) setState(() {});
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
                          child: Row(
                            children: [
                              Text(country.flag,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(country.name,
                                    style: DS.body(
                                        size: 13,
                                        color: isSelected
                                            ? DS.teal
                                            : DS.textPrimary)),
                              ),
                              Text(
                                'UTC${_fmtOffset(country.utcOffset)}',
                                style: DS.labelCaps(size: 8, color: DS.textMuted),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check_circle,
                                    size: 16, color: DS.teal),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AlertDialog(
        backgroundColor: DS.surface1,
        shape: RoundedRectangleBorder(borderRadius: DS.aeroCorner),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: DS.red, size: 20),
          const SizedBox(width: 8),
          Text('DANGER ZONE',
              style: DS.headline(size: 15, color: DS.red)),
        ]),
        content: Text(
          'Permanently delete your account and all telemetry history? This cannot be undone.',
          style: DS.body(size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL',
                style: DS.labelCaps(size: 9, color: DS.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: DS.red),
            child: Text('DELETE ACCOUNT',
                style: DS.labelCaps(size: 9, color: DS.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });
      final success = await ref.read(authProvider.notifier).deleteAccount();
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          context.go('/onboarding');
        } else {
          setState(() {
            _errorMessage =
                ref.read(authProvider).errorMessage ?? 'DELETE FAILED';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;

    final visibleTeams =
        _showAllTeams ? F1Team.values.toList() : F1Team.values.take(4).toList();
    final visibleDrivers =
        _showAllDrivers ? kDrivers2026List : kDrivers2026List.take(6).toList();

    final userCountry = authState.country != null
        ? kCountries.where((c) => c.name == authState.country).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: DSAppBar(subtitle: 'PIT LANE SETTINGS', latencyMs: '12'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banners
            if (_successMessage != null)
              _buildStatusBanner(_successMessage!, DS.teal),
            if (_errorMessage != null)
              _buildStatusBanner(_errorMessage!, DS.red),

            // ── PROFILE CARD ──
            DSWidgets.leftAccentCard(
              accent: accentColor,
              bgColor: DS.surface1,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.5), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (authState.name?.isNotEmpty == true
                              ? authState.name![0]
                              : 'A')
                          .toUpperCase(),
                      style: DS.display(size: 22, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authState.name ?? 'DRIVER',
                            style: DS.headline(size: 16)),
                        const SizedBox(height: 2),
                        Text(authState.email ?? '',
                            style:
                                DS.labelCaps(size: 8, color: DS.textMuted)),
                        const SizedBox(height: 6),
                        Row(children: [
                          DSWidgets.statusChip(
                              authState.favouriteTeam ?? 'NO TEAM',
                              color: accentColor,
                              size: 8),
                          if (userCountry != null) ...[
                            const SizedBox(width: 6),
                            Text(userCountry.flag,
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.verified_outlined, size: 12, color: DS.teal),
                const SizedBox(width: 4),
                Text('APEX TELEMETRY PRO',
                    style: DS.labelCaps(size: 8, color: DS.teal)),
                const Spacer(),
                Text('VIP PADDOCK PASS',
                    style: DS.labelCaps(size: 8, color: DS.orange)),
              ],
            ),
            const SizedBox(height: 20),

            // ── CHANGE TEAM ──
            _buildSectionHeader(
                Icons.shield_outlined, 'CHANGE TEAM', 'CONSTRUCTOR', accentColor),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  ...visibleTeams.map((team) {
                    final teamData = getTeamData(team.name);
                    final isSelected = themeState.selectedTeam == team;
                    return GestureDetector(
                      onTap: () {
                        ref.read(themeProvider.notifier).selectTeam(team);
                        ref
                            .read(authProvider.notifier)
                            .updateFavouriteTeam(team.name);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? team.primaryColor.withValues(alpha: 0.15)
                              : DS.surface2,
                          borderRadius: DS.aeroCornerSm,
                          border: Border.all(
                            color: isSelected ? team.primaryColor : DS.outline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (teamData != null)
                              SvgPicture.asset(
                                teamData.logoColorAsset,
                                width: 28,
                                height: 28,
                                colorFilter: isSelected
                                    ? null
                                    : ColorFilter.mode(
                                        DS.textMuted, BlendMode.srcIn),
                              )
                            else
                              Icon(Icons.shield,
                                  size: 28,
                                  color: isSelected
                                      ? team.primaryColor
                                      : DS.textMuted),
                            const SizedBox(height: 4),
                            Text(
                              team.name.toUpperCase(),
                              style: DS.labelCaps(
                                  size: 7,
                                  color: isSelected
                                      ? team.primaryColor
                                      : DS.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (!_showAllTeams)
                    GestureDetector(
                      onTap: () => setState(() => _showAllTeams = true),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: DS.surface2,
                          borderRadius: DS.aeroCornerSm,
                          border: Border.all(color: DS.outline),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 20, color: DS.textMuted),
                            const SizedBox(height: 4),
                            Text('ALL ${F1Team.values.length}',
                                style:
                                    DS.labelCaps(size: 7, color: DS.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── CHANGE DRIVER ──
            _buildSectionHeader(Icons.person_pin_outlined, 'CHANGE DRIVER',
                'COCKPIT', accentColor),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...visibleDrivers.map((driver) {
                    final isSelected = authState.favouriteDriver == driver.name;
                    final driverTeamColor =
                        getTeamData(driver.team)?.primaryColor ?? DS.textMuted;
                    return GestureDetector(
                      onTap: () async {
                        await ref
                            .read(authProvider.notifier)
                            .updateProfile(favouriteDriver: driver.name);
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? driverTeamColor
                                      : DS.outline,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                color: DS.surface2,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  driver.portraitAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.person,
                                      size: 28,
                                      color: DS.textMuted),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              driver.code,
                              style: DS.labelCaps(
                                  size: 8,
                                  color: isSelected
                                      ? driverTeamColor
                                      : DS.textMuted),
                            ),
                            if (isSelected)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: driverTeamColor,
                                    shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (!_showAllDrivers)
                    GestureDetector(
                      onTap: () => setState(() => _showAllDrivers = true),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: DS.outline),
                          color: DS.surface2,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.more_horiz,
                                size: 18, color: DS.textMuted),
                            Text('ALL',
                                style: DS.labelCaps(
                                    size: 7, color: DS.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── LOCATION & TIMEZONE ──
            _buildSectionHeader(Icons.language_outlined, 'LOCATION & TIMEZONE',
                'LOCAL TIME', DS.teal),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: DS.surface1,
                  borderRadius: DS.aeroCorner,
                  border: Border.all(color: DS.outline),
                ),
                child: Row(
                  children: [
                    if (userCountry != null) ...[
                      Text(userCountry.flag,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userCountry.name,
                                style: DS.body(
                                    size: 13, color: DS.textPrimary)),
                            Text(
                              'UTC${_fmtOffset(userCountry.utcOffset)} ${userCountry.abbr}',
                              style: DS.labelCaps(size: 8, color: DS.teal),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.language_outlined,
                          size: 22, color: DS.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('TAP TO SELECT YOUR COUNTRY',
                            style: DS.labelCaps(
                                size: 9, color: DS.textMuted)),
                      ),
                    ],
                    Icon(Icons.chevron_right, size: 18, color: DS.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── DRIVER PROFILE / DISPLAY NAME ──
            _buildSectionHeader(Icons.badge_outlined, 'DRIVER PROFILE',
                'IDENTITY', DS.textMuted),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DS.surface1,
                borderRadius: DS.aeroCorner,
                border: Border.all(color: DS.outline),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: DS.telemetry(size: 13),
                    decoration: InputDecoration(
                      labelText: 'DISPLAY NAME',
                      labelStyle:
                          DS.labelCaps(size: 9, color: DS.textMuted),
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
                          borderSide: BorderSide(color: accentColor)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: DS.aeroCorner),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : Text('SAVE DISPLAY NAME',
                              style: DS.labelCaps(
                                  size: 10, color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── TELEMETRY FEEDS & ALERTS ──
            _buildSectionHeader(Icons.notifications_outlined,
                'TELEMETRY FEEDS & ALERTS', 'DEVICE', DS.textMuted),
            const SizedBox(height: 10),
            _buildGroupedSection([
              _buildToggleRow(
                  'Race Weekend Alerts',
                  'Lights out, green flag, podium updates',
                  _notifyRaceWeekend,
                  (v) => setState(() => _notifyRaceWeekend = v),
                  accentColor),
              _buildToggleRow(
                  'Qualifying Reminders',
                  'Q1 sector grid countdown sync',
                  _notifyQualifying,
                  (v) => setState(() => _notifyQualifying = v),
                  accentColor,
                  badge: 'T-15M'),
              _buildToggleRow(
                  'Prediction Lock Warnings',
                  'Prior to pit lane green light',
                  _notifyPredictionLock,
                  (v) => setState(() => _notifyPredictionLock = v),
                  accentColor,
                  badge: 'T-30M'),
              _buildToggleRow(
                  'Team Radio Transcripts',
                  'Live uncensored driver comms feed',
                  _notifyTeamRadio,
                  (v) => setState(() => _notifyTeamRadio = v),
                  accentColor),
            ]),
            const SizedBox(height: 20),

            // ── DISPLAY UNITS ──
            _buildSectionHeader(
                Icons.speed_outlined, 'DISPLAY UNITS', 'METRIC', DS.yellow),
            const SizedBox(height: 10),
            _buildGroupedSection([
              _buildUnitRow(
                'Speed Trap Units',
                'Telemetry overlay & sector speeds',
                options: ['KM/H', 'MPH'],
                selected: _isKph ? 0 : 1,
                onSelect: (i) => setState(() => _isKph = i == 0),
                accentColor: accentColor,
              ),
              _buildUnitRow(
                'Track Surface Temp',
                'Pirelli tire carcass & asphalt thermal',
                options: ['°C', '°F'],
                selected: _isCelsius ? 0 : 1,
                onSelect: (i) => setState(() => _isCelsius = i == 0),
                accentColor: accentColor,
              ),
            ]),
            const SizedBox(height: 20),

            // ── ACCOUNT & CALIBRATION ──
            _buildSectionHeader(Icons.manage_accounts_outlined,
                'ACCOUNT & CALIBRATION', 'SECURITY', DS.textMuted),
            const SizedBox(height: 10),
            _buildGroupedSection([
              _buildActionRow(
                  Icons.lock_outline,
                  'CHANGE SECURITY KEY & PASSWORD',
                  'Update your login credentials',
                  _showChangePasswordSheet),
            ]),
            const SizedBox(height: 14),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/onboarding');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: DS.outline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: DS.aeroCorner),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: DS.textMuted),
                    const SizedBox(width: 8),
                    Text('SIGN OUT',
                        style:
                            DS.labelCaps(size: 10, color: DS.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── DANGER ZONE ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DS.red.withValues(alpha: 0.06),
                borderRadius: DS.aeroCorner,
                border: Border.all(color: DS.red.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: DS.red),
                    const SizedBox(width: 6),
                    Text('PIT LANE DANGER ZONE',
                        style: DS.labelCaps(size: 9, color: DS.red)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Permanently deletes your account and all associated telemetry history. VIP credentials will be revoked.',
                    style: DS.body(size: 11),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _deleteAccount,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: DS.red.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: DS.aeroCorner),
                        backgroundColor: DS.red.withValues(alpha: 0.08),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever_outlined,
                              size: 16, color: DS.red),
                          const SizedBox(width: 8),
                          Text('DELETE ACCOUNT & TELEMETRY HISTORY',
                              style: DS.labelCaps(size: 9, color: DS.red)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── ABOUT ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DS.surface1,
                borderRadius: DS.aeroCorner,
                border: Border.all(color: DS.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: DS.red, borderRadius: DS.aeroCornerSm),
                    alignment: Alignment.center,
                    child: Text('A',
                        style: DS.display(size: 16, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('APEX F1 v2.1.0',
                            style: DS.labelCaps(size: 8, color: DS.textMuted)),
                        Text(
                            'POWERED BY SPORTRADAR · AWS · FIA DIRECT TIMING',
                            style:
                                DS.labelCaps(size: 7, color: DS.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('FIA DATA // ENCRYPTED SESSION',
                  style: DS.labelCaps(size: 7, color: DS.surface4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String msg, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DS.aeroCornerSm,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
              color == DS.teal
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 14,
              color: color),
          const SizedBox(width: 8),
          Text(msg, style: DS.labelCaps(size: 9, color: color)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      IconData icon, String title, String meta, Color metaColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: metaColor),
        const SizedBox(width: 8),
        Text(title, style: DS.labelCaps(size: 10, color: DS.textPrimary)),
        const Spacer(),
        DSWidgets.statusChip(meta, color: metaColor, size: 7),
      ],
    );
  }

  Widget _buildGroupedSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface1,
        borderRadius: DS.aeroCorner,
        border: Border.all(color: DS.outline),
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(color: DS.outline, height: 1, thickness: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color activeColor, {
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: DS.body(size: 13, color: DS.textPrimary)),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    DSWidgets.statusChip(badge, color: DS.orange, size: 7),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(subtitle, style: DS.bodySm(size: 11)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: activeColor, activeTrackColor: activeColor.withValues(alpha: 0.5), onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildUnitRow(
    String title,
    String subtitle, {
    required List<String> options,
    required int selected,
    required void Function(int) onSelect,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DS.body(size: 13, color: DS.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: DS.bodySm(size: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: DS.surface2,
              borderRadius: DS.aeroCornerSm,
              border: Border.all(color: DS.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options.asMap().entries.map((e) {
                final isSelected = e.key == selected;
                return GestureDetector(
                  onTap: () => onSelect(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor : Colors.transparent,
                      borderRadius: DS.aeroCornerSm,
                    ),
                    child: Text(
                      e.value,
                      style: DS.labelCaps(
                          size: 9,
                          color: isSelected ? Colors.black : DS.textMuted),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: DS.surface2, borderRadius: DS.aeroCornerSm),
              child: Icon(icon, size: 16, color: DS.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DS.body(size: 13, color: DS.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: DS.bodySm(size: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: DS.textMuted),
          ],
        ),
      ),
    );
  }
}
