import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/providers/telemetry_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/constants/f1_data.dart';

class StandingsScreen extends ConsumerStatefulWidget {
  const StandingsScreen({super.key});

  @override
  ConsumerState<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends ConsumerState<StandingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;

    final driversAsync = ref.watch(liveDriverStandingsProvider);
    final constructorsAsync = ref.watch(liveConstructorStandingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF0B0B0E),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'APEX',
              style: AppFonts.wide(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Text(
              'F1',
              style: AppFonts.wide(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFF1744)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF18181E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                '2026 SEASON',
                style: AppFonts.number(fontSize: 9, color: Colors.grey[400]!, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F13),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF202028)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF09090C),
              unselectedLabelColor: const Color(0xFF8F909A),
              labelStyle: const TextStyle(
                fontFamily: 'Formula1Wide',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Formula1Wide',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'DRIVERS'),
                Tab(text: 'CONSTRUCTORS'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Drivers Standings
          driversAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
            error: (err, stack) => Center(
              child: Text(
                'Error loading standings: $err',
                style: AppFonts.regular(color: Colors.grey),
              ),
            ),
            data: (drivers) => _buildDriversView(accentColor, drivers),
          ),
          // Constructors Standings
          constructorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.red)),
            error: (err, stack) => Center(
              child: Text(
                'Error loading standings: $err',
                style: AppFonts.regular(color: Colors.grey),
              ),
            ),
            data: (constructors) => _buildConstructorsView(accentColor, themeState.selectedTeam.name, constructors),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversView(Color accentColor, List<DriverStandingJolpica> drivers) {
    if (drivers.isEmpty) {
      return Center(
        child: Text('No driver standings available', style: AppFonts.regular(color: Colors.grey)),
      );
    }

    final top3 = drivers.take(3).toList();
    final remaining = drivers.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // ── TOP 3 PODIUM HERO (P2, P1, P3) ───────────────────────────────────
        if (top3.length >= 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd Place (Left)
                Expanded(
                  child: _buildPodiumCard(top3[1], 2, const Color(0xFFC0C0C0), 185),
                ),
                const SizedBox(width: 8),
                // 1st Place (Center - Elevated)
                Expanded(
                  child: _buildPodiumCard(top3[0], 1, const Color(0xFFFFD700), 215),
                ),
                const SizedBox(width: 8),
                // 3rd Place (Right)
                Expanded(
                  child: _buildPodiumCard(top3[2], 3, const Color(0xFFCD7F32), 175),
                ),
              ],
            ),
          ),

        // ── SECTION HEADER ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'DRIVER RANKINGS (P4 - P22)',
                  style: TextStyle(
                    fontFamily: 'Formula1Wide',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'POINTS',
                style: TextStyle(
                  fontFamily: 'Formula1Wide',
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // ── POSITIONS 4 TO 22 LIST ───────────────────────────────────────────
        ...remaining.map((d) => _buildDriverRow(d)),
      ],
    );
  }

  Widget _buildPodiumCard(DriverStandingJolpica d, int place, Color placeColor, double height) {
    final driverData = getDriverData(d.name);
    final teamData = getTeamData(driverData?.team ?? d.team);
    final teamColor = teamData?.primaryColor ?? getDriverTeamColor(d.name);
    final isFirst = place == 1;

    return Container(
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFirst ? placeColor.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.08),
          width: isFirst ? 1.8 : 1.0,
        ),
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: placeColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Place number + Team Color indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: placeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '0$place',
                  style: AppFonts.number(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: placeColor,
                  ),
                ),
              ),
              if (teamData != null && teamData.logoWhiteAsset.isNotEmpty)
                SvgPicture.asset(
                  teamData.logoWhiteAsset,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(teamColor, BlendMode.srcIn),
                ),
            ],
          ),

          // Driver Portrait Cutout
          Container(
            width: isFirst ? 58 : 48,
            height: isFirst ? 58 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF202028),
              border: Border.all(color: teamColor.withValues(alpha: 0.6), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: driverData != null && driverData.portraitAsset.isNotEmpty
                ? Image.asset(
                    driverData.portraitAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        driverData.code,
                        style: AppFonts.number(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      d.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                      style: AppFonts.number(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),

          // Driver Info & Points
          Column(
            children: [
              Text(
                driverData?.code ?? (d.name.split(' ').last.toUpperCase().length >= 3
                    ? d.name.split(' ').last.toUpperCase().substring(0, 3)
                    : d.name.split(' ').last.toUpperCase()),
                style: AppFonts.driverName(
                  fontSize: isFirst ? 14 : 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                d.name.split(' ').last,
                style: AppFonts.regular(fontSize: 10, color: Colors.grey[400]!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${d.pts} PTS',
                style: AppFonts.number(
                  fontSize: isFirst ? 13 : 11,
                  fontWeight: FontWeight.w900,
                  color: isFirst ? placeColor : Colors.white,
                ),
              ),
              if (d.wins != '0')
                Text(
                  '${d.wins} WINS',
                  style: TextStyle(
                    fontFamily: 'Formula1Wide',
                    fontSize: 7.5,
                    color: const Color(0xFFFF1744),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow(DriverStandingJolpica d) {
    final driverData = getDriverData(d.name);
    final teamData = getTeamData(driverData?.team ?? d.team);
    final teamColor = teamData?.primaryColor ?? getDriverTeamColor(d.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 24,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Position
          SizedBox(
            width: 26,
            child: Text(
              d.pos,
              style: AppFonts.number(
                color: Colors.grey[400]!,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Driver Portrait Thumbnail
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF202028),
              border: Border.all(color: teamColor.withValues(alpha: 0.5), width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: driverData != null && driverData.portraitAsset.isNotEmpty
                ? Image.asset(
                    driverData.portraitAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 10),

          // Driver Name + Team
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      driverData?.code ?? '',
                      style: AppFonts.driverName(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        d.name,
                        style: AppFonts.regular(fontSize: 10.5, color: Colors.grey[400]!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  teamData?.name ?? d.team,
                  style: TextStyle(
                    fontFamily: 'Formula1',
                    color: Colors.grey[500],
                    fontSize: 9.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Wins
          if (d.wins != '0')
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${d.wins}W',
                style: TextStyle(
                  fontFamily: 'Formula1Wide',
                  color: const Color(0xFFFF1744),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Points
          Text(
            '${d.pts} PTS',
            style: AppFonts.number(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstructorsView(Color accentColor, String userFavouriteTeam, List<ConstructorStandingJolpica> constructors) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: constructors.length,
      itemBuilder: (context, index) {
        final c = constructors[index];
        final teamData = getTeamData(c.name);
        final teamColor = teamData?.primaryColor ?? getTeamColor(c.name);
        final isUserFavorite = c.name.toLowerCase() == userFavouriteTeam.toLowerCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141419),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUserFavorite ? accentColor.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.05),
              width: isUserFavorite ? 1.5 : 1,
            ),
            boxShadow: isUserFavorite
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Rank (01 to 11)
              SizedBox(
                width: 26,
                child: Text(
                  c.pos.padLeft(2, '0'),
                  style: AppFonts.number(
                    color: isUserFavorite ? accentColor : Colors.grey[500]!,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Vector Team Logo
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: teamData != null && teamData.logoWhiteAsset.isNotEmpty
                    ? SvgPicture.asset(
                        teamData.logoWhiteAsset,
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(teamColor, BlendMode.srcIn),
                      )
                    : Icon(Icons.shield, color: teamColor, size: 18),
              ),
              const SizedBox(width: 12),

              // Constructor Name + Spec
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            teamData?.name.toUpperCase() ?? c.name.toUpperCase(),
                            style: AppFonts.driverName(
                              fontWeight: isUserFavorite ? FontWeight.w900 : FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUserFavorite) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'FAVORITE',
                              style: TextStyle(
                                fontFamily: 'Formula1Wide',
                                fontSize: 7,
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teamData?.chassisPu ?? '2026 CONSTRUCTOR',
                      style: AppFonts.regular(color: Colors.grey[400]!, fontSize: 9.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Front car render thumbnail
              if (teamData != null && teamData.carFrontAsset.isNotEmpty) ...[
                Image.asset(
                  teamData.carFrontAsset,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
                const SizedBox(width: 10),
              ],

              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    c.pts,
                    style: AppFonts.number(
                      color: isUserFavorite ? accentColor : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'PTS',
                    style: TextStyle(
                      fontFamily: 'Formula1Wide',
                      fontSize: 7.5,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
