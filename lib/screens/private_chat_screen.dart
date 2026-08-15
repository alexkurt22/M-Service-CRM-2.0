import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/push_service.dart';
import 'order_details_screen.dart'; 

class PrivateChatScreen extends StatefulWidget {
  final String roomId;
  final String targetName;

  const PrivateChatScreen({super.key, required this.roomId, required this.targetName});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _myPhone;
  String _myName = "Сотрудник";

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMyData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? 'admin';
    if (mounted) setState(() => _myPhone = phone);

    final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
    if (doc.exists && mounted) {
      setState(() => _myName = doc.data()?['name'] ?? "Сотрудник");
    }
  }

  Future<void> _sendTextMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();
    await _sendMessageToDb(text: text);
  }

  Future<void> _pickAndSendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 800, maxHeight: 800);
      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        await _sendMessageToDb(text: '📷 Фотография', imageBase64: base64Image);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _sendMessageToDb({required String text, String? imageBase64}) async {
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').add({
      'text': text,
      'sender_phone': _myPhone,
      'sender_name': _myName,
      'created_at': FieldValue.serverTimestamp(),
      'is_read': false,
      'is_edited': false,
      if (imageBase64 != null) 'image_base64': imageBase64,
    });
    
    await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({
      'last_message': text,
      'last_message_time': FieldValue.serverTimestamp(),
      'unread_count': FieldValue.increment(1), 
      'last_sender': _myPhone,
    });

    try {
      final roomDoc = await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).get();
      final roomData = roomDoc.data();
      if (roomData == null) return;

      final parts = List<String>.from(roomData['participants'] ?? []);
      final isGroup = roomData['is_group'] == true;
      final groupName = roomData['group_name'] ?? widget.targetName;

      for (String targetPhone in parts) {
        if (targetPhone == _myPhone) continue;
        if (widget.roomId.contains('team_') || isGroup) {
          final empDoc = await FirebaseFirestore.instance.collection('employees').doc(targetPhone).get();
          if (empDoc.exists && empDoc.data()?['fcm_token'] != null) {
            String pushTitle = isGroup ? 'Группа "$groupName"' : 'Сообщение от $_myName';
            await PushService.sendPushToToken(empDoc.data()!['fcm_token'], pushTitle, text);
          }
        } else {
          final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(targetPhone).get();
          if (clientDoc.exists && clientDoc.data()?['fcm_token'] != null) {
            await PushService.sendPushToToken(clientDoc.data()!['fcm_token'], 'Ответ от мастера', text);
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка Push: $e');
    }
  }

  void _editMessage(String messageId, String currentText) {
    final editController = TextEditingController(text: currentText);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать сообщение'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty || newText == currentText) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').doc(messageId).update({
                  'text': newText, 'is_edited': true, 'edit_history': FieldValue.arrayUnion([{'old_text': currentText, 'edited_at': DateTime.now()}])
                });
              } catch (e) { debugPrint('Ошибка редактирования: $e'); }
            }, 
            child: const Text('Сохранить')
          )
        ],
      ),
    );
  }

  void _showEditHistory(List<dynamic> history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('История изменений', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true, itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final date = (item['edited_at'] as Timestamp?)?.toDate() ?? DateTime.now();
              return ListTile(contentPadding: EdgeInsets.zero, title: Text(item['old_text'] ?? '', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)), subtitle: Text(DateFormat('dd.MM.yy HH:mm').format(date), style: const TextStyle(fontSize: 10)));
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
      )
    );
  }

  Future<void> _openOrderDetails(String orderId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (mounted) {
        Navigator.pop(context); 
        if (doc.exists) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: orderId, orderData: doc.data() as Map<String, dynamic>)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ удален или не найден')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _acceptOrder(String messageId, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы принимаете заявку в работу?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => Navigator.pop(ctx, true), child: const Text('Да, принимаю', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ]
      )
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
           'master_accepted': true,
           'status': 'in_progress', 
           'has_unread_update': true,
           'accepted_at': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').doc(messageId).update({
           'is_order_accepted': true,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ принят в работу!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _getFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate == today) return 'СЕГОДНЯ';
    if (targetDate == yesterday) return 'ВЧЕРА';
    return DateFormat('dd MMMM yyyy').format(date).toUpperCase();
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, String messageId, bool isMe, DateTime dt, bool isSending, bool isDark) {
    final bool showName = !isMe && widget.roomId.contains('team_');
    final bool isEdited = data['is_edited'] == true;
    final List<dynamic> editHistory = data['edit_history'] ?? [];
    
    final bool isOrderInvite = data['is_order_invite'] == true;
    final String? orderId = data['order_id'];
    final bool isOrderAccepted = data['is_order_accepted'] == true;

    return GestureDetector(
      onLongPress: isMe && !isSending && data['image_base64'] == null && !isOrderInvite ? () => _editMessage(messageId, data['text'] ?? '') : null,
      onTap: () {
        if (isEdited) _showEditHistory(editHistory);
        
        // ЛОГИКА БЛОКИРОВКИ ВХОДА В ЗАКАЗ
        if (isOrderInvite && orderId != null) {
          if (!isOrderAccepted && !isMe) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Сначала примите заявку в работу, нажав зеленую кнопку ниже!', style: TextStyle(fontWeight: FontWeight.bold)), 
                backgroundColor: Colors.red
              )
            );
            return; 
          }
          _openOrderDetails(orderId);
        }
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isMe ? 50 : 10, right: isMe ? 10 : 50, top: 4, bottom: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
          decoration: BoxDecoration(
            color: isMe ? (isDark ? Colors.blue[900] : Colors.blue[100]) : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showName) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(data['sender_name'] ?? 'Коллега', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[700]))),
              
              if (isOrderInvite) ...[
                 Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        const Row(children: [Icon(Icons.assignment, color: Colors.orange), SizedBox(width: 8), Text('НАЗНАЧЕН ЗАКАЗ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))]),
                        const SizedBox(height: 8),
                        Text(data['text'] ?? '', style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 12),
                        
                        if (!isOrderAccepted && !isMe) ...[
                           SizedBox(
                             width: double.infinity,
                             child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () => _acceptOrder(messageId, orderId!),
                                child: const Text('ПРИНЯТЬ ЗАЯВКУ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                             )
                           )
                        ] else if (isOrderAccepted) ...[
                           const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Заявка принята', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))])
                        ] else if (!isOrderAccepted && isMe) ...[
                           const Row(children: [Icon(Icons.access_time, color: Colors.orange), SizedBox(width: 8), Text('Ожидает подтверждения мастера', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))])
                        ]
                     ]
                   )
                 )
              ] else ...[
                if (data['image_base64'] != null)
                  GestureDetector(
                    onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data['image_base64']), fit: BoxFit.contain))))),
                    child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(data['image_base64']), height: 150, width: double.infinity, fit: BoxFit.cover))),
                  ),
                if (data['image_base64'] == null)
                  Text(data['text'] ?? '', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              ],
              
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ИСПРАВЛЕНА ОШИБКА EdgeInsets.right -> EdgeInsets.only(right: 4)
                  if (isEdited) Padding(padding: const EdgeInsets.only(right: 4.0), child: Text('(изм.)', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.grey[600]))),
                  Text(isSending ? 'Отправка...' : DateFormat('HH:mm').format(dt), style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey[600])),
                  if (isMe) ...[const SizedBox(width: 4), Icon(isSending ? Icons.access_time : (data['is_read'] == true ? Icons.done_all : Icons.check), size: 14, color: isSending ? Colors.grey : (data['is_read'] == true ? (isDark ? Colors.lightBlueAccent : Colors.blue) : Colors.grey))]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.blueGrey[900], foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Поиск по сообщениям...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none), onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()))
            : Text(widget.targetName),
        actions: [IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search), onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchController.clear(); _searchQuery = ''; } }))],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).collection('messages').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var messages = snapshot.data!.docs.toList();
                if (_searchQuery.isNotEmpty) messages = messages.where((doc) => ((doc.data() as Map<String, dynamic>)['text'] ?? '').toString().toLowerCase().contains(_searchQuery)).toList();
                if (messages.isEmpty) return Center(child: Text(_searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет сообщений', style: const TextStyle(color: Colors.grey)));
                
                return ListView.builder(
                  reverse: true, padding: const EdgeInsets.only(top: 10, bottom: 20), itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final data = messages[i].data() as Map<String, dynamic>;
                    final bool isMe = data['sender_phone'] == _myPhone;
                    final Timestamp? ts = data['created_at'] as Timestamp?;
                    final DateTime dt = ts?.toDate() ?? DateTime.now();
                    final bool isSending = ts == null; 
                    
                    if (!isMe && data['is_read'] == false && !isSending) {
                      WidgetsBinding.instance.addPostFrameCallback((_) { messages[i].reference.update({'is_read': true}); FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).update({'unread_count': 0}); });
                    }

                    bool showDate = false;
                    if (i == messages.length - 1) showDate = true; 
                    else if (!isSending) {
                      final prevTs = (messages[i+1].data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                      if (prevTs != null && prevTs.toDate().day != dt.day) showDate = true;
                    }

                    return Column(
                      children: [
                        if (showDate && !_isSearching) 
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], thickness: 1)),
                                Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.blueGrey[50], borderRadius: BorderRadius.circular(12)), child: Text(_getFriendlyDate(dt), style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey[700], fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300], thickness: 1)),
                              ],
                            ),
                          ),
                        _buildMessageBubble(data, messages[i].id, isMe, dt, isSending, isDark),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, -2))]),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.attach_file, color: isDark ? Colors.grey[400] : Colors.grey[600]), onPressed: _pickAndSendImage),
                  Expanded(
                    child: TextField(
                      controller: _controller, style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(hintText: 'Сообщение...', hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: isDark ? Colors.grey[800] : Colors.grey[200], contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                      maxLines: 3, minLines: 1, textCapitalization: TextCapitalization.sentences, onChanged: (text) => setState(() {}),
                    )
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: _controller.text.trim().isNotEmpty ? Colors.blue[600] : Colors.grey[400], shape: BoxShape.circle), 
                    child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _controller.text.trim().isNotEmpty ? _sendTextMessage : null)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

