import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  
  /// Умная отправка пуша для ВСЕЙ системы.
  /// Читает единый ключ из ассетов (от GitHub Actions) и проверяет галочки настроек.
  static Future<void> sendPushNotification(String token, String title, String body, [String? reviewType]) async {
    if (token.isEmpty) return;

    try {
      // 1. Проверяем галочки в настройках Админки (Отправлять или нет?)
      if (reviewType != null) {
        final pushConfig = await FirebaseFirestore.instance.collection('settings').doc('notifications').get();
        if (pushConfig.exists && pushConfig.data() != null) {
          final data = pushConfig.data()!;
          
          if (reviewType == 'negotiation' && data['push_on_negotiation'] == false) {
            print('🔕 Пуш (Согласование) отключен в настройках. Отмена.');
            return;
          }
          if (reviewType == 'bonus' && data['push_on_bonus'] == false) {
            print('🔕 Пуш (Бонусы) отключен в настройках. Отмена.');
            return;
          }
          if (reviewType == 'chat' && data['push_on_chat'] == false) {
            print('🔕 Пуш (Чат) отключен в настройках. Отмена.');
            return;
          }
        }
      }

      // 2. Читаем ЕДИНЫЙ ключ, который нам любезно положил GitHub Actions
      final jsonString = await rootBundle.loadString('assets/firebase_credentials.json');
      final Map<String, dynamic> account = jsonDecode(jsonString);

      // 🔥 ВОТ ОН, ФИКС ОШИБКИ 400! 
      // Принудительно восстанавливаем переносы строк в ключе, чтобы подпись совпала!
      account['private_key'] = (account['private_key'] as String).replaceAll(r'\n', '\n');

      final credentials = auth.ServiceAccountCredentials.fromJson(account);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await auth.clientViaServiceAccount(credentials, scopes);

      final String projectId = account['project_id'];
      final String url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      final Map<String, dynamic> payload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
        },
      };

      final response = await authClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        print('❌ Ошибка FCM (Код ${response.statusCode}): ${response.body}');
      } else {
        print('✅ Универсальный Push успешно отправлен!');
      }
      authClient.close();
    } catch (e) {
      print('❌ Сбой отправки пуша: $e');
    }
  }
}
