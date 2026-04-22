import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import 'food_screen.dart';
import 'exercise_screen.dart';
import 'weight_screen.dart';

/// Three logs (food / training / weight) under one tab with a top TabBar.
class RecordsScreen extends StatefulWidget {
  final int initialTab;
  const RecordsScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLog),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(icon: const Icon(Icons.restaurant), text: l10n.logFoodTab),
            Tab(icon: const Icon(Icons.fitness_center), text: l10n.logTrainingTab),
            Tab(icon: const Icon(Icons.monitor_weight), text: l10n.logWeightTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          FoodScreen(showAppBar: false),
          ExerciseScreen(showAppBar: false),
          WeightScreen(showAppBar: false),
        ],
      ),
    );
  }
}
