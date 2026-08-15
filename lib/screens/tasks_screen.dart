import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final diff = taskDate.difference(today).inDays;

    if (diff == 0) return 'СЕГОДНЯ';
    if (diff == 1) return 'ЗАВТРА';
    if (diff == -1) return 'ВЧЕРА';
    if (diff < 0) return 'ПРОСРОЧЕНО (${-diff} дн.)';
    
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Color _getDateColor(DateTime date, bool isCompleted, bool isDark) {
    if (isCompleted) return isDark ? Colors.grey[600]! : Colors.grey;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final diff = taskDate.difference(today).inDays;

    if (diff < 0) return Colors.red;
    if (diff == 0) return Colors.orange;
    return Colors.blue;
  }

  void _showAddTaskSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 140),
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Text('Новое напоминание', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                
                TextField(
                  controller: titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Что нужно сделать? (Напр: Забрать долг)',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.task_alt),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: descController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Детали / Клиент (Необязательно)',
                    labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Дата выполнения', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey)),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(selectedDate), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  trailing: ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Выбрать'),
                  ),
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueGrey[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    await FirebaseFirestore.instance.collection('tasks').add({
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'due_date': Timestamp.fromDate(selectedDate),
                      'is_completed': false,
                      'created_at': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Задача добавлена!'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toggleTaskStatus(String id, bool currentStatus) {
    FirebaseFirestore.instance.collection('tasks').doc(id).update({
      'is_completed': !currentStatus,
    });
  }

  void _deleteTask(String id) {
    FirebaseFirestore.instance.collection('tasks').doc(id).delete();
  }

  Widget _buildTasksList(bool showCompleted, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tasks').where('is_completed', isEqualTo: showCompleted).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(showCompleted ? Icons.task_alt : Icons.next_plan_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                const SizedBox(height: 16),
                Text(showCompleted ? 'Нет выполненных задач' : 'Все задачи выполнены! Вы супер!', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 16)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['due_date'] as Timestamp?;
          final bDate = (b.data() as Map<String, dynamic>)['due_date'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          // Активные сортируем от самых старых (просроченных) к новым. Выполненные — наоборот.
          return showCompleted ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
        });

        return ListView.builder(
          padding: EdgeInsets.only(top: 12, left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Без названия';
            final desc = data['description'] ?? '';
            final dueDate = (data['due_date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final isCompleted = data['is_completed'] == true;

            final dateColor = _getDateColor(dueDate, isCompleted, isDark);
            final dateText = _getFriendlyDate(dueDate);

            return Card(
              elevation: isCompleted ? 0 : 2,
              color: isCompleted ? (isDark ? Colors.grey[850] : Colors.grey[100]) : Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isCompleted ? Colors.transparent : (isDark ? Colors.grey[700]! : dateColor.withOpacity(0.5)), width: isCompleted ? 0 : 1.5)
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: Checkbox(
                  value: isCompleted,
                  activeColor: Colors.green,
                  shape: const CircleBorder(),
                  onChanged: (_) => _toggleTaskStatus(doc.id, isCompleted),
                ),
                title: Text(
                  title, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isCompleted ? (isDark ? Colors.grey[500] : Colors.grey) : (isDark ? Colors.white : Colors.black87),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  )
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc, style: TextStyle(color: isCompleted ? (isDark ? Colors.grey[600] : Colors.grey) : (isDark ? Colors.white70 : Colors.blueGrey[700]))),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: dateColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        dateText, 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dateColor)
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => _deleteTask(doc.id),
                  tooltip: 'Удалить задачу',
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
        title: const Text('Задачи и Напоминания'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '🔥 Активные'),
            Tab(text: '✅ Выполненные'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: Colors.blue[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Добавить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksList(false, isDark), // Активные
          _buildTasksList(true, isDark),  // Выполненные
        ],
      ),
    );
  }
}

