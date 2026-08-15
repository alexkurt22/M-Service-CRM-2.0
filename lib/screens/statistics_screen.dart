import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cash_register_screen.dart'; // Импорт нового экрана кассы

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'За 30 дней';
  final List<String> _periods = ['Сегодня', 'За 7 дней', 'За 30 дней', 'За всё время'];

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[900],
        foregroundColor: Colors.white,
        title: const Text('Бизнес Статистика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              icon: const Icon(Icons.account_balance_wallet, size: 18),
              label: const Text('КАССА', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CashRegisterScreen()));
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
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
                if (ordersSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                double totalRevenue = 0;
                double totalPaid = 0; 
                double totalDebt = 0;
                int ordersCount = 0;

                if (ordersSnapshot.hasData) {
                  for (var doc in ordersSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final completedAt = data['completed_at'] as Timestamp?;
                    
                    if (_isWithinPeriod(completedAt)) {
                      ordersCount++;
                      double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
                      double paid = double.tryParse(data['paid_amount']?.toString() ?? price.toString()) ?? 0;
                      double debt = double.tryParse(data['debt_amount']?.toString() ?? '0') ?? 0;

                      totalRevenue += price;
                      totalPaid += paid;
                      totalDebt += debt;
                    }
                  }
                }

                double averageCheck = ordersCount > 0 ? (totalRevenue / ordersCount) : 0;

                return ListView(
                  padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: MediaQuery.of(context).padding.bottom + 80),
                  children: [
                    const Text('ПРОДАЖИ И ЗАКАЗЫ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    _buildMetricCard(title: 'ОБЩАЯ ВЫРУЧКА', amount: totalRevenue, icon: Icons.insights, color: Colors.blueAccent, isDark: isDark, isLarge: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard(title: 'Выполнено заказов', amount: ordersCount.toDouble(), icon: Icons.check_circle, color: Colors.teal, isDark: isDark, isCurrency: false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard(title: 'Средний чек', amount: averageCheck, icon: Icons.receipt_long, color: Colors.indigo, isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('ДВИЖЕНИЕ СРЕДСТВ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard(title: 'ФАКТ. ОПЛАЧЕНО', amount: totalPaid, icon: Icons.account_balance_wallet, color: Colors.green, isDark: isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard(title: 'ДОЛГИ КЛИЕНТОВ', amount: totalDebt, icon: Icons.warning_amber_rounded, color: Colors.orange, isDark: isDark)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String title, required double amount, required IconData icon, required Color color, required bool isDark, bool isLarge = false, bool isCurrency = true}) {
    return Card(
      elevation: isLarge ? 2 : 1,
      color: isLarge ? (isDark ? color.withOpacity(0.2) : color.withOpacity(0.1)) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isLarge ? color.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.grey.shade200))),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isDark && !isLarge ? color.withOpacity(0.8) : color, size: isLarge ? 28 : 20),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: isLarge ? 14 : 12))),
              ],
            ),
            SizedBox(height: isLarge ? 12 : 8),
            Text(
              '${amount.toStringAsFixed(0)} ${isCurrency ? 'TMT' : 'шт'}', 
              style: TextStyle(fontSize: isLarge ? 32 : 22, fontWeight: FontWeight.w900, color: isLarge ? (isDark ? Colors.white : color) : (isDark ? Colors.white : Colors.black87))
            ),
          ],
        ),
      ),
    );
  }
}
