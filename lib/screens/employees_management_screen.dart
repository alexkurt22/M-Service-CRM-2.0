import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeesManagementScreen extends StatefulWidget {
  const EmployeesManagementScreen({super.key});

  @override
  State<EmployeesManagementScreen> createState() => _EmployeesManagementScreenState();
}

class _EmployeesManagementScreenState extends State<EmployeesManagementScreen> {
  final List<String> _roles = [
    'Исполнитель (Мастер)',
    'Менеджер',
    'Администратор',
    'Маркетолог',
    'Владелец'
  ];

  // Одобрение сотрудника с назначением роли
  Future<void> _approveEmployee(String phoneId, String role) async {
    try {
      await FirebaseFirestore.instance.collection('employees').doc(phoneId).update({
        'is_approved': true,
        'role': role,
        // По умолчанию новому сотруднику даем базовые права
        'permissions': ['view_own_orders'] 
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сотрудник одобрен!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  // Удаление (отклонение заявки или увольнение)
  Future<void> _deleteEmployee(String phoneId) async {
    try {
      await FirebaseFirestore.instance.collection('employees').doc(phoneId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Доступ удален'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  // --- НОВОЕ: ОБНОВЛЕНИЕ ПРАВ ДОСТУПА ---
  Future<void> _updatePermissions(String phoneId, List<dynamic> permissions) async {
    try {
      await FirebaseFirestore.instance.collection('employees').doc(phoneId).update({
        'permissions': permissions,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Права обновлены!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  // Всплывающее окно для НОВЫХ заявок
  void _showApprovalDialog(Map<String, dynamic> data, String phoneId) {
    String selectedRole = 'Исполнитель (Мастер)';
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Модерация заявки', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Имя: ${data['name']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Телефон: ${data['phone']}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                  child: Row(
                    children: [
                      const Icon(Icons.sms, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('Код СМС: ${data['verification_code'] ?? 'Нет'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Назначить должность', border: OutlineInputBorder()),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setState(() => selectedRole = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _deleteEmployee(phoneId);
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Отклонить'),
              ),
              ElevatedButton(
                onPressed: () {
                  _approveEmployee(phoneId, selectedRole);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                child: const Text('Одобрить доступ'),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- НОВОЕ: ВСПЛЫВАЮЩЕЕ ОКНО НАСТРОЙКИ ПРАВ ---
  void _showPermissionsDialog(Map<String, dynamic> data, String phoneId) {
    List<dynamic> currentPermissions = data['permissions'] ?? [];
    
    // Вспомогательная функция для чекбоксов
    Widget buildCheckbox(String key, String title, StateSetter setStateDialog) {
      return CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        value: currentPermissions.contains(key),
        activeColor: Colors.blueGrey[900],
        onChanged: (bool? value) {
          setStateDialog(() {
            if (value == true) {
              currentPermissions.add(key);
            } else {
              currentPermissions.remove(key);
            }
          });
        },
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Права: ${data['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildCheckbox('view_all_orders', 'Видеть все заказы (чужие)', setStateDialog),
                  buildCheckbox('view_finance', 'Видеть финансы и статистику', setStateDialog),
                  buildCheckbox('manage_clients', 'Управлять базой клиентов', setStateDialog),
                  buildCheckbox('manage_settings', 'Настройки, Услуги и Контент', setStateDialog),
                  buildCheckbox('send_push', 'Отправлять Push-рассылки', setStateDialog),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                onPressed: () {
                  _updatePermissions(phoneId, currentPermissions);
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить права'),
              ),
            ],
          );
        }
      ),
    );
  }

  // Всплывающее окно для АКТИВНЫХ сотрудников
  void _showEditDialog(Map<String, dynamic> data, String phoneId) {
    String currentRole = data['role'] ?? 'Исполнитель (Мастер)';
    if (!_roles.contains(currentRole)) currentRole = _roles[0];
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Телефон: ${data['phone']}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: currentRole,
                  decoration: const InputDecoration(labelText: 'Изменить должность', border: OutlineInputBorder()),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setState(() => currentRole = val!),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  _deleteEmployee(phoneId);
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.person_off),
                label: const Text('Уволить'),
              ),
              ElevatedButton(
                onPressed: () async {
                   await FirebaseFirestore.instance.collection('employees').doc(phoneId).update({
                    'role': currentRole,
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Должность обновлена'), backgroundColor: Colors.green));
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                child: const Text('Сохранить'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Сотрудники', style: TextStyle(fontSize: 18)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: 'ОЖИДАЮТ', icon: Icon(Icons.timer)),
              Tab(text: 'АКТИВНЫЕ', icon: Icon(Icons.check_circle)),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('employees').orderBy('created_at', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Список сотрудников пуст', style: TextStyle(color: Colors.grey, fontSize: 16)));
            }

            final docs = snapshot.data!.docs;
            final pending = docs.where((d) => (d.data() as Map<String, dynamic>)['is_approved'] == false).toList();
            final active = docs.where((d) => (d.data() as Map<String, dynamic>)['is_approved'] == true).toList();

            return TabBarView(
              children: [
                // ВКЛАДКА 1: ОЖИДАЮТ
                pending.isEmpty
                    ? const Center(child: Text('Нет новых заявок', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: pending.length,
                        itemBuilder: (ctx, i) {
                          final data = pending[i].data() as Map<String, dynamic>;
                          final docId = pending[i].id;
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange[200]!, width: 2)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(backgroundColor: Colors.orange[100], child: const Icon(Icons.person_add, color: Colors.orange)),
                              title: Text(data['name'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(data['phone'] ?? ''),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                                onPressed: () => _showApprovalDialog(data, docId),
                                child: const Text('Смотреть'),
                              ),
                            ),
                          );
                        },
                      ),

                // ВКЛАДКА 2: АКТИВНЫЕ
                active.isEmpty
                    ? const Center(child: Text('Нет активных сотрудников', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: active.length,
                        itemBuilder: (ctx, i) {
                          final data = active[i].data() as Map<String, dynamic>;
                          final docId = active[i].id;
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: Colors.blueGrey[100], child: const Icon(Icons.person, color: Colors.blueGrey)),
                              title: Text(data['name'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${data['role']} • ${data['phone']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // --- НОВАЯ КНОПКА ПРАВ ДОСТУПА ---
                                  IconButton(
                                    icon: const Icon(Icons.security, color: Colors.orange),
                                    tooltip: 'Права доступа',
                                    onPressed: () => _showPermissionsDialog(data, docId),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.settings, color: Colors.grey),
                                    tooltip: 'Настройки',
                                    onPressed: () => _showEditDialog(data, docId),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

