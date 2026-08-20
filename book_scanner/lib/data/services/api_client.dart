import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://119.91.119.89:9000';

  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_authInterceptor());
  }

  late final Dio _dio;
  String? _token;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    );
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  // ─── Auth ────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });
    final token = res.data['access_token'] as String;
    await saveToken(token);
    return res.data;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final res = await _dio.post('/api/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    final token = res.data['access_token'] as String;
    await saveToken(token);
    return res.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get('/api/auth/profile');
    return res.data;
  }

  Future<Map<String, dynamic>> updateProfile({String? username, String? avatar, String? bio}) async {
    final res = await _dio.put('/api/auth/profile', data: {
      if (username != null) 'username': username,
      if (avatar != null) 'avatar': avatar,
      if (bio != null) 'bio': bio,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath, {List<int>? bytes}) async {
    final formData = FormData.fromMap({
      'file': bytes != null
          ? MultipartFile.fromBytes(bytes, filename: 'avatar.png')
          : await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/api/auth/avatar', data: formData);
    return res.data;
  }

  // ─── Records ─────────────────────────────────────

  Future<Map<String, dynamic>> getRecords({String search = '', int page = 1, int pageSize = 20}) async {
    final res = await _dio.get('/api/records', queryParameters: {
      'search': search,
      'page': page,
      'page_size': pageSize,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getRecord(String id) async {
    final res = await _dio.get('/api/records/$id');
    return res.data;
  }

  Future<Map<String, dynamic>> createRecord(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/records', data: data);
    return res.data;
  }

  // ─── Voice（客户端采集 PCM，经 WebSocket 推流到后端转写）──

  Future<Map<String, dynamic>> saveVoice({String title = '', required String text}) async {
    final res = await _dio.post('/api/voice/save', data: {'title': title, 'text': text});
    return res.data;
  }

  Future<Map<String, dynamic>> renameRecord(String id, String title) async {
    final res = await _dio.put('/api/records/$id', data: {'title': title});
    return res.data;
  }

  Future<Map<String, dynamic>> updateRecordText(String id, String text) async {
    final res = await _dio.put('/api/records/$id', data: {'text_content': text});
    return res.data;
  }

  Future<void> deleteRecord(String id) async {
    await _dio.delete('/api/records/$id');
  }

  // ─── Device ──────────────────────────────────────

  Future<Map<String, dynamic>> getDeviceStatus() async {
    final res = await _dio.get('/api/device/status');
    return res.data;
  }

  Future<Map<String, dynamic>> connectDevice(String deviceId, {bool useWifi = false}) async {
    final res = await _dio.post('/api/device/connect', data: {
      'device_id': deviceId,
      'use_wifi': useWifi,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> disconnectDevice() async {
    final res = await _dio.post('/api/device/connect', data: {
      'device_id': '',
      'use_wifi': false,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> initializeDevice() async {
    final res = await _dio.post('/api/device/initialize');
    return res.data;
  }

  Future<Map<String, dynamic>> startPrint() async {
    final res = await _dio.post('/api/device/start');
    return res.data;
  }

  Future<Map<String, dynamic>> stopPrint() async {
    final res = await _dio.post('/api/device/stop');
    return res.data;
  }

  Future<Map<String, dynamic>> paperReady() async {
    final res = await _dio.post('/api/device/paper-ready');
    return res.data;
  }

  // ─── News（AI 新闻摘要）─────────────────────────

  Future<Map<String, dynamic>> fetchNews() async {
    final res = await _dio.get('/api/news/latest');
    return res.data;
  }

  // ─── Logs ────────────────────────────────────────

  Future<Map<String, dynamic>> getLogs({String? deviceId, int limit = 50}) async {
    final res = await _dio.get('/api/logs', queryParameters: {
      if (deviceId != null) 'device_id': deviceId,
      'limit': limit,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> uploadLogs(List<String> logs) async {
    final res = await _dio.post('/api/logs/upload', data: {'logs': logs});
    return res.data;
  }

  // ─── Showcase（首页）────────────────────────────

  Future<Map<String, dynamic>> getShowcasePosts({int page = 1, int pageSize = 20, String? keyword}) async {
    final res = await _dio.get('/api/showcase/posts', queryParameters: {
      'page': page,
      'page_size': pageSize,
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getShowcasePost(String id) async {
    final res = await _dio.get('/api/showcase/posts/$id');
    return res.data;
  }

  Future<Map<String, dynamic>> createShowcasePost(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/showcase/posts', data: data);
    return res.data;
  }

  Future<void> deleteShowcasePost(String id) async {
    await _dio.delete('/api/showcase/posts/$id');
  }

  Future<List<dynamic>> getUnpublishedRecords() async {
    final res = await _dio.get('/api/showcase/posts/me/unpublished');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> likeShowcasePost(String id) async {
    final res = await _dio.post('/api/showcase/posts/$id/like');
    return res.data;
  }

  Future<Map<String, dynamic>> unlikeShowcasePost(String id) async {
    final res = await _dio.delete('/api/showcase/posts/$id/like');
    return res.data;
  }

  Future<Map<String, dynamic>> favoriteShowcasePost(String id) async {
    final res = await _dio.post('/api/showcase/posts/$id/favorite');
    return res.data;
  }

  Future<Map<String, dynamic>> unfavoriteShowcasePost(String id) async {
    final res = await _dio.delete('/api/showcase/posts/$id/favorite');
    return res.data;
  }

  Future<Map<String, dynamic>> getMyFavorites({int page = 1, int pageSize = 20}) async {
    final res = await _dio.get('/api/showcase/favorites', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return res.data;
  }

  Future<List<dynamic>> getPostComments(String postId) async {
    final res = await _dio.get('/api/showcase/posts/$postId/comments');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> addPostComment(String postId, String content) async {
    final res = await _dio.post('/api/showcase/posts/$postId/comments', data: {'content': content});
    return res.data;
  }

  Future<void> deletePostComment(int commentId) async {
    await _dio.delete('/api/showcase/comments/$commentId');
  }

  Future<Map<String, dynamic>> getShowcaseUser(String userId) async {
    final res = await _dio.get('/api/showcase/users/$userId');
    return res.data;
  }

  Future<Map<String, dynamic>> getUserPosts(String userId, {int page = 1, int pageSize = 20}) async {
    final res = await _dio.get('/api/showcase/users/$userId/posts', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return res.data;
  }
}
