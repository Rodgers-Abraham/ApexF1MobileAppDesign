import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/widgets/pro_gate.dart';
import '../../../../shared/constants/f1_data.dart';

class PredictorScreen extends ConsumerStatefulWidget {
  const PredictorScreen({super.key});

  @override
  ConsumerState<PredictorScreen> createState() => _PredictorScreenState();
}

class _PredictorScreenState extends ConsumerState<PredictorScreen> {
  // Podium picks: [P1, P2, P3] (codes)
  final List<String?> _podiumPicks = ['NOR', 'LEC', null];
  int? _activeSlotIndex;

  String _poleSitter = 'LEC';
  String _fastestLap = 'PIA';
  int _safetyCars = 1;
  String _firstTeamToPit = 'Williams';
  double _confidence = 72;
  bool _isLocked = false;
  bool _showError = false;

  void _submitPicks() {
    if (_podiumPicks.any((pick) => pick == null)) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _showError = false;
      _isLocked = true;
    });
  }

  void _openDriverPicker(int slotIndex) {
    if (_isLocked) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final excludedCodes = _podiumPicks.whereType<String>().toSet();
        final currentPick = _podiumPicks[slotIndex];
        if (currentPick != null) {
          excludedCodes.remove(currentPick);
        }

        final availableDrivers = kDrivers2026List.where((d) => !excludedCodes.contains(d.code)).toList();

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SELECT P${slotIndex + 1} DRIVER',
                      style: const TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF202028), height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: availableDrivers.length,
                  itemBuilder: (context, index) {
                    final d = availableDrivers[index];
                    final teamColor = getTeamColor(d.team);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF19191F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF282832)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: teamColor, width: 3.5)),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _podiumPicks[slotIndex] = d.code;
                                _showError = false;
                              });
                              Navigator.pop(context);
                            },
                            leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: teamColor.withValues(alpha: 0.5), width: 1.2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: d.portraitAsset.isNotEmpty
                              ? Image.asset(d.portraitAsset, fit: BoxFit.cover, alignment: Alignment.topCenter)
                              : const SizedBox(),
                        ),
                        title: Row(
                          children: [
                            Text(
                              d.code,
                              style: const TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              d.name,
                              style: const TextStyle(
                                fontFamily: 'Formula1',
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          d.team,
                          style: TextStyle(
                            fontFamily: 'Formula1',
                            fontSize: 9.5,
                            color: teamColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                      ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;
    final maxReward = ((50 * _confidence) / 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'APEX ',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  TextSpan(
                    text: 'PREDICTOR',
                    style: TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFFFF1744),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ProGateWidget(
        featureName: 'ML Winner Predictions & Race Cards',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RACE WEEKEND',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'PREDICTOR',
                        style: TextStyle(
                          fontFamily: 'Formula1',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF202028)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'LOCKS IN',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 7.5,
                            color: Color(0xFF8F909A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '18:42:18',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hero Card
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Icon(Icons.track_changes_rounded, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROUND 01 · MELBOURNE',
                            style: TextStyle(
                              fontFamily: 'Formula1Wide',
                              fontSize: 8.5,
                              color: Color(0xFF8F909A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLocked ? 'PICKS LOCKED' : 'CALL THE RACE',
                            style: const TextStyle(
                              fontFamily: 'Formula1',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLocked
                                ? 'Your race card is live. Score updates as GP unfolds.'
                                : 'Build your race card. Higher confidence = higher reward.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8F909A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isLocked
                            ? const Color(0xFF00E676).withValues(alpha: 0.2)
                            : const Color(0xFF202028),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _isLocked ? const Color(0xFF00E676) : Colors.white12,
                        ),
                      ),
                      child: Text(
                        _isLocked ? 'LIVE' : '${_podiumPicks.whereType<String>().length}/5',
                        style: TextStyle(
                          fontFamily: 'Formula1Wide',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _isLocked ? const Color(0xFF00E676) : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Podium Prediction (30 PTS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Podium Prediction',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '30 PTS',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3 Podium Slots (P1 Gold, P2 Silver, P3 Bronze)
              Row(
                children: [
                  _buildPodiumSlot(0, 'P1', const Color(0xFFFFD700)),
                  const SizedBox(width: 8),
                  _buildPodiumSlot(1, 'P2', const Color(0xFFC0C0C0)),
                  const SizedBox(width: 8),
                  _buildPodiumSlot(2, 'P3', const Color(0xFFCD7F32)),
                ],
              ),

              if (_showError) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF1744)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Color(0xFFFF1744), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Complete all three podium positions before locking your picks.',
                          style: TextStyle(color: Color(0xFFFF1744), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Section 2: Race Calls (20 PTS)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Race Calls',
                    style: TextStyle(
                      fontFamily: 'Formula1',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '20 PTS',
                      style: TextStyle(
                        fontFamily: 'Formula1Wide',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF202028)),
                ),
                child: Column(
                  children: [
                    // Pole Sitter
                    _buildDropdownRow(
                      'POLE SITTER',
                      _poleSitter,
                      kDrivers2026List.map((d) => d.code).toList(),
                      (val) {
                        if (!_isLocked && val != null) setState(() => _poleSitter = val);
                      },
                    ),
                    const Divider(color: Color(0xFF202028), height: 18),

                    // Fastest Lap
                    _buildDropdownRow(
                      'FASTEST LAP',
                      _fastestLap,
                      kDrivers2026List.map((d) => d.code).toList(),
                      (val) {
                        if (!_isLocked && val != null) setState(() => _fastestLap = val);
                      },
                    ),
                    const Divider(color: Color(0xFF202028), height: 18),

                    // Safety Cars Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SAFETY CARS',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 9.5,
                            color: Color(0xFF8F909A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                              onPressed: _isLocked || _safetyCars <= 0
                                  ? null
                                  : () => setState(() => _safetyCars--),
                            ),
                            Text(
                              '$_safetyCars',
                              style: const TextStyle(
                                fontFamily: 'Formula1Wide',
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 22),
                              onPressed: _isLocked || _safetyCars >= 5
                                  ? null
                                  : () => setState(() => _safetyCars++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF202028), height: 18),

                    // First Team to Pit
                    _buildDropdownRow(
                      'FIRST TEAM TO PIT',
                      _firstTeamToPit,
                      kTeams2026.keys.toList(),
                      (val) {
                        if (!_isLocked && val != null) setState(() => _firstTeamToPit = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: Confidence Slider
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF202028)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CONFIDENCE',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 9.5,
                            color: Color(0xFF8F909A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_confidence.toInt()}%',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _confidence,
                      min: 25,
                      max: 100,
                      divisions: 15,
                      activeColor: accentColor,
                      inactiveColor: const Color(0xFF202028),
                      onChanged: _isLocked
                          ? null
                          : (val) => setState(() => _confidence = val),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SAFE',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 8.5,
                            color: Color(0xFF8F909A),
                          ),
                        ),
                        Text(
                          'MAX REWARD · $maxReward PTS',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit / Edit Picks Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLocked
                    ? OutlinedButton(
                        onPressed: () => setState(() => _isLocked = false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'EDIT PICKS',
                          style: TextStyle(
                            fontFamily: 'Formula1Wide',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _submitPicks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'LOCK MY PICKS',
                              style: TextStyle(
                                fontFamily: 'Formula1Wide',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumSlot(int index, String label, Color metalColor) {
    final pick = _podiumPicks[index];
    final driver = pick != null ? getDriverData(pick) : null;
    final teamColor = driver != null ? getTeamColor(driver.team) : Colors.transparent;

    return Expanded(
      child: GestureDetector(
        onTap: () => _openDriverPicker(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: pick != null ? metalColor : const Color(0xFF202028),
              width: pick != null ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: metalColor,
                ),
              ),
              const SizedBox(height: 8),
              if (driver != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: driver.portraitAsset.isNotEmpty
                      ? Image.asset(driver.portraitAsset, fit: BoxFit.cover, alignment: Alignment.topCenter)
                      : Center(child: Text(driver.code, style: TextStyle(color: teamColor))),
                ),
                const SizedBox(height: 6),
                Text(
                  driver.code,
                  style: const TextStyle(
                    fontFamily: 'Formula1',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  driver.team,
                  style: const TextStyle(
                    fontFamily: 'Formula1',
                    fontSize: 8.5,
                    color: Color(0xFF8F909A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF19191F),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_rounded, color: Colors.white38, size: 24),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'SELECT',
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Text(
                  'DRIVER',
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    fontSize: 8,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownRow(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Formula1Wide',
            fontSize: 9.5,
            color: Color(0xFF8F909A),
            fontWeight: FontWeight.bold,
          ),
        ),
        DropdownButton<String>(
          value: options.contains(currentValue) ? currentValue : options.first,
          dropdownColor: const Color(0xFF1E1E26),
          underline: const SizedBox(),
          style: const TextStyle(
            fontFamily: 'Formula1',
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(opt),
            );
          }).toList(),
          onChanged: _isLocked ? null : onChanged,
        ),
      ],
    );
  }
}
