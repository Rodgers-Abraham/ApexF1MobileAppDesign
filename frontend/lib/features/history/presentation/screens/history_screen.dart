import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../home/presentation/screens/pitwall_screen.dart' show getCircuitAssetPath;

// Providers for historical F1 data
final allSeasonsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/history/seasons');
  final list = response.data as List;
  return list.map((i) => i as Map<String, dynamic>).toList();
});

final seasonRacesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, year) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/history/season/$year/races');
  final list = response.data as List;
  return list.map((i) => i as Map<String, dynamic>).toList();
});

final historySearchProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, query) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get('/api/f1/history/search?q=${Uri.encodeComponent(query)}');
  return response.data as Map<String, dynamic>;
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedYear = 2026;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accentColor = themeState.selectedTeam.primaryColor;

    final seasonsAsync = ref.watch(allSeasonsProvider);
    final seasonRacesAsync = ref.watch(seasonRacesProvider(_selectedYear));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            const SizedBox(width: 8),
            Text('HISTORICAL ARCHIVE', style: AppFonts.header(fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Box
            TextFormField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  final parsedYear = int.tryParse(_searchQuery);
                  if (parsedYear != null && parsedYear >= 1950 && parsedYear <= 2026) {
                    _selectedYear = parsedYear;
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Search circuit (SPA, SIL, MON), driver (Senna), team, or year...',
                hintStyle: AppFonts.regular(color: Colors.grey[500]!, fontSize: 13),
                fillColor: const Color(0xFF141418),
                filled: true,
                prefixIcon: Icon(Icons.search_rounded, color: accentColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Smart Multi-Category Search Result Card
            if (_searchQuery.isNotEmpty) ...[
              _SmartSearchCard(query: _searchQuery, accentColor: accentColor),
              const SizedBox(height: 24),
            ],

            // Quick Year Filter Horizontal Bar
            Text('CHOOSE SEASON YEAR (1950 – 2026)', style: AppFonts.header(fontSize: 11, color: Colors.grey[400]!, letterSpacing: 1)),
            const SizedBox(height: 10),

            seasonsAsync.when(
              loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => _YearFilterBar(
                selectedYear: _selectedYear,
                years: const [2026, 2025, 2024, 2023, 2021, 2004, 1988, 1976, 1950],
                accentColor: accentColor,
                onYearSelected: (y) => setState(() => _selectedYear = y),
              ),
              data: (seasons) {
                final yearList = seasons.map((s) => int.tryParse(s['season']?.toString() ?? '') ?? 2026).where((y) => y >= 1950 && y <= 2026).toList();
                return _YearFilterBar(
                  selectedYear: _selectedYear,
                  years: yearList,
                  accentColor: accentColor,
                  onYearSelected: (y) => setState(() => _selectedYear = y),
                );
              },
            ),
            const SizedBox(height: 24),

            // Season Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withOpacity(0.4)),
                  ),
                  child: Text('SEASON $_selectedYear', style: AppFonts.number(color: accentColor, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Text('GRAND PRIX RESULTS', style: AppFonts.header(fontSize: 12, color: Colors.grey[300]!, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 12),

            // Season Races Results List
            seasonRacesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading season results: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (races) {
                if (races.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No historical race records found for this season.', style: TextStyle(color: Colors.grey))),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: races.length,
                  itemBuilder: (context, index) {
                    final r = races[index];
                    final roundNum = r['round']?.toString() ?? '${index + 1}';
                    final raceName = r['race_name']?.toString() ?? 'Grand Prix';
                    final circuitName = r['circuit_name']?.toString() ?? 'F1 Circuit';
                    final locality = r['locality']?.toString() ?? '';
                    final date = r['date']?.toString() ?? '';
                    final winner = r['winner'] as Map<String, dynamic>? ?? {};
                    final winnerName = winner['driver']?.toString() ?? 'Winner';
                    final winnerConstructor = winner['constructor']?.toString() ?? 'F1 Team';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141418),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'R$roundNum',
                                style: AppFonts.number(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  raceName,
                                  style: AppFonts.driverName(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$circuitName ${locality.isNotEmpty ? "• $locality" : ""} ${date.isNotEmpty ? "($date)" : ""}',
                                  style: AppFonts.regular(fontSize: 11, color: Colors.grey[400]!),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    winnerName,
                                    style: AppFonts.driverName(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                winnerConstructor,
                                style: AppFonts.regular(fontSize: 10, color: Colors.grey[500]!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _YearFilterBar extends StatelessWidget {
  final int selectedYear;
  final List<int> years;
  final Color accentColor;
  final ValueChanged<int> onYearSelected;

  const _YearFilterBar({
    required this.selectedYear,
    required this.years,
    required this.accentColor,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = year == selectedYear;

          return GestureDetector(
            onTap: () => onYearSelected(year),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : const Color(0xFF141418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? accentColor : Colors.white.withOpacity(0.08)),
              ),
              child: Text(
                '$year',
                style: AppFonts.number(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[400]!,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SmartSearchCard extends ConsumerWidget {
  final String query;
  final Color accentColor;

  const _SmartSearchCard({required this.query, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(historySearchProvider(query));

    return searchAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (err, stack) => const SizedBox(),
      data: (result) {
        final type = result['type']?.toString() ?? 'circuit';
        final data = result['data'] as Map<String, dynamic>? ?? {};

        if (type == 'driver') {
          final name = data['name']?.toString() ?? query;
          final nationality = data['nationality']?.toString() ?? 'F1 Driver';
          final titles = data['titles']?.toString() ?? '0';
          final wins = data['wins']?.toString() ?? '0';
          final poles = data['poles']?.toString() ?? '0';
          final teams = data['teams']?.toString() ?? 'F1 Teams';
          final moment = data['iconic_moment']?.toString() ?? '';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      name.toUpperCase(),
                      style: AppFonts.header(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DRIVER LEGEND',
                        style: TextStyle(color: Colors.amber[300], fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Championship Titles', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text(titles, style: AppFonts.number(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Race Wins', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text('$wins Wins', style: AppFonts.number(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Pole Positions', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text('$poles Poles', style: AppFonts.number(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                Text('TEAMS DRIVEN FOR', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                Text(teams, style: AppFonts.driverName(fontSize: 12, color: Colors.white70)),
                if (moment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('ICONIC CAREER MOMENT', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                  Text('"$moment"', style: const TextStyle(fontSize: 12, color: Colors.white, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          );
        }

        if (type == 'team') {
          final name = data['name']?.toString() ?? query;
          final titles = data['titles']?.toString() ?? '0';
          final wins = data['wins']?.toString() ?? '0';
          final hq = data['headquarters']?.toString() ?? '';
          final drivers = data['legendary_drivers']?.toString() ?? '';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: accentColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      name.toUpperCase(),
                      style: AppFonts.header(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CONSTRUCTOR',
                        style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Constructor Titles', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text(titles, style: AppFonts.number(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Victories', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text('$wins Wins', style: AppFonts.number(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                Text('LEGENDARY DRIVERS', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                Text(drivers, style: AppFonts.driverName(fontSize: 12, color: Colors.white70)),
              ],
            ),
          );
        }

        // Default: Circuit Archive Card
        final raceName = data['race_name']?.toString() ?? query;
        final firstHeld = data['first_held']?.toString() ?? '1950';
        final totalRaces = data['total_races_held']?.toString() ?? '70+';
        final topDriver = data['most_wins_driver']?.toString() ?? 'Michael Schumacher (6 Wins)';
        final topTeam = data['most_wins_constructor']?.toString() ?? 'Ferrari (18 Wins)';
        final recentList = (data['recent_winners'] as List?) ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_edu_rounded, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CIRCUIT ARCHIVE: ${raceName.toUpperCase()}',
                    style: AppFonts.header(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Layout Image
              Container(
                height: 110,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(
                    getCircuitAssetPath(raceName),
                    fit: BoxFit.contain,
                    color: Colors.white.withOpacity(0.9),
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.map_rounded, color: accentColor, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('First Held', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                      Text('$firstHeld Season', style: AppFonts.number(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total Grand Prix', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                      Text('$totalRaces Races', style: AppFonts.number(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Most Wins Driver', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text(topDriver, style: AppFonts.driverName(fontSize: 12, color: Colors.amber)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Most Wins Constructor', style: AppFonts.regular(fontSize: 10, color: Colors.grey)),
                        Text(topTeam, style: AppFonts.driverName(fontSize: 12, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),

              if (recentList.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 20),
                Text('RECENT WINNERS', style: AppFonts.header(fontSize: 10, color: Colors.grey[400]!)),
                const SizedBox(height: 8),
                Column(
                  children: recentList.take(4).map((item) {
                    final yr = item['year']?.toString() ?? '';
                    final drv = item['driver']?.toString() ?? '';
                    final team = item['constructor']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(yr, style: AppFonts.number(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(drv, style: AppFonts.driverName(fontSize: 12, color: Colors.white))),
                          Text(team, style: AppFonts.regular(fontSize: 11, color: Colors.grey[400]!)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
