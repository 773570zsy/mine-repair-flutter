import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/color_constants.dart';
import '../../config/constants.dart';
import '../../models/admin.dart';
import '../../providers/admin_provider.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  String? _roleFilter;
  String _keyword = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = UserFilter(role: _roleFilter, keyword: _keyword.isEmpty ? null : _keyword);
    final usersAsync = ref.watch(adminUsersProvider(filter));
    final actions = ref.read(adminActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('人员管理'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: AppColors.gold, size: 22),
            tooltip: '添加用户',
            onPressed: () => _showAddUserDialog(),
          ),
        ],
      ),
      body: Column(children: [
        // ---- 搜索 + 筛选（保留） ----
        Container(
          padding: const EdgeInsets.all(10),
          color: AppColors.surface,
          child: Row(children: [
            Expanded(child: _searchBox()),
            const SizedBox(width: 8),
            _roleDropdown(),
          ]),
        ),
        // ---- 表头 ----
        _tableHeader(),
        const Divider(color: AppColors.border, height: 1),
        // ---- 用户列表 ----
        Expanded(child: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.danger))),
          data: (users) => users.isEmpty
              ? const Center(child: Text('暂无用户', style: TextStyle(color: AppColors.text2)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: users.length,
                  itemBuilder: (_, i) => _userRow(users[i], actions),
                ),
        )),
      ]),
    );
  }

  // ==================== 搜索框 ====================
  Widget _searchBox() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.search, size: 16, color: AppColors.text2),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            decoration: const InputDecoration(
              hintText: '搜索姓名/手机号',
              hintStyle: TextStyle(color: AppColors.text2, fontSize: 13),
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (v) => setState(() => _keyword = v.trim()),
          ),
        ),
        if (_keyword.isNotEmpty)
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _keyword = '');
            },
            child: const Icon(Icons.close, size: 14, color: AppColors.text2),
          ),
      ]),
    );
  }

  // ==================== 角色筛选 ====================
  Widget _roleDropdown() {
    final roles = <String?, String>{
      null: '全部角色',
      for (final e in roleMap.entries) e.key: e.value,
    };
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _roleFilter,
          items: roles.entries
              .map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _roleFilter = v),
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.text2, size: 20),
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
      ),
    );
  }

  // ==================== 表头（参考3000） ====================
  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.surface2,
      child: Row(children: const [
        Expanded(flex: 2, child: Text('归属部门', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w500))),
        Expanded(flex: 2, child: Text('姓名', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w500))),
        Expanded(flex: 3, child: Text('手机号', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w500))),
        Expanded(flex: 2, child: Text('角色', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w500))),
        SizedBox(width: 40, child: Text('操作', style: TextStyle(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ==================== 用户行 ====================
  Widget _userRow(AdminUser user, dynamic actions) {
    final roleColor = _roleColor(user.role);
    final belong = user.deptName ?? user.shopName ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        // 归属部门
        Expanded(
          flex: 2,
          child: Text(belong, style: const TextStyle(fontSize: 12, color: AppColors.text2), overflow: TextOverflow.ellipsis),
        ),
        // 姓名
        Expanded(
          flex: 2,
          child: Text(user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis),
        ),
        // 手机号
        Expanded(
          flex: 3,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_outlined, size: 11, color: AppColors.text2),
            const SizedBox(width: 3),
            Flexible(child: Text(user.phone.isNotEmpty ? user.phone : '-', style: const TextStyle(fontSize: 12, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
          ]),
        ),
        // 角色
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
            ),
            child: Text(user.roleLabel, style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ),
        ),
        // 操作
        SizedBox(
          width: 40,
          child: _canDelete(user)
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  tooltip: '删除',
                  onPressed: () => _confirmDelete(user, actions),
                )
              : const Icon(Icons.lock_outline, size: 12, color: AppColors.text2),
        ),
      ]),
    );
  }

  bool _canDelete(AdminUser user) {
    // 参考3000：管理员账号不可删除
    if (user.role == 'admin') return false;
    return true;
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppColors.danger;
      case 'driver': return AppColors.success;
      case 'leader': return AppColors.gold;
      case 'safety_officer': return AppColors.warning;
      case 'dispatcher': return AppColors.info;
      case 'applicant': return Color(0xFF9b7fd4); // purple-ish
      case 'repair_shop': return Color(0xFF4ea5d9); // blue-ish
      case 'external_repair': return Color(0xFFe8943a); // orange-ish
      default: return AppColors.text2;
    }
  }

  // ==================== 删除确认 ====================
  void _confirmDelete(AdminUser user, dynamic actions) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('确认删除', style: TextStyle(color: AppColors.text)),
        content: Text('删除用户「${user.name}」？\n此操作不可恢复。', style: const TextStyle(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await actions.deleteUser(user.id);
                if (mounted) ref.invalidate(adminUsersProvider(UserFilter()));
              } catch (e) {
                if (mounted) _snack('$e');
              }
            },
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  // ==================== 添加用户弹窗（参考3000） ====================
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddUserDialog(
        onSaved: () => ref.invalidate(adminUsersProvider(UserFilter())),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
  }
}

