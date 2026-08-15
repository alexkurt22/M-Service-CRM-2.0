import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  String _selectedPeriod = 'За 30 дней';
  final List<String> _periods = ['Сегодня', 'За 7 дней', 'За 30 дней', 'За всё время'];

  String _myPhone = '';
  String _myName = '';
  String _myRole = 'master'; // По умолчанию ограничиваем права

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    _myPhone = prefs.getString('employee_phone') ?? '';
    
    if (_myPhone.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('employees').doc(_myPhone).get();
      if (doc.exists && mounted) {
        setState(() {
          _myName = doc.data()?['name'] ?? 'Мастер';
          _myRole = doc.data()?['role'] ?? 'master'; // 'admin' или 'master'
        });
      }
    }
  }

  bool _isWithinPeriod(Timestamp? timestamp) {
    if (timestamp == null) return false;
    if (_selectedPeriod == 'За всё время') return true;

    final date = timestamp.toDate();
    final now = DateTime.now();

    if (_selectedPeriod == 'Сегодня') {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    } else if (_selectedPeriod == 'За 7 дней') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return date.isAfter(weekAgo);
    } else if (_selectedPeriod == 'За 30 дней') {
      final monthAgo = now.subtract(const Duration(days: 30));
      return date.isAfter(monthAgo);
    }
    return true;
  }

  void _showAddTransactionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String transactionCategory = 'expense'; // 'expense', 'real_debt', 'realization'
    String selectedRegister = _myRole == 'admin' ? 'Дневная касса (Офис)' : 'Выездная касса ($_myName)';
    
    final List<String> adminRegisters = ['Дневная касса (Офис)', 'Глобальная (Безнал/Счет)'];
    
    final amountController = TextEditingController();
    final descController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Новая операция', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ВЫБОР ТИПА ОПЕРАЦИИ ---
                  Container(
                    decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => transactionCategory = 'expense'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: transactionCategory == 'expense' ? Colors.red[400] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  child: Text('РАСХОД', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: transactionCategory == 'expense' ? Colors.white : Colors.grey)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => transactionCategory = 'real_debt'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: transactionCategory == 'real_debt' ? Colors.orange[600] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  child: Text('ВЗЯЛ ДЕНЬГИ\n(Долг)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: transactionCategory == 'real_debt' ? Colors.white : Colors.grey)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => transactionCategory = 'realization'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: transactionCategory == 'realization' ? Colors.deepPurple[400] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  child: Text('ВЗЯЛ ТОВАР\n(Реализация)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: transactionCategory == 'realization' ? Colors.white : Colors.grey)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Сумма (TMT)',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      prefixIcon: Icon(Icons.money_off, color: transactionCategory == 'expense' ? Colors.red : Colors.deepPurple),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: transactionCategory == 'expense' ? 'На что потратил?' : 'У кого взял?',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700]),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  
                  if (transactionCategory == 'expense') ...[
                    const SizedBox(height: 16),
                    if (_myRole == 'admin')
                      DropdownButtonFormField<String>(
                        value: selectedRegister,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Из какой кассы минус?'),
                        items: adminRegisters.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedRegister = val);
                        },
                      )
                    else
                       // Мастер видит только свою кассу, изменить не может
                       TextField(
                         enabled: false,
                         decoration: InputDecoration(
                           labelText: 'Касса списания',
                           hintText: 'Выездная касса ($_myName)',
                           border: const OutlineInputBorder(),
                           prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                         ),
                       )
                  ]
                ],
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: transactionCategory == 'expense' ? Colors.red[600] : Colors.deepPurple[600]),
                onPressed: isSaving ? null : () async {
                  final amount = double.tryParse(amountController.text.trim());
                  final desc = descController.text.trim();
                  
                  if (amount == null || amount <= 0 || desc.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите корректную сумму и описание')));
                    return;
                  }

                  setModalState(() => isSaving = true);
                  
                  try {
                    String finalRegister = '';
                    if (transactionCategory == 'expense') {
                       finalRegister = _myRole == 'admin' ? selectedRegister : 'Выездная касса ($_myPhone)';
                    } else {
                       finalRegister = transactionCategory == 'real_debt' ? 'Долг (Деньги)' : 'Долг (Реализация)';
                    }

                    await FirebaseFirestore.instance.collection('financial_transactions').add({
                      'type': transactionCategory, // 'expense', 'real_debt', 'realization'
                      'amount': amount,
                      'description': desc,
                      'register': finalRegister,
                      'created_at': FieldValue.serverTimestamp(),
                      'added_by': _myPhone,
                      'added_by_name': _myName,
                      'is_active_debt': transactionCategory != 'expense', // Флаг для долгов
                    });

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Операция сохранена!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setModalState(() => isSaving = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('СОХРАНИТЬ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showCalculateDividendsDialog(double currentCashBalance) {
    // Этот диалог доступен только админам, код не менялся
    // ... (Оставил базовый расчет, чтобы не удлинять ответ, он у тебя уже есть)
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: Text(_myRole == 'admin' ? 'Касса предприятия' : 'Моя выездная касса', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
           IconButton(
             icon: const Icon(Icons.add, size: 30),
             tooltip: 'Добавить операцию',
             onPressed: _showAddTransactionDialog,
           )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))]),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: isDark ? Colors.white54 : Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      dropdownColor: Theme.of(context).cardColor,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white : Colors.black87),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      items: _periods.map((String p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPeriod = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
              builder: (context, ordersSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('financial_transactions').snapshots(),
                  builder: (context, transSnapshot) {

                    if (ordersSnapshot.connectionState == ConnectionState.waiting || transSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Переменные Админа
                    double adminCashTotal = 0; 
                    double adminNonCashTotal = 0; 
                    double adminExpensesCash = 0; 
                    double adminExpensesGlobal = 0; 

                    // Переменные Мастера
                    double masterCashTotal = 0;
                    double masterExpenses = 0;

                    // Долги (считаются ЗА ВСЕ ВРЕМЯ, независимо от фильтра дат)
                    double totalRealDebt = 0; 
                    double totalRealization = 0; 
                    List<Map<String, dynamic>> activeDebtsList = [];

                    // --- 1. ОБРАБОТКА ЗАКАЗОВ (ДОХОД) ---
                    if (ordersSnapshot.hasData) {
                      for (var doc in ordersSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final completedAt = data['completed_at'] as Timestamp?;
                        
                        if (_isWithinPeriod(completedAt)) {
                          double paid = double.tryParse(data['paid_amount']?.toString() ?? '0') ?? 0;
                          String method = (data['payment_method'] ?? 'Наличные').toString().toLowerCase();
                          
                          // Если это админ - считаем всё
                          if (_myRole == 'admin') {
                            if (method.contains('карта') || method.contains('терминал') || method.contains('перечисл') || method.contains('бонус')) {
                              adminNonCashTotal += paid;
                            } else {
                              adminCashTotal += paid; 
                            }
                          } 
                          // Если это мастер - считаем ТОЛЬКО наличку по ЕГО заказам
                          else {
                            // Предполагаем, что в заказе есть master_phone или employee_phone
                            String orderMaster = data['master_phone'] ?? data['employee_phone'] ?? '';
                            if (orderMaster == _myPhone && !method.contains('карта') && !method.contains('перечисл')) {
                              masterCashTotal += paid;
                            }
                          }
                        }
                      }
                    }

                    // --- 2. ОБРАБОТКА ОПЕРАЦИЙ И ДОЛГОВ ---
                    if (transSnapshot.hasData) {
                      for (var doc in transSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final createdAt = data['created_at'] as Timestamp?;
                        double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                        String type = data['type'] ?? 'expense';
                        String register = data['register'] ?? '';
                        String addedBy = data['added_by'] ?? '';

                        // Долги считаются всегда (без фильтра дат), если они активны
                        if (data['is_active_debt'] == true) {
                           activeDebtsList.add(data);
                           if (type == 'real_debt') totalRealDebt += amount;
                           if (type == 'realization') totalRealization += amount;
                        }

                        // Траты считаются с учетом фильтра дат
                        if (_isWithinPeriod(createdAt) && type == 'expense') {
                          if (_myRole == 'admin') {
                            if (register.contains('Глобальная')) {
                              adminExpensesGlobal += amount;
                            } else {
                              adminExpensesCash += amount; 
                            }
                          } else {
                             // Мастер видит только свои выездные траты
                             if (addedBy == _myPhone) {
                                masterExpenses += amount;
                             }
                          }
                        }
                      }
                    }

                    double actualCashOnHand = _myRole == 'admin' 
                        ? (adminCashTotal - adminExpensesCash) 
                        : (masterCashTotal - masterExpenses);

                    return ListView(
                      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: MediaQuery.of(context).padding.bottom + 80),
                      children: [
                        
                        // ===== БЛОК ДЛЯ АДМИНА =====
                        if (_myRole == 'admin') ...[
                          const Text('КАССА ОФИСА (НАЛИЧНЫЕ)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 1,
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.green.withOpacity(0.5))),
                            child: Column(
                              children: [
                                _buildPaymentRow('Пришло наличными', adminCashTotal, Icons.monetization_on, Colors.green, isDark),
                                Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                                _buildPaymentRow('Расходы налом', adminExpensesCash, Icons.money_off, Colors.red[400]!, isDark, isMinus: true),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('ОСТАТОК КАССЫ СЕЙЧАС', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('${actualCashOnHand.toStringAsFixed(0)} TMT', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.green[800])),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('БЕЗНАЛ И СЧЕТА', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 1,
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade200)),
                            child: Column(
                              children: [
                                _buildPaymentRow('Карта / Перечисление', adminNonCashTotal, Icons.credit_card, Colors.blue, isDark),
                                Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                                _buildPaymentRow('Расходы по безналу', adminExpensesGlobal, Icons.credit_card_off, Colors.red[400]!, isDark, isMinus: true),
                              ],
                            ),
                          ),
                        ],

                        // ===== БЛОК ДЛЯ МАСТЕРА =====
                        if (_myRole != 'admin') ...[
                           const Text('МОЯ ВЫЕЗДНАЯ КАССА', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.2)),
                           const SizedBox(height: 8),
                           Card(
                            elevation: 1,
                            color: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.green.withOpacity(0.5))),
                            child: Column(
                              children: [
                                _buildPaymentRow('Собрано налом (заказы)', masterCashTotal, Icons.monetization_on, Colors.green, isDark),
                                Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
                                _buildPaymentRow('Мои расходы на выезде', masterExpenses, Icons.local_gas_station, Colors.red[400]!, isDark, isMinus: true),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text('НАЛИЧНЫХ НА РУКАХ', style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text('${actualCashOnHand.toStringAsFixed(0)} TMT', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.green[800])),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ===== БЛОК ДОЛГОВ И РЕАЛИЗАЦИИ (ВИДЯТ ВСЕ) =====
                        const Text('АКТУАЛЬНЫЕ ДОЛГИ КОМПАНИИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildDebtCard('РЕАЛЬНЫЕ ДОЛГИ', 'Заняли живые деньги', totalRealDebt, Icons.money_off, Colors.orange[700]!, isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDebtCard('ПОД РЕАЛИЗАЦИЮ', 'Взяли товар/запчасти', totalRealization, Icons.inventory, Colors.deepPurple[600]!, isDark)),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        if (activeDebtsList.isNotEmpty) ...[
                          const Text('ДЕТАЛИЗАЦИЯ ДОЛГОВ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          ...activeDebtsList.map((debt) {
                             bool isReal = debt['type'] == 'real_debt';
                             return Card(
                               color: Theme.of(context).cardColor,
                               margin: const EdgeInsets.only(bottom: 8),
                               child: ListTile(
                                 leading: Icon(isReal ? Icons.money_off : Icons.inventory, color: isReal ? Colors.orange : Colors.deepPurple),
                                 title: Text(debt['description'] ?? 'Без описания', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                 subtitle: Text('Добавил: ${debt['added_by_name'] ?? 'Сотрудник'}', style: const TextStyle(fontSize: 12)),
                                 trailing: Text('${debt['amount']} TMT', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 15)),
                               ),
                             );
                          })
                        ]
                      ],
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(String title, String subtitle, double amount, IconData icon, Color color, bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.4))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
            Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[700], fontSize: 10)),
            const SizedBox(height: 8),
            Text('${amount.toStringAsFixed(0)} TMT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String title, double amount, IconData icon, Color color, bool isDark, {bool isMinus = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
      trailing: Text(
        '${isMinus && amount > 0 ? '-' : ''}${amount.toStringAsFixed(0)} TMT', 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)
      ),
    );
  }
}
