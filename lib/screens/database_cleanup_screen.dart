import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseCleanupScreen extends StatefulWidget {
  const DatabaseCleanupScreen({super.key});

  @override
  State<DatabaseCleanupScreen> createState() => _DatabaseCleanupScreenState();
}

class _DatabaseCleanupScreenState extends State<DatabaseCleanupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Наборы для хранения ID выбранных элементов
  final Set<String> _selectedClients = {};
  final Set<String> _selectedOrders = {};

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Обновляем экран при переключении вкладок, чтобы менять кнопку FAB
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- УДАЛЕНИЕ ОДНОГО ДОКУМЕНТА (Оставил на всякий случай) ---
  Future<void> _deleteSingleDocument(String collection, String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение удаления', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Вы действительно хотите безвозвратно удалить $title?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.blueGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
        setState(() {
          if (collection == 'clients') _selectedClients.remove(docId);
          if (collection == 'orders') _selectedOrders.remove(docId);
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Успешно удалено'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- МАССОВОЕ УДАЛЕНИЕ ВЫБРАННЫХ (С ОБХОДОМ ЛИМИТА FIREBASE В 500 ЗАПИСЕЙ) ---
  Future<void> _deleteSelectedBatch(String collection, Set<String> selectedIds) async {
    final count = selectedIds.length;
    final typeName = collection == 'clients' ? 'пользователей' : 'заказов';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('МАССОВОЕ УДАЛЕНИЕ!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Вы действительно хотите БЕЗВОЗВРАТНО удалить $count $typeName? Это действие отменить нельзя.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('УНИЧТОЖИТЬ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        final db = FirebaseFirestore.instance;
        final list = selectedIds.toList();

        // Firebase WriteBatch принимает максимум 500 операций за раз.
        // Поэтому дробим наш огромный список на чанки (куски) по 500 штук.
        for (int i = 0; i < list.length; i += 500) {
          final batch = db.batch();
          final end = (i + 500 < list.length) ? i + 500 : list.length;
          final chunk = list.sublist(i, end);
          
          for (String id in chunk) {
            batch.delete(db.collection(collection).doc(id));
          }
          await batch.commit(); // Отправляем пачку на сервер
        }

        if (mounted) {
           setState(() {
              if (collection == 'clients') _selectedClients.clear();
              else _selectedOrders.clear();
           });
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Успешно удалено $count записей!'), backgroundColor: Colors.green));
        }
      } catch(e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка массового удаления: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  // --- СПИСОК КЛИЕНТОВ ---
  Widget _buildClientsList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('База пользователей пуста', style: TextStyle(color: Colors.grey)));

        final docs = snapshot.data!.docs;
        final allSelected = _selectedClients.length == docs.length && docs.isNotEmpty;

        return Column(
          children: [
            // ПАНЕЛЬ "ВЫБРАТЬ ВСЕ"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Всего в базе: ${docs.length}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedClients.clear();
                        } else {
                          _selectedClients.addAll(docs.map((d) => d.id));
                        }
                      });
                    }, 
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all, color: Colors.blue),
                    label: Text(allSelected ? 'Снять выделение' : 'Выбрать всех', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Без имени';
                  final phone = data['phone'] ?? doc.id;
                  final isApproved = data['is_approved'] == true;
                  final isSelected = _selectedClients.contains(doc.id);

                  return Card(
                    elevation: isSelected ? 2 : 1,
                    color: isSelected ? (isDark ? Colors.red[900]?.withOpacity(0.3) : Colors.red[50]) : Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), 
                      side: BorderSide(color: isSelected ? Colors.red : (isDark ? Colors.grey[800]! : Colors.grey.shade200), width: isSelected ? 2 : 1)
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.red,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.only(left: 8, right: 16),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) _selectedClients.add(doc.id);
                          else _selectedClients.remove(doc.id);
                        });
                      },
                      title: Row(
                        children: [
                          Icon(isApproved ? Icons.person : Icons.person_outline, color: isApproved ? Colors.green : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(phone),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Удалить одного',
                        onPressed: () => _deleteSingleDocument('clients', doc.id, 'пользователя "$name"'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- СПИСОК ЗАКАЗОВ ---
  Widget _buildOrdersList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('База заказов пуста', style: TextStyle(color: Colors.grey)));

        final docs = snapshot.data!.docs;
        final allSelected = _selectedOrders.length == docs.length && docs.isNotEmpty;

        return Column(
          children: [
            // ПАНЕЛЬ "ВЫБРАТЬ ВСЕ"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Всего в базе: ${docs.length}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedOrders.clear();
                        } else {
                          _selectedOrders.addAll(docs.map((d) => d.id));
                        }
                      });
                    }, 
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all, color: Colors.blue),
                    label: Text(allSelected ? 'Снять выделение' : 'Выбрать все', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final device = data['device_type'] ?? 'Устройство';
                  final clientName = data['client_name'] ?? 'Неизвестный';
                  final status = data['status'] ?? '';
                  final isSelected = _selectedOrders.contains(doc.id);

                  return Card(
                    elevation: isSelected ? 2 : 1,
                    color: isSelected ? (isDark ? Colors.red[900]?.withOpacity(0.3) : Colors.red[50]) : Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), 
                      side: BorderSide(color: isSelected ? Colors.red : (isDark ? Colors.grey[800]! : Colors.grey.shade200), width: isSelected ? 2 : 1)
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.red,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.only(left: 8, right: 16),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) _selectedOrders.add(doc.id);
                          else _selectedOrders.remove(doc.id);
                        });
                      },
                      title: Row(
                        children: [
                          const Icon(Icons.build, color: Colors.blueGrey, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('$device ($clientName)', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('Статус: $status'),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Удалить один',
                        onPressed: () => _deleteSingleDocument('orders', doc.id, 'заказ "$device"'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  int _getSelectedCount() {
    return _tabController.index == 0 ? _selectedClients.length : _selectedOrders.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.red[900], 
            foregroundColor: Colors.white,
            title: const Text('Очистка базы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.group), text: 'Пользователи'),
                Tab(icon: Icon(Icons.home_repair_service), text: 'Заказы'),
              ],
            ),
          ),
          
          // --- ПЛАВАЮЩАЯ КНОПКА МАССОВОГО УДАЛЕНИЯ ---
          floatingActionButton: _getSelectedCount() > 0 
            ? FloatingActionButton.extended(
                onPressed: () {
                  String collection = _tabController.index == 0 ? 'clients' : 'orders';
                  Set<String> ids = _tabController.index == 0 ? _selectedClients : _selectedOrders;
                  _deleteSelectedBatch(collection, ids);
                },
                backgroundColor: Colors.red[700],
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                label: Text('УДАЛИТЬ (${_getSelectedCount()})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
            
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildClientsList(isDark),
              _buildOrdersList(isDark),
            ],
          ),
        ),
        
        // --- ЭКРАН ЗАГРУЗКИ ПОВЕРХ ВСЕГО ---
        if (_isDeleting)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.redAccent),
                  SizedBox(height: 16),
                  Text('Идет массовое удаление...\nПожалуйста, подождите.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none)),
                ],
              ),
            ),
          )
      ],
    );
  }
}
