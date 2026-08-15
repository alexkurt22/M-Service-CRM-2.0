import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class AdminNotesScreen extends StatefulWidget {
  const AdminNotesScreen({super.key});

  @override
  State<AdminNotesScreen> createState() => _AdminNotesScreenState();
}

class _AdminNotesScreenState extends State<AdminNotesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _selectedCategory = 'Все';

  final List<String> _categories = [
    'Все', 'Принтеры', 'Ноутбуки', 'ПК и Железо', 'Программное обеспечение', 'Сети', 'Другое'
  ];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- ПРОСМОТР СТАТЬИ (РЕЖИМ ЧТЕНИЯ) ---
  void _showNoteViewer(String docId, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = data['title'] ?? 'Без заголовка';
    final content = data['content'] ?? '';
    final category = data['category'] ?? 'Другое';
    final tags = List<String>.from(data['tags'] ?? []);
    final checklist = List<String>.from(data['checklist'] ?? []);
    final imageBase64 = data['image_base64'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(8)),
                    child: Text(category, style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey), onPressed: () { Navigator.pop(ctx); _showNoteEditor(docId: docId, initialData: data); }),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { Navigator.pop(ctx); _deleteNote(docId, title); }),
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)), child: Text('#$t', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.blueGrey)))).toList(),
                    ),
                  const SizedBox(height: 24),
                  if (imageBase64 != null && imageBase64.toString().isNotEmpty) ...[
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)),
                    const SizedBox(height: 24),
                  ],
                  Text(content, style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 32),
                  if (checklist.isNotEmpty) ...[
                    Text('Пошаговый Чек-лист:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blueGrey[800])),
                    const SizedBox(height: 12),
                    ...checklist.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_box_outline_blank, color: isDark ? Colors.white54 : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(step, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- РЕДАКТОР СТАТЬИ ---
  void _showNoteEditor({String? docId, Map<String, dynamic>? initialData}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final titleController = TextEditingController(text: initialData?['title']);
    final contentController = TextEditingController(text: initialData?['content']);
    final tagsController = TextEditingController(text: (initialData?['tags'] as List<dynamic>? ?? []).join(', '));
    
    String category = initialData?['category'] ?? 'Другое';
    if (!_categories.contains(category)) category = 'Другое';

    List<TextEditingController> checklistControllers = [];
    if (initialData?['checklist'] != null) {
      for (var item in initialData!['checklist']) {
        checklistControllers.add(TextEditingController(text: item));
      }
    }

    String? currentImageBase64 = initialData?['image_base64'];
    bool isSaving = false;

    Future<void> pickImage(StateSetter setModalState) async {
      try {
        final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
        if (pickedFile != null) {
          final bytes = await File(pickedFile.path).readAsBytes();
          setModalState(() => currentImageBase64 = base64Encode(bytes));
        }
      } catch (e) {
        debugPrint('Ошибка выбора фото: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(margin: const EdgeInsets.symmetric(horizontal: 140), height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(docId == null ? 'Создание статьи' : 'Редактирование', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView(
                    children: [
                      DropdownButtonFormField<String>(
                        value: category == 'Все' ? 'Другое' : category,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(labelText: 'Категория', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey), border: const OutlineInputBorder()),
                        items: _categories.where((c) => c != 'Все').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) { if (val != null) setSheetState(() => category = val); },
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: titleController, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Заголовок (Проблема / Решение)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey), border: const OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: tagsController, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Теги (через запятую: hp, ошибка 5b00)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.tag))),
                      const SizedBox(height: 12),
                      
                      GestureDetector(
                        onTap: () => pickImage(setSheetState),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!), image: currentImageBase64 != null ? DecorationImage(image: MemoryImage(base64Decode(currentImageBase64!)), fit: BoxFit.cover) : null),
                          child: currentImageBase64 == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 40, color: Colors.blueGrey[400]), const SizedBox(height: 8), Text('Прикрепить фото / схему', style: TextStyle(color: Colors.blueGrey[400]))]) : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.edit, color: Colors.white, size: 20)))),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(controller: contentController, maxLines: 6, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: 'Текст инструкции', alignLabelWithHint: true, labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey), border: const OutlineInputBorder())),
                      const SizedBox(height: 16),
                      
                      Text('Чек-лист (Пошаговые действия):', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.blueGrey)),
                      const SizedBox(height: 8),
                      ...checklistControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(child: TextField(controller: entry.value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: 'Шаг ${idx + 1}', isDense: true, border: const OutlineInputBorder()))),
                              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setSheetState(() => checklistControllers.removeAt(idx))),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(onPressed: () => setSheetState(() => checklistControllers.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Добавить шаг')),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: isSaving ? null : () async {
                    if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заголовок и текст обязательны')));
                      return;
                    }

                    setSheetState(() => isSaving = true);
                    try {
                      List<String> parsedTags = tagsController.text.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
                      List<String> parsedChecklist = checklistControllers.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();

                      Map<String, dynamic> saveData = {
                        'title': titleController.text.trim(),
                        'content': contentController.text.trim(),
                        'category': category,
                        'tags': parsedTags,
                        'checklist': parsedChecklist,
                        'image_base64': currentImageBase64,
                        'updated_at': FieldValue.serverTimestamp(),
                      };

                      if (docId == null) {
                        saveData['created_at'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('admin_notes').add(saveData);
                      } else {
                        await FirebaseFirestore.instance.collection('admin_notes').doc(docId).update(saveData);
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(docId == null ? 'Статья добавлена!' : 'Статья обновлена!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                    } finally {
                      setSheetState(() => isSaving = false);
                    }
                  },
                  child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('СОХРАНИТЬ В БАЗУ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteNote(String docId, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Удаление', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Удалить статью "$title"?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]), onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('admin_notes').doc(docId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Удалено')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Поиск (например: hp 59.f0)', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              )
            : const Text('База знаний', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchController.clear(); _searchQuery = ''; } }),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_note_btn',
        onPressed: () => _showNoteEditor(),
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Создать', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 4, offset: const Offset(0, 2))]),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.blueGrey))),
                    selected: isSelected,
                    selectedColor: Colors.blue[700],
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    onSelected: (selected) { if (selected) setState(() => _selectedCategory = cat); },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('admin_notes').orderBy('updated_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('База пуста', style: TextStyle(color: Colors.grey[500])));

                var docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // ПРИВОДИМ ВСЁ К НИЖНЕМУ РЕГИСТРУ ДЛЯ ИДЕАЛЬНОГО ПОИСКА
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final content = (data['content'] ?? '').toString().toLowerCase();
                  
                  // Собираем чек-лист в одну строку
                  final checklistArr = data['checklist'] as List<dynamic>? ?? [];
                  final checklistStr = checklistArr.join(' ').toLowerCase();

                  // Собираем теги
                  final tagsArr = data['tags'] as List<dynamic>? ?? [];
                  final tagsStr = tagsArr.join(' ').toLowerCase();
                  
                  final category = data['category'] ?? 'Другое';

                  bool matchesCategory = _selectedCategory == 'Все' || category == _selectedCategory;
                  if (!matchesCategory) return false;

                  // --- УМНЫЙ МНОГОСЛОВНЫЙ ПОИСК ---
                  if (_searchQuery.isNotEmpty) {
                    final searchWords = _searchQuery.split(RegExp(r'\s+')); 
                    final searchableText = '$title $content $checklistStr $tagsStr $category';
                    
                    for (var word in searchWords) {
                      if (!searchableText.contains(word)) {
                        return false; 
                      }
                    }
                  }

                  return true;
                }).toList();

                if (docs.isEmpty) return Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey[500])));

                return ListView.builder(
                  padding: EdgeInsets.only(top: 12, left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 140),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Без заголовка';
                    final category = data['category'] ?? 'Другое';
                    final hasImage = data['image_base64'] != null;
                    final hasChecklist = (data['checklist'] as List<dynamic>? ?? []).isNotEmpty;

                    return Card(
                      elevation: 1,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showNoteViewer(doc.id, data),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.blue[800]))),
                                  if (hasImage) const Icon(Icons.image, size: 16, color: Colors.grey),
                                  if (hasChecklist) ...[const SizedBox(width: 4), const Icon(Icons.checklist, size: 16, color: Colors.grey)],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: isDark ? Colors.blueGrey[800] : Colors.blueGrey[50], borderRadius: BorderRadius.circular(4)),
                                child: Text(category, style: TextStyle(fontSize: 10, color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[700], fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

