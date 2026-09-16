import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  runApp(const PCRemoteApp());
}

class PCRemoteApp extends StatelessWidget {
  const PCRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PC Remote',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const RemoteHomeScreen(),
    );
  }
}

class RemoteHomeScreen extends StatefulWidget {
  const RemoteHomeScreen({super.key});

  @override
  State<RemoteHomeScreen> createState() => _RemoteHomeScreenState();
}

class _RemoteHomeScreenState extends State<RemoteHomeScreen> {
  final TextEditingController ipController = TextEditingController(text: '192.168.1.11');
  final TextEditingController macController = TextEditingController(text: 'F0-79-59-5D-1A-85');
  final TextEditingController textController = TextEditingController();

  String statusMessage = '';

  void _showStatus(String msg) {
    setState(() {
      statusMessage = msg;
    });
  }

  // إرسال الأوامر للسيرفر عبر TCP Socket
  Future<void> _sendCommand(Map<String, dynamic> command) async {
    final String ip = ipController.text.trim();
    if (ip.isEmpty) {
      _showStatus("خطأ: يرجى كتابة عنوان IP");
      return;
    }

    try {
      final socket = await Socket.connect(ip, 65432, timeout: const Duration(seconds: 3));
      socket.write(jsonEncode(command));
      await socket.flush();
      await socket.close();
      _showStatus("تم إرسال الأمر بنجاح!");
    } catch (e) {
      _showStatus("خطأ في الاتصال بالسيرفر: $e");
    }
  }

  // إرسال حزمة Wake-on-LAN لتشغيل الكمبيوتر
  void _sendWOL() async {
    try {
      String mac = macController.text.replaceAll(':', '').replaceAll('-', '').trim();
      if (mac.length != 12) {
        _showStatus("خطأ: عنوان MAC غير صحيح");
        return;
      }

      List<int> macBytes = [];
      for (int i = 0; i < 12; i += 2) {
        macBytes.add(int.parse(mac.substring(i, i + 2), radix: 16));
      }

      // إنشاء Magic Packet باستخدام قائمة قابلة للتوسع تجنباً للـ Unsupported Operation Error
      List<int> packet = List<int>.filled(6, 0xFF, growable: true);
      for (int i = 0; i < 16; i++) {
        packet.addAll(macBytes);
      }

      RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(packet, InternetAddress('255.255.255.255'), 9);
      socket.close();

      _showStatus("تم إرسال أمر Wake-on-LAN بنجاح!");
    } catch (e) {
      _showStatus("خطأ في إرسال WOL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحكم في الكمبيوتر'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: macController,
              decoration: const InputDecoration(
                labelText: 'MAC Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.green[800],
              ),
              onPressed: _sendWOL,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('تشغيل الكمبيوتر (Wake-on-LAN)'),
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                    onPressed: () => _sendCommand({"type": "power", "action": "shutdown"}),
                    child: const Text('إطفاء'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand({"type": "power", "action": "restart"}),
                    child: const Text('إعادة تشغيل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendCommand({"type": "power", "action": "sleep"}),
                    child: const Text('Sleep'),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'نص لإرساله للكمبيوتر (Clipboard)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  _sendCommand({
                    "type": "clipboard",
                    "text": textController.text,
                  });
                }
              },
              child: const Text('إرسال النص'),
            ),
            if (statusMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                color: Colors.white10,
                child: Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.orangeAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
