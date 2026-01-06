import 'package:flutter/material.dart';
import 'add_fee_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/fee_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<int> fees = [];

  Future<void> saveFees() async {
    final prefs = await SharedPreferences.getInstance();
    final feeStrings = fees.map((e) => e.toString()).toList();
    await prefs.setStringList('fees', feeStrings);
  }

  void removeFee(int index) {
    final removedFee = fees[index];

    setState(() {
      fees.removeAt(index);
    });
    saveFees();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed fee: ₹$removedFee'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int getTotalFees() {
    return fees.fold(0, (sum, fee) => sum + fee);
  }

  Future<void> loadFees() async {
    final prefs = await SharedPreferences.getInstance();
    final feeStrings = prefs.getStringList('fees') ?? [];

    setState(() {
      fees.clear();
      fees.addAll(feeStrings.map(int.parse));
    });
  }

  @override
  void initState() {
    super.initState();
    loadFees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FeeCollect - Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: fees.isEmpty
                  ? const Center(
                      child: Text(
                        'No fees added yet\nTap + to add one',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: fees.length,
                      itemBuilder: (context, index) {
                        return FeeListItem(
                          amount: fees[index],
                          onDelete: () => removeFee(index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push<int>(
            context,
            MaterialPageRoute(builder: (_) => const AddFeeScreen()),
          );

          if (result != null) {
            setState(() {
              fees.insert(0, result);
            });
          }
        },
      ),
    );
  }
}
