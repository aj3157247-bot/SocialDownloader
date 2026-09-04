import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// مدل ویدیوهای دانلود شده
class DownloadedVideoModel {
  String filePath;
  String date;

  DownloadedVideoModel({required this.filePath, required this.date});
}

// لیست سراسری ویدیوهای دانلود شده برای نمایش در برنامه
List<DownloadedVideoModel> downloadedHistory = [];

// لیست سرورهای پشتیبان
List<String> cobaltApiUrls = [
  'https://api.cobalt.best/api/json',
  'https://co.wuk.sh/api/json',
];

// مدل داده‌ای تبلیغات
class AdModel {
  String id;
  String title;
  String link;
  int duration;
  bool isActive;

  AdModel({
    required this.id,
    required this.title,
    this.link = '',
    required this.duration,
    this.isActive = true,
  });
}

List<AdModel> globalAds = [
  AdModel(
    id: '1', 
    title: 'تبلیغ اول: معرفی کانال تلگرام ما\nارتباط با ما: 09123456789', 
    link: 'https://t.me/example',
    duration: 5, 
    isActive: true,
  ),
  AdModel(
    id: '2', 
    title: 'تبلیغ دوم: تخفیف ویژه سرویس‌ها', 
    link: '',
    duration: 5, 
    isActive: true,
  ),
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
  bool _isPaused = false;
  double _downloadProgress = 0.0;
  
  CancelToken? _cancelToken;
  String? _currentDownloadUrl;
  String? _currentFilePath;
  int _receivedBytes = 0;
  int _totalBytes = 0;

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
            'لینک کامل ویدیو (تیک‌تاک، یوتیوب، اینستاگرام) را وارد کنید:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: 'https://vt.tiktok.com/... یا https://youtu.be/...',
              hintTextDirection: TextDirection.ltr,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _urlController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _isDownloading
              ? Column(
                  children: [
                    LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPaused
                              ? 'متوقف شده (${(_downloadProgress * 100).toStringAsFixed(0)}%)'
                              : 'در حال دانلود: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Row(
                          children: [
                            if (_isPaused)
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                                onPressed: _resumeDownload,
                                tooltip: 'ادامه',
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.pause, color: Colors.orangeAccent),
                                onPressed: _pauseDownload,
                                tooltip: 'توقف',
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent),
                              onPressed: _cancelDownload,
                              tooltip: 'کنسل',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
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
          const SizedBox(height: 20),
          const Text(
            'ویدیوهای دانلود شده اخیر در این برنامه (برای پخش لمس کنید):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: downloadedHistory.isEmpty
                ? const Center(
                    child: Text(
                      'هنوز ویدیویی دانلود نشده است',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: downloadedHistory.length,
                    itemBuilder: (context, index) {
                      final item = downloadedHistory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.video_file, color: Colors.blueAccent, size: 36),
                          title: Text(
                            'ویدیو شماره ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(item.date, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            // باز کردن و پخش ویدیو در داخل برنامه
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(filePath: item.filePath),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.share, color: Colors.greenAccent),
                            onPressed: () async {
                              try {
                                await Share.shareXFiles(
                                  [XFile(item.filePath)],
                                  text: 'دانلود شده از اپلیکیشن Social Downloader Pro',
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطا در اشتراک‌گذاری: $e')),
                                );
                              }
                            },
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

  void _pauseDownload() {
    _cancelToken?.cancel('paused');
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeDownload() async {
    setState(() {
      _isPaused = false;
    });
    try {
      final dio = Dio();
      _cancelToken = CancelToken();
      
      final file = File(_currentFilePath!);
      final raf = await file.open(mode: FileMode.append);

      final response = await dio.get<ResponseBody>(
        _currentDownloadUrl!,
        options: Options(
          headers: {'range': 'bytes=$_receivedBytes-'},
          responseType: ResponseType.stream,
        ),
        cancelToken: _cancelToken,
      );

      response.data!.stream.listen(
        (data) {
          if (_isPaused) return;
          raf.writeFromSync(data);
          _receivedBytes += data.length;
          if (mounted) {
            setState(() {
              if (_totalBytes > 0) {
                _downloadProgress = _receivedBytes / _totalBytes;
              }
            });
          }
        },
        onDone: () async {
          await raf.close();
          if (!_isPaused) {
            await Gal.putVideo(_currentFilePath!);
            setState(() {
              downloadedHistory.add(
                DownloadedVideoModel(
                  filePath: _currentFilePath!,
                  date: DateTime.now().toString().substring(0, 19),
                ),
              );
              _isDownloading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ویدیو با موفقیت دانلود و در گالری ذخیره شد!')),
              );
              _urlController.clear();
            }
          }
        },
        onError: (e) async {
          await raf.close();
          if (!CancelToken.isCancel(e)) {
            setState(() => _isDownloading = false);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!CancelToken.isCancel(e)) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('cancelled');
    setState(() {
      _isDownloading = false;
      _isPaused = false;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('دانلود لغو شد')),
    );
  }

  String _extractValidUrl(String rawText) {
    String text = rawText.trim();
    if (text.startsWith('ttps://')) {
      text = 'h$text';
    } else if (text.startsWith('ttp://')) {
      text = 'h$text';
    } else if (text.startsWith('tp://')) {
      text = 'ht$text';
    } else if (text.startsWith('t.tiktok.com') || text.startsWith('vt.tiktok.com')) {
      text = 'https://$text';
    }

    if (text.startsWith('/')) {
      return 'https://youtu.be$text';
    }

    final regExp = RegExp(r'https?:\/\/[^\s]+|ttps?:\/\/[^\s]+|youtu\.be\/[^\s]+|instagram\.com\/[^\s]+|tiktok\.com\/[^\s]+|vt\.tiktok\.com\/[^\s]+');
    final match = regExp.firstMatch(text);
    
    if (match != null) {
      text = match.group(0)!;
      if (text.startsWith('ttps://')) {
        text = 'h$text';
      }
    }
    return text;
  }

  void _playAdsAndDownload(BuildContext context, String rawUrl) async {
    String formattedUrl = _extractValidUrl(rawUrl);
    final activeAds = globalAds.where((ad) => ad.isActive).toList();

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
      _isPaused = false;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
    });

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 15);

      String? downloadUrl;
      bool success = false;

      if (formattedUrl.contains('tiktok.com') || formattedUrl.contains('vt.tiktok.com')) {
        try {
          final response = await dio.get(
            'https://www.tikwm.com/api/',
            queryParameters: {'url': formattedUrl},
          );
          if (response.statusCode == 200 && response.data['code'] == 0) {
            downloadUrl = response.data['data']['play'];
            success = true;
          }
        } catch (_) {}
      }

      if (!success) {
        String lastError = '';
        for (String apiUrl in cobaltApiUrls) {
          try {
            final response = await dio.post(
              apiUrl,
              options: Options(
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                },
              ),
              data: {'url': formattedUrl},
            );
            if (response.statusCode == 200) {
              final data = response.data;
              if (data['status'] == 'stream' || data['status'] == 'redirect') {
                downloadUrl = data['url'];
                success = true;
                break;
              } else if (data['status'] == 'picker') {
                final picker = data['picker'] as List;
                if (picker.isNotEmpty) {
                  downloadUrl = picker[0]['url'];
                  success = true;
                  break;
                }
              }
            }
          } catch (err) {
            lastError = err.toString();
            continue;
          }
        }
        if (!success) {
          throw Exception('امکان دریافت لینک ویدیو وجود ندارد. جزئیات: $lastError');
        }
      }

      if (downloadUrl != null) {
        var dir = await getTemporaryDirectory();
        var filePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        
        _currentDownloadUrl = downloadUrl;
        _currentFilePath = filePath;
        _cancelToken = CancelToken();

        final response = await dio.get<ResponseBody>(
          downloadUrl,
          options: Options(responseType: ResponseType.stream),
          cancelToken: _cancelToken,
        );

        final totalHeader = response.headers.value(Headers.contentLengthHeader);
        _totalBytes = totalHeader != null ? int.parse(totalHeader) : -1;

        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        final raf = await file.open(mode: FileMode.write);

        response.data!.stream.listen(
          (data) {
            if (_isPaused) return;
            raf.writeFromSync(data);
            _receivedBytes += data.length;
            if (mounted) {
              setState(() {
                if (_totalBytes > 0) {
                  _downloadProgress = _receivedBytes / _totalBytes;
                }
              });
            }
          },
          onDone: () async {
            await raf.close();
            if (!_isPaused) {
              await Gal.putVideo(filePath);
              setState(() {
                downloadedHistory.add(
                  DownloadedVideoModel(
                    filePath: filePath,
                    date: DateTime.now().toString().substring(0, 19),
                  ),
                );
                _isDownloading = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ویدیو با موفقیت دانلود و در گالری ذخیره شد!')),
                );
                _urlController.clear();
              }
            }
          },
          onError: (e) async {
            await raf.close();
            if (!CancelToken.isCancel(e)) {
              setState(() => _isDownloading = false);
            }
          },
          cancelOnError: true,
        );

      } else {
        throw Exception('لینک دانلود از پاسخ سرور استخراج نشد.');
      }
    } catch (e) {
      if (!CancelToken.isCancel(e)) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.contains('Failed host lookup')) {
            errorMessage = 'خطا در اتصال به اینترنت. لطفاً دسترسی شبکه را بررسی کنید.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage, textDirection: TextDirection.rtl),
              duration: const Duration(seconds: 7),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
}

// صفحه پخش ویدیوی داخلی برنامه
class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  const VideoPlayerScreen({super.key, required this.filePath});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _isPlaying = true;
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پخش ویدیو')),
      body: Center(
        child: _controller.value.isInitialized
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  const SizedBox(height: 16),
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: Colors.blueAccent),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                        onPressed: () {
                          setState(() {
                            if (_isPlaying) {
                              _controller.pause();
                              _isPlaying = false;
                            } else {
                              _controller.play();
                              _isPlaying = true;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

// صفحه نمایش تبلیغ با قابلیت کلیک روی لینک
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign_rounded, size: 90, color: Colors.amberAccent),
                  const SizedBox(height: 24),
                  SelectableText(
                    widget.ad.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.ad.link.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(widget.ad.link);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        widget.ad.link,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'لطفاً برای حمایت از اپلیکیشن تا اتمام تبلیغ صبور باشید...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 35),
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
                  const SizedBox(height: 35),
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
  final TextEditingController _adLinkController = TextEditingController();
  final TextEditingController _adDurationController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('پنل مدیریت پیشرفته', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: 'مدیریت تبلیغات'),
                  Tab(text: 'مدیریت سرورهای API'),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'متن تبلیغ (توضیحات، شماره تماس و...)',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _adLinkController,
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                      labelText: 'لینک قابل کلیک (URL - مثلاً https://...)',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _adDurationController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'تایم تبلیغ به ثانیه (مثلاً 5)'),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (_adTitleController.text.isNotEmpty && _adDurationController.text.isNotEmpty) {
                                        setState(() {
                                          globalAds.add(AdModel(
                                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                                            title: _adTitleController.text,
                                            link: _adLinkController.text.trim(),
                                            duration: int.tryParse(_adDurationController.text) ?? 5,
                                            isActive: true,
                                          ));
                                          _adTitleController.clear();
                                          _adLinkController.clear();
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
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: globalAds.length,
                            itemBuilder: (context, index) {
                              final ad = globalAds[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('مدت: ${ad.duration} ثانیه ${ad.link.isNotEmpty ? "| دارای لینک" : ""}'),
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
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('افزودن سرور API جدید', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _serverController,
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                      labelText: 'آدرس کامل API',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (_serverController.text.isNotEmpty) {
                                        setState(() {
                                          cobaltApiUrls.add(_serverController.text.trim());
                                          _serverController.clear();
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('سرور جدید اضافه شد!')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.dns),
                                    label: const Text('افزودن سرور'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('لیست سرورهای فعال:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cobaltApiUrls.length,
                            itemBuilder: (context, index) {
                              final serverUrl = cobaltApiUrls[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(serverUrl, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() {
                                        cobaltApiUrls.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
