import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsManagementScreen extends StatelessWidget {
  const ReviewsManagementScreen({super.key});

  void _approveReview(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('reviews').doc(docId).update({
      'is_approved': true,
      'needs_edit': FieldValue.delete(),
      'admin_message': FieldValue.delete(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отзыв опубликован!'), backgroundColor: Colors.green));
    }
  }

  void _deleteReview(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Точно удалить этот отзыв навсегда?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('reviews').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отзыв удален.')));
      }
    }
  }

  Widget _buildReviewsList(bool isApproved) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reviews')
          .where('is_approved', isEqualTo: isApproved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isApproved ? Icons.verified : Icons.hourglass_empty, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(isApproved ? 'Нет опубликованных отзывов' : 'Новых отзывов нет', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final rating = data['rating'] ?? 5;
            final text = data['text'] ?? '';
            final author = data['author_name'] ?? 'Клиент';
            final device = data['device_type'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isApproved ? Colors.green.shade200 : Colors.blue.shade200, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.orange, size: 20))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(device, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 24),
                    
                    Text(
                      text.isEmpty ? 'Пользователь не оставил комментарий, только оценку.' : text, 
                      style: TextStyle(fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal, color: text.isEmpty ? Colors.grey : Colors.black87, fontSize: 15)
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _deleteReview(context, doc.id),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Удалить',
                        ),
                        if (!isApproved) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
                            onPressed: () => _approveReview(context, doc.id),
                            icon: const Icon(Icons.check),
                            label: const Text('Одобрить'),
                          )
                        ]
                      ],
                    )
                  ],
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          title: const Text('Отзывы клиентов', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: 'На проверке'),
              Tab(text: 'Опубликованы'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReviewsList(false), 
            _buildReviewsList(true), 
          ],
        ),
      ),
    );
  }
}
