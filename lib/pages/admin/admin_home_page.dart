import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/color_constants.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('管理后台'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('管理'),
          const SizedBox(height: 10),
          Row(children: [
            _navCard(context, Icons.people, '人员管理', '添加/查看用户', '/admin/users'),
            const SizedBox(width: 10),
            _navCard(context, Icons.directions_car, '车辆管理', '录入/绑定/管理', '/vehicle-archive/list'),
          ]),
        ]),
      ),
    );
  }

  Widget _section(String t) => Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gold));

  Widget _navCard(BuildContext context, IconData icon, String title, String subtitle, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            Icon(icon, size: 30, color: AppColors.gold),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.text2), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
