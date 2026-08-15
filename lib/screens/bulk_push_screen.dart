import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mservice_crm/services/fcm_service.dart';

class BulkPushScreen extends StatefulWidget {
  const BulkPushScreen({super.key});

  @override
  State<BulkPushScreen> createState() => _BulkPushScreenState();
}

class _BulkPushScreenState extends State<BulkPushScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String _selectedGender = 'Все';
  String _sortOrder = 'Сначала новые';
  
  Set<String> _selectedTokens = {};
  bool _selectAll = false;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool? val, List<DocumentSnapshot> filteredDocs) {
    setState(() {
      _selectAll = val ?? false;
      if (_selectAll) {
        _selectedTokens = filteredDocs
            .map((d) => (d.data() as Map<String, dynamic>)['fcm_token'] as String?)
            .where((t) => t != null && t.isNotEmpty)
            .cast<String>()
            .toSet();
      } else {
        _selectedTokens.clear();
      }
    });
  }

  void _toggleClient(String token) {
    setState(() {
      if (_selectedTokens.contains(token)) {
        _selectedTokens.remove(token);
        _selectAll = false; // Снимаем общую галочку, если сняли хоть одну ручную
      } else {
        _selectedTokens.add(token);
      }
    });
  }

  Future<void> _sendPushNotifications() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните заголовок и текст рассылки!'), backgroundColor: Colors.red));
      return;
    }

    if (_selectedTokens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите хотя бы одного клиента!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSending = true);

    try {
      int successCount = 0;
      for (String token in _selectedTokens) {
        // Отправляем пуши по одному (маркетинговый тип)
        await FCMService.sendPushNotification(token, title, body, 'marketing');
        successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Рассылка успешно отправлена $successCount клиентам!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Маркетинговая рассылка', style: TextStyle(fontSize: 18)),
      ),
      body: Column(
        children: [
          // --- БЛОК 1: ФОРМА СООБЩЕНИЯ ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Заголовок (Напр: Скидка 20% на чистку!)',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    prefixIcon: const Icon(Icons.campaign, color: Colors.orange),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Текст уведомления',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),

          // --- БЛОК 2: ФИЛЬТРЫ И СОРТИРОВКА ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelText: 'Пол',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: ['Все', 'Мужской', 'Женский'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() { _selectedGender = v!; _selectAll = false; _selectedTokens.clear(); }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortOrder,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelText: 'Сортировка',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: ['Сначала новые', 'Сначала старые'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _sortOrder = v!),
                  ),
                ),
              ],
            ),
          ),

          // --- БЛОК 3: СПИСОК КЛИЕНТОВ ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('clients').where('is_approved', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Нет доступных клиентов'));
                }

                // 1. Фильтрация (оставляем только с токенами и по полу)
                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final token = data['fcm_token'];
                  final gender = data['gender'] ?? 'Не указан';
                  
                  if (token == null || token.toString().isEmpty) return false;
                  
                  if (_selectedGender != 'Все' && gender != _selectedGender) return false;
                  
                  return true;
                }).toList();

                // 2. Сортировка по дате
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  
                  return _sortOrder == 'Сначала новые' 
                      ? bTime.compareTo(aTime) 
                      : aTime.compareTo(bTime);
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('Ни один клиент не подходит под фильтры', style: TextStyle(color: Colors.grey)));
                }

                return Column(
                  children: [
                    // Галочка "ВЫБРАТЬ ВСЕХ"
                    Container(
                      color: isDark ? Colors.grey[850] : Colors.blueGrey[50],
                      child: CheckboxListTile(
                        value: _selectAll,
                        activeColor: Colors.blue[700],
                        title: Text('Выбрать всех (${docs.length} чел.)', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        onChanged: (val) => _toggleSelectAll(val, docs),
                      ),
                    ),
                    const Divider(height: 1),
                    // Сам список
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final token = data['fcm_token'] as String;
                          final name = data['name'] ?? 'Без имени';
                          final phone = data['phone'] ?? '';
                          final gender = data['gender'] ?? 'Не указан';
                          
                          String dateStr = '';
                          if (data['created_at'] != null) {
                            final dt = (data['created_at'] as Timestamp).toDate();
                            dateStr = DateFormat('dd.MM.yy').format(dt);
                          }

                          bool isChecked = _selectedTokens.contains(token);

                          return Column(
                            children: [
                              CheckboxListTile(
                                value: isChecked,
                                activeColor: Colors.orange,
                                selectedTileColor: isDark ? Colors.orange[900]?.withOpacity(0.1) : Colors.orange[50],
                                selected: isChecked,
                                title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                subtitle: Text('$phone • $gender • Рег: $dateStr', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700], fontSize: 12)),
                                onChanged: (val) => _toggleClient(token),
                              ),
                              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // --- КНОПКА ОТПРАВКИ С УМНЫМ ОТСТУПОМ ---
          Container(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              top: 16, 
              bottom: MediaQuery.of(context).padding.bottom + 16 // <-- УМНЫЙ ОТСТУП ЗДЕСЬ
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSending ? null : _sendPushNotifications,
                icon: _isSending 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(
                  _isSending ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ (${_selectedTokens.length} КЛИЕНТАМ)', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
