import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  List<String> _globalPlatforms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlatforms();
  }

  // Загружаем список площадок из настроек (или создаем базовый)
  Future<void> _loadPlatforms() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('marketing').get();
      if (doc.exists && doc.data()!.containsKey('platforms')) {
        setState(() {
          _globalPlatforms = List<String>.from(doc.data()!['platforms']);
          _isLoading = false;
        });
      } else {
        // Базовый список, если заходим в первый раз
        final defaultPlatforms = ['Instagram', 'Вестник ТМ', 'TMCars'];
        await FirebaseFirestore.instance.collection('settings').doc('marketing').set({
          'platforms': defaultPlatforms
        }, SetOptions(merge: true));
        
        setState(() {
          _globalPlatforms = defaultPlatforms;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки площадок: $e');
      setState(() => _isLoading = false);
    }
  }

  // Добавление новой площадки навсегда в базу
  Future<void> _addNewPlatform() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final newPlatform = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Новая площадка', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Например: TikTok, Доска объявлений...',
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (newPlatform != null && newPlatform.isNotEmpty && !_globalPlatforms.contains(newPlatform)) {
      setState(() => _globalPlatforms.add(newPlatform));
      await FirebaseFirestore.instance.collection('settings').doc('marketing').set({
        'platforms': _globalPlatforms
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Площадка "$newPlatform" добавлена!'), backgroundColor: Colors.green));
    }
  }

  // --- СОЗДАНИЕ РЕКЛАМНОГО ПОСТА (ИСПРАВЛЕННЫЙ ИНТЕРФЕЙС БЕЗ ИИ) ---
  void _showCreateAdDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String? currentImageBase64;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            // Отступ снизу для клавиатуры
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom, 
              left: 16, right: 16, top: 16
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Позволяем колонке сжиматься/растягиваться
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(margin: const EdgeInsets.symmetric(horizontal: 140), height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Новая рекламная кампания', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                const SizedBox(height: 16),

                // Скроллируемая область формы (теперь не схлопнется при клавиатуре)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: titleController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(labelText: 'Внутреннее название (для себя)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),

                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 1000);
                            if (pickedFile != null) {
                              final bytes = await pickedFile.readAsBytes();
                              setModalState(() => currentImageBase64 = base64Encode(bytes));
                            }
                          },
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                              image: currentImageBase64 != null ? DecorationImage(image: MemoryImage(base64Decode(currentImageBase64!)), fit: BoxFit.cover) : null,
                            ),
                            child: currentImageBase64 == null 
                                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 40, color: Colors.blueGrey[400]), const SizedBox(height: 8), Text('Прикрепить фото для рекламы', style: TextStyle(color: Colors.blueGrey[400]))])
                                : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(8.0), child: CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.edit, color: Colors.white, size: 20)))),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: contentController,
                          minLines: 6, // Минимальная высота поля - 6 строк (никогда не схлопнется)
                          maxLines: 20, // Максимальная - 20, дальше появится внутренний скролл
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Рекламный текст (Пост)', 
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), 
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // КНОПКА СОХРАНИТЬ (Теперь под защитой SafeArea от системных кнопок)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните заголовок и текст')));
                          return;
                        }

                        setModalState(() => isSaving = true);
                        try {
                          Map<String, bool> platformsStatus = {};
                          for (var p in _globalPlatforms) {
                            platformsStatus[p] = false; 
                          }

                          await FirebaseFirestore.instance.collection('marketing_campaigns').add({
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim(),
                            'image_base64': currentImageBase64,
                            'platforms_status': platformsStatus,
                            'created_at': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рекламная кампания создана!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('СОХРАНИТЬ КАМПАНИЮ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      )
    );
  }

  // --- УПРАВЛЕНИЕ КОНКРЕТНОЙ КАМПАНИЕЙ ---
  void _openCampaignDetails(String docId, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = data['title'] ?? 'Без названия';
    final content = data['content'] ?? '';
    final imageBase64 = data['image_base64'];
    Map<String, dynamic> platformsStatus = data['platforms_status'] ?? {};

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
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setDetailsState) {
            return Column(
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87), maxLines: 2)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                        await FirebaseFirestore.instance.collection('marketing_campaigns').doc(docId).delete();
                        if (context.mounted) Navigator.pop(ctx);
                      })
                    ],
                  ),
                ),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // ФОТО И ТЕКСТ
                      if (imageBase64 != null && imageBase64.toString().isNotEmpty) ...[
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Text(content, style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                      ),
                      const SizedBox(height: 16),

                      // КНОПКИ ДЕЙСТВИЙ
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: content));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован!'), backgroundColor: Colors.blue));
                              },
                              icon: const Icon(Icons.copy), label: const Text('КОПИРОВАТЬ')
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                              onPressed: () {
                                // Нативный Share
                                Share.share(content);
                              },
                              icon: const Icon(Icons.share), label: const Text('ПОДЕЛИТЬСЯ')
                            )
                          )
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ЧЕК-ЛИСТ ПЛОЩАДОК
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Где опубликовано:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blueGrey[800])),
                          TextButton.icon(onPressed: _addNewPlatform, icon: const Icon(Icons.add), label: const Text('Добавить'))
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Собираем все глобальные площадки и проверяем их статус в этой кампании
                      ..._globalPlatforms.map((platform) {
                        bool isPosted = platformsStatus[platform] == true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isPosted ? Colors.green : (isDark ? Colors.grey[800]! : Colors.grey[300]!))),
                          child: CheckboxListTile(
                            activeColor: Colors.green,
                            checkColor: Colors.white,
                            title: Text(platform, style: TextStyle(fontWeight: FontWeight.bold, color: isPosted ? Colors.green : (isDark ? Colors.white : Colors.black87), decoration: isPosted ? TextDecoration.lineThrough : null)),
                            value: isPosted,
                            onChanged: (val) async {
                              setDetailsState(() => platformsStatus[platform] = val);
                              await FirebaseFirestore.instance.collection('marketing_campaigns').doc(docId).update({
                                'platforms_status': platformsStatus
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 40), // Отступ в самом низу
                    ],
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue[800],
        foregroundColor: Colors.white,
        title: const Text('Рекламные кампании', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAdDialog,
        backgroundColor: Colors.blue[800],
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text('Новый пост', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('marketing_campaigns').orderBy('created_at', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ads_click, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                      const SizedBox(height: 16),
                      Text('Нет рекламных постов', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.only(top: 12, left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 80),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Без названия';
                  final imageBase64 = data['image_base64'];
                  
                  // Считаем статистику площадок
                  Map<String, dynamic> pStatus = data['platforms_status'] ?? {};
                  int postedCount = pStatus.values.where((v) => v == true).length;
                  int totalCount = _globalPlatforms.length;

                  return Card(
                    elevation: 1,
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade200)),
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openCampaignDetails(doc.id, data),
                      child: Row(
                        children: [
                          Container(
                            height: 90, width: 90,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.blue[50],
                              image: imageBase64 != null && imageBase64.toString().isNotEmpty ? DecorationImage(image: MemoryImage(base64Decode(imageBase64)), fit: BoxFit.cover) : null,
                            ),
                            child: imageBase64 == null || imageBase64.toString().isEmpty
                                ? Icon(Icons.campaign, size: 36, color: Colors.blue[300])
                                : null,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.checklist, size: 16, color: postedCount == totalCount ? Colors.green : Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Опубликовано: $postedCount из $totalCount', 
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: postedCount == totalCount ? Colors.green : Colors.orange)
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

