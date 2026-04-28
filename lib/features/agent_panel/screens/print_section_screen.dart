import 'package:flutter/material.dart';

class PrintSectionScreen extends StatelessWidget {
  const PrintSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قسم الطباعة (قيد الإنشاء)')),
      body: const Center(
        child: Text('سيتم تطوير هذا القسم قريباً', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
