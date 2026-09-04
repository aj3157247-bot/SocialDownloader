import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

// مدل داده‌ای تبلیغات
class AdModel {
  String id;
  String title;
  int duration; // ثانیه
  bool isActive;

  AdModel({
    required this.id,
    required this.title,
    required this.duration,
    this.isActive = true,
  });
}

// لیست سراسری تبلیغات (مدیریت شده توسط ادمین)
List<AdModel> globalAds = [
  AdModel(id: '1', title: 'تبلیغ اول: معرفی کانال تلگرام ما', duration: 5, isActive: true),
  AdModel(id: '2', title: 'تبلیغ دوم: تخفیف ویژه سرویس‌ها', duration: 5, isActive: true),
];

void main() {
  runApp(const SocialDownloaderApp());
}

class SocialDownloaderApp extends StatelessWidget {
  const SocialDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Downloader Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDownloadPage(context),
      const AdminLoginScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'دانلودر هوشمند سوشال مدیا' : 'پنل مدیریت ادمین'),
        centerTitle: true,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'دانلود',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'مدیریت ادمین',
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'لینک ویدیو (تیک‌تاک، یوتیوب، اینستاگرام، فیسبوک) را وارد کنید:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: 'https://...',
              hintTextDirection: TextDirection.ltr,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 20),
          _isDownloading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: () {
                    if (_urlController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لطفاً یک لینک معتبر وارد کنید')),
                      );
                      return;
                    }
                    _playAdsAndDownload(context, _urlController.text.trim());
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('شروع دانلود و ذخیره در گالری'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              if (_urlController.text.isNotEmpty) {
                Share.share('Check out this video: ${_urlController.text}');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لینکی برای اشتراک‌گذاری وجود ندارد')),
                );
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('اشتراک‌گذاری'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _extractValidUrl(String rawText) {
    String text = rawText.trim();
    // پاکسازی متن‌های اضافی احتمالی اطراف لینک
    final regExp = RegExp(r'https?:\/\/[^\s]+|youtu\.be\/[^\s]+|instagram\.com\/[^\s]+|tiktok\.com\/[^\s]+');
    final match = regExp.firstMatch(text);
    
    if (match != null) {
      text = match.group(0)!;
    }

    if (text.startsWith('youtu.be/')) {
      return 'https://$text';
    }
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return 'https://$text';
    }
    return text;
  }

  void _playAdsAndDownload(BuildContext context, String rawUrl) async {
    String formattedUrl = _extractValidUrl(rawUrl);

    final activeAds = globalAds.where((ad) => ad.isActive).toList();

    // نمایش تبلیغات فعال پیش از شروع دانلود
    if (activeAds.isNotEmpty) {
      for (var ad in activeAds) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdPlayerScreen(ad: ad),
            fullscreenDialog: true,
          ),
        );
      }
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 20);
      dio.options.receiveTimeout = const Duration(seconds: 20);

      final response = await dio.post(
        'https://api.cobalt.tools/api/json',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ),
        data: {
          'url': formattedUrl,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        String? downloadUrl;

        if (data['status'] == 'stream' || data['status'] == 'redirect') {
          downloadUrl = data['url'];
        } else if (data['status'] == 'picker') {
          final picker = data['picker'] as List;
          if (picker.isNotEmpty) {
            downloadUrl = picker[0]['url'];
          }
        }

        if (downloadUrl != null) {
          var dir = await getTemporaryDirectory();
          var filePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
          
          await dio.download(downloadUrl, filePath);
          await Gal.putVideo(filePath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ویدیو با موفقیت دانلود و در گالری ذخیره شد!')),
            );
            _urlController.clear();
          }
        } else {
          throw Exception('فرمت پاسخ سرور ناشناخته است یا لینک دانلود یافت نشد.');
        }
      } else {
        throw Exception('کد خطای سرور: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Failed host lookup')) {
          errorMessage = 'خطا در اتصال به اینترنت. لطفاً دسترسی اینترنت را بررسی کنید.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
}

// صفحه نمایش تبلیغ با تایمر شمارش معکوس
class AdPlayerScreen extends StatefulWidget {
  final AdModel ad;
  const AdPlayerScreen({super.key, required this.ad});

  @override
  State<AdPlayerScreen> createState() => _AdPlayerScreenState();
}

class _AdPlayerScreenState extends State<AdPlayerScreen> {
  late int _timeLeft;
  bool _canClose = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.ad.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 1) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _canClose = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _canClose,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('درحال نمایش تبلیغ اسپانسر'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign_rounded, size: 90, color: Colors.amberAccent),
                const SizedBox(height: 24),
                Text(
                  widget.ad.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'لطفاً برای حمایت از اپلیکیشن تا اتمام تبلیغ صبور باشید...',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 45),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _canClose ? Colors.green : Colors.orange),
                  ),
                  child: Text(
                    _canClose ? 'تبلیغ به پایان رسید' : 'تایم باقی‌مانده: $_timeLeft ثانیه',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _canClose ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 45),
                ElevatedButton(
                  onPressed: _canClose ? () => Navigator.pop(context) : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_canClose ? 'ادامه دانلود ویدیو' : 'صبر کنید تا تایم تمام شود...'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// پنل مدیریت ادمین
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggedIn = false;

  final TextEditingController _adTitleController = TextEditingController();
  final TextEditingController _adDurationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مدیریت تبلیغات هوشمند', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _isLoggedIn = false;
                      _emailController.clear();
                      _passwordController.clear();
                    });
                  },
                ),
              ],
            ),
            const Divider(),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('افزودن تبلیغ جدید', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adTitleController,
                      decoration: const InputDecoration(labelText: 'متن یا عنوان تبلیغ'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'تایم تبلیغ به ثانیه (مثلاً 10)'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_adTitleController.text.isNotEmpty && _adDurationController.text.isNotEmpty) {
                          setState(() {
                            globalAds.add(AdModel(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              title: _adTitleController.text,
                              duration: int.tryParse(_adDurationController.text) ?? 5,
                              isActive: true,
                            ));
                            _adTitleController.clear();
                            _adDurationController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تبلیغ جدید با موفقیت اضافه شد!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('ثبت و افزودن تبلیغ'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('لیست تبلیغات ثبت شده:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: globalAds.length,
                itemBuilder: (context, index) {
                  final ad = globalAds[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(ad.title),
                      subtitle: Text('مدت زمان: ${ad.duration} ثانیه'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: ad.isActive,
                            onChanged: (val) {
                              setState(() {
                                ad.isActive = val;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                globalAds.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ورود اختصاصی ادمین',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'ایمیل ادمین',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'رمز عبور',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_emailController.text.trim() == 'abdullahjafari712@gmail.com' &&
                  _passwordController.text == '05050505') {
                setState(() {
                  _isLoggedIn = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خوش آمدید عبدالله عزیز! پنل مدیریت باز شد.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ایمیل یا رمز عبور اشتباه است!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ورود به پنل مدیریت'),
          ),
        ],
      ),
    );
  }
}
