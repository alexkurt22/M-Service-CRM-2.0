import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; 

class OfflineOrderScreen extends StatefulWidget {
  const OfflineOrderScreen({super.key});

  @override
  State<OfflineOrderScreen> createState() => _OfflineOrderScreenState();
}

class _OfflineOrderScreenState extends State<OfflineOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();

  bool _isLoading = false; 

  // Переменные для умного поиска клиента по номеру
  List<DocumentSnapshot> _suggestedClients = [];
  bool _isSearchingClient = false;
  bool _isClientSelectedFromDb = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  // Поиск клиентов по базе на лету при вводе телефона
  Future<void> _onPhoneChanged(String value) async {
    if (_isClientSelectedFromDb) return; 

    final cleanVal = value.trim();
    if (cleanVal.length < 3) {
      setState(() => _suggestedClients = []);
      return;
    }

    setState(() => _isSearchingClient = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .orderBy('phone')
          .startAt(['+993$cleanVal'])
          .endAt(['+993$cleanVal\uf8ff'])
          .limit(5)
          .get();

      setState(() {
        _suggestedClients = querySnapshot.docs;
        _isSearchingClient = false;
      });
    } catch (e) {
      setState(() => _isSearchingClient = false);
    }
  }

  // Выбор клиента из подсказок
  void _selectClient(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final fullPhone = data['phone'] ?? '';
    final shortPhone = fullPhone.startsWith('+993') ? fullPhone.substring(4) : fullPhone;

    setState(() {
      _phoneController.text = shortPhone;
      _nameController.text = data['name'] ?? '';
      _isClientSelectedFromDb = true; // Блокируем поле имени
      _suggestedClients = [];
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    String finalPhone = '+993${_phoneController.text.trim()}';
    String clientName = _nameController.text.trim();
    String problemDesc = _issueController.text.trim();

    try {
      // 1. Создаем сам заказ
      await FirebaseFirestore.instance.collection('orders').add({
        'client_name': clientName,
        'phone': finalPhone, 
        'device_type': 'Оффлайн заказ', 
        'problem': problemDesc, 
        'status': 'new', 
        'created_at': FieldValue.serverTimestamp(),
        'source': 'Оффлайн',
        'is_offline': true, 
      });

      // 2. Проверяем, есть ли такой клиент в базе (если вводили вручную)
      final clientQuery = await FirebaseFirestore.instance
          .collection('clients')
          .where('phone', isEqualTo: finalPhone)
          .get();
      
      if (clientQuery.docs.isEmpty) {
         // Клиент новый - создаем
         await FirebaseFirestore.instance.collection('clients').doc(finalPhone).set({
            'name': clientName,
            'phone': finalPhone,
            'is_approved': true, 
            'is_offline': true,
            'created_at': FieldValue.serverTimestamp(),
            'source': 'Оффлайн',
         });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оффлайн-заказ успешно создан!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
          );
       }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Новый оффлайн-заказ', style: TextStyle(fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).padding.bottom + 24.0, 
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. НОМЕР ТЕЛЕФОНА ---
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 8,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, 
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          String text = newValue.text;
                          if (text.startsWith('993') && text.length > 3) {
                            text = text.substring(3);
                          } else if (text.startsWith('8') && text.length > 1) {
                            text = text.substring(1);
                          }
                          if (text.length > 8) {
                            text = text.substring(text.length - 8);
                          }
                          return TextEditingValue(
                            text: text,
                            selection: TextSelection.collapsed(offset: text.length),
                          );
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Номер телефона',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                        prefixText: '+993 ', 
                        prefixStyle: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                        prefixIcon: Icon(Icons.phone, color: isDark ? Colors.white54 : Colors.blueGrey),
                        suffixIcon: _isClientSelectedFromDb 
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _isClientSelectedFromDb = false;
                                    _nameController.clear();
                                    _phoneController.clear();
                                  });
                                },
                                tooltip: 'Сбросить выбор клиента',
                              )
                            : (_isSearchingClient ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.white,
                        counterText: "", 
                      ),
                      onChanged: _onPhoneChanged,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Введите номер телефона';
                        if (val.length != 8) return 'Введите ровно 8 цифр (без +993)';
                        
                        final validCodes = ['60', '61', '62', '63', '64', '65', '71', '72'];
                        final code = val.substring(0, 2);
                        if (!validCodes.contains(code)) {
                          return 'Неверный код оператора (доступны: 60-65, 71, 72)';
                        }
                        return null;
                      },
                    ),

                    // ВЫПАДАЮЩИЙ СПИСОК ПОДСКАЗОК
                    if (_suggestedClients.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.blueGrey.shade200),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestedClients.length,
                          itemBuilder: (context, index) {
                            final doc = _suggestedClients[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Без имени';
                            final phone = data['phone'] ?? '';

                            return ListTile(
                              leading: const Icon(Icons.person_pin, color: Colors.blue),
                              title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                              subtitle: Text(phone, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                              trailing: const Text('Выбрать', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              onTap: () => _selectClient(doc),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // --- 2. ИМЯ КЛИЕНТА (БЛОКИРУЕТСЯ, ЕСЛИ ИЗ БАЗЫ) ---
                    TextFormField(
                      controller: _nameController,
                      readOnly: _isClientSelectedFromDb, // Строгая блокировка
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Имя клиента',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                        prefixIcon: Icon(Icons.person, color: isDark ? Colors.white54 : Colors.blueGrey),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: _isClientSelectedFromDb 
                            ? (isDark ? Colors.grey[900] : Colors.grey[200]) // Серый фон для заблокированного поля
                            : (isDark ? Colors.grey[800] : Colors.white),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите имя' : null,
                    ),
                    
                    const SizedBox(height: 32),

                    // --- 3. ОПИСАНИЕ ---
                    TextFormField(
                      controller: _issueController,
                      maxLines: 5,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Описание',
                        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.white,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Введите описание' : null,
                    ),

                    const SizedBox(height: 40),
                    
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.orange[700] : Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitOrder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('ОФОРМИТЬ ЗАКАЗ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

