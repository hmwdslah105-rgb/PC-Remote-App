import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  runApp(const PcRemoteApp());
}

class PcRemoteApp extends StatelessWidget {
  const PcRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PC Controller',
      theme: ThemeData.dark(),
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
  // البيانات الخاصة بجهازك تم إدراجها كافتراضية
  final TextEditingController ipController = TextEditingController(text: "192.168.1.11");
  final TextEditingController macController = TextEditingController(text: "F0-79-59-5D-1A-85");
  final TextEditingController textController = TextEditingController();

  Future<void> sendCommand(Map<String, dynamic> command) async {
    try {
      final socket = await Socket.connect(ipController.text, 65432, timeout: const Duration(seconds: 2));
      socket.write(jsonEncode(command));
      await socket.close();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال بالسيرفر: $e')),
      );
    }
  }

  Future<void> sendWakeOnLan() async {
    try {
      String mac = macController.text.replaceAll(':', '').replaceAll('-', '');
      List<int> bytes = List.filled(6, 0xFF);
      List<int> macBytes = [];
      for (int i = 0; i < mac.length; i += 2) {
        macBytes.add(int.parse(mac.substring(i, i + 2), radix: 16));
      }
      for (int i = 0; i < 16; i++) {
        bytes.addAll(macBytes);
      }

      RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(bytes, InternetAddress('255.255.255.255'), 9);
      socket.close();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال أمر التشغيل (Magic Packet)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحكم في الكمبيوتر')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: ipController, decoration: const InputDecoration(labelText: 'IP Address')),
            TextField(controller: macController, decoration: const InputDecoration(labelText: 'MAC Address')),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: sendWakeOnLan,
              icon: const Icon(Icons.power_settings_new, color: Colors.green),
              label: const Text('تشغيل الكمبيوتر (Wake-on-LAN)'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => sendCommand({'type': 'power', 'action': 'shutdown'}),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('إطفاء'),
                ),
                ElevatedButton(
                  onPressed: () => sendCommand({'type': 'power', 'action': 'restart'}),
                  child: const Text('إعادة تشغيل'),
                ),
                ElevatedButton(
                  onPressed: () => sendCommand({'type': 'power', 'action': 'sleep'}),
                  child: const Text('Sleep'),
                ),
              ],
            ),
            const Divider(height: 30),
            TextField(
              controller: textController,
              decoration: const InputDecoration(labelText: 'نص لإرساله للكمبيوتر (Clipboard)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                sendCommand({'type': 'clipboard', 'text': textController.text});
                textController.clear();
              },
              child: const Text('إرسال النص'),
            ),
          ],
        ),
      ),
    );
  }
}