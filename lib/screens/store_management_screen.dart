import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // <--- НАШ НОВЫЙ СОВРЕМЕННЫЙ СКАНЕР
import 'package:permission_handler/permission_handler.dart'; 

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // УНИВЕРСАЛЬНАЯ ФУНКЦИЯ: ДОБАВЛЕНИЕ ИЛИ РЕДАКТИРОВАНИЕ
  void _showProductDialog({DocumentSnapshot? existingDoc}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Подставляем данные, если это редактирование
    final nameController = TextEditingController(text: existingDoc?['name'] ?? '');
    final priceController = TextEditingController(text: existingDoc?['price']?.toString() ?? '');
    final stockController = TextEditingController(text: existingDoc?['stock']?.toString() ?? '1');
    final barcodeController = TextEditingController(text: existingDoc?['barcode'] ?? '');
    final descController = TextEditingController(text: existingDoc?['description'] ?? '');
    
    String condition = existingDoc?['condition'] ?? 'Новый'; 
    String? currentImageBase64 = existingDoc?['image_base64'];
    Uint8List? selectedImageBytes;
    bool isSaving = false;

    Future<void> pickImage(StateSetter setModalState) async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
        if (pickedFile != null) {
          final bytes = await pickedFile.readAsBytes();
          setModalState(() {
            selectedImageBytes = bytes;
            currentImageBase64 = null; // Сбрасываем старую картинку
          });
        }
      } catch (e) {
        debugPrint('Ошибка выбора фото: $e');
      }
    }

    // === ИНТЕГРАЦИЯ НОВОГО СКАНЕРА ПРИ ДОБАВЛЕНИИ ТОВАРА ===
    Future<void> openBarcodeScanner(StateSetter setModalState) async {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        if (!context.mounted) return;
        
        // Открываем наш новый экран сканирования
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
        );
        
        // Если вернулся результат, записываем его в текстовое поле
        if (result != null && result is String && result.isNotEmpty) {
          setModalState(() => barcodeController.text = result);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет доступа к камере! Разрешите в настройках.'), backgroundColor: Colors.red));
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 16, right: 16, top: 16),
            child: FractionallySizedBox(
              heightFactor: 0.92,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(margin: const EdgeInsets.symmetric(horizontal: 140), height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text(existingDoc == null ? 'Добавление товара' : 'Редактирование товара', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    GestureDetector(
                      onTap: () => pickImage(setModalState),
                      child: Center(
                        child: Container(
                          height: 120,
                          width: 120, 
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 2),
                            image: selectedImageBytes != null 
                                ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover) 
                                : (currentImageBase64 != null && currentImageBase64!.isNotEmpty)
                                    ? DecorationImage(image: MemoryImage(base64Decode(currentImageBase64!)), fit: BoxFit.cover)
                                    : null,
                          ),
                          child: (selectedImageBytes == null && (currentImageBase64 == null || currentImageBase64!.isEmpty))
                              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 32, color: Colors.blueGrey[400]), const SizedBox(height: 4), Text('Фото', style: TextStyle(color: Colors.blueGrey[400], fontSize: 12, fontWeight: FontWeight.bold))])
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(labelText: 'Название товара / запчасти', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: condition,
                            dropdownColor: Theme.of(context).cardColor,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(labelText: 'Состояние', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                            items: ['Новый', 'Б/У'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) { if (val != null) setModalState(() => condition = val); },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(labelText: 'Цена (TMT)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.sell, color: Colors.green)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: barcodeController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Штрихкод', 
                              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), 
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                                onPressed: () => openBarcodeScanner(setModalState), 
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(labelText: 'В наличии (шт)', labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), border: const OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Описание характеристик', 
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]), 
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blueGrey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        final name = nameController.text.trim();
                        final price = double.tryParse(priceController.text) ?? 0;
                        final stock = int.tryParse(stockController.text) ?? 0;
                        
                        if (name.isEmpty || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите название и цену больше нуля')));
                          return;
                        }

                        setModalState(() => isSaving = true);
                        try {
                          String? finalImageBase64 = currentImageBase64;
                          if (selectedImageBytes != null) {
                            finalImageBase64 = base64Encode(selectedImageBytes!);
                          }

                          Map<String, dynamic> data = {
                            'name': name,
                            'price': price,
                            'stock': stock,
                            'condition': condition,
                            'barcode': barcodeController.text.trim(),
                            'description': descController.text.trim(),
                            'image_base64': finalImageBase64,
                            'is_active': stock > 0, 
                          };

                          if (existingDoc == null) {
                            // СОЗДАНИЕ НОВОГО ТОВАРА
                            data['created_at'] = FieldValue.serverTimestamp();
                            await FirebaseFirestore.instance.collection('products').add(data);
                          } else {
                            // ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО
                            await FirebaseFirestore.instance.collection('products').doc(existingDoc.id).update(data);
                          }

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existingDoc == null ? 'Товар добавлен!' : 'Товар обновлен!'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(existingDoc == null ? 'ОПУБЛИКОВАТЬ В МАГАЗИН' : 'СОХРАНИТЬ ИЗМЕНЕНИЯ', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        }
      )
    );
  }

  void _deleteProduct(String docId) {
    FirebaseFirestore.instance.collection('products').doc(docId).delete();
  }

  // === ИНТЕГРАЦИЯ НОВОГО СКАНЕРА ДЛЯ ПОИСКА ТОВАРОВ ===
  Future<void> _scanBarcodeForSearch() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      if (!mounted) return;
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
      );
      
      if (result != null && result is String && result.isNotEmpty) {
        setState(() {
          _searchController.text = result;
          _searchQuery = result.toLowerCase();
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет доступа к камере! Разрешите в настройках.'), backgroundColor: Colors.red));
      }
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
        title: const Text('Склад и Витрина', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(), 
        backgroundColor: Colors.blueGrey[800],
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Добавить товар', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))]),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Поиск по названию или штрихкоду...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                  onPressed: _scanBarcodeForSearch,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').orderBy('created_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.blueGrey[200]),
                        const SizedBox(height: 16),
                        Text('Склад пуст', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.blueGrey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                // ЛОГИКА ФИЛЬТРАЦИИ ПОИСКА
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || barcode.contains(_searchQuery);
                  }).toList();
                }

                return ListView.builder(
                  padding: EdgeInsets.only(top: 12, left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Без названия';
                    final price = data['price'] ?? 0;
                    final stock = data['stock'] ?? 0;
                    final condition = data['condition'] ?? 'Новый';
                    final imageBase64 = data['image_base64'];

                    bool outOfStock = stock <= 0;

                    return Card(
                      elevation: 1,
                      color: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade200)),
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          Container(
                            height: 90,
                            width: 90,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              image: imageBase64 != null && imageBase64.toString().isNotEmpty
                                  ? DecorationImage(image: MemoryImage(base64Decode(imageBase64)), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: imageBase64 == null || imageBase64.toString().isEmpty
                                ? Icon(Icons.image_not_supported, color: isDark ? Colors.grey[600] : Colors.grey[400])
                                : null,
                          ),
                          
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                                      ),
                                      // КНОПКА РЕДАКТИРОВАНИЯ
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.edit, color: isDark ? Colors.blue[300] : Colors.blue[600], size: 20),
                                        onPressed: () => _showProductDialog(existingDoc: doc),
                                      ),
                                      const SizedBox(width: 12),
                                      // КНОПКА УДАЛЕНИЯ
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () => _deleteProduct(doc.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('$price TMT', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: condition == 'Новый' ? Colors.blue[100] : Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                                        child: Text(condition, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: condition == 'Новый' ? Colors.blue[800] : Colors.orange[800])),
                                      ),
                                      Text(
                                        outOfStock ? 'НЕТ В НАЛИЧИИ' : 'Остаток: $stock шт',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: outOfStock ? Colors.red : Colors.grey),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }
}

// === НОВЫЙ ЭКРАН СКАНЕРА (MOBILE_SCANNER) ===
class SimpleBarcodeScannerPage extends StatefulWidget {
  const SimpleBarcodeScannerPage({super.key});

  @override
  State<SimpleBarcodeScannerPage> createState() => _SimpleBarcodeScannerPageState();
}

class _SimpleBarcodeScannerPageState extends State<SimpleBarcodeScannerPage> {
  bool _isScanned = false; // Защита от двойного считывания

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Наведите камеру на штрихкод', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_isScanned) return; // Если уже сосканировали, игнорируем остальные кадры
          
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            _isScanned = true;
            Navigator.pop(context, barcodes.first.rawValue); // Возвращаемся и передаем код
          }
        },
      ),
    );
  }
}
