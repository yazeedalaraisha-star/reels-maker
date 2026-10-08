// الرفع على Google Drive. بنستخدم "Device flow" من Google: التطبيق بيعطيك
// كود قصير، بتفتح google.com/device وبتدخله مرة وحدة، وبعدين الرفع تلقائي.
// الصلاحية drive.file يعني التطبيق بيشوف بس الملفات اللي هو رفعها.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/engine.dart';
import '../core/settings.dart';

class DeviceCode {
  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int interval;
  final int expiresIn;
  DeviceCode(this.deviceCode, this.userCode, this.verificationUrl,
      this.interval, this.expiresIn);
}

class DriveService {
  final AppSettings settings;
  final LogFn log;
  final http.Client _http;
  String? _accessToken;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  DriveService(this.settings, this.log, [http.Client? client])
      : _http = client ?? http.Client();

  static const scope = 'https://www.googleapis.com/auth/drive.file';

  bool get isConnected => settings.driveRefreshToken.isNotEmpty;
  bool get hasClient => settings.driveClientId.isNotEmpty;

  Future<DeviceCode> startDeviceLogin() async {
    final r = await _http.post(Uri.parse('https://oauth2.googleapis.com/device/code'),
        body: {'client_id': settings.driveClientId.trim(), 'scope': scope});
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) {
      throw Exception('Google: ${j['error_description'] ?? j['error'] ?? r.body}');
    }
    return DeviceCode(j['device_code'], j['user_code'],
        j['verification_url'] ?? j['verification_uri'], j['interval'] ?? 5, j['expires_in'] ?? 1800);
  }

  /// يستنى لحد ما المستخدم يوافق، ويرجع refresh token.
  Future<String> waitForApproval(DeviceCode code, {bool Function()? cancelled}) async {
    var interval = code.interval;
    final until = DateTime.now().add(Duration(seconds: code.expiresIn));
    while (DateTime.now().isBefore(until)) {
      if (cancelled?.call() == true) throw Exception('انلغى');
      await Future.delayed(Duration(seconds: interval));
      final r = await _http.post(Uri.parse('https://oauth2.googleapis.com/token'), body: {
        'client_id': settings.driveClientId.trim(),
        'client_secret': settings.driveClientSecret.trim(),
        'device_code': code.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      });
      final j = jsonDecode(r.body);
      if (r.statusCode == 200) {
        _accessToken = j['access_token'];
        _expires = DateTime.now().add(Duration(seconds: (j['expires_in'] ?? 3600) - 60));
        return j['refresh_token'] ?? '';
      }
      final err = j['error'];
      if (err == 'authorization_pending') continue;
      if (err == 'slow_down') {
        interval += 5;
        continue;
      }
      throw Exception('Google: ${j['error_description'] ?? err}');
    }
    throw Exception('انتهت مدة الكود، جرب مرة تانية');
  }

  Future<String> _token() async {
    if (_accessToken != null && DateTime.now().isBefore(_expires)) return _accessToken!;
    if (!isConnected) throw Exception('Google Drive مش مربوط');
    final r = await _http.post(Uri.parse('https://oauth2.googleapis.com/token'), body: {
      'client_id': settings.driveClientId.trim(),
      'client_secret': settings.driveClientSecret.trim(),
      'refresh_token': settings.driveRefreshToken,
      'grant_type': 'refresh_token',
    });
    final j = jsonDecode(r.body);
    if (r.statusCode != 200) {
      throw Exception('Google: ${j['error_description'] ?? j['error']}');
    }
    _accessToken = j['access_token'];
    _expires = DateTime.now().add(Duration(seconds: (j['expires_in'] ?? 3600) - 60));
    return _accessToken!;
  }

  /// يرجع (أو ينشئ) مجلد التطبيق على درايف.
  Future<String> ensureFolder() async {
    if (settings.driveFolderId.isNotEmpty) return settings.driveFolderId;
    final t = await _token();
    final name = settings.driveFolderName.isEmpty ? 'Reels Maker' : settings.driveFolderName;
    final q = Uri.encodeQueryComponent(
        "mimeType='application/vnd.google-apps.folder' and name='${name.replaceAll("'", "\\'")}' and trashed=false");
    final s = await _http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files?q=$q&fields=files(id,name)'),
        headers: {'Authorization': 'Bearer $t'});
    final files = (jsonDecode(s.body)['files'] as List? ?? []);
    if (files.isNotEmpty) {
      settings.driveFolderId = files.first['id'];
      return settings.driveFolderId;
    }
    final c = await _http.post(Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id'),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'mimeType': 'application/vnd.google-apps.folder'}));
    if (c.statusCode != 200) throw Exception('إنشاء مجلد درايف: ${c.body}');
    settings.driveFolderId = jsonDecode(c.body)['id'];
    return settings.driveFolderId;
  }

  /// رفع ملف (رفع قابل للاستكمال، مناسب للفيديوهات الكبيرة).
  /// يرجع (id, رابط المشاهدة).
  Future<(String, String)> upload(String path, {String? folderId, String? description}) async {
    final t = await _token();
    final parent = folderId ?? await ensureFolder();
    final file = File(path);
    final len = await file.length();
    final mime = switch (p.extension(path).toLowerCase()) {
      '.mp4' => 'video/mp4',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.srt' => 'application/x-subrip',
      _ => 'text/plain',
    };
    final init = await _http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,webViewLink'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': mime,
        'X-Upload-Content-Length': '$len',
      },
      body: jsonEncode({
        'name': p.basename(path),
        'parents': [parent],
        if (description != null) 'description': description,
      }),
    );
    final loc = init.headers['location'];
    if (init.statusCode != 200 || loc == null) {
      throw Exception('درايف: ${init.statusCode} ${init.body}');
    }
    final req = http.StreamedRequest('PUT', Uri.parse(loc))
      ..headers['Content-Type'] = mime
      ..contentLength = len;
    file.openRead().listen(req.sink.add, onDone: req.sink.close, onError: req.sink.addError);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('درايف: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    log('☁️ انرفع على درايف: ${p.basename(path)}');
    return (j['id'] as String, (j['webViewLink'] ?? 'https://drive.google.com/file/d/${j['id']}/view') as String);
  }
}
