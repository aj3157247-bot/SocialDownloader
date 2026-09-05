import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class DownloadedVideoModel {
  String filePath;
  String date;

  DownloadedVideoModel({required this.filePath, required this.date});
}

List<DownloadedVideoModel> downloadedHistory = [];

class DownloadingTaskModel {
  final String id;
  final String url;
  double progress;
  int receivedBytes;
  int totalBytes;
  bool isPaused;
  CancelToken cancelToken;
  String? filePath;

  DownloadingTaskModel({
    required this.id,
    required this.url,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.isPaused = false,
    required this.cancelToken,
    this.filePath,
  });
}

// سرورهای Cobalt فعلی؛ endpoint اصلی نسخه‌های جدید روی / است.
// api.cobalt.tools هنوز از /api/json استفاده می‌کند.
final List<String> cobaltApiUrls = [
  'https://api.cobalt.tools/api/json',
  'https://nuko-c.meowing.de/',
  'https://api-cobalt.eversiege.network/',
  'https://cobaltapi.kittycat.boo/',
  'https://cobalt-alpha.wolfy.love/',
  'https://bergung-api.hoffnungfuerdiezukunft.net/',
];

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
    title: 'برای نشر تبلیغات خود با ما در واتساپ به تماس شوید', 
    link: 'https://wa.me/9378045492',
    duration: 5, 
    isActive: true,
  ),
];

bool isEnglish = false;

void main() {
  runApp(const SocialDownloaderApp());
}

class SocialDownloaderApp extends StatefulWidget {
  const SocialDownloaderApp({super.key});

  @override
  State<SocialDownloaderApp> createState() => _SocialDownloaderAppState();
}

