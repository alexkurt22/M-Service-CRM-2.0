import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ContentManagerScreen extends StatefulWidget {
  const ContentManagerScreen({super.key});

  @override
  State<ContentManagerScreen> createState() => _ContentManagerScreenState();
}

class _ContentManagerScreenState extends State<ContentManagerScreen> {
  final ImagePicker _picker = ImagePicker();

  // --- ОКНО СОЗДАНИЯ КОНТЕНТА (ПОСТА) ---
  void _showCreatePostDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    
    String selectedType = 'Акция'; 
    bool isUploading = false;
    File? selectedImage;

    // Настройки интерактива
    bool allowComments = true;
    bool allowLikes = true;
    bool allowSharing = true;

    // Настройки Опроса (Голосования)
    bool hasPoll = false;
    final pollQuestionController = TextEditingController();
    List<TextEditingController> pollOptionsControllers = [
      TextEditingController(),
      TextEditingController()
    ];

    Future<void> pickImage(StateSetter setSheetState) async {
      try {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70, // Сжатие до 70%
          maxWidth: 1200,    
        );
        if (image != null) {
          setSheetState(() {
            selectedImage = File(image.path);
          });
        }
      } catch (e) {
        debugPrint('Ошибка выбора фото: $e');
      }
    }

    void insertFormatting(String prefix, String suffix) {
      final text = contentController.text;
      final selection = contentController.selection;
      if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
        final newText = text.replaceRange(selection.start, selection.end, '$prefix${text.substring(selection.start, selection.end)}$suffix');
        contentController.text = newText;
        contentController.selection = TextSelection.collapsed(offset: selection.start + prefix.length);
      } else {
        contentController.text = text + prefix + suffix;
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
              left: 16, right: 16, top: 16
            ),
            child: FractionallySizedBox(
              heightFactor: 0.95, 
              child: SingleChildScrollView( 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 140),
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    Text('Создание публикации', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Акция', groupValue: selectedType, activeColor: Colors.orange,
                            onChanged: (val) => setSheetState(() => selectedType = val!),
                          ),
                          Text('Акция', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(width: 8),
                          Radio<String>(
                            value: 'Новость', groupValue: selectedType, activeColor: Colors.blue,
                            onChanged: (val) => setSheetState(() => selectedType = val!),
                          ),
                          Text('Новость', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(width: 8),
                          Radio<String>(
                            value: 'Конкурс', groupValue: selectedType, activeColor: Colors.pink,
                            onChanged: (val) => setSheetState(() => selectedType = val!),
                          ),
                          Text('Конкурс', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Броский заголовок',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.format_bold), tooltip: 'Жирный', onPressed: () => insertFormatting('**', '**')),
                          IconButton(icon: const Icon(Icons.format_italic), tooltip: 'Курсив', onPressed: () => insertFormatting('_', '_')),
                          IconButton(icon: const Icon(Icons.title), tooltip: 'Заголовок', onPressed: () => insertFormatting('### ', '\n')),
                          IconButton(icon: const Icon(Icons.format_list_bulleted), tooltip: 'Список', onPressed: () => insertFormatting('• ', '\n')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: contentController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Основной текст статьи',
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                        border: const OutlineInputBorder(),
                        helperText: 'Используйте панель выше для форматирования',
                      ),
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => pickImage(setSheetState), 
                      icon: const Icon(Icons.image, color: Colors.green), 
                      label: Text(selectedImage == null ? 'ВЫБРАТЬ ФОТО (Base64)' : 'ИЗМЕНИТЬ ФОТО', style: const TextStyle(color: Colors.green))
                    ),
                    
                    if (selectedImage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Фото выбрано и готово к сжатию', style: TextStyle(fontSize: 12, color: Colors.green[700]))),
                          TextButton(
                            onPressed: () => setSheetState(() => selectedImage = null),
                            child: const Text('Удалить', style: TextStyle(color: Colors.red, fontSize: 12)),
                          )
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text('НАСТРОЙКИ ИНТЕРАКТИВА', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text('Разрешить лайки', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      value: allowLikes,
                      activeColor: Colors.redAccent,
                      onChanged: (val) => setSheetState(() => allowLikes = val),
                    ),
                    SwitchListTile(
                      title: Text('Разрешить комментарии', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      value: allowComments,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setSheetState(() => allowComments = val),
                    ),
                    SwitchListTile(
                      title: Text('Разрешить делиться ссылкой', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      subtitle: const Text('Важно для конкурсов!', style: TextStyle(fontSize: 12)),
                      value: allowSharing,
                      activeColor: Colors.green,
                      onChanged: (val) => setSheetState(() => allowSharing = val),
                    ),

                    const SizedBox(height: 16),
                    Text('ГОЛОСОВАНИЕ / ОПРОС', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text('Прикрепить опрос', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      value: hasPoll,
                      activeColor: Colors.deepPurple,
                      onChanged: (val) => setSheetState(() => hasPoll = val),
                    ),

                    if (hasPoll) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.deepPurple[900]!.withOpacity(0.2) : Colors.deepPurple[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.deepPurple[700]! : Colors.deepPurple[200]!)
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: pollQuestionController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Текст вопроса (напр., Кто победит?)',
                                labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                                filled: true,
                                fillColor: isDark ? Colors.grey[800] : Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...pollOptionsControllers.asMap().entries.map((entry) {
                              int index = entry.key;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: entry.value,
                                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                        decoration: InputDecoration(
                                          labelText: 'Вариант ответа ${index + 1}',
                                          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                                          filled: true,
                                          fillColor: isDark ? Colors.grey[800] : Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    if (pollOptionsControllers.length > 2)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () {
                                          setSheetState(() {
                                            pollOptionsControllers[index].dispose();
                                            pollOptionsControllers.removeAt(index);
                                          });
                                        },
                                      )
                                  ],
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  pollOptionsControllers.add(TextEditingController());
                                });
                              }, 
                              icon: const Icon(Icons.add, color: Colors.deepPurple), 
                              label: const Text('Добавить вариант', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold))
                            )
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: selectedType == 'Акция' ? Colors.orange[600] : (selectedType == 'Конкурс' ? Colors.pink[600] : Colors.blue[600]),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isUploading ? null : () async {
                        final title = titleController.text.trim();
                        final content = contentController.text.trim();

                        if (title.isEmpty || content.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните заголовок и текст')));
                          return;
                        }

                        Map<String, dynamic>? pollData;
                        if (hasPoll) {
                          final question = pollQuestionController.text.trim();
                          if (question.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите текст вопроса для опроса')));
                            return;
                          }
                          List<Map<String, dynamic>> options = [];
                          for (var ctrl in pollOptionsControllers) {
                            if (ctrl.text.trim().isNotEmpty) {
                              options.add({'text': ctrl.text.trim(), 'votes': 0});
                            }
                          }
                          if (options.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В опросе должно быть минимум 2 варианта ответа')));
                            return;
                          }
                          pollData = {
                            'question': question,
                            'options': options,
                            'voted_users': [], 
                            'total_votes': 0
                          };
                        }

                        setSheetState(() => isUploading = true);

                        try {
                          String? imageBase64;

                          if (selectedImage != null) {
                            final bytes = await selectedImage!.readAsBytes();
                            imageBase64 = base64Encode(bytes);
                          }

                          await FirebaseFirestore.instance.collection('news_feed').add({
                            'title': title,
                            'content': content,
                            'type': selectedType,
                            'image_base64': imageBase64, 
                            'created_at': FieldValue.serverTimestamp(),
                            'is_active': true, 
                            'allow_likes': allowLikes,
                            'allow_comments': allowComments,
                            'allow_sharing': allowSharing,
                            'likes_count': 0,
                            'comments_count': 0, // <--- ИЗМЕНЕНИЕ: счетчик комментариев со старта 0
                            'liked_by': [],
                            'shares_count': 0,
                            'poll': pollData, 
                          });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Публикация успешно создана!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                        } finally {
                          setSheetState(() => isUploading = false);
                        }
                      },
                      child: isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('ОПУБЛИКОВАТЬ КОНТЕНТ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _deletePost(String docId) {
    FirebaseFirestore.instance.collection('news_feed').doc(docId).delete();
  }

  Future<void> _togglePostActiveStatus(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('news_feed').doc(docId).update({
        'is_active': !currentStatus
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(!currentStatus ? 'Пост снова виден клиентам' : 'Пост скрыт от клиентов'),
        backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления статуса: $e')));
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
        title: const Text('Контент-Менеджер', style: TextStyle(fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.pink[600],
        icon: const Icon(Icons.add_box, color: Colors.white),
        label: const Text('Создать пост', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('news_feed').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                  const SizedBox(height: 16),
                  Text('Лента пуста', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Создайте первый пост, акцию или опрос!', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.blueGrey[300], fontSize: 14)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final type = data['type'] ?? 'Новость';
              final title = data['title'] ?? 'Без заголовка';
              final content = data['content'] ?? '';
              
              final imageBase64 = data['image_base64'];
              final imageUrl = data['image_url'];

              final isActive = data.containsKey('is_active') ? data['is_active'] as bool : true;
              
              final likes = data['likes_count'] ?? 0;
              final shares = data['shares_count'] ?? 0;
              final commentsCount = data['comments_count'] ?? 0; // Для админки тоже считываем
              
              final hasPoll = data['poll'] != null;
              final pollVotes = hasPoll ? (data['poll']['total_votes'] ?? 0) : 0;
              
              String dateStr = '';
              if (data['created_at'] != null) {
                final dt = (data['created_at'] as Timestamp).toDate();
                dateStr = DateFormat('dd.MM.yy в HH:mm').format(dt);
              }

              return Card(
                elevation: 2,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.transparent)
                ),
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: type == 'Акция' 
                            ? (isDark ? Colors.orange[900]!.withOpacity(0.4) : Colors.orange[50]) 
                            : (type == 'Конкурс' 
                                ? (isDark ? Colors.pink[900]!.withOpacity(0.4) : Colors.pink[50]) 
                                : (isDark ? Colors.blue[900]!.withOpacity(0.4) : Colors.blue[50])),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(type == 'Акция' ? Icons.local_fire_department : (type == 'Конкурс' ? Icons.emoji_events : Icons.info), 
                                color: type == 'Акция' ? Colors.deepOrange : (type == 'Конкурс' ? Colors.pink : Colors.blue), size: 20),
                              const SizedBox(width: 8),
                              Text(type.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: type == 'Акция' ? Colors.deepOrange : (type == 'Конкурс' ? Colors.pink : Colors.blue), fontSize: 12, letterSpacing: 1.2)),
                            ],
                          ),
                          Text(dateStr, style: TextStyle(color: isDark ? Colors.white54 : Colors.blueGrey, fontSize: 12)),
                        ],
                      ),
                    ),

                    if (imageBase64 != null && imageBase64.toString().isNotEmpty)
                      Image.memory(
                        base64Decode(imageBase64),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(height: 50, child: Center(child: Text('Ошибка загрузки фото'))),
                      )
                    else if (imageUrl != null && imageUrl.toString().isNotEmpty)
                      Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                        },
                        errorBuilder: (context, error, stackTrace) => const SizedBox(height: 50, child: Center(child: Text('Ошибка загрузки фото'))),
                      ),
                    
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 8),
                          Text(
                            content, 
                            maxLines: 3, 
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[800], fontSize: 14, height: 1.4)
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(children: [const Icon(Icons.favorite, color: Colors.red, size: 16), const SizedBox(width: 4), Text('$likes', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          Row(children: [const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 16), const SizedBox(width: 4), Text('$commentsCount', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          Row(children: [const Icon(Icons.share, color: Colors.green, size: 16), const SizedBox(width: 4), Text('$shares', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          if (hasPoll)
                            Row(children: [const Icon(Icons.poll, color: Colors.deepPurple, size: 16), const SizedBox(width: 4), Text('$pollVotes голосов', style: const TextStyle(fontWeight: FontWeight.bold))]),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: Colors.green,
                                onChanged: (val) => _togglePostActiveStatus(doc.id, isActive),
                              ),
                              Text(isActive ? 'Активен' : 'Скрыт', style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deletePost(doc.id),
                            tooltip: 'Удалить навсегда',
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

