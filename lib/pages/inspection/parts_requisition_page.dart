import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/vehicle.dart';
import '../../providers/inspection_provider.dart';

import '../../config/color_constants.dart';

class PartsRequisitionPage extends ConsumerStatefulWidget {
  final int partId;

  const PartsRequisitionPage({super.key, required this.partId});

  @override
  ConsumerState<PartsRequisitionPage> createState() => _PartsRequisitionPageState();
}

class _PartsRequisitionPageState extends ConsumerState<PartsRequisitionPage> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  int? _vehicleId;
  bool _submitting = false;

  @override
  void dispose() { _qtyCtrl.dispose(); _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效数量')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(inspectionActionsProvider.notifier).requisitionPart(
        partId: widget.partId,
        vehicleId: _vehicleId,
        quantity: qty,
        reason: _reasonCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('领用申请已提交')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('配件领用'), backgroundColor: AppColors.surface, foregroundColor: AppColors.text, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildField('数量 *', _qtyCtrl, keyboardType: TextInputType.number),
          _buildField('领用原因', _reasonCtrl, maxLines: 2),
          const SizedBox(height: 12),
          vehiclesAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (vehicles) => _buildVehiclePicker(vehicles),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_submitting ? '提交中...' : '提交领用申请', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text, fontSize: 13),
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.gold)),
        ),
      ),
    );
  }

  Widget _buildVehiclePicker(List<Vehicle> vehicles) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('绑定车辆（选填）', style: TextStyle(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: _vehicleId,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          ),
          hint: const Text('不绑定（通用领用）', style: TextStyle(color: AppColors.text2, fontSize: 13)),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('不绑定', style: TextStyle(color: AppColors.text2, fontSize: 13))),
            ...vehicles.map((v) => DropdownMenuItem<int?>(
              value: v.id,
              child: Text('${v.plateNumber} (${v.vehicleType})', style: const TextStyle(color: AppColors.text, fontSize: 13)),
            )),
          ],
          onChanged: (v) => setState(() => _vehicleId = v),
        ),
      ]),
    );
  }
}
