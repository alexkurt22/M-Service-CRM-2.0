import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'private_chat_screen.dart'; 
import 'import_clients_screen.dart';
import 'client_profile_screen.dart'; 
import 'package:intl/intl.dart'; // Нужно для форматирования даты

class UsersScreen extends StatefulWidget {
  final int tabType;
  final String title;

  const UsersScreen({
    super.key, 
    required this.tabType,
    required this.title,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть звонилку на этом устройстве')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка вызова: $e')),
        );
      }
    }
  }

  void _approveUser(String docId) {
    FirebaseFirestore.instance.collection('clients').doc(docId).update({
      'is_approved': true,
      'rejection_reason': null,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Клиент одобрен'), backgroundColor: Colors.green));
  }

  void _rejectUser(BuildContext context, String docId) {
    String selectedReason = 'Неверный номер';
    final reasons = ['Неверный номер', 'Неверный код', 'Спам'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text('Причина отклонения', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              content: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedReason,
                  dropdownColor: Theme.of(context).cardColor,
                  isExpanded: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedReason = val);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Отмена', style: TextStyle(color: Colors.blueGrey))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('clients').doc(docId).update({
                      'is_approved': false,
                      'rejection_reason': selectedReason,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _deepDeleteClient(String docId, String name) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Удаление клиента', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(
          'Вы уверены, что хотите безвозвратно удалить клиента "$name"?\n\nВся его история баллов, комментариев и профиль будут удалены навсегда.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
            label: const Text('Удалить навсегда', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final clientRef = FirebaseFirestore.instance.collection('clients').doc(docId);
      final batch = FirebaseFirestore.instance.batch();

      final bonusHistory = await clientRef.collection('bonus_history').get();
      for (var doc in bonusHistory.docs) {
        batch.delete(doc.reference);
      }

      final comments = await clientRef.collection('comments').get();
      for (var doc in comments.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(clientRef);
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Клиент и вся его история успешно удалены'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _openPrivateChat(BuildContext context, String targetPhone, String targetName) async {
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

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PrivateChatScreen(roomId: roomId, targetName: targetName)
      ));
    }
  }

  void _showAddOfflineClientDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+993');
    bool isSaving = false;
    bool isChecking = false;
    String warningMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            void checkPhone(String currentPhone) async {
              if (currentPhone.length < 11) {
                setModalState(() => warningMessage = '');
                return;
              }
              setModalState(() { isChecking = true; warningMessage = ''; });
              
              final existingCheck = await FirebaseFirestore.instance
                  .collection('clients')
                  .where('phone', isEqualTo: currentPhone)
                  .get();

              setModalState(() {
                isChecking = false;
                if (existingCheck.docs.isNotEmpty) {
                  final clientName = existingCheck.docs.first.data()['name'] ?? 'Неизвестно';
                  warningMessage = 'Этот номер уже принадлежит клиенту: $clientName';
                }
              });
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text('Новый клиент (Оффлайн)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Номер телефона',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      prefixIcon: Icon(Icons.phone, color: isDark ? Colors.white54 : Colors.blueGrey),
                      suffixIcon: isChecking ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.blue[300]! : Colors.blue)),
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: checkPhone, 
                  ),
                  
                  if (warningMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(warningMessage, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Имя клиента',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      prefixIcon: Icon(Icons.person, color: isDark ? Colors.white54 : Colors.blueGrey),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.blue[300]! : Colors.blue)),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена', style: TextStyle(color: Colors.blueGrey)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: warningMessage.isNotEmpty ? Colors.grey : Colors.blueGrey[900]),
                  onPressed: (isSaving || warningMessage.isNotEmpty) ? null : () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty || phone.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните корректно Телефон и Имя')));
                      return;
                    }

                    setModalState(() => isSaving = true);

                    try {
                      await FirebaseFirestore.instance.collection('clients').add({
                        'name': name,
                        'phone': phone,
                        'is_offline': true, 
                        'is_approved': false,
                        'created_at': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Оффлайн клиент успешно добавлен!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                      setModalState(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Сохранить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      }
    );
  }

  // Вспомогательная функция для красивого формата даты
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Неизвестно';
    return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
  }

  Widget _buildUsersList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Пусто', style: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey[400], fontSize: 16)));
        }

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final reason = data['rejection_reason'];
          final isApproved = data['is_approved'] == true;
          final isOffline = data['is_offline'] == true;

          // ФИЛЬТРАЦИЯ ПО ВКЛАДКАМ (0 - Ждут, 1 - Оффлайн, 2 - С приложением, 3 - Отклоненные)
          bool matchesTab = false;
          if (widget.tabType == 0) matchesTab = !isApproved && reason == null && !isOffline; 
          if (widget.tabType == 1) matchesTab = isOffline; 
          if (widget.tabType == 2) matchesTab = isApproved && !isOffline; 
          if (widget.tabType == 3) matchesTab = !isApproved && reason != null; 

          if (!matchesTab) return false;

          // УМНЫЙ ПОИСК
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final phone = (data['phone'] ?? '').toLowerCase();
            final name = (data['name'] ?? '').toLowerCase();
            
            if (!phone.contains(query) && !name.contains(query)) {
              return false; 
            }
          }

          return true;
        }).toList();

        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                const SizedBox(height: 16),
                Text(_searchQuery.isNotEmpty ? 'Ничего не найдено' : 'В этой категории пока пусто', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80, top: 12, left: 12, right: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final isPending = widget.tabType == 0;
            final isRejected = widget.tabType == 3;
            final isActive = widget.tabType == 2;
            final isOfflineTab = widget.tabType == 1;
            
            final phone = data['phone'] ?? '';
            final name = data['name'] ?? 'Без имени';
            final lastSeen = data['last_seen'] as Timestamp?;
            final fcmToken = data['fcm_token'] as String?;
            
            // Проверка: удалил ли человек приложение (нет токена, но он в табе "С приложением")
            final bool hasDeletedApp = isActive && (fcmToken == null || fcmToken.isEmpty);

            List<Widget> trailingActions = [];

            if (phone.isNotEmpty) {
              trailingActions.add(
                IconButton(
                  icon: Icon(Icons.phone_in_talk, color: isDark ? Colors.teal[300] : Colors.teal),
                  onPressed: () => _makePhoneCall(phone),
                  tooltip: 'Позвонить',
                )
              );
            }

            if (isPending) {
              trailingActions.add(
                IconButton(
                  icon: Icon(Icons.check_circle, color: isDark ? Colors.green[300] : Colors.green),
                  onPressed: () => _approveUser(doc.id),
                  tooltip: 'Одобрить',
                )
              );
              trailingActions.add(
                IconButton(
                  icon: Icon(Icons.cancel, color: isDark ? Colors.red[300] : Colors.red),
                  onPressed: () => _rejectUser(context, doc.id),
                  tooltip: 'Отклонить',
                )
              );
            } else if (isActive && phone.isNotEmpty) {
              trailingActions.add(
                IconButton(
                  icon: Icon(Icons.chat, color: isDark ? Colors.blue[300] : Colors.blue),
                  onPressed: () => _openPrivateChat(context, phone, name),
                  tooltip: 'Написать сообщение',
                )
              );
            }

            trailingActions.add(
              IconButton(
                icon: Icon(Icons.delete_forever, color: isDark ? Colors.red[400] : Colors.red[700]),
                onPressed: () => _deepDeleteClient(doc.id, name),
                tooltip: 'Удалить клиента и историю',
              )
            );

            return Card(
              elevation: 1,
              color: Theme.of(context).cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: hasDeletedApp ? Colors.red.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.transparent))
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientProfileScreen(
                        clientId: doc.id,
                        clientData: data,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive 
                          ? (isDark ? Colors.green[900]?.withOpacity(0.4) : Colors.green[100]) 
                          : (isRejected ? (isDark ? Colors.red[900]?.withOpacity(0.4) : Colors.red[100]) 
                          : (isOfflineTab ? (isDark ? Colors.grey[800] : Colors.grey[200]) 
                          : (isDark ? Colors.orange[900]?.withOpacity(0.4) : Colors.orange[100]))),
                      child: Icon(
                        isActive ? Icons.verified_user : (isRejected ? Icons.person_off : (isOfflineTab ? Icons.person_outline : Icons.person_add)),
                        color: isActive ? Colors.green : (isRejected ? Colors.red : (isOfflineTab ? Colors.grey : Colors.orange)),
                      ),
                    ),
                    title: RichText(
                      text: TextSpan(
                        text: name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                        children: [
                          if (hasDeletedApp)
                            const TextSpan(
                              text: ' (Удалил App)',
                              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.normal),
                            ),
                        ]
                      )
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.phone, size: 16, color: isDark ? Colors.grey[400] : Colors.blueGrey),
                              const SizedBox(width: 6),
                              Text(phone, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                            ],
                          ),
                          
                          // НОВОЕ: ОТОБРАЖЕНИЕ LAST_SEEN (ДАТА ПОСЛЕДНЕГО ВХОДА)
                          if (isActive && lastSeen != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: isDark ? Colors.grey[400] : Colors.blueGrey),
                                const SizedBox(width: 6),
                                Text('Был(а): ${_formatDate(lastSeen)}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ],

                          const SizedBox(height: 6),
                          if (isPending)
                            Row(
                              children: [
                                Icon(Icons.sms, size: 16, color: isDark ? Colors.orange[300] : Colors.deepOrange),
                                const SizedBox(width: 6),
                                Text('Код из SMS: ${data['sms_code'] ?? '-'}', style: TextStyle(color: isDark ? Colors.orange[300] : Colors.deepOrange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          if (isRejected)
                            Row(
                              children: [
                                Icon(Icons.error_outline, size: 16, color: isDark ? Colors.red[300] : Colors.red),
                                const SizedBox(width: 6),
                                Expanded(child: Text('Причина: ${data['rejection_reason'] ?? '-'}', style: TextStyle(color: isDark ? Colors.red[300] : Colors.red))),
                              ],
                            ),
                          if (isOfflineTab)
                            Row(
                              children: [
                                Icon(Icons.app_blocking, size: 16, color: isDark ? Colors.grey[500] : Colors.grey),
                                const SizedBox(width: 6),
                                Text('Добавлен вручную', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        ...trailingActions,
                      ]
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
        actions: [
          if (widget.tabType == 1)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Массовый импорт базы',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportClientsScreen()));
              },
            ),
        ],
      ),
      floatingActionButton: widget.tabType == 1 
          ? FloatingActionButton.extended(
              onPressed: _showAddOfflineClientDialog,
              backgroundColor: isDark ? Colors.blueGrey[700] : Colors.blueGrey[800],
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Добавить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          // ПОЛОСА УМНОГО ПОИСКА
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
                hintText: 'Поиск по имени или телефону...',
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
          
          // СПИСОК КЛИЕНТОВ
          Expanded(child: _buildUsersList(isDark)),
        ],
      ), 
    );
  }
}

