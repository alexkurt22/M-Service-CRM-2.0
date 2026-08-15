import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'users_screen.dart';
import 'orders_screen.dart';
import 'database_cleanup_screen.dart'; 
import 'settings_screen.dart'; 
import 'chat_lists_screen.dart'; 
import 'statistics_screen.dart';
import 'tasks_screen.dart'; 
import 'bulk_push_screen.dart'; 
import 'admin_notes_screen.dart';
import 'content_manager_screen.dart'; // Подключен Контент-завод
import 'store_management_screen.dart';
import 'cash_register_screen.dart'; 
import 'marketing_screen.dart'; 
import 'login_screen.dart'; 
import 'company_editor_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _myPhone = 'admin';
  String _myRole = 'Сотрудник';
  List<dynamic> _myPermissions = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('employee_phone') ?? 'admin';
    
    setState(() => _myPhone = phone);

    if (phone != 'admin') {
       final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
       if (doc.exists) {
         setState(() {
           _myRole = doc.data()?['role'] ?? 'Сотрудник';
           _myPermissions = doc.data()?['permissions'] ?? [];
         });
       }
    }
    _setupPushNotifications(); 
  }

  bool _hasPermission(String permission) {
    if (_myRole == 'Владелец') return true; 
    return _myPermissions.contains(permission);
  }

  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    
    if (_hasPermission('manage_clients') || _hasPermission('view_all_orders')) {
       await messaging.subscribeToTopic('admins'); 
    } else {
       await messaging.unsubscribeFromTopic('admins'); 
    }

    String? token = await messaging.getToken();
    if (token != null && _myPhone.isNotEmpty) {
      await FirebaseFirestore.instance.collection('employees').doc(_myPhone).set({
        'fcm_token': token,
      }, SetOptions(merge: true));
    }

    messaging.onTokenRefresh.listen((newToken) async {
      if (_myPhone.isNotEmpty) {
        await FirebaseFirestore.instance.collection('employees').doc(_myPhone).set({
          'fcm_token': newToken,
        }, SetOptions(merge: true));
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      HapticFeedback.heavyImpact();
    });
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выход из системы'),
          content: const Text('Вы точно хотите выйти из аккаунта?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('employee_phone'); 
      
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()), 
        (route) => false,
      );
    }
  }

  Widget _buildDrawer(BuildContext context, bool isDark) {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: SafeArea( 
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.blueGrey[900]),
              accountName: const Text('M-SERVICE CRM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
              accountEmail: Text(_myRole, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              currentAccountPicture: CircleAvatar(backgroundColor: isDark ? Colors.grey[800] : Colors.white, child: Icon(Icons.admin_panel_settings, size: 40, color: isDark ? Colors.white : Colors.blueGrey[900])),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), 
                    child: Text('ИНСТРУМЕНТЫ', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.blueGrey[400], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2))
                  ),
                  
                  if (_hasPermission('view_finance'))
                    ListTile(leading: Icon(Icons.bar_chart, color: isDark ? Colors.white70 : Colors.blueGrey[700]), title: Text('Статистика', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())); }),

                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.green), 
                    title: Text('Касса и Долги', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), 
                    onTap: () { 
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CashRegisterScreen())); 
                    }
                  ),

                  if (_hasPermission('send_push'))
                    ListTile(leading: Icon(Icons.send_to_mobile, color: isDark ? Colors.white70 : Colors.blueGrey[700]), title: Text('Создать рассылку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkPushScreen())); }),
                  
                  ListTile(
                    leading: const Icon(Icons.campaign, color: Colors.blueAccent), 
                    title: Text('Рекламные кампании', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), 
                    onTap: () { 
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketingScreen())); 
                    }
                  ),

                  ListTile(leading: Icon(Icons.menu_book, color: isDark ? Colors.white70 : Colors.blueGrey[700]), title: Text('База знаний', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotesScreen())); }),
                  
                  if (_hasPermission('manage_settings')) ...[
                    ListTile(leading: Icon(Icons.storefront, color: isDark ? Colors.green[300] : Colors.green[700]), title: Text('Магазин и Склад', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreManagementScreen())); }),
                    
                    // --- НОВАЯ КНОПКА: КОНТЕНТ-ЗАВОД ---
                    ListTile(
                      leading: Icon(Icons.dynamic_feed, color: isDark ? Colors.pink[300] : Colors.pink[600]), 
                      title: Text('Контент-завод', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), 
                      onTap: () { 
                        Navigator.pop(context); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ContentManagerScreen())); 
                      }
                    ),
                    
                    ListTile(
                      leading: const Icon(Icons.business, color: Colors.indigo), 
                      title: Text('Инфо о компании (FAQ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), 
                      onTap: () { 
                        Navigator.pop(context); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyEditorScreen())); 
                      }
                    ),

                    ListTile(leading: Icon(Icons.settings, color: isDark ? Colors.white70 : Colors.blueGrey[700]), title: Text('Настройки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
                  ]
                ],
              ),
            ),
            
            if (_myRole == 'Владелец') ...[
              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
              ListTile(
                tileColor: isDark ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50], 
                leading: Icon(Icons.delete_sweep, color: isDark ? Colors.red[300] : Colors.red), 
                title: Text('Очистка базы данных', style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold, fontSize: 15)), 
                onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const DatabaseCleanupScreen())); }
              ),
            ],

            Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required BuildContext context, required String title, required IconData icon, required Color color, required Widget child, required VoidCallback onTap, required bool isDark}) {
    return Card(
      elevation: 2, color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 32, color: color), const SizedBox(height: 8), child, const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.blueGrey))]),
        ),
      ),
    );
  }

  Widget _buildStreamStat({required Stream<QuerySnapshot> stream, required Color color, bool Function(DocumentSnapshot)? filter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2));
        int count = 0;
        if (snapshot.hasData) count = filter != null ? snapshot.data!.docs.where(filter).length : snapshot.data!.docs.length;
        return Text(count.toString(), style: TextStyle(fontSize: 26, color: color, fontWeight: FontWeight.w900));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900], foregroundColor: Colors.white,
        title: const Text('Сводка CRM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), elevation: 0,
        leading: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'incoming').snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;
            if (snapshot.hasData) unreadCount = snapshot.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['has_unread_update'] == true && (_hasPermission('view_all_orders') || (d.data() as Map<String, dynamic>)['assigned_to'] == _myPhone)).length;
            return Builder(builder: (ctx) => IconButton(icon: Badge(isLabelVisible: unreadCount > 0, label: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red, child: const Icon(Icons.menu)), onPressed: () => Scaffold.of(ctx).openDrawer()));
          },
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').where('is_completed', isEqualTo: false).snapshots(),
            builder: (context, snapshot) {
              int urgentTasks = 0;
              if (snapshot.hasData) {
                final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                urgentTasks = snapshot.data!.docs.where((doc) {
                  final date = ((doc.data() as Map<String, dynamic>)['due_date'] as Timestamp?)?.toDate();
                  if (date == null) return false;
                  return DateTime(date.year, date.month, date.day).difference(today).inDays <= 0;
                }).length;
              }
              return IconButton(icon: Badge(isLabelVisible: urgentTasks > 0, label: Text('$urgentTasks', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red, child: const Icon(Icons.notifications)), tooltip: 'Задачи и Напоминания', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen())));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, isDark), 
      
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),
        builder: (context, snapshot) {
          int unreadClientChats = 0;
          int unreadTeamChats = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              int count = data['unread_count'] as int? ?? 0;
              if (count > 0 && data['last_sender'] != _myPhone) {
                if (data['type'] == 'private' && _hasPermission('manage_clients')) unreadClientChats += count;
                if (data['type'] == 'team' && (data['participants'] ?? []).contains(_myPhone)) unreadTeamChats += count;
              }
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_hasPermission('manage_clients'))
                Badge(isLabelVisible: unreadClientChats > 0, label: Text(unreadClientChats.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red, offset: const Offset(-4, -4), child: FloatingActionButton.extended(heroTag: 'client_chat_btn', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientChatsListScreen())), backgroundColor: Colors.blue[700], icon: const Icon(Icons.support_agent, color: Colors.white), label: const Text('Чаты с клиентами', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 16),
              Badge(isLabelVisible: unreadTeamChats > 0, label: Text(unreadTeamChats.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red, offset: const Offset(-4, -4), child: FloatingActionButton.extended(heroTag: 'team_chat_btn', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamChatsListScreen())), backgroundColor: Colors.orange[600], icon: const Icon(Icons.groups, color: Colors.white), label: const Text('Чат команды', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ],
          );
        },
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: MediaQuery.of(context).padding.bottom + 140.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Icon(Icons.home_repair_service, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800]), const SizedBox(width: 8), Text('Заказы (Новая структура)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blueGrey[900], letterSpacing: 1.2))]),
              const SizedBox(height: 12),
              
              // --- ОБНОВЛЕННАЯ СЕТКА ИЗ 3-Х КВАДРАТОВ ЗАКАЗОВ ---
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1,
                children: [
                  _buildStatCard(
                    context: context, isDark: isDark, title: 'Поступившие', icon: Icons.inbox, color: Colors.blue, 
                    child: _buildStreamStat(
                      stream: FirebaseFirestore.instance.collection('orders').where('status', whereIn: ['new', 'awaiting_approval']).snapshots(), 
                      color: isDark ? Colors.blue[300]! : Colors.blue[800]!, 
                      filter: (doc) => _hasPermission('view_all_orders') || (doc.data() as Map<String, dynamic>)['assigned_to'] == _myPhone
                    ), 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'incoming', title: 'Поступившие')))
                  ),
                  _buildStatCard(
                    context: context, isDark: isDark, title: 'В работе', icon: Icons.build_circle, color: Colors.orange, 
                    child: _buildStreamStat(
                      stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'in_progress').snapshots(), 
                      color: isDark ? Colors.orange[300]! : Colors.orange[800]!, 
                      filter: (doc) => _hasPermission('view_all_orders') || (doc.data() as Map<String, dynamic>)['assigned_to'] == _myPhone
                    ), 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'in_progress', title: 'Готово к исполнению')))
                  ),
                  _buildStatCard(
                    context: context, isDark: isDark, title: 'Архив', icon: Icons.archive, color: Colors.teal, 
                    child: _buildStreamStat(
                      stream: FirebaseFirestore.instance.collection('orders').where('status', whereIn: ['completed', 'canceled']).snapshots(), 
                      color: isDark ? Colors.teal[300]! : Colors.teal[800]!, 
                      filter: (doc) => _hasPermission('view_all_orders') || (doc.data() as Map<String, dynamic>)['assigned_to'] == _myPhone
                    ), 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(status: 'archive', title: 'Архив')))
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              if (_hasPermission('manage_clients')) ...[
                Row(children: [Icon(Icons.people_alt, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[800]), const SizedBox(width: 8), Text('Клиенты', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.blueGrey[900], letterSpacing: 1.2))]),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1,
                  children: [
                    _buildStatCard(context: context, isDark: isDark, title: 'Ждут одобрения', icon: Icons.timer, color: Colors.orange, child: _buildStreamStat(stream: FirebaseFirestore.instance.collection('clients').snapshots(), color: isDark ? Colors.orange[300]! : Colors.orange[800]!, filter: (doc) => (doc.data() as Map<String, dynamic>)['is_approved'] == false && (doc.data() as Map<String, dynamic>)['rejection_reason'] == null && (doc.data() as Map<String, dynamic>)['is_offline'] != true), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 0, title: 'Ждут одобрения')))),
                    _buildStatCard(context: context, isDark: isDark, title: 'Без приложения', icon: Icons.person_outline, color: Colors.grey, child: _buildStreamStat(stream: FirebaseFirestore.instance.collection('clients').snapshots(), color: isDark ? Colors.grey[400]! : Colors.grey[800]!, filter: (doc) => (doc.data() as Map<String, dynamic>)['is_offline'] == true), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 1, title: 'Без приложения')))),
                    _buildStatCard(context: context, isDark: isDark, title: 'С приложением', icon: Icons.verified_user, color: Colors.green, child: _buildStreamStat(stream: FirebaseFirestore.instance.collection('clients').snapshots(), color: isDark ? Colors.green[300]! : Colors.green[800]!, filter: (doc) => (doc.data() as Map<String, dynamic>)['is_approved'] == true && (doc.data() as Map<String, dynamic>)['is_offline'] != true), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 2, title: 'С приложением')))),
                    _buildStatCard(context: context, isDark: isDark, title: 'Отклоненные', icon: Icons.block, color: Colors.red, child: _buildStreamStat(stream: FirebaseFirestore.instance.collection('clients').snapshots(), color: isDark ? Colors.red[300]! : Colors.red[800]!, filter: (doc) => (doc.data() as Map<String, dynamic>)['is_approved'] == false && (doc.data() as Map<String, dynamic>)['rejection_reason'] != null), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen(tabType: 3, title: 'Отклоненные')))),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

