import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';

import '../../config/color_constants.dart';

class ShopManagementPage extends ConsumerWidget {
  const ShopManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(repairShopsProvider);
    final actions = ref.read(adminActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('修理厂管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.gold), onPressed: () => _showForm(context, ref)),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
        data: (shops) => shops.isEmpty
            ? const Center(child: Text('暂无修理厂', style: TextStyle(color: AppColors.text2)))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: shops.length,
                itemBuilder: (ctx, i) => _shopRow(context, shops[i], actions, ref),
              ),
      ),
    );
  }

  Widget _shopRow(BuildContext context, dynamic shop, dynamic actions, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 4),
          Row(children: [
            _itag(Icons.person, shop.contactPerson.isNotEmpty ? shop.contactPerson : '未设置联系人', AppColors.text2),
            const SizedBox(width: 10),
            _itag(Icons.phone, shop.contactPhone.isNotEmpty ? shop.contactPhone : '未设置电话', AppColors.text2),
          ]),
          if (shop.remark != null && shop.remark!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(shop.remark!, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ],
        ])),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger), onPressed: () => _confirmDelete(context, shop, actions, ref)),
      ]),
    );
  }

  Widget _itag(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color), const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }

  void _confirmDelete(BuildContext context, dynamic shop, dynamic actions, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认删除', style: TextStyle(color: AppColors.text)),
        content: Text('删除修理厂 ${shop.name}？', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            try { await actions.deleteRepairShop(shop.id); ref.invalidate(repairShopsProvider); } catch (e) { _snack(context, '$e'); }
          }, child: const Text('删除', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(), personCtrl = TextEditingController(), phoneCtrl = TextEditingController(), remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('添加修理厂', style: TextStyle(color: AppColors.text, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _tf('名称*', nameCtrl),
          const SizedBox(height: 10), _tf('联系人', personCtrl),
          const SizedBox(height: 10), _tf('联系电话', phoneCtrl),
          const SizedBox(height: 10), _tf('备注', remarkCtrl),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            try {
              await ref.read(adminActionsProvider).addRepairShop(name: nameCtrl.text, cp: personCtrl.text, cph: phoneCtrl.text, r: remarkCtrl.text);
              ref.invalidate(repairShopsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) { if (ctx.mounted) _snack(ctx, '$e'); }
          }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg), child: const Text('添加', style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _tf(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13), border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
      style: const TextStyle(color: AppColors.text, fontSize: 13),
    );
  }

  void _snack(BuildContext context, String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
