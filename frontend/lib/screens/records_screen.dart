import 'package:flutter/material.dart';
import 'food_screen.dart';
import 'exercise_screen.dart';
import 'weight_screen.dart';

/// 把饮食 / 运动 / 体重 三个"记录"合到一个 tab 下，
/// 通过顶部 TabBar 切换，避免底部导航过宽。
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('记录'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: '饮食'),
            Tab(icon: Icon(Icons.directions_run), text: '运动'),
            Tab(icon: Icon(Icons.monitor_weight), text: '体重'),
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
