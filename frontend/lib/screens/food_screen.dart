import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/food_service.dart';
import '../models/food_record.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({Key? key}) : super(key: key);

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final FoodService _foodService = FoodService();
  List<FoodRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.currentUser != null) {
        _records = await _foodService.getRecords(
          userId: userProvider.currentUser!.id,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('饮食记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 24),
                      Text(
                        '暂无饮食记录',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddFoodDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('添加记录'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getMealTypeColor(record.mealType),
                            child: Icon(
                              _getMealTypeIcon(record.mealType),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(record.foodName),
                          subtitle: Text(
                            '${record.calories.toStringAsFixed(0)} kcal | ${record.mealTypeLabel}',
                          ),
                          trailing: Text(
                            '${record.eatenAt.month}/${record.eatenAt.day}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFoodDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snack':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  void _showAddFoodDialog() {
    final formKey = GlobalKey<FormState>();
    String foodName = '';
    double calories = 0;
    String mealType = 'breakfast';
    double protein = 0;
    double carbohydrates = 0;
    double fat = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加饮食记录'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '食物名称',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入食物名称';
                    }
                    return null;
                  },
                  onSaved: (value) => foodName = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '热量 (kcal)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入热量';
                    }
                    return null;
                  },
                  onSaved: (value) => calories = double.parse(value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: mealType,
                  decoration: const InputDecoration(
                    labelText: '餐次',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'breakfast', child: Text('早餐')),
                    DropdownMenuItem(value: 'lunch', child: Text('午餐')),
                    DropdownMenuItem(value: 'dinner', child: Text('晚餐')),
                    DropdownMenuItem(value: 'snack', child: Text('加餐')),
                  ],
                  onChanged: (value) => mealType = value!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                
                try {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  if (userProvider.currentUser != null) {
                    await _foodService.createRecord(
                      userId: userProvider.currentUser!.id,
                      foodName: foodName,
                      calories: calories,
                      protein: protein,
                      carbohydrates: carbohydrates,
                      fat: fat,
                      mealType: mealType,
                    );
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _loadRecords();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('添加成功')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('添加失败：$e')),
                    );
                  }
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
