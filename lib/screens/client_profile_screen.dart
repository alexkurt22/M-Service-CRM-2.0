import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; 
import 'private_chat_screen.dart';
import 'order_details_screen.dart'; 

class ClientProfileScreen extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic> clientData;

  const ClientProfileScreen({super.key, required this.clientId, required this.clientData});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  double _averageRating = 0.0;
  int _commentsCount = 0;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть звонилку')));
    }
  }

  Future<void> _openPrivateChat(String targetPhone, String targetName) async {
    final prefs = await SharedPreferences.getInstance();
    final myPhone = prefs.getString('employee_phone') ?? 'admin';
    List<String> participants = [myPhone, targetPhone];
    participants.sort();
    String roomId = 'private_${participants[0]}_${participants[1]}';

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();
    if (!doc.exists) {
      await roomRef.set({
        'type': 'private',
        'participants': participants,
        'created_at': FieldValue.serverTimestamp(),
        'last_message': 'Чат создан',
        'last_message_time': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: roomId, targetName: targetName)));
    }
  }

  // --- ИСПРАВЛЕННАЯ ЛОГИКА PUNCH-КАРТЫ ( + и - ) ---
  Future<void> _updateCartridgeRefills(int delta) async {
    try {
      final clientRef = FirebaseFirestore.instance.collection('clients').doc(widget.clientId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(clientRef);
        int currentRefills = 0;
        if (snapshot.exists && snapshot.data()!.containsKey('cartridge_refills')) {
          currentRefills = snapshot.data()!['cartridge_refills'] ?? 0;
        }

        int newRefills = currentRefills + delta;
        if (newRefills < 0) newRefills = 0; // Защита от минуса

        transaction.set(clientRef, {'cartridge_refills': newRefills}, SetOptions(merge: true));
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddCommentDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController();
    int selectedStars = 5; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text('Оценить клиента', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Рейтинг:', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedStars ? Icons.star : Icons.star_border,
                          color: index < selectedStars ? Colors.amber : Colors.grey,
                          size: 36,
                        ),
                        onPressed: () => setModalState(() => selectedStars = index + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Опишите поведение клиента...',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900]),
                  onPressed: () async {
                    if (textController.text.trim().isEmpty) return;
                    
                    final prefs = await SharedPreferences.getInstance();
                    final author = prefs.getString('employee_phone') ?? 'admin';

                    await FirebaseFirestore.instance
                        .collection('clients')
                        .doc(widget.clientId)
                        .collection('comments')
                        .add({
                          'text': textController.text.trim(),
                          'stars': selectedStars,
                          'author': author,
                          'created_at': FieldValue.serverTimestamp(),
                        });
                    
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getRatingColor(double rating) {
    if (_commentsCount == 0) return Colors.blueGrey[900]!; 
    if (rating >= 4.0) return Colors.green[700]!; 
    if (rating >= 2.5) return Colors.orange[700]!; 
    return Colors.red[800]!; 
  }

  // Функция для красивого вывода даты
  String _formatLastActive(Timestamp? timestamp) {
    if (timestamp == null) return 'Никогда';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Сегодня в ${DateFormat('HH:mm').format(date)}';
    if (diff.inDays == 1) return 'Вчера в ${DateFormat('HH:mm').format(date)}';
    return DateFormat('dd.MM.yy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.clientData['name'] ?? 'Без имени';
    final phone = widget.clientData['phone'] ?? '';
    final isOffline = widget.clientData['is_offline'] == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).snapshots(),
        builder: (context, clientSnap) {
          int currentRefills = 0;
          int currentBonuses = 0;
          bool isDeleted = false;
          Timestamp? lastActive;

          if (clientSnap.hasData && clientSnap.data!.exists) {
            final clientMap = clientSnap.data!.data() as Map<String, dynamic>?;
            if (clientMap != null) {
              currentRefills = clientMap['cartridge_refills'] ?? 0;
              currentBonuses = clientMap['points'] ?? 0;
              lastActive = clientMap['last_active'] as Timestamp?;
              isDeleted = clientMap['app_deleted'] == true;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clients').doc(widget.clientId).collection('comments').snapshots(),
            builder: (context, snapshot) {
              
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                _commentsCount = snapshot.data!.docs.length;
                int totalStars = 0;
                for (var doc in snapshot.data!.docs) {
                  totalStars += (doc.data() as Map<String, dynamic>)['stars'] as int? ?? 5;
                }
                _averageRating = totalStars / _commentsCount;
              } else {
                _commentsCount = 0;
                _averageRating = 0.0;
              }

              final headerColor = _getRatingColor(_averageRating);

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 250.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: headerColor, 
                    foregroundColor: Colors.white,
                    flexibleSpace: FlexibleSpaceBar(
                      background: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 30.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white24,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 8),
                              Text(name, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(phone, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                              
                              const SizedBox(height: 8),

                              // --- НОВЫЙ БЛОК: ТРЕКИНГ АКТИВНОСТИ ---
                              if (isOffline)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                                  child: const Text('ОФФЛАЙН КЛИЕНТ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else if (isDeleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red[800], borderRadius: BorderRadius.circular(12)),
                                  child: const Text('УДАЛИЛ ПРИЛОЖЕНИЕ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text('В сети: ${_formatLastActive(lastActive)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),

                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      _commentsCount > 0 ? '${_averageRating.toStringAsFixed(1)} ($_commentsCount отз.)' : 'Нет оценок', 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Кнопки связи
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
                                  onPressed: phone.isNotEmpty ? () => _makePhoneCall(phone) : null,
                                  icon: const Icon(Icons.phone, color: Colors.white),
                                  label: const Text('Позвонить', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              if (!isOffline) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 12)),
                                    onPressed: phone.isNotEmpty ? () => _openPrivateChat(phone, name) : null,
                                    icon: const Icon(Icons.chat, color: Colors.white),
                                    label: const Text('Чат', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ]
                            ],
                          ),
                          
                          const SizedBox(height: 24),

                          // --- БЛОК УПРАВЛЕНИЯ PUNCH-КАРТОЙ (ИСПРАВЛЕНО) ---
                          Card(
                            elevation: 1,
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade300)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.print, color: Colors.orange),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Заправки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                          Text('Punch-карта клиента', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Новый контроллер (+ / -)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, color: Colors.redAccent),
                                          onPressed: currentRefills > 0 ? () => _updateCartridgeRefills(-1) : null,
                                        ),
                                        Text('$currentRefills', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        IconButton(
                                          icon: const Icon(Icons.add, color: Colors.green),
                                          onPressed: () => _updateCartridgeRefills(1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          
                          // --- БЛОК ОТЗЫВОВ МАСТЕРОВ ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('СЛУЖЕБНЫЕ ЗАМЕТКИ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
                              TextButton.icon(
                                onPressed: _showAddCommentDialog, 
                                icon: const Icon(Icons.add_comment, size: 18), 
                                label: const Text('Оценить')
                              )
                            ],
                          ),
                          
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Пока нет комментариев о клиенте.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final sortedDocs = snapshot.data!.docs.toList();
                                sortedDocs.sort((a, b) {
                                  final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                                  final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                                  if (aTime == null || bTime == null) return 0;
                                  return bTime.compareTo(aTime);
                                });

                                final commentData = sortedDocs[index].data() as Map<String, dynamic>;
                                final stars = commentData['stars'] as int? ?? 5;
                                final text = commentData['text'] ?? '';
                                final author = commentData['author'] ?? 'Админ';
                                
                                String dateStr = '';
                                if (commentData['created_at'] != null) {
                                   final dt = (commentData['created_at'] as Timestamp).toDate();
                                   dateStr = DateFormat('dd.MM.yy HH:mm').format(dt);
                                }

                                return Card(
                                  color: Theme.of(context).cardColor,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: stars >= 4 ? Colors.green[100] : (stars >= 3 ? Colors.orange[100] : Colors.red[100]), shape: BoxShape.circle),
                                      child: Text(stars.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: stars >= 4 ? Colors.green[800] : (stars >= 3 ? Colors.orange[800] : Colors.red[800]))),
                                    ),
                                    title: Text(text, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                                    subtitle: Text('$author • $dateStr', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey)),
                                  ),
                                );
                              },
                            ),

                          const SizedBox(height: 24),

                          // --- БЛОК ФИНАНСОВ И ИСТОРИИ (С РАСЧЕТОМ LTV) ---
                          Text('ИСТОРИЯ ЗАКАЗОВ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('orders').where('phone', isEqualTo: phone).snapshots(),
                            builder: (context, orderSnap) {
                              if (orderSnap.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                              
                              final orders = orderSnap.hasData ? orderSnap.data!.docs.toList() : [];
                              
                              // Считаем LTV (общую сумму)
                              double totalSpent = 0;
                              int completedCount = 0;
                              
                              for (var o in orders) {
                                final oData = o.data() as Map<String, dynamic>;
                                if (oData['status'] == 'completed') {
                                  completedCount++;
                                  totalSpent += double.tryParse(oData['price']?.toString() ?? '0') ?? 0;
                                }
                              }

                              orders.sort((a, b) {
                                  final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                                  final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                                  if (aTime == null || bTime == null) return 0;
                                  return bTime.compareTo(aTime);
                              });

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Мини-статистика по клиенту
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: isDark ? Colors.blue[900]?.withOpacity(0.3) : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Баланс бонусов', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.blueGrey)),
                                              Text('$currentBonuses Б', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Принес сервису', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.green[700])),
                                              Text('${totalSpent.toStringAsFixed(0)} TMT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[600])),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  if (orders.isEmpty) 
                                    const Text('Нет истории заказов', style: TextStyle(color: Colors.grey))
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: orders.length,
                                      itemBuilder: (context, i) {
                                        final oData = orders[i].data() as Map<String, dynamic>;
                                        final oStatus = oData['status'] ?? 'unknown';
                                        
                                        Color sColor = Colors.grey;
                                        if (oStatus == 'new') sColor = Colors.blue;
                                        if (oStatus == 'in_progress') sColor = Colors.orange;
                                        if (oStatus == 'completed') sColor = Colors.teal;

                                        return Card(
                                          color: Theme.of(context).cardColor,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)),
                                          child: InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => OrderDetailsScreen(
                                                    orderId: orders[i].id,
                                                    orderData: oData,
                                                    fromProfile: true,
                                                  ),
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: ListTile(
                                              leading: Icon(Icons.build_circle, color: sColor),
                                              title: Text(oData['device_type'] ?? 'Устройство', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                              subtitle: Text(oData['problem'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54)),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text('${oData['price'] ?? '?'} TMT', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                                  const SizedBox(width: 8),
                                                  const Icon(Icons.chevron_right, color: Colors.grey), 
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
          );
        }
      ),
    );
  }
}