class _SocialDownloaderAppState extends State<SocialDownloaderApp> {
  void toggleLanguage() {
    setState(() {
      isEnglish = !isEnglish;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Downloader Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: HomeScreen(onLanguageChanged: toggleLanguage),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onLanguageChanged;
  const HomeScreen({super.key, required this.onLanguageChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final List<DownloadingTaskModel> _activeDownloads = [];

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildDownloadPage(context),
      const AdminLoginScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 
            ? (isEnglish ? 'Smart Social Downloader' : 'دانلودر هوشمند سوشال مدیا') 
            : (isEnglish ? 'Admin Panel' : 'پنل مدیریت ادمین')),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: InkWell(
                onTap: () {
                  widget.onLanguageChanged();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: Text(
                    isEnglish ? 'FA 🇮🇷' : 'EN 🇺🇸',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.download),
            label: isEnglish ? 'Download' : 'دانلود',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.admin_panel_settings),
            label: isEnglish ? 'Admin' : 'مدیریت ادمین',
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blueAccent, Colors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, size: 36, color: Colors.amberAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEnglish ? 'High Speed & Smart Download' : 'دانلود همزمان و هوشمند',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isEnglish ? '⚡ 3X Turbo' : '⚡ سرعت ۳برابر',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnglish 
                            ? 'Support TikTok, Instagram & YouTube • Optimized for max speed' 
                            : 'پشتیبانی از تیک‌تاک، اینستاگرام و یوتیوب • بهینه‌سازی شده برای سرعت بالا',
                        style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isEnglish ? 'Enter full video link below:' : 'لینک کامل ویدیو را وارد کنید:',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    hintText: 'https://instagram.com/... یا https://youtu.be/...',
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
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  if (_urlController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEnglish ? 'Please enter a valid link' : 'لطفاً یک لینک معتبر وارد کنید')),
                    );
                    return;
                  }
                  String urlToDownload = _urlController.text.trim();
                  _urlController.clear();
                  _playAdsAndStartDownload(context, urlToDownload);
                },
                icon: const Icon(Icons.download_rounded),
                label: Text(isEnglish ? 'Add' : 'افزودن'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_activeDownloads.isNotEmpty) ...[
            Text(
              isEnglish ? 'Active Downloads:' : 'دانلودهای فعال:',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 130,
              child: ListView.builder(
                itemCount: _activeDownloads.length,
                itemBuilder: (context, index) {
                  final task = _activeDownloads[index];
                  return Card(
                    color: Colors.grey[850],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  task.url,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  task.cancelToken.cancel('cancelled');
                                  setState(() {
                                    _activeDownloads.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: task.totalBytes > 0 ? task.progress : null,
                            backgroundColor: Colors.grey[800],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                            minHeight: 6,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                task.isPaused
                                    ? (isEnglish ? 'Paused' : 'متوقف شده')
                                    : (task.totalBytes > 0
                                        ? (isEnglish ? 'Downloading: ${(task.progress * 100).toStringAsFixed(0)}%' : 'در حال دانلود: ${(task.progress * 100).toStringAsFixed(0)}%')
                                        : (isEnglish ? 'Connecting & Fetching... (${(task.receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB)' : 'در حال اتصال و دریافت... (${(task.receivedBytes / 1024 / 1024).toStringAsFixed(1)} مگابایت)')),
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            isEnglish ? 'Recent downloaded videos (Tap to play):' : 'ویدیوهای دانلود شده اخیر در این برنامه (برای پخش لمس کنید):',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: downloadedHistory.isEmpty
                ? Center(
                    child: Text(
                      isEnglish ? 'No videos downloaded yet' : 'هنوز ویدیویی دانلود نشده است',
                      style: const TextStyle(color: Colors.grey),
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
                            isEnglish ? 'Video #${index + 1}' : 'ویدیو شماره ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(item.date, style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(filePath: item.filePath),
                              ),
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.greenAccent),
                                onPressed: () async {
                                  try {
                                    await Share.shareXFiles(
                                      [XFile(item.filePath)],
                                      text: 'Downloaded from Social Downloader Pro',
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    downloadedHistory.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isEnglish ? 'Removed from list' : 'ویدیو از لیست صفحه پاک شد')),
                                  );
                                },
                                tooltip: 'حذف',
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

  String _extractValidUrl(String rawText) {
    String text = rawText.trim();
    final regExp = RegExp(r'https?:\/\/[^\s]+');
    final match = regExp.firstMatch(text);
    if (match != null) {
      text = match.group(0)!;
    }
    return text;
  }

  void _playAdsAndStartDownload(BuildContext context, String rawUrl) async {
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

    final task = DownloadingTaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: formattedUrl,
      cancelToken: CancelToken(),
    );

    setState(() {
      _activeDownloads.add(task);
    });

    _startConcurrentDownload(task);
  }

  Future<void> _startConcurrentDownload(DownloadingTaskModel task) async {
    Dio? dio;
    try {
      dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: true,
        maxRedirects: 8,
        validateStatus: (status) => status != null && status >= 200 && status < 500,
      ));

      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        client.connectionTimeout = const Duration(seconds: 12);
        return client;
      };

      final sourceUrl = task.url;
      final lowerUrl = sourceUrl.toLowerCase();
      final isTikTok = lowerUrl.contains('tiktok.com') || lowerUrl.contains('vm.tiktok.com');
      final isInstagram = lowerUrl.contains('instagram.com');
      final isYouTube = lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be');

      String? downloadUrl;
      String lastError = '';

      Future<bool> tryTikwm() async {
        try {
          final response = await dio!.get(
            'https://www.tikwm.com/api/',
            queryParameters: {'url': sourceUrl},
            options: Options(headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Android 14) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
            }),
            cancelToken: task.cancelToken,
          );
          if (response.statusCode == 200 && response.data is Map) {
            final body = Map<String, dynamic>.from(response.data as Map);
            final data = body['data'];
            if (data is Map) {
              for (final key in ['hdplay', 'play', 'wmplay']) {
                final value = data[key];
                if (value is String && value.trim().isNotEmpty) {
                  downloadUrl = value.trim();
                  return true;
                }
              }
            }
            lastError = body['msg']?.toString() ?? 'TikWM returned no video URL';
          } else {
            lastError = 'TikWM HTTP ${response.statusCode}';
          }
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) rethrow;
          lastError = 'TikWM: $e';
        }
        return false;
      }

      Future<bool> tryCobalt(String base) async {
        final endpoints = <String>[];
        final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        if (normalized == 'https://api.cobalt.tools') {
          endpoints.add('$normalized/api/json');
        } else {
          endpoints.add('$normalized/');
          endpoints.add('$normalized/api/json');
        }

        for (final endpoint in endpoints) {
          try {
            final response = await dio!.post(
              endpoint,
              options: Options(headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'User-Agent': 'SocialDownloader/1.0 (Android)',
              }),
              data: {
                'url': sourceUrl,
                'videoQuality': isYouTube ? '720' : '1080',
                'youtubeVideoCodec': 'h264',
                'downloadMode': 'auto',
              },
              cancelToken: task.cancelToken,
            );

            if (response.statusCode != 200 || response.data is! Map) {
              lastError = 'Cobalt HTTP ${response.statusCode}';
              continue;
            }

            final data = Map<String, dynamic>.from(response.data as Map);
            final status = data['status']?.toString() ?? '';
            if (status == 'error' || status == 'rate-limit') {
              lastError = data['text']?.toString() ?? data['code']?.toString() ?? status;
              continue;
            }

            final candidates = <dynamic>[
              data['url'],
              data['downloadUrl'],
              data['directUrl'],
              data['stream'],
              data['link'],
            ];
            for (final candidate in candidates) {
              if (candidate is String && candidate.trim().isNotEmpty) {
                downloadUrl = candidate.trim();
                return true;
              }
            }

            final picker = data['picker'];
            if (picker is List) {
              for (final item in picker) {
                if (item is Map) {
                  final value = item['url'];
                  final type = item['type']?.toString();
                  if (value is String && value.trim().isNotEmpty &&
                      (type == null || type == 'video')) {
                    downloadUrl = value.trim();
                    return true;
                  }
                }
              }
            }

            lastError = data['text']?.toString() ?? 'Cobalt returned no download URL';
          } catch (e) {
            if (e is DioException && CancelToken.isCancel(e)) rethrow;
            lastError = '$endpoint: $e';
          }
        }
        return false;
      }

      // TikTok: TikWM را اول امتحان می‌کنیم تا وابسته به یک Cobalt instance نباشیم.
      if (isTikTok) {
        await tryTikwm();
      }

      // سپس Cobalt؛ ترتیب برای هر سرویس بر اساس وضعیت فعلی instanceها تنظیم شده است.
      if (downloadUrl == null) {
        final ordered = <String>[];
        if (isInstagram) {
          ordered.addAll([
            'https://nuko-c.meowing.de/',
            'https://api-cobalt.eversiege.network/',
            'https://cobaltapi.kittycat.boo/',
            'https://bergung-api.hoffnungfuerdiezukunft.net/',
          ]);
        } else if (isYouTube) {
          ordered.addAll([
            'https://cobalt-alpha.wolfy.love/',
            'https://api-cobalt.eversiege.network/',
            'https://cobaltapi.kittycat.boo/',
            'https://nuko-c.meowing.de/',
            'https://bergung-api.hoffnungfuerdiezukunft.net/',
          ]);
        } else if (isTikTok) {
          ordered.addAll([
            'https://api-cobalt.eversiege.network/',
            'https://nuko-c.meowing.de/',
            'https://cobaltapi.kittycat.boo/',
            'https://cobalt-alpha.wolfy.love/',
          ]);
        } else {
          ordered.addAll(cobaltApiUrls);
        }

        // API رسمی را هم در انتها امتحان می‌کنیم.
        ordered.add('https://api.cobalt.tools/api/json');

        for (final api in ordered) {
          if (await tryCobalt(api)) break;
        }
      }

      // اگر TikTok ویدیو کوتاه بود و TikWM در لحظه جواب نداد، یک بار دیگر با Cobalt امتحان شده است.
      if (downloadUrl == null && isTikTok) {
        await tryTikwm();
      }

      if (downloadUrl == null || downloadUrl!.isEmpty) {
        throw Exception(lastError.isEmpty
            ? 'No download URL returned by providers'
            : lastError);
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${task.id}.mp4';
      task.filePath = filePath;

      final response = await dio.get<ResponseBody>(
        downloadUrl!,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': '*/*',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
          },
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
        ),
        cancelToken: task.cancelToken,
      );

      if (response.data == null) {
        throw Exception('Empty media response');
      }

      final totalHeader = response.headers.value(Headers.contentLengthHeader);
      task.totalBytes = int.tryParse(totalHeader ?? '') ?? -1;

      final file = File(filePath);
      if (await file.exists()) await file.delete();
      final raf = await file.open(mode: FileMode.write);
      var closed = false;

      Future<void> closeFile() async {
        if (!closed) {
          closed = true;
          await raf.close();
        }
      }

      var lastReceivedBytes = 0;

      response.data!.stream.listen(
        (data) {
          if (task.isPaused) return;
          raf.writeFromSync(data);
          task.receivedBytes += data.length;
          if (task.receivedBytes - lastReceivedBytes > 100 * 1024 ||
              (task.totalBytes > 0 && task.receivedBytes >= task.totalBytes)) {
            lastReceivedBytes = task.receivedBytes;
            if (mounted) {
              setState(() {
                if (task.totalBytes > 0) {
                  task.progress = (task.receivedBytes / task.totalBytes).clamp(0.0, 1.0).toDouble();
                }
              });
            }
          }
        },
        onDone: () async {
          await closeFile();
          if (!task.isPaused && await file.exists() && await file.length() > 0) {
            try {
              await Gal.putVideo(filePath);
              if (mounted) {
                setState(() {
                  _activeDownloads.remove(task);
                  downloadedHistory.add(DownloadedVideoModel(
                    filePath: filePath,
                    date: DateTime.now().toString().substring(0, 19),
                  ));
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEnglish
                      ? 'Successfully saved to gallery!'
                      : 'ویدیو با موفقیت دانلود و در گالری ذخیره شد!')),
                );
              }
            } catch (e) {
              if (mounted) {
                setState(() => _activeDownloads.remove(task));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEnglish
                      ? 'Downloaded, but could not save to gallery.'
                      : 'ویدیو دانلود شد اما ذخیره در گالری ناموفق بود.')),
                );
              }
            }
          } else if (mounted) {
            setState(() => _activeDownloads.remove(task));
          }
        },
        onError: (e) async {
          await closeFile();
          if (mounted) setState(() => _activeDownloads.remove(task));
        },
        cancelOnError: true,
      );
    } catch (e) {
      final isCancelled = e is DioException && CancelToken.isCancel(e);
      if (!isCancelled && mounted) {
        setState(() => _activeDownloads.remove(task));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnglish
                ? 'Download failed. The source server may be temporarily unavailable.'
                : 'دانلود ناموفق بود. ممکن است سرور دانلود موقتاً در دسترس نباشد.',
                textDirection: TextDirection.rtl),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }}

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
      appBar: AppBar(title: Text(isEnglish ? 'Video Player' : 'پخش ویدیو')),
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
          title: Text(isEnglish ? 'Sponsor Ad' : 'درحال نمایش تبلیغ اسپانسر'),
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
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(widget.ad.link);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          try {
                            await launchUrl(uri, mode: LaunchMode.platformDefault);
                          } catch (_) {}
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            Text(
                              widget.ad.link,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.greenAccent,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    isEnglish ? 'Please wait until the ad ends...' : 'لطفاً برای حمایت از اپلیکیشن تا اتمام تبلیغ صبور باشید...',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                      _canClose 
                          ? (isEnglish ? 'Ad Finished' : 'تبلیغ به پایان رسید') 
                          : (isEnglish ? 'Time remaining: $_timeLeft s' : 'تایم باقی‌مانده: $_timeLeft ثانیه'),
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
                    child: Text(_canClose 
                        ? (isEnglish ? 'Continue Downloading' : 'ادامه دانلود ویدیو') 
                        : (isEnglish ? 'Please wait...' : 'صبر کنید تا تایم تمام شود...')),
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
                  Text(isEnglish ? 'Advanced Admin Panel' : 'پنل مدیریت پیشرفته', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              TabBar(
                tabs: [
                  Tab(text: isEnglish ? 'Ads Management' : 'مدیریت تبلیغات'),
                  Tab(text: isEnglish ? 'API Servers' : 'مدیریت سرورهای API'),
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
                                  Text(isEnglish ? 'Add New Ad' : 'افزودن تبلیغ جدید', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _adTitleController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      labelText: isEnglish ? 'Ad Text' : 'متن تبلیغ',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _adLinkController,
                                    textDirection: TextDirection.ltr,
                                    decoration: InputDecoration(
                                      labelText: isEnglish ? 'Clickable Link (e.g. https://wa.me/...)' : 'لینک قابل کلیک (مثلاً https://wa.me/...)',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _adDurationController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: isEnglish ? 'Duration in seconds (e.g. 5)' : 'تایم تبلیغ به ثانیه (مثلاً 5)'),
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
                                          SnackBar(content: Text(isEnglish ? 'Ad added' : 'تبلیغ جدید اضافه شد')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.add),
                                    label: Text(isEnglish ? 'Save Ad' : 'ثبت تبلیغ'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(isEnglish ? 'Ads List:' : 'لیست تبلیغات:', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                  subtitle: Text(isEnglish ? 'Duration: ${ad.duration}s' : 'مدت: ${ad.duration} ثانیه'),
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
                                  Text(isEnglish ? 'Add New API Server' : 'افزودن سرور API جدید', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _serverController,
                                    textDirection: TextDirection.ltr,
                                    decoration: InputDecoration(labelText: isEnglish ? 'Full API URL' : 'آدرس کامل API'),
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
                                          SnackBar(content: Text(isEnglish ? 'Server added' : 'سرور اضافه شد')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.dns),
                                    label: Text(isEnglish ? 'Add' : 'افزودن'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(isEnglish ? 'Active Servers:' : 'سرورهای فعال:', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          Text(
            isEnglish ? 'Admin Login' : 'ورود ادمین',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: isEnglish ? 'Admin Email' : 'ایمیل ادمین',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isEnglish ? 'Password' : 'رمز عبور',
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
                  SnackBar(content: Text(isEnglish ? 'Welcome!' : 'خوش آمدید!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEnglish ? 'Invalid credentials' : 'اطلاعات اشتباه است')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEnglish ? 'Login' : 'ورود'),
          ),
        ],
      ),
    );
  }
}
