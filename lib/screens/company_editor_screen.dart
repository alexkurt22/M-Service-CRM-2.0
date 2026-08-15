import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyEditorScreen extends StatefulWidget {
  const CompanyEditorScreen({super.key});

  @override
  State<CompanyEditorScreen> createState() => _CompanyEditorScreenState();
}

class _CompanyEditorScreenState extends State<CompanyEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Контроллеры для контактов
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _aboutController = TextEditingController();

  bool _isLoading = true;

  // Список FAQ
  List<Map<String, dynamic>> _faqItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _scheduleController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Грузим инфу о компании
      final companyDoc = await FirebaseFirestore.instance.collection('settings').doc('company_info').get();
      if (companyDoc.exists) {
        final data = companyDoc.data()!;
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _scheduleController.text = data['schedule'] ?? '';
        _aboutController.text = data['about_text'] ?? '';
      }

      // Грузим FAQ
      final faqDoc = await FirebaseFirestore.instance.collection('settings').doc('faq').get();
      if (faqDoc.exists) {
        final data = faqDoc.data()!;
        setState(() {
          _faqItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCompanyInfo() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      await FirebaseFirestore.instance.collection('settings').doc('company_info').set({
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'schedule': _scheduleController.text.trim(),
        'about_text': _aboutController.text.trim(),
      }, SetOptions(merge: true));
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Контакты обновлены!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveFaq() async {
    try {
      await FirebaseFirestore.instance.collection('settings').doc('faq').set({
        'items': _faqItems,
      }, SetOptions(merge: true));
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FAQ обновлен!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAddFaqDialog([int? index]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qController = TextEditingController(text: index != null ? _faqItems[index]['question'] : '');
    final aController = TextEditingController(text: index != null ? _faqItems[index]['answer'] : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(index == null ? 'Новый вопрос' : 'Редактировать', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: const InputDecoration(labelText: 'Вопрос', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aController,
              maxLines: 3,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: const InputDecoration(labelText: 'Ответ', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (qController.text.trim().isEmpty || aController.text.trim().isEmpty) return;
              
              setState(() {
                if (index == null) {
                  _faqItems.add({'question': qController.text.trim(), 'answer': aController.text.trim()});
                } else {
                  _faqItems[index] = {'question': qController.text.trim(), 'answer': aController.text.trim()};
                }
              });
              _saveFaq();
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Инфо о компании')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Редактор Инфо'),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Контакты / О Нас'),
              Tab(text: 'База FAQ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Вкладка 1: КОНТАКТЫ И О НАС
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('БЛОК КОНТАКТОВ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(labelText: 'Телефон', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(labelText: 'Адрес', prefixIcon: Icon(Icons.location_on), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _scheduleController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(labelText: 'Режим работы', prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    
                    Text('О КОМПАНИИ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _aboutController,
                      maxLines: 5,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(labelText: 'Текст о компании', border: OutlineInputBorder(), alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveCompanyInfo,
                      child: const Text('СОХРАНИТЬ КОНТАКТЫ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),

            // Вкладка 2: FAQ
            Column(
              children: [
                Expanded(
                  child: _faqItems.isEmpty
                    ? Center(child: Text('Нет вопросов. Добавьте первый!', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _faqItems.length,
                        itemBuilder: (context, index) {
                          final item = _faqItems[index];
                          return Card(
                            color: Theme.of(context).cardColor,
                            child: ListTile(
                              title: Text(item['question'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                              subtitle: Text(item['answer'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showAddFaqDialog(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _faqItems.removeAt(index));
                                      _saveFaq();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showAddFaqDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('ДОБАВИТЬ ВОПРОС', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
