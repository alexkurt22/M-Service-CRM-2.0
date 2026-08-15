import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'private_chat_screen.dart'; 

// ============================================================================
// 1. ЭКРАН СПИСКА ЧАТОВ С КЛИЕНТАМИ
// ============================================================================
class ClientChatsListScreen extends StatefulWidget {
  const ClientChatsListScreen({super.key});

  @override
  State<ClientChatsListScreen> createState() => _ClientChatsListScreenState();
}

class _ClientChatsListScreenState extends State<ClientChatsListScreen> {
  String _myPhone = 'admin';
  String _myRole = 'Сотрудник';

  @override
  void initState() {
    super.initState();
    _loadMyData();
  }

  Future<void> _loadMyData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? 'admin';
    setState(() => _myPhone = phone);

    final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
    if (doc.exists && mounted) {
      setState(() => _myRole = doc.data()?['role'] ?? 'Сотрудник');
    }
  }

  // --- ФУНКЦИЯ УДАЛЕНИЯ ЧАТА ---
  Future<void> _deleteChat(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: const Text('Это удалит всю переписку без возможности восстановления.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // Удаляем сам документ комнаты (сообщения внутри останутся сиротами, но чат исчезнет из списка)
      await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Чат удален')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _myRole == 'Владелец' || _myRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Чаты с клиентами'), backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

          final rooms = snapshot.data!.docs.where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'private').toList();
          if (rooms.isEmpty) return _buildEmptyState();

          rooms.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['last_message_time'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['last_message_time'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: MediaQuery.of(context).padding.bottom + 20),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final data = rooms[i].data() as Map<String, dynamic>;
              final participants = data['participants'] as List<dynamic>? ?? [];
              String clientPhone = 'Клиент';
              if (participants.isNotEmpty) clientPhone = participants.firstWhere((p) => p != _myPhone, orElse: () => participants.last).toString();

              int unreadCount = data['unread_count'] as int? ?? 0;
              bool isClientSender = data['last_sender'] != _myPhone;

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('clients').where('phone', isEqualTo: clientPhone).limit(1).get(),
                builder: (context, clientSnapshot) {
                  String displayName = clientPhone; 
                  if (clientSnapshot.hasData && clientSnapshot.data!.docs.isNotEmpty) {
                    final clientData = clientSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                    if (clientData['name'] != null && clientData['name'].toString().trim().isNotEmpty) displayName = clientData['name'];
                  }

                  return Card(
                    elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Badge(isLabelVisible: isClientSender && unreadCount > 0, label: Text(unreadCount.toString()), child: CircleAvatar(backgroundColor: Colors.blue[50], child: Icon(Icons.person, color: Colors.blue[700]))),
                      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                      subtitle: Text(data['last_message'] ?? 'Нет сообщений', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteChat(rooms[i].id)),
                          const Icon(Icons.chevron_right, color: Colors.blueGrey),
                        ],
                      ),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: rooms[i].id, targetName: displayName))),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.blueGrey[200]),
            const SizedBox(height: 16),
            Text('Нет активных чатов', style: TextStyle(color: Colors.blueGrey[600], fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. ЭКРАН СПИСКА ЧАТОВ СОТРУДНИКОВ
// ============================================================================
class TeamChatsListScreen extends StatefulWidget {
  const TeamChatsListScreen({super.key});

  @override
  State<TeamChatsListScreen> createState() => _TeamChatsListScreenState();
}

class _TeamChatsListScreenState extends State<TeamChatsListScreen> {
  String _myPhone = 'admin';
  String _myRole = 'Сотрудник';

  @override
  void initState() {
    super.initState();
    _loadMyData();
  }

  Future<void> _loadMyData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? 'admin';
    if (mounted) setState(() => _myPhone = phone);
    
    final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
    if (doc.exists && mounted) {
      setState(() => _myRole = doc.data()?['role'] ?? 'Сотрудник');
    }
  }

  Future<void> _startChatWithEmployee(BuildContext context, String empPhone, String empName) async {
    List<String> participants = [_myPhone, empPhone];
    participants.sort();
    String roomId = 'team_${participants[0]}_${participants[1]}';

    final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(roomId);
    final doc = await roomRef.get();
    
    if (!doc.exists) {
      await roomRef.set({'type': 'team', 'is_group': false, 'participants': participants, 'created_at': FieldValue.serverTimestamp(), 'last_message': 'Чат создан', 'last_message_time': FieldValue.serverTimestamp()});
    }

    if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: roomId, targetName: empName)));
  }

  String _getRoomId(String phone1, String phone2) {
    List<String> p = [phone1, phone2];
    p.sort();
    return 'team_${p[0]}_${p[1]}';
  }

  Future<void> _deleteChat(String roomId) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Удалить чат?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red)))]));
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).delete();
    }
  }

  // ... (КОД СОЗДАНИЯ ГРУППЫ ОСТАЛСЯ ПРЕЖНИМ, НЕ МЕНЯЛСЯ)
  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    List<String> selectedPhones = [];
    bool isSaving = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(margin: const EdgeInsets.symmetric(horizontal: 140), height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Создание новой группы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextField(controller: nameController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Название группы', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder())),
                  const SizedBox(height: 16),
                  Text('Выберите участников:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('employees').get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('Нет сотрудников для добавления');

                        final emps = snapshot.data!.docs.where((d) => (d.data() as Map)['phone'] != _myPhone).toList();
                        return ListView.builder(
                          itemCount: emps.length,
                          itemBuilder: (context, i) {
                            final empData = emps[i].data() as Map<String, dynamic>;
                            final phone = empData['phone'];
                            final name = empData['name'] ?? 'Сотрудник';
                            return CheckboxListTile(
                              activeColor: Colors.orange[600], checkColor: Colors.white, title: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)), subtitle: Text(phone, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])), value: selectedPhones.contains(phone),
                              onChanged: (val) { setModalState(() { if (val == true) selectedPhones.add(phone); else selectedPhones.remove(phone); }); },
                            );
                          }
                        );
                      }
                    )
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isSaving ? null : () async {
                      if (nameController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название группы'))); return; }
                      if (selectedPhones.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите хотя бы 1 сотрудника'))); return; }
                      setModalState(() => isSaving = true);
                      try {
                        List<String> participants = [_myPhone, ...selectedPhones];
                        String roomId = 'team_group_${DateTime.now().millisecondsSinceEpoch}';
                        await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).set({'type': 'team', 'is_group': true, 'group_name': nameController.text.trim(), 'participants': participants, 'created_at': FieldValue.serverTimestamp(), 'last_message': 'Группа создана', 'last_message_time': FieldValue.serverTimestamp(), 'unread_count': 0, 'last_sender': _myPhone});
                        if (context.mounted) { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: roomId, targetName: nameController.text.trim()))); }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                      } finally { setModalState(() => isSaving = false); }
                    },
                    child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('СОЗДАТЬ ГРУППУ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                ]
              )
            )
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = _myRole == 'Владелец' || _myRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Чат команды'), backgroundColor: Colors.orange[600], foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton(onPressed: _showCreateGroupDialog, backgroundColor: Colors.orange[600], foregroundColor: Colors.white, child: const Icon(Icons.group_add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').where('is_group', isEqualTo: true).where('participants', arrayContains: _myPhone).snapshots(),
        builder: (context, groupSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('employees').snapshots(),
            builder: (context, empSnapshot) {
              if (empSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final groups = groupSnapshot.data?.docs ?? [];
              final employees = empSnapshot.data?.docs.where((d) => (d.data() as Map)['phone'] != _myPhone).toList() ?? [];
              
              return ListView(
                padding: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: MediaQuery.of(context).padding.bottom + 80),
                children: [
                  if (groups.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('ГРУППЫ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[400], fontSize: 12))),
                    ...groups.map((g) {
                      final data = g.data() as Map<String, dynamic>;
                      int unreadCount = data['unread_count'] as int? ?? 0;
                      return Card(
                        elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Badge(isLabelVisible: data['last_sender'] != _myPhone && unreadCount > 0, label: Text(unreadCount.toString()), child: CircleAvatar(backgroundColor: Colors.orange[800], child: const Icon(Icons.group, color: Colors.white))),
                          title: Text(data['group_name'] ?? 'Группа', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(data['last_message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (isAdmin) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteChat(g.id)), const Icon(Icons.chevron_right, color: Colors.blueGrey)]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(roomId: g.id, targetName: data['group_name'] ?? 'Группа'))),
                        ),
                      );
                    }),
                  ],
                  if (employees.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('ЛИЧНЫЕ ЧАТЫ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[400], fontSize: 12))),
                    ...employees.map((e) {
                      final data = e.data() as Map<String, dynamic>;
                      String empPhone = data['phone'] ?? '';
                      String roomId = _getRoomId(_myPhone, empPhone);
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).snapshots(),
                        builder: (context, roomSnapshot) {
                          int unreadCount = 0; bool isOtherSender = false; String lastMsg = 'Начать переписку';
                          if (roomSnapshot.hasData && roomSnapshot.data!.exists) {
                            final roomData = roomSnapshot.data!.data() as Map<String, dynamic>;
                            unreadCount = roomData['unread_count'] as int? ?? 0; isOtherSender = roomData['last_sender'] != _myPhone; lastMsg = roomData['last_message'] ?? 'Начать переписку';
                          }
                          return Card(
                            elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Badge(isLabelVisible: isOtherSender && unreadCount > 0, label: Text(unreadCount.toString()), child: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white))),
                              title: Text(data['name'] ?? 'Сотрудник', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (isAdmin && roomSnapshot.hasData && roomSnapshot.data!.exists) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteChat(roomId)), const Icon(Icons.chevron_right, color: Colors.blueGrey)]),
                              onTap: () => _startChatWithEmployee(context, empPhone, data['name'] ?? 'Сотрудник'),
                            ),
                          );
                        }
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

