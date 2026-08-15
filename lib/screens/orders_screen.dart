import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'order_details_screen.dart';
import 'offline_order_screen.dart'; 

class OrdersScreen extends StatefulWidget {
  final String status;
  final String title;

  const OrdersScreen({
    super.key, 
    required this.status, 
    required this.title,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String _myPhone = 'admin';
  String _myRole = 'Сотрудник';
  List<dynamic> _myPermissions = [];
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? 'admin';
    
    if (phone != 'admin') {
       final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
       if (doc.exists) {
         _myRole = doc.data()?['role'] ?? 'Сотрудник';
         _myPermissions = doc.data()?['permissions'] ?? [];
       }
    }
    
    setState(() {
      _myPhone = phone;
      _isLoadingUser = false;
    });
  }

  bool _hasPermission(String permission) {
    if (_myRole == 'Владелец') return true; 
    return _myPermissions.contains(permission);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Функция для красивого вывода времени создания заказа
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Время неизвестно';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    if (isToday) {
      return 'Сегодня в ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd.MM.yy в HH:mm').format(date);
    }
  }

  Widget _buildOrdersList(String statusKey, bool isDark) {
    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- 1. ЛОГИКА ГИБКОГО ЗАПРОСА ДЛЯ СБОРНЫХ ЭКРАНОВ ---
    Query query = FirebaseFirestore.instance.collection('orders');

    if (statusKey == 'incoming') {
      query = query.where('status', whereIn: ['new', 'awaiting_approval']);
    } else if (statusKey == 'archive') {
      query = query.where('status', whereIn: ['completed', 'canceled']);
    } else {
      query = query.where('status', isEqualTo: statusKey);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка базы данных', style: TextStyle(color: Colors.red[700])));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDark);
        }

        var docs = snapshot.data!.docs.toList();

        // --- ЛОГИКА ОГРАНИЧЕНИЯ ДОСТУПА ПО РОЛЯМ ---
        if (!_hasPermission('view_all_orders')) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['assigned_to'] == _myPhone;
          }).toList();
        }

        if (docs.isEmpty) {
           return _buildEmptyState(isDark);
        }

        // --- ЛОГИКА УМНОГО ПОИСКА ЗАКАЗОВ ---
        if (_searchQuery.isNotEmpty) {
          final queryText = _searchQuery.toLowerCase();
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['client_name'] ?? '').toString().toLowerCase();
            final phone = (data['phone'] ?? '').toString().toLowerCase();
            final device = (data['device_type'] ?? '').toString().toLowerCase();
            final problem = (data['problem'] ?? '').toString().toLowerCase();
            
            return name.contains(queryText) || phone.contains(queryText) || device.contains(queryText) || problem.contains(queryText);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                const SizedBox(height: 16),
                Text('Ничего не найдено', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 16)),
              ],
            ),
          );
        }

        // Сортировка: Сначала с непрочитанными обновлениями, затем по дате
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          bool aUnread = aData['has_unread_update'] == true;
          bool bUnread = bData['has_unread_update'] == true;
          if (aUnread && !bUnread) return -1;
          if (!aUnread && bUnread) return 1;

          final aTime = aData['created_at'] as Timestamp?;
          final bTime = bData['created_at'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: EdgeInsets.only(
            top: 12.0,
            left: 12.0,
            right: 12.0,
            bottom: MediaQuery.of(context).padding.bottom + 120.0, 
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final clientName = data['client_name'] ?? 'Неизвестный клиент';
            final deviceType = data['device_type'] ?? 'Устройство';
            final currentStatus = data['status'] ?? 'new';
            final hasUnreadUpdate = data['has_unread_update'] == true; 
            
            final createdAt = data['created_at'] as Timestamp?;
            
            Color iconColor = Colors.blue; // По умолчанию для новых
            IconData statusIcon = Icons.new_releases;
            
            if (currentStatus == 'awaiting_approval') {
              iconColor = Colors.deepPurple;
              statusIcon = Icons.hourglass_empty;
            } else if (currentStatus == 'in_progress') {
              iconColor = Colors.orange;
              statusIcon = Icons.build_circle;
            } else if (currentStatus == 'completed') {
              iconColor = Colors.teal;
              statusIcon = Icons.check_circle;
            } else if (currentStatus == 'canceled') {
              iconColor = Colors.red;
              statusIcon = Icons.cancel;
            }

            Color cardColor = Theme.of(context).cardColor;
            BorderSide borderSide = BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent);

            if (hasUnreadUpdate) {
              cardColor = isDark ? Colors.red[900]!.withOpacity(0.3) : Colors.red[50]!;
              borderSide = BorderSide(color: isDark ? Colors.red[700]! : Colors.red[300]!, width: 2);
            } else if (currentStatus == 'completed') {
              borderSide = BorderSide(color: Colors.teal.withOpacity(0.5), width: 1);
            } else if (currentStatus == 'canceled') {
              borderSide = BorderSide(color: Colors.red.withOpacity(0.3), width: 1);
            }

            return Card(
              elevation: hasUnreadUpdate ? 3 : 1,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: borderSide,
              ),
              margin: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  if (hasUnreadUpdate) {
                    await FirebaseFirestore.instance.collection('orders').doc(doc.id).update({
                      'has_unread_update': false,
                    });
                  }

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsScreen(orderId: doc.id, orderData: data),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(statusIcon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87))),
                                if (hasUnreadUpdate)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('НОВОЕ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  )
                              ],
                            ),
                            const SizedBox(height: 4),
                            // ВЫВОД УСТРОЙСТВА И ВРЕМЕНИ СОЗДАНИЯ ЗАКАЗА
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(deviceType, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.blueGrey[800], fontWeight: FontWeight.w600))),
                                Text(_formatTime(createdAt), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['problem'] ?? 'Проблема не указана',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isDark ? Colors.grey[500] : Colors.blueGrey[400], fontSize: 13),
                            ),
                            
                            // БЫСТРЫЙ ВЫВОД ИНФОРМАЦИИ В АРХИВЕ
                            if (currentStatus == 'completed' && data['price'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0), // <-- ИСПРАВЛЕНО
                                child: Text('Сумма: ${data['price']}', style: TextStyle(color: isDark ? Colors.tealAccent : Colors.teal, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            if (currentStatus == 'canceled' && data['cancel_reason'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0), // <-- ИСПРАВЛЕНО
                                child: Text('Причина: ${data['cancel_reason']}', style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[600], fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.blueGrey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
          const SizedBox(height: 16),
          Text('В этой категории пока пусто', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: Text(widget.title), 
      ),
      // КНОПКА ДОБАВЛЕНИЯ ЗАКАЗА ТЕПЕРЬ ТОЛЬКО ВО ВКЛАДКЕ INCOMING (ПОСТУПИВШИЕ)
      floatingActionButton: widget.status == 'incoming' && _hasPermission('view_all_orders') 
          ? Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8.0),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfflineOrderScreen()),
                  );
                },
                backgroundColor: Colors.orange[600],
                tooltip: 'Ручной ввод заказа',
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Поиск по имени, номеру или устройству...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(child: _buildOrdersList(widget.status, isDark)),
        ],
      ), 
    );
  }
}

