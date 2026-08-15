import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // <--- НОВЫЙ ИМПОРТ ДЛЯ ФОРМАТИРОВАНИЯ ДАТ
import 'package:mservice_crm/services/fcm_service.dart';
import 'client_profile_screen.dart'; 

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final bool fromProfile;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.orderData,
    this.fromProfile = false,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final List<Map<String, TextEditingController>> _options = [
    {
      'description': TextEditingController(),
      'price': TextEditingController(),
    }
  ];
  
  bool _isLoading = false;
  bool _isBargainingMode = false; 
  String? _myPhone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _myPhone = prefs.getString('employee_phone');
      });
    }
  }

  @override
  void dispose() {
    for (var opt in _options) {
      opt['description']?.dispose();
      opt['price']?.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _options.add({
        'description': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  void _removeOption(int index) {
    if (_options.length > 1) {
      setState(() {
        _options[index]['description']?.dispose();
        _options[index]['price']?.dispose();
        _options.removeAt(index);
      });
    }
  }

  Future<void> _openClientProfile() async {
    final String? phone = widget.orderData['phone'];
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Номер телефона не найден')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isEqualTo: phone)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final clientDoc = querySnapshot.docs.first;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientProfileScreen(
                clientId: clientDoc.id,
                clientData: clientDoc.data(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientProfileScreen(
                clientId: 'unknown_client',
                clientData: {
                  'name': widget.orderData['client_name'] ?? 'Без имени',
                  'phone': phone,
                  'is_offline': true,
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки профиля: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDelegationSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String orderText = '''
🛒 НОВЫЙ ЗАКАЗ #${widget.orderId.substring(0, 5).toUpperCase()}
📱 Устройство: ${widget.orderData['device_type'] ?? 'Не указано'}
⚠️ Проблема: ${widget.orderData['problem'] ?? 'Не указана'}
👤 Клиент: ${widget.orderData['client_name'] ?? 'Без имени'}
📞 Телефон: ${widget.orderData['phone'] ?? 'Не указан'}
💳 Оплата: ${widget.orderData['payment_method'] ?? 'Наличные'}
    '''.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            Text('Передать заказ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.share, color: Colors.white)),
              title: Text('Отправить во внешний мессенджер', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              subtitle: Text('WhatsApp, Telegram, SMS и др.', style: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(orderText);
              },
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue[600], child: const Icon(Icons.copy, color: Colors.white)),
              title: Text('Скопировать текст заказа', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: orderText));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст заказа скопирован!'), backgroundColor: Colors.blue));
              },
            ),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.orange[600], child: const Icon(Icons.engineering, color: Colors.white)),
              title: Text('Назначить мастера (CRM чат)', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              subtitle: Text('Передать заказ сотруднику внутри системы', style: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey)),
              onTap: () {
                Navigator.pop(ctx);
                _showAssignMasterDialog(orderText);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAssignMasterDialog(String orderText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Выберите мастера', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('employees').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Text('Нет сотрудников в базе', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey));
              
              final docs = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final emp = docs[i].data() as Map<String, dynamic>;
                  final empPhone = docs[i].id; 
                  final empName = emp['name'] ?? 'Мастер';
                  final empRole = emp['role'] ?? 'Сотрудник';
                  
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], child: Icon(Icons.person, color: isDark ? Colors.white : Colors.blueGrey)),
                    title: Text(empName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                    subtitle: Text(empRole, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _assignOrderToMaster(empPhone, empName, orderText);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey)))
        ]
      )
    );
  }

  Future<void> _assignOrderToMaster(String empPhone, String empName, String orderText) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'assigned_to': empPhone,
        'assigned_name': empName,
        'has_unread_update': true,
        'master_accepted': false, 
      });

      final prefs = await SharedPreferences.getInstance();
      final myPhone = prefs.getString('employee_phone') ?? 'admin';
      List<String> parts = [myPhone, empPhone];
      parts.sort();
      String roomId = 'team_${parts[0]}_${parts[1]}'; 

      final chatRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
      await chatRef.set({
        'type': 'team', 
        'participants': parts,
        'updated_at': FieldValue.serverTimestamp(),
        'last_message': 'Отправлен новый заказ',
        'last_sender': myPhone,
        'unread_count': FieldValue.increment(1), 
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'text': 'Поступил новый заказ на ремонт:\n\n$orderText',
        'sender_phone': myPhone, 
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false, 
        'is_order_invite': true, 
        'order_id': widget.orderId, 
        'is_order_accepted': false, 
      });

      final empDoc = await FirebaseFirestore.instance.collection('employees').doc(empPhone).get();
      if (empDoc.exists && empDoc.data()?['fcm_token'] != null) {
        await FCMService.sendPushNotification(
          empDoc.data()!['fcm_token'], 
          'Новый заказ!', 
          'Вам назначен новый заказ на ремонт. Проверьте чат и подтвердите!',
          'chat'
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Заказ успешно назначен мастеру $empName!'), backgroundColor: Colors.green));
        setState(() {
          widget.orderData['assigned_to'] = empPhone;
          widget.orderData['assigned_name'] = empName;
          widget.orderData['master_accepted'] = false;
        });
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ПРИНЯТИЕ ЗАКАЗА (СОХРАНЯЕМ ВРЕМЯ ПРИНЯТИЯ) ---
  Future<void> _acceptOrderFromDetails() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
         'master_accepted': true,
         'status': 'in_progress', 
         'has_unread_update': true,
         'accepted_at': FieldValue.serverTimestamp(), // ФИКСИРУЕМ ВРЕМЯ РЕАКЦИИ
      });

      if (_myPhone != null && _myPhone!.isNotEmpty) {
         final roomsQuery = await FirebaseFirestore.instance
             .collection('chat_rooms')
             .where('participants', arrayContains: _myPhone)
             .get();
             
         for (var room in roomsQuery.docs) {
            final msgs = await room.reference.collection('messages')
                .where('order_id', isEqualTo: widget.orderId)
                .get();
            for (var msg in msgs.docs) {
               await msg.reference.update({'is_order_accepted': true});
            }
         }
      }

      if (mounted) {
         setState(() {
           widget.orderData['master_accepted'] = true;
           widget.orderData['status'] = 'in_progress';
           widget.orderData['accepted_at'] = Timestamp.now(); // Для обновления UI
         });
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы успешно приняли заказ в работу!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForceStartDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priceController = TextEditingController(text: widget.orderData['price']?.toString() ?? '');
    final commentController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Принять в работу (Устно)', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Укажите согласованную цену и диагноз. Заказ сразу перейдет в статус "В работе".', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.blueGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Итоговая цена (TMT)',
                labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments, color: Colors.green),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Диагноз / Комментарий',
                labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.build),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
            onPressed: () async {
              final price = priceController.text.trim();
              final comment = commentController.text.trim();
              if (price.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите цену!'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx);
              await _forceStartOrder(price, comment);
            },
            child: const Text('Принять в работу'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceStartOrder(String price, String comment) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': 'in_progress',
        'price': price,
        'admin_comment': comment.isNotEmpty ? comment : 'Согласовано устно',
        'has_unread_update': true,
        'options': FieldValue.delete(),
        'selected_option_index': FieldValue.delete(),
        'accepted_at': FieldValue.serverTimestamp(), // ФИКСИРУЕМ ПРИНЯТИЕ УСТНО
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ переведен в работу!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCompletionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialPrice = widget.orderData['price']?.toString() ?? '';
    final priceController = TextEditingController(text: initialPrice);
    final paidController = TextEditingController(text: initialPrice); 
    int refillsCount = 0;
    String selectedPaymentMethod = 'Наличные'; 

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Выдача и расчет заказа', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. ФИНАНСЫ И ОПЛАТА', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.blueGrey)),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Способ оплаты',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.payment, color: Colors.blue),
                    ),
                    items: ['Наличные', 'Карта / Терминал', 'Перечисление']
                        .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selectedPaymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Итоговая цена (TMT)',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.payments, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Оплачено сейчас (TMT)',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                      helperText: 'Разница уйдет в ДОЛГ клиента',
                      helperStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text('2. ДОБАВИТЬ ЗАПРАВКИ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.blueGrey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Количество:', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: refillsCount > 0 ? () => setStateDialog(() => refillsCount--) : null,
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          ),
                          Text('$refillsCount шт.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          IconButton(
                            onPressed: () => setStateDialog(() => refillsCount++),
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
                onPressed: () async {
                  final priceStr = priceController.text.trim();
                  final paidStr = paidController.text.trim();
                  
                  if (priceStr.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите итоговую цену!'), backgroundColor: Colors.red));
                    return;
                  }

                  Navigator.pop(ctx);
                  await _processOrderCompletion(priceStr, paidStr, refillsCount, selectedPaymentMethod);
                },
                child: const Text('ВЫДАТЬ И ЗАКРЫТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _processOrderCompletion(String priceStr, String paidStr, int refills, String paymentMethod) async {
    setState(() => _isLoading = true);
    try {
      double price = double.tryParse(priceStr) ?? 0;
      double paid = paidStr.isEmpty ? price : (double.tryParse(paidStr) ?? price); 
      double debt = price - paid;
      if (debt < 0) debt = 0;

      final batch = FirebaseFirestore.instance.batch();
      
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      batch.update(orderRef, {
        'status': 'completed',
        'price': priceStr,
        'paid_amount': paid.toString(),
        'debt_amount': debt.toString(),
        'payment_method': paymentMethod, 
        'added_refills': refills,
        'completed_at': FieldValue.serverTimestamp(),
        'has_unread_update': true,
      });

      final phone = widget.orderData['phone'];
      if (phone != null && phone.isNotEmpty && refills > 0) {
        final clientRef = FirebaseFirestore.instance.collection('clients').doc(phone);
        batch.set(clientRef, {
          'cartridge_refills': FieldValue.increment(refills)
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ремонт успешно завершен и выдан!'), backgroundColor: Colors.green));
        Navigator.pop(context); 
        _showFollowUpDialog(); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFollowUpDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Напоминание', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: Text('Хотите, чтобы CRM напомнила вам связаться с клиентом и узнать, как работает устройство после ремонта?', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); 
            },
            child: const Text('Не надо', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => _createTask(1, ctx),
            child: const Text('Через 1 мес.', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () => _createTask(3, ctx),
            child: const Text('Через 3 мес.', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask(int months, BuildContext dialogCtx) async {
    Navigator.pop(dialogCtx); 
    try {
      final prefs = await SharedPreferences.getInstance();
      final myPhone = prefs.getString('employee_phone') ?? 'admin';
      final dueDate = DateTime.now().add(Duration(days: 30 * months));

      await FirebaseFirestore.instance.collection('tasks').add({
        'title': 'Follow-up: ${widget.orderData['client_name'] ?? 'Клиент'}',
        'description': 'Узнать как работает ${widget.orderData['device_type'] ?? 'устройство'} после ремонта.\nТелефон: ${widget.orderData['phone'] ?? ''}',
        'due_date': Timestamp.fromDate(dueDate),
        'is_completed': false,
        'created_at': FieldValue.serverTimestamp(),
        'assigned_to': myPhone,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Напоминание успешно создано!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка создания задачи: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showCancelOrderDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedReason = 'Клиент отказался';
    final customReasonController = TextEditingController();
    
    final predefinedReasons = [
      'Клиент отказался',
      'Нет нужных запчастей',
      'Не удалось связаться с клиентом',
      'Не устроила цена',
      'Отказ от предоплаты',
      'Другое (указать вручную)'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Отмена заказа', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[400])),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Укажите причину отмены заказа. Это действие нельзя отменить.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.blueGrey)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Причина отмены',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    border: const OutlineInputBorder(),
                  ),
                  items: predefinedReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedReason = val);
                  },
                ),
                if (selectedReason == 'Другое (указать вручную)') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customReasonController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Опишите причину',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Назад', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
                onPressed: () {
                  String finalReason = selectedReason;
                  if (selectedReason == 'Другое (указать вручную)') {
                    finalReason = customReasonController.text.trim();
                    if (finalReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Опишите причину отмены'), backgroundColor: Colors.red));
                      return;
                    }
                  }
                  Navigator.pop(ctx);
                  _processCancelOrder(finalReason);
                },
                child: const Text('ОТМЕНИТЬ ЗАКАЗ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _processCancelOrder(String reason) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': 'canceled',
        'cancel_reason': reason, 
        'canceled_at': FieldValue.serverTimestamp(),
        'has_unread_update': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ успешно отменен'), backgroundColor: Colors.orange));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отмены: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus, {bool isAwaitingApproval = false, bool isBargainingMode = false}) async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'has_unread_update': true,
      };

      if (isAwaitingApproval) {
        bool isValid = true;
        List<Map<String, dynamic>> optionsData = [];

        for (var opt in _options) {
          String desc = opt['description']!.text.trim();
          String price = opt['price']!.text.trim();
          if (desc.isEmpty || price.isEmpty) {
            isValid = false;
            break;
          }
          optionsData.add({'description': desc, 'price': price});
        }

        if (!isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заполните все описания и цены в добавленных вариантах'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
          return;
        }

        if (isBargainingMode) {
          List<dynamic> oldOptions = widget.orderData['options'] ?? [];
          List<dynamic> currentHistory = widget.orderData['history'] ?? [];
          if (oldOptions.isNotEmpty) {
            currentHistory.add({'options': oldOptions});
            updateData['history'] = currentHistory;
          }
        }

        updateData['options'] = optionsData;
        updateData['selected_option_index'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update(updateData);

      if (isAwaitingApproval) {
        String? phone = widget.orderData['phone'];
        if (phone != null) {
          var clientDoc = await FirebaseFirestore.instance.collection('clients').doc(phone).get();
          if (clientDoc.exists && clientDoc.data() != null) {
            String? fcmToken = clientDoc.data()!['fcm_token'];
            if (fcmToken != null) {
              await FCMService.sendPushNotification(
                fcmToken,
                isBargainingMode ? 'Новое предложение от мастера!' : 'Заказ ожидает согласования',
                isBargainingMode ? 'Мастер предложил новые условия ремонта. Ознакомьтесь!' : 'Мастер предложил варианты ремонта. Выберите подходящий.',
                'negotiation'
              );
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBargainingMode ? 'Новые условия отправлены!' : 'Отправлено на согласование'), backgroundColor: Colors.green));
      } else if (newStatus == 'canceled') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ отозван')));
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMediaAttachments(bool isDark) {
    final imageBase64 = widget.orderData['image_base64'];
    if (imageBase64 == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Прикрепленные файлы:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(10),
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(base64Decode(imageBase64), fit: BoxFit.contain),
                  ),
                ),
              ),
            );
          },
          child: Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
              image: DecorationImage(
                image: MemoryImage(base64Decode(imageBase64)),
                fit: BoxFit.cover,
              ),
            ),
            child: const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.zoom_out_map, color: Colors.white, shadows: [Shadow(blurRadius: 5, color: Colors.black)]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryBlock(Map<String, dynamic> data, bool isDark) {
    final history = data['history'] as List<dynamic>?;
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('История прошлых предложений:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.blueGrey)),
        const SizedBox(height: 8),
        ...history.asMap().entries.map((entry) {
          int round = entry.key + 1;
          List<dynamic> oldOptions = entry.value['options'] ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Раунд $round (Отклонено)', style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                ...oldOptions.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${opt['description']} — ${opt['price']} TMT',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 13),
                  ),
                )).toList(),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAuditTrail(Map<String, dynamic> data, bool isDark) {
    final options = data.containsKey('options') ? data['options'] as List<dynamic> : null;
    final selectedIndex = data.containsKey('selected_option_index') ? data['selected_option_index'] as int? : null;

    if (options != null && selectedIndex != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('История согласования вариантов:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            int idx = entry.key;
            var opt = entry.value;
            bool isSelected = idx == selectedIndex;

            return Card(
              color: isSelected 
                  ? (isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green.shade50) 
                  : Theme.of(context).cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: isSelected ? Colors.green : (isDark ? Colors.grey[800]! : Colors.grey.shade300), width: isSelected ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.cancel_outlined,
                  color: isSelected ? Colors.green[600] : Colors.grey[400],
                  size: 28,
                ),
                title: Text(
                  opt['description'] ?? '',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.grey[500],
                    decoration: isSelected ? TextDecoration.none : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '${opt['price']} TMT',
                  style: TextStyle(
                    color: isSelected ? Colors.green[500] : Colors.grey[500],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                trailing: isSelected ? const Text('ВЫБРАНО ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)) : null,
              ),
            );
          }),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('Диагноз/Комментарий: ${data['admin_comment'] ?? 'Нет'}', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('Стоимость: ${data['price'] ?? 'Не указана'} TMT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          if (data.containsKey('debt_amount') && double.tryParse(data['debt_amount'].toString()) != null && double.parse(data['debt_amount'].toString()) > 0) ...[
            const SizedBox(height: 4),
            Text('Имеется долг: ${data['debt_amount']} TMT', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ],
      );
    }
  }

  IconData _getPaymentIcon(String method) {
    if (method.contains('карта')) return Icons.credit_card;
    if (method.contains('Перечисление')) return Icons.account_balance;
    if (method.contains('бонус')) return Icons.stars_rounded;
    return Icons.payments; 
  }

  // --- ФОРМАТИРОВАНИЕ ДАТ ДЛЯ ТАЙМИНГА ---
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '—';
    if (timestamp is Timestamp) {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
    }
    return '—';
  }

  Widget _buildTimeRow(String label, String time, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(child: Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTimingBlock(bool isDark) {
    final createdAt = widget.orderData['created_at'];
    final acceptedAt = widget.orderData['accepted_at'];
    final completedAt = widget.orderData['completed_at'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Тайминг заказа (SLA):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          _buildTimeRow('Оформлен:', _formatTimestamp(createdAt), Icons.add_circle_outline, Colors.blue),
          if (acceptedAt != null)
            _buildTimeRow('Принят мастером:', _formatTimestamp(acceptedAt), Icons.handyman, Colors.orange),
          if (completedAt != null)
            _buildTimeRow('Завершен:', _formatTimestamp(completedAt), Icons.check_circle_outline, Colors.green),
        ],
      ),
    );
  }

  Widget _buildLockScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock, size: 100, color: Colors.orange[600]),
            const SizedBox(height: 24),
            Text(
              'Ожидание подтверждения!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 16),
            Text(
              'Вы назначены мастером на этот заказ. Пожалуйста, примите его в работу, чтобы получить доступ к контактам клиента и деталям поломки.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.blueGrey),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.check_circle, size: 28),
                label: const Text('ПРИНЯТЬ ЗАЯВКУ В РАБОТУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _acceptOrderFromDetails,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Назад к списку', style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.orderData['status'] ?? 'unknown';
    String paymentMethod = widget.orderData['payment_method'] ?? 'Наличные';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool isAssignedMaster = widget.orderData['assigned_to'] == _myPhone;
    bool isAwaitingAcceptance = widget.orderData['assigned_to'] != null && widget.orderData['master_accepted'] == false;
    bool isLockedForMe = isAwaitingAcceptance && isAssignedMaster;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Детали заказа', style: TextStyle(fontSize: 18)),
        actions: isLockedForMe ? [] : [
          if (status != 'completed' && status != 'canceled')
            IconButton(
              tooltip: 'Отменить заказ',
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _showCancelOrderDialog,
            ),
          if (status != 'completed' && status != 'canceled')
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _showCompletionDialog,
              icon: const Icon(Icons.task_alt, color: Colors.greenAccent),
              label: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _myPhone == null || _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isLockedForMe
              ? _buildLockScreen(isDark)
              : SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                    bottom: MediaQuery.of(context).padding.bottom + 40.0, 
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: widget.fromProfile ? null : _openClientProfile,
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          elevation: widget.fromProfile ? 0 : 2, 
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), 
                            side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person, color: isDark ? Colors.grey[400] : Colors.blueGrey[400]),
                                        const SizedBox(width: 8),
                                        Text('${widget.orderData['client_name'] ?? 'Без имени'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                                      ],
                                    ),
                                    if (!widget.fromProfile)
                                      const Icon(Icons.chevron_right, color: Colors.grey), 
                                  ],
                                ),
                                Divider(height: 24, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('${widget.orderData['phone'] ?? 'Не указан'}', style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.devices, size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('${widget.orderData['device_type'] ?? 'Не указана'}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(_getPaymentIcon(paymentMethod), size: 18, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text('Оплата: $paymentMethod', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[800])),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.orange[900]?.withOpacity(0.2) : Colors.orange[50], 
                                    borderRadius: BorderRadius.circular(8), 
                                    border: Border.all(color: isDark ? Colors.orange[800]! : Colors.orange[200]!)
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text('${widget.orderData['problem'] ?? 'Не указана'}', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
                                        ],
                                      ),
                                      _buildMediaAttachments(isDark),
                                    ],
                                  ),
                                ),
                                if (widget.orderData['assigned_name'] != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: isDark ? Colors.blueGrey[800] : Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.engineering, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
                                            const SizedBox(width: 8),
                                            Text('Назначен мастер: ${widget.orderData['assigned_name']}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                          ]
                                        ),
                                        const SizedBox(height: 8),
                                        if (widget.orderData['master_accepted'] == false)
                                          Row(children: [const Icon(Icons.access_time, color: Colors.orange, size: 16), const SizedBox(width: 4), const Text('ОЖИДАЕТ ПОДТВЕРЖДЕНИЯ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))])
                                        else
                                          Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 16), const SizedBox(width: 4), const Text('ЗАЯВКА ПРИНЯТА В РАБОТУ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))])
                                      ],
                                    )
                                  )
                                ],
                                
                                // --- НОВЫЙ БЛОК: ТАЙМИНГ ЗАКАЗА ---
                                const SizedBox(height: 12),
                                _buildTimingBlock(isDark),

                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? Colors.blueGrey[600]! : Colors.blueGrey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showDelegationSheet,
                        icon: Icon(Icons.share, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700]),
                        label: Text('ПОДЕЛИТЬСЯ / НАЗНАЧИТЬ МАСТЕРА', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800])),
                      ),
                      const SizedBox(height: 24),

                      _buildHistoryBlock(widget.orderData, isDark), 

                      if (status == 'new') ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _showForceStartDialog,
                          icon: const Icon(Icons.handyman),
                          label: const Text('ПРИНЯТЬ В РАБОТУ (УСТНО)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("ИЛИ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text('Оценка ремонта (Варианты для приложения):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _options.length,
                          itemBuilder: (context, index) {
                            return Card(
                              elevation: 1,
                              color: Theme.of(context).cardColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Вариант ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blueGrey[800])),
                                        if (_options.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _removeOption(index),
                                            tooltip: 'Удалить вариант',
                                          ),
                                      ],
                                    ),
                                    TextField(
                                      controller: _options[index]['description'],
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                      decoration: InputDecoration(
                                        labelText: 'Диагноз / Что делаем',
                                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                                        filled: true,
                                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _options[index]['price'],
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                      decoration: InputDecoration(
                                        labelText: 'Цена (TMT)',
                                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                                        prefixIcon: const Icon(Icons.payments_outlined, color: Colors.green),
                                        filled: true,
                                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.blueGrey[400]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _addOption,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('ДОБАВИТЬ ЕЩЕ ВАРИАНТ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _updateStatus('awaiting_approval', isAwaitingApproval: true),
                          icon: const Icon(Icons.send),
                          label: const Text('ОТПРАВИТЬ КЛИЕНТУ НА ВЫБОР', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],

                  if (status == 'awaiting_approval') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[300]!)),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_bottom, color: Colors.deepOrange, size: 28),
                          SizedBox(width: 12),
                          Expanded(child: Text('Ожидаем решения клиента по предложенным вариантам', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showForceStartDialog,
                      icon: const Icon(Icons.handyman),
                      label: const Text('ПРИНЯТЬ В РАБОТУ (УСТНО)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),

                    if (widget.orderData.containsKey('options')) ...[
                      Text('Предложенные варианты:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.blueGrey)),
                      const SizedBox(height: 12),
                      ...(widget.orderData['options'] as List<dynamic>).map((opt) {
                        return Card(
                          elevation: 0,
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(opt['description'] ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text('${opt['price']} TMT', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            leading: const Icon(Icons.help_outline, color: Colors.orange),
                          ),
                        );
                      }),
                    ] else ...[
                      Text('Диагноз/Комментарий: ${widget.orderData['admin_comment'] ?? 'Нет'}', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Text('Стоимость: ${widget.orderData['price'] ?? 'Не указана'} TMT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ],

                  if (status == 'in_progress') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isDark ? Colors.blue[900]?.withOpacity(0.3) : Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)),
                      child: Row(
                        children: [
                          Icon(Icons.handyman, color: isDark ? Colors.blue[300] : Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Заказ в процессе ремонта.', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAuditTrail(widget.orderData, isDark),
                    const SizedBox(height: 32),
                  ],

                  if (status == 'completed') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[300]!)),
                      child: Row(
                        children: [
                          Icon(Icons.celebration, color: isDark ? Colors.green[300] : Colors.green, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Ремонт успешно завершен и выдан клиенту!', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green, fontSize: 16))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAuditTrail(widget.orderData, isDark),
                  ],

                  if (status == 'canceled') ...[
                    if (!_isBargainingMode) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.red[900]?.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[300]!)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Заказ отменен', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.red[300] : Colors.red, fontSize: 16)),
                                  if (widget.orderData['cancel_reason'] != null)
                                    Text('Причина: ${widget.orderData['cancel_reason']}', style: TextStyle(color: isDark ? Colors.red[200] : Colors.red[800], fontSize: 14)),
                                ],
                              )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.orderData.containsKey('options')) ...[
                        Text('Были предложены варианты:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.blueGrey)),
                        const SizedBox(height: 8),
                        ...(widget.orderData['options'] as List<dynamic>).map((opt) {
                          return Card(
                            elevation: 0,
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(opt['description'] ?? '', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                              subtitle: Text('${opt['price']} TMT', style: const TextStyle(color: Colors.grey)),
                              leading: const Icon(Icons.close, color: Colors.grey),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 32),
                      
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            _isBargainingMode = true;
                            _options.clear();
                            _options.add({'description': TextEditingController(), 'price': TextEditingController()});
                          });
                        },
                        icon: const Icon(Icons.local_offer),
                        label: const Text('ПРЕДЛОЖИТЬ НОВЫЕ УСЛОВИЯ (ТОРГ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ] else ...[
                      Text('Новые варианты ремонта (Скидка / БУ деталь):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _options.length,
                        itemBuilder: (context, index) {
                          return Card(
                            elevation: 1,
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue[300]!)),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Спец-предложение ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[300])),
                                      if (_options.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _removeOption(index),
                                        ),
                                    ],
                                  ),
                                  TextField(
                                    controller: _options[index]['description'],
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: 'Новые условия (напр., скидка 15%)',
                                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[800] : Colors.blue[50],
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _options[index]['price'],
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: 'Новая цена (TMT)',
                                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                                      prefixIcon: const Icon(Icons.payments_outlined, color: Colors.green),
                                      filled: true,
                                      fillColor: isDark ? Colors.grey[800] : Colors.blue[50],
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.blue[400]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _addOption,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        label: const Text('ДОБАВИТЬ ЕЩЕ ВАРИАНТ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _updateStatus('awaiting_approval', isAwaitingApproval: true, isBargainingMode: true),
                        icon: const Icon(Icons.send),
                        label: const Text('ОТПРАВИТЬ НОВОЕ ПРЕДЛОЖЕНИЕ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _isBargainingMode = false),
                        child: const Text('Отмена', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ]
                  ],
                ],
              ),
            ),
    );
  }
}

