import 'package:flutter/material.dart';

class FeeListItem extends StatelessWidget {
  final int amount;
  final VoidCallback onDelete;

  const FeeListItem({super.key, required this.amount, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.currency_rupee),
        title: Text('₹$amount'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
