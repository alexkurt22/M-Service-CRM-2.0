import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mservice_crm/services/fcm_service.dart';
import 'client_profile_screen.dart';
import 'private_chat_screen.dart'; // Для перехода в чат с клиентом

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
  
  late TextEditingController _internalNotesCtrl;
  bool _isLoading = false;
  String? _myPhone;

  @override
  void initState() {
    super.initState();
    _internalNotesCtrl = TextEditingController(text: widget.orderData['internal_notes'] ?? '');
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
    _internalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveInternalNotes() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'internal_notes': _internalNotesCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пометки сохранены'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openClientProfile() async {
    final String? phone = widget.orderData['phone'];
    if (phone == null || phone.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('clients').where('phone', isEqualTo: phone).get();
      if (querySnapshot.docs.isNotEmpty) {
        final clientDoc = querySnapshot.docs.first;
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ClientProfileScreen(clientId: clientDoc.id, clientData: clientDoc.data())));
      } else {
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ClientProfileScreen(clientId: 'unknown_client', clientData: {'name': widget.orderData['client_name'] ?? 'Без имени', 'phone': phone, 'is_offline': true})));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditOrderDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceCtrl = TextEditingController(text: widget.orderData['device_type'] ?? '');
    final problemCtrl = TextEditingController(text: widget.orderData['problem'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Редактировать заказ', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deviceCtrl,
              decoration: const InputDecoration(labelText: 'Устройство', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: problemCtrl,
              decoration: const InputDecoration(labelText: 'Проблема', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
                  'device_type': deviceCtrl.text.trim(),
                  'problem': problemCtrl.text.trim(),
                });
                setState(() {
                  widget.orderData['device_type'] = deviceCtrl.text.trim();
                  widget.orderData['problem'] = problemCtrl.text.trim();
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ обновлен!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Сохранить'),
          )
        ],
      ),
    );
  }

  void _showAssignMasterSheet() {
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
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            Text('Назначить мастера', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.share, color: Colors.white)),
              title: Text('Отправить во внешний мессенджер', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(ctx); Share.share(orderText); },
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue[600], child: const Icon(Icons.copy, color: Colors.white)),
              title: Text('Скопировать текст заказа', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: orderText));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован!'), backgroundColor: Colors.blue));
              },
            ),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.orange[600], child: const Icon(Icons.engineering, color: Colors.white)),
              title: Text('Выбрать мастера из базы', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(ctx); _showMasterListDialog(orderText); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMasterListDialog(String orderText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите мастера', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('employees').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, i) {
                  final emp = snapshot.data!.docs[i].data() as Map<String, dynamic>;
                  final empPhone = snapshot.data!.docs[i].id;
                  final empName = emp['name'] ?? 'Мастер';
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(empName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(emp['role'] ?? 'Сотрудник'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _assignMasterToOrder(empPhone, empName, orderText);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _assignMasterToOrder(String empPhone, String empName, String orderText) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'assigned_to': empPhone,
        'assigned_name': empName,
        'has_unread_update': true,
        'master_accepted': false, 
      });

      final myPhone = _myPhone ?? 'admin';
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
      }, SetOptions(merge: true));

      // Уведомление в чат БЕЗ кликабельности (как просил)
      await chatRef.collection('messages').add({
        'text': 'Поступил новый заказ на ремонт:\n\n$orderText',
        'sender_phone': myPhone, 
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false, 
        'is_order_invite': false, // Убрали кликабельность кнопки в чате
      });

      if (mounted) {
        setState(() {
          widget.orderData['assigned_to'] = empPhone;
          widget.orderData['assigned_name'] = empName;
          widget.orderData['master_accepted'] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Мастер $empName назначен!'), backgroundColor: Colors.green));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOrderFromDetails() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
         'master_accepted': true,
         'status': 'in_progress', 
         'has_unread_update': true,
         'accepted_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
         setState(() {
           widget.orderData['master_accepted'] = true;
           widget.orderData['status'] = 'in_progress';
           widget.orderData['accepted_at'] = Timestamp.now();
         });
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ принят в работу!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- УМНЫЕ ЧЕКБОКСЫ ЗАКРЫТИЯ ЗАКАЗА ---
  Future<void> _showCompletionDialog() async {
    bool isTimely = false;
    bool isDelayed = false;
    bool isCanceled = false;

    final jobDetailsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final paidCtrl = TextEditingController();
    final delayReasonCtrl = TextEditingController();
    final cancelReasonCtrl = TextEditingController();
    final cancelSumCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Завершение заказа', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text("Своевременное выполнение", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    value: isTimely,
                    activeColor: Colors.green,
                    onChanged: isCanceled ? null : (val) => setStateDialog(() => isTimely = val!),
                  ),
                  if (isTimely) Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Column(
                      children: [
                        TextField(controller: jobDetailsCtrl, decoration: const InputDecoration(labelText: 'Выполненные работы (детали)', border: OutlineInputBorder()), maxLines: 2),
                        const SizedBox(height: 8),
                        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Итоговая цена', prefixIcon: Icon(Icons.money), border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        TextField(controller: paidCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Оплачено по факту', prefixIcon: Icon(Icons.account_balance_wallet), border: OutlineInputBorder(), helperText: 'Разница уйдет в долг клиента')),
                      ],
                    ),
                  ),

                  CheckboxListTile(
                    title: const Text("Отложенное выполнение / Перенос", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    value: isDelayed,
                    activeColor: Colors.orange,
                    onChanged: isCanceled ? null : (val) => setStateDialog(() => isDelayed = val!),
                  ),
                  if (isDelayed) Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: TextField(controller: delayReasonCtrl, decoration: const InputDecoration(labelText: 'Причина переноса / Забрать в СЦ', helperText: 'Будет создана новая заявка', border: OutlineInputBorder()), maxLines: 2),
                  ),

                  const Divider(),

                  CheckboxListTile(
                    title: const Text("Отмена заказа", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    value: isCanceled,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setStateDialog(() {
                        isCanceled = val!;
                        if (isCanceled) {
                          isTimely = false;
                          isDelayed = false;
                        }
                      });
                    },
                  ),
                  if (isCanceled) Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Column(
                      children: [
                        TextField(controller: cancelReasonCtrl, decoration: const InputDecoration(labelText: 'Причина отмены', border: OutlineInputBorder()), maxLines: 2),
                        const SizedBox(height: 8),
                        TextField(controller: cancelSumCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Сумма за вызов (Необязательно)', border: OutlineInputBorder())),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Назад', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                onPressed: () async {
                  if (!isTimely && !isDelayed && !isCanceled) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите хотя бы один чекбокс'), backgroundColor: Colors.red));
                    return;
                  }
                  if (isCanceled && cancelReasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите причину отмены'), backgroundColor: Colors.red));
                    return;
                  }
                  if (isTimely && (jobDetailsCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите детали работы и цену'), backgroundColor: Colors.red));
                    return;
                  }
                  if (isDelayed && delayReasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите причину отложенного выполнения'), backgroundColor: Colors.red));
                    return;
                  }

                  Navigator.pop(ctx);
                  await _processAdvancedCompletion(
                    isTimely: isTimely,
                    isDelayed: isDelayed,
                    isCanceled: isCanceled,
                    jobDetails: jobDetailsCtrl.text.trim(),
                    priceStr: priceCtrl.text.trim(),
                    paidStr: paidCtrl.text.trim(),
                    delayReason: delayReasonCtrl.text.trim(),
                    cancelReason: cancelReasonCtrl.text.trim(),
                    cancelSum: cancelSumCtrl.text.trim(),
                  );
                },
                child: const Text('ПРИМЕНИТЬ'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _processAdvancedCompletion({
    required bool isTimely,
    required bool isDelayed,
    required bool isCanceled,
    String? jobDetails,
    String? priceStr,
    String? paidStr,
    String? delayReason,
    String? cancelReason,
    String? cancelSum,
  }) async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

      if (isCanceled) {
        batch.update(orderRef, {
          'status': 'canceled',
          'cancel_reason': cancelReason,
          'cancel_sum': cancelSum,
          'canceled_at': FieldValue.serverTimestamp(),
          'has_unread_update': true,
        });
      } else {
        Map<String, dynamic> updates = {
          'status': 'completed',
          'completed_at': FieldValue.serverTimestamp(),
          'has_unread_update': true,
        };

        if (isTimely) {
          double price = double.tryParse(priceStr ?? '') ?? 0;
          double paid = paidStr == null || paidStr.isEmpty ? price : (double.tryParse(paidStr) ?? price);
          double debt = price - paid;
          if (debt < 0) debt = 0; // Переплаты не уводим в минус по долгу
          
          updates['job_details'] = jobDetails;
          updates['price'] = priceStr;
          updates['paid_amount'] = paid.toString();
          updates['debt_amount'] = debt.toString();
        }

        if (isDelayed) {
          updates['delay_reason'] = delayReason;
          if (!isTimely) updates['is_just_delayed'] = true;

          // Генерируем новую заявку
          final newOrderRef = FirebaseFirestore.instance.collection('orders').doc();
          Map<String, dynamic> newOrderData = Map<String, dynamic>.from(widget.orderData);
          newOrderData.remove('status');
          newOrderData.remove('assigned_to');
          newOrderData.remove('assigned_name');
          newOrderData.remove('master_accepted');
          newOrderData.remove('accepted_at');
          newOrderData.remove('completed_at');
          
          newOrderData['status'] = 'new';
          newOrderData['created_at'] = FieldValue.serverTimestamp();
          newOrderData['problem'] = delayReason; 
          newOrderData['is_delayed_copy'] = true;
          newOrderData['parent_order_id'] = widget.orderId;

          batch.set(newOrderRef, newOrderData);
        }

        batch.update(orderRef, updates);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Действие успешно выполнено!'), backgroundColor: Colors.green));
        Navigator.pop(context); 
        if (!isCanceled) _askForFollowUp(); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- КАЛЕНДАРЬ НАПОМИНАНИЙ ---
  void _askForFollowUp() async {
    bool wantsReminder = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.notifications_active, color: Colors.orange), SizedBox(width: 8), Text('Напоминание')]),
        content: const Text('Создать напоминание для связи с клиентом по этому ремонту?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Не надо', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выбрать дату')),
        ],
      )
    ) ?? false;

    if (wantsReminder && mounted) {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 1000)),
      );
      if (picked != null) {
        await FirebaseFirestore.instance.collection('tasks').add({
          'title': 'Связь с клиентом: ${widget.orderData['client_name']}',
          'description': 'Узнать как работает ${widget.orderData['device_type']} после ремонта. Телефон: ${widget.orderData['phone']}',
          'due_date': Timestamp.fromDate(picked),
          'is_completed': false,
          'created_at': FieldValue.serverTimestamp(),
          'assigned_to': _myPhone ?? 'admin',
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Напоминание создано!'), backgroundColor: Colors.green));
      }
    }
  }

  // --- ВЫЕЗЖАЮЩЕЕ ОКНО ТОРГА ---
  void _showTorgBottomSheet() {
    setState(() {
      _options.clear();
      _options.add({'description': TextEditingController(), 'price': TextEditingController()});
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Предложить варианты ремонта', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...List.generate(_options.length, (index) {
                    return Card(
                      color: Colors.blueGrey.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Вариант ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (_options.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => setSheetState(() {
                                      _options[index]['description']?.dispose();
                                      _options[index]['price']?.dispose();
                                      _options.removeAt(index);
                                    }),
                                  )
                              ],
                            ),
                            TextField(controller: _options[index]['description'], decoration: const InputDecoration(labelText: 'Что делаем', border: OutlineInputBorder()), maxLines: 2),
                            const SizedBox(height: 8),
                            TextField(controller: _options[index]['price'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена (TMT)', border: OutlineInputBorder())),
                          ],
                        ),
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setSheetState(() => _options.add({'description': TextEditingController(), 'price': TextEditingController()})),
                    icon: const Icon(Icons.add), label: const Text('Добавить еще вариант'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    onPressed: () async {
                      List<Map<String, dynamic>> optionsData = [];
                      for (var opt in _options) {
                        String desc = opt['description']!.text.trim();
                        String price = opt['price']!.text.trim();
                        if (desc.isNotEmpty && price.isNotEmpty) {
                          optionsData.add({'description': desc, 'price': price});
                        }
                      }
                      if (optionsData.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните варианты'), backgroundColor: Colors.red));
                        return;
                      }
                      
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
                          'status': 'awaiting_approval',
                          'options': optionsData,
                          'selected_option_index': FieldValue.delete(),
                          'has_unread_update': true,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Варианты отправлены клиенту!'), backgroundColor: Colors.green));
                        Navigator.pop(context);
                      } catch(e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
                    child: const Text('ОТПРАВИТЬ КЛИЕНТУ'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }
      ),
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
          Text('Выбранный клиентом вариант:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
          const SizedBox(height: 12),
          Card(
            color: Colors.green.withOpacity(0.1),
            shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green, size: 28),
              title: Text(options[selectedIndex]['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${options[selectedIndex]['price']} TMT', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      );
    }
    return const SizedBox.shrink();
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
            Text('Ожидание подтверждения!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            Text('Примите заказ в работу, чтобы увидеть детали.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.blueGrey)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32), backgroundColor: Colors.green[600], foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle, size: 28),
              label: const Text('ПРИНЯТЬ В РАБОТУ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _acceptOrderFromDetails,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.orderData['status'] ?? 'new';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool isAssignedMaster = widget.orderData['assigned_to'] == _myPhone;
    bool isAwaitingAcceptance = widget.orderData['assigned_to'] != null && widget.orderData['master_accepted'] == false;
    bool isLockedForMe = isAwaitingAcceptance && isAssignedMaster;

    String formattedDate = '—';
    if (widget.orderData['created_at'] != null) {
       formattedDate = DateFormat('dd.MM.yyyy в HH:mm').format((widget.orderData['created_at'] as Timestamp).toDate());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Детали заказа', style: TextStyle(fontSize: 18)),
        actions: isLockedForMe ? [] : [
          // ЧЕКБОКСЫ ЗАКРЫТИЯ ТОЛЬКО В СТАТУСЕ В РАБОТЕ
          if (status == 'in_progress' && widget.orderData['assigned_to'] != null)
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
                  padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: MediaQuery.of(context).padding.bottom + 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // КАРТОЧКА КЛИЕНТА
                      Card(
                        elevation: 2, 
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Кликабельна только верхняя строка
                              InkWell(
                                onTap: widget.fromProfile ? null : _openClientProfile,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person, color: isDark ? Colors.grey[400] : Colors.blueGrey[400]),
                                        const SizedBox(width: 8),
                                        Text('${widget.orderData['client_name'] ?? 'Без имени'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                                      ],
                                    ),
                                    if (!widget.fromProfile) const Icon(Icons.chevron_right, color: Colors.grey), 
                                  ],
                                ),
                              ),
                              Divider(height: 24, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                              
                              // Номер телефона + Быстрые действия
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('${widget.orderData['phone'] ?? 'Не указан'}', style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)),
                                  const Spacer(),
                                  if (widget.orderData['phone'] != null) ...[
                                    IconButton(
                                      icon: const Icon(Icons.call, color: Colors.green),
                                      onPressed: () => launchUrl(Uri.parse('tel:${widget.orderData['phone']}')),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: Colors.blue),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(
                                          chatId: widget.orderData['phone'],
                                          clientName: widget.orderData['client_name'],
                                          clientPhone: widget.orderData['phone'],
                                        )));
                                      },
                                    ),
                                  ]
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Поступил: $formattedDate', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Детали поломки с кнопкой редактирования
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: isDark ? Colors.orange[900]?.withOpacity(0.2) : Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text('Устройство: ${widget.orderData['device_type'] ?? 'Не указано'}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                        ),
                                        IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey), onPressed: _showEditOrderDialog, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('${widget.orderData['problem'] ?? 'Не указана'}', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              if (widget.orderData['assigned_name'] != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: isDark ? Colors.blueGrey[800] : Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.engineering, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
                                      const SizedBox(width: 8),
                                      Text('Мастер: ${widget.orderData['assigned_name']}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                    ]
                                  ),
                                )
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Кнопка назначения мастера
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? Colors.blueGrey[600]! : Colors.blueGrey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAssignMasterSheet,
                        icon: Icon(Icons.person_add_alt_1, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700]),
                        label: Text('НАЗНАЧИТЬ МАСТЕРА', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800])),
                      ),
                      const SizedBox(height: 24),

                      // Блоки статусов
                      if (status == 'new') ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _showTorgBottomSheet,
                          icon: const Icon(Icons.local_offer),
                          label: const Text('ПРЕДЛОЖИТЬ ВАРИАНТЫ (ТОРГ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      if (status == 'awaiting_approval') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_bottom, color: Colors.deepOrange, size: 28),
                              SizedBox(width: 12),
                              Expanded(child: Text('Ожидаем решения клиента по предложенным вариантам', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16))),
                            ],
                          ),
                        ),
                      ],

                      if (status == 'in_progress') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            children: [
                              Icon(Icons.handyman, color: Colors.blue, size: 28),
                              SizedBox(width: 12),
                              Expanded(child: Text('Заказ в процессе ремонта.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16))),
                            ],
                          ),
                        ),
                        _buildAuditTrail(widget.orderData, isDark),
                      ],

                      if (status == 'completed') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            children: [
                              Icon(Icons.celebration, color: Colors.green, size: 28),
                              SizedBox(width: 12),
                              Expanded(child: Text('Ремонт завершен!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))),
                            ],
                          ),
                        ),
                        _buildAuditTrail(widget.orderData, isDark),
                      ],

                      if (status == 'canceled') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Заказ отменен', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                                    if (widget.orderData['cancel_reason'] != null) Text('Причина: ${widget.orderData['cancel_reason']}', style: TextStyle(color: Colors.red[800], fontSize: 14)),
                                  ],
                                )
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ВНУТРЕННИЕ ПОМЕТКИ
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('Внутренние пометки (не видны клиенту):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _internalNotesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Напишите важную информацию для других мастеров...',
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.amber[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _saveInternalNotes,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Сохранить пометку'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                        ),
                      )
                    ],
                  ),
                ),
    );
  }
}
