import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String _resultMessage = '';
  String? _directVideoUrl;

  // آدرس سرور اختصاصی شما در هاگینگ‌فیس
  final String _apiUrl = 'https://muhamadjafari-video-downloader-api.hf.space/download';

  Future<void> _extractVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _resultMessage = 'لطفاً یک لینک معتبر وارد کنید.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = 'در حال ارتباط با سرور اختصاصی...';
      _directVideoUrl = null;
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          setState(() {
            _directVideoUrl = data['url'];
            _resultMessage = 'عنوان: ${data['title']}\nفرمت: ${data['ext']}';
          });
        } else {
          setState(() {
            _resultMessage = 'خطا از سرور: ${data['error']}';
          });
        }
      } else {
        setState(() {
          _resultMessage = 'خطا در برقراری ارتباط با سرور (کد: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _resultMessage = 'خطای اتصال: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دانلودر اختصاصی ویدیو'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'لینک ویدیو (یوتیوب، اینستاگرام و...)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _extractVideo,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('دریافت لینک مستقیم', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            Text(
              _resultMessage,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (_directVideoUrl != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  // اینجا می‌توانید لینک مستقیم را به پکیج دانلود بدهید یا کپی کنید
                  print("لینک مستقیم برای دانلود: $_directVideoUrl");
                },
                icon: const Icon(Icons.download),
                label: const Text('آماده برای دانلود فایل'),
              ),
          ],
        ),
      ),
    );
  }
}