// ==================== 添加用户弹窗组件 ====================
class _AddUserDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddUserDialog({required this.onSaved});

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _roles = ['driver', 'repair_shop', 'leader', 'admin', 'safety_officer', 'dispatcher', 'applicant', 'external_repair'];
  final _roleLabels = roleMap;

  String _name = '', _phone = '', _role = 'driver';
  int? _deptId;
  int? _shopId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);
    final shopsAsync = ref.watch(repairShopsProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('添加用户', style: TextStyle(color: AppColors.text, fontSize: 16)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 姓名 + 手机号（参考3000: row2布局）
            Row(children: [
              Expanded(child: _tf('姓名 *', (v) => _name = v)),
              const SizedBox(width: 10),
              Expanded(child: _tf('手机号', (v) => _phone = v)),
            ]),
            const SizedBox(height: 10),
            // 角色
            _dd('角色', _role, _roles.map((r) => DropdownMenuItem(value: r, child: Text(_roleLabels[r] ?? r, style: const TextStyle(color: AppColors.text, fontSize: 13)))).toList(), (v) {
              setState(() { _role = v as String; _shopId = null; });
            }),
            const SizedBox(height: 10),
            // 部门（参考3000）
            deptsAsync.when(
              loading: () => const SizedBox(height: 44, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)))),
              error: (_, _) => const SizedBox.shrink(),
              data: (depts) => Column(children: [
                _dd('归属部门', _deptId, [
                  const DropdownMenuItem(value: null, child: Text('不指定部门', style: TextStyle(color: AppColors.text2, fontSize: 13))),
                  ...depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(color: AppColors.text, fontSize: 13)))),
                ], (v) => _deptId = v as int?),
                const SizedBox(height: 10),
              ]),
            ),
            // 修理厂（仅角色=repair_shop时显示，参考3000）
            if (_role == 'repair_shop')
              shopsAsync.when(
                loading: () => const SizedBox(height: 44, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)))),
                error: (_, _) => const SizedBox.shrink(),
                data: (shops) => _dd('选择修理厂', _shopId, [
                  const DropdownMenuItem(value: null, child: Text('请选择修理厂', style: TextStyle(color: AppColors.text2, fontSize: 13))),
                  ...shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: AppColors.text, fontSize: 13)))),
                ], (v) => _shopId = v as int?),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: AppColors.text2))),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
          child: Text(_saving ? '...' : '添加', style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_name.trim().isEmpty) { _snack('请输入姓名'); return; }
    if (_role == 'repair_shop' && _shopId == null) { _snack('请选择修理厂'); return; }
    setState(() => _saving = true);
    try {
      await ref.read(adminActionsProvider).addUser(
        name: _name.trim(),
        phone: _phone.trim(),
        role: _role,
        repairShopId: _shopId,
        departmentId: _deptId,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.danger));

  Widget _tf(String label, ValueChanged<String> onChange) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
        border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(color: AppColors.text, fontSize: 13),
      onChanged: onChange,
    );
  }

  Widget _dd(String label, dynamic value, List<DropdownMenuItem<dynamic>> items, ValueChanged<dynamic> onChange) {
    return DropdownButtonFormField<dynamic>(
      initialValue: value,
      items: items,
      onChanged: onChange,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.text2, fontSize: 13),
        border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      dropdownColor: AppColors.surface2,
      style: const TextStyle(color: AppColors.text, fontSize: 13),
    );
  }
}
