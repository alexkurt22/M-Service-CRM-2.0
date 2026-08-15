import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _isWaitingForApproval = false; // Режим ожидания модерации

  // ❗ ВПИШИ СЮДА СВОЙ НОМЕР ТЕЛЕФОНА ДЛЯ ПОЛУЧЕНИЯ SMS ОТ СОТРУДНИКОВ ❗
  final String ownerPhone = '+99363644925'; 

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = '+993${_phoneController.text.trim()}';
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance.collection('employees').doc(phone).get();
      
      if (_isRegistering) {
        if (_passController.text != _confirmPassController.text) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароли не совпадают'), backgroundColor: Colors.red));
          setState(() => _isLoading = false); 
          return;
        }
        if (doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Этот номер уже зарегистрирован. Выполните вход.'), backgroundColor: Colors.orange));
          setState(() => _isLoading = false); 
          return;
        }
        
        // 1. Генерируем 6-значный код
        String code = (Random().nextInt(900000) + 100000).toString();

        // 2. Регистрируем в базу со статусом Ожидания
        await FirebaseFirestore.instance.collection('employees').doc(phone).set({
          'name': _nameController.text.trim(),
          'phone': phone,
          'password': _passController.text.trim(), 
          'is_approved': false,
          'role': 'waiting', // Роль пока не назначена
          'verification_code': code, // Сохраняем код для сверки
          'created_at': FieldValue.serverTimestamp(),
        });
        
        // 3. Открываем нативное SMS приложение с готовым текстом
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: ownerPhone,
          queryParameters: <String, String>{
            'body': 'Регистрация сотрудника M-Service.\nИмя: ${_nameController.text.trim()}\nКод: $code',
          },
        );
        
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        } else {
          debugPrint('Не удалось открыть приложение SMS');
        }

        // 4. Переводим экран в режим ожидания
        setState(() {
          _isRegistering = false;
          _isWaitingForApproval = true;
        });

      } else {
        // --- ЛОГИКА ВХОДА ---
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сотрудник не найден. Подайте заявку на регистрацию.'), backgroundColor: Colors.red));
        } else if (doc.data()?['password'] != _passController.text.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Неверный пароль'), backgroundColor: Colors.red));
        } else if (doc.data()?['is_approved'] == false) {
          // Если пароль верный, но владелец еще не одобрил
          setState(() => _isWaitingForApproval = true);
        } else {
          // Успешный вход
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('employee_phone', phone);
          
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: Text(_isRegistering ? 'Регистрация сотрудника' : 'Вход в CRM'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isWaitingForApproval ? _buildWaitingScreen() : _buildAuthForm(),
        ),
      ),
    );
  }

  // Экран ожидания (когда заявка улетела, но ты еще не нажал "Одобрить")
  Widget _buildWaitingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.hourglass_empty, size: 80, color: Colors.orange[600]),
        const SizedBox(height: 24),
        const Text(
          'Заявка на рассмотрении',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ваши данные отправлены Владельцу.\nОжидайте, пока вам назначат права доступа.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.blueGrey),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => setState(() {
            _isWaitingForApproval = false; // Позволяет вернуться на форму входа
            _passController.clear();
          }),
          child: const Text('Вернуться на экран входа'),
        )
      ],
    );
  }

  // Экран Входа / Регистрации
  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.admin_panel_settings, size: 64, color: Colors.blueGrey[900]),
          const SizedBox(height: 24),
          
          if (_isRegistering) ...[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Ваше Имя', prefixIcon: Icon(Icons.person), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              validator: (val) => val == null || val.isEmpty ? 'Введите имя' : null,
            ),
            const SizedBox(height: 16),
          ],
          
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Номер телефона',
              prefixText: '+993 ',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              counterText: "",
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Введите номер';
              if (val.length != 8) return 'Введите 8 цифр';
              final validCodes = ['61', '62', '63', '64', '65', '71'];
              if (!validCodes.contains(val.substring(0, 2))) return 'Неверный код оператора';
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _passController,
            decoration: const InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            obscureText: true,
            validator: (val) => val == null || val.length < 6 ? 'Минимум 6 символов' : null,
          ),
          
          if (_isRegistering) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPassController,
              decoration: const InputDecoration(labelText: 'Подтвердите пароль', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              obscureText: true,
            ),
          ],
          
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _isLoading ? null : _handleAuth,
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isRegistering ? 'ОТПРАВИТЬ ЗАЯВКУ И СМС' : 'ВОЙТИ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _isRegistering = !_isRegistering;
              _formKey.currentState?.reset();
            }),
            child: Text(_isRegistering ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Подать заявку', style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
