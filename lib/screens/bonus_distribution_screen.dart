import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm_service.dart'; // <--- ОБЯЗАТЕЛЬНЫЙ ИМПОРТ СЕРВИСА ПУШЕЙ

class BonusDistributionScreen extends StatefulWidget {
  const BonusDistributionScreen({super.key});

  @override
  State<BonusDistributionScreen> createState() => _BonusDistributionScreenState();
}

class _BonusDistributionScreenState extends State<BonusDistributionScreen> {
  List<QueryDocumentSnapshot> _allClients = [];
  List<QueryDocumentSnapshot> _filteredClients = [];
  Set<String> _selectedPhones = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('clients').get();
      setState(() {
        _allClients = snap.docs;
        _filteredClients = snap.docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterClients(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredClients = _allClients.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toLowerCase();
        final phone = (data['phone'] ?? '').toLowerCase();
        return name.contains(_searchQuery) || phone.contains(_searchQuery);
      }).toList();
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedPhones.addAll(_filteredClients.map((doc) => doc.id));
      } else {
        _selectedPhones.removeAll(_filteredClients.map((doc) => doc.id));
      }
    });
  }

  void _showDistributionDialog() {
    if (_selectedPhones.isEmpty) return;

    final pointsController = TextEditingController();
    final reasonController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Начисление баллов', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Выбрано клиентов: ${_selectedPhones.length}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: pointsController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  decoration: const InputDecoration(labelText: 'Количество баллов', border: OutlineInputBorder(), prefixIcon: Icon(Icons.stars, color: Colors.orange)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Причина (для истории)', hintText: 'Например: Подарок на Новый Год', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
              isProcessing
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () async {
                        final points = int.tryParse(pointsController.text.trim()) ?? 0;
                        final reason = reasonController.text.trim();

                        if (points == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите количество баллов!')));
                          return;
                        }
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите причину!')));
                          return;
                        }

                        setStateDialog(() => isProcessing = true);

                        try {
                          final db = FirebaseFirestore.instance;
                          WriteBatch batch = db.batch();
                          int opCount = 0;

                          for (String phone in _selectedPhones) {
                            final clientDoc = _allClients.firstWhere((doc) => doc.id == phone);
                            final data = clientDoc.data() as Map<String, dynamic>;
                            final fcmToken = data['fcm_token'] as String?;

                            final clientRef = db.collection('clients').doc(phone);
                            final historyRef = clientRef.collection('bonus_history').doc();

                            batch.update(clientRef, {'bonus_points': FieldValue.increment(points)});
                            batch.set(historyRef, {
                              'amount': points,
                              'description': reason,
                              'created_at': FieldValue.serverTimestamp(),
                            });

                            // 🔥 ВОТ ОН - ВЫЗОВ ПУШ-УВЕДОМЛЕНИЯ 🔥
                            if (fcmToken != null && fcmToken.isNotEmpty) {
                              await FCMService.sendPushNotification(
                                fcmToken,
                                points > 0 ? 'Вам начислен бонус! 🎉' : 'Списание баллов',
                                points > 0 ? 'Мы подарили вам $points баллов. Причина: $reason' : 'С вашего счета списано ${points.abs()} баллов. Причина: $reason',
                                'bonus', 
                              );
                            }

                            opCount += 2;
                            if (opCount >= 490) {
                              await batch.commit();
                              batch = db.batch();
                              opCount = 0;
                            }
                          }
                          if (opCount > 0) await batch.commit();

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Успешно начислено ${_selectedPhones.length} клиентам!'), backgroundColor: Colors.green));
                            setState(() {
                              _selectedPhones.clear();
                            });
                            _loadClients(); 
                          }
                        } catch (e) {
                          setStateDialog(() => isProcessing = false);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                        }
                      },
                      child: const Text('Начислить', style: TextStyle(color: Colors.white)),
                    ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAllSelected = _filteredClients.isNotEmpty && _filteredClients.every((doc) => _selectedPhones.contains(doc.id));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Рассылка баллов', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterClients,
              decoration: InputDecoration(
                labelText: 'Поиск по имени или телефону...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          if (!_isLoading && _filteredClients.isNotEmpty)
            Container(
              color: Colors.white,
              child: CheckboxListTile(
                title: const Text('Выбрать всех в списке', style: TextStyle(fontWeight: FontWeight.bold)),
                value: isAllSelected,
                onChanged: _toggleSelectAll,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.orange[700],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                    ? const Center(child: Text('Клиенты не найдены', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final doc = _filteredClients[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final phone = doc.id;
                          final name = data['name'] ?? 'Без имени';
                          final points = data['bonus_points'] ?? 0;
                          final isSelected = _selectedPhones.contains(phone);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.orange.shade300 : Colors.grey.shade200, width: isSelected ? 2 : 1)),
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPhones.add(phone);
                                  } else {
                                    _selectedPhones.remove(phone);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: Colors.orange[700],
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(phone, style: TextStyle(color: Colors.grey[600])),
                              secondary: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
                                child: Text('$points Б', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange[800])),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedPhones.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showDistributionDialog,
              backgroundColor: Colors.orange[700],
              icon: const Icon(Icons.send, color: Colors.white),
              label: Text('Начислить (${_selectedPhones.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
