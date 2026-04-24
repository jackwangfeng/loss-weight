import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio();
  String _baseUrl = _defaultBaseUrl();
  String? _token;

  // Real devices default to our Cloudflare-fronted prod backend over HTTPS.
  // CF edge terminates TLS and proxies to EC2:8000 via an Origin Rule.
  // Local dev overrides with --dart-define=API_BASE=http://localhost:8000/v1.
  static const _kBetaBackend = 'https://recompdaily.com/v1';
  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) {
      final base = Uri.base;
      if (base.host.isNotEmpty) {
        return '${base.scheme}://${base.host}:8000/v1';
      }
      return 'http://localhost:8000/v1';
    }
    return _kBetaBackend;
  }

  String get baseUrl => _baseUrl;
  set baseUrl(String value) => _baseUrl = value;

  String? get token => _token;
  set token(String? value) => _token = value;

  void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
  }

  Map<String, dynamic> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(
        '$_baseUrl$path',
        queryParameters: queryParameters,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> post(String path, dynamic data) async {
    try {
      return await _dio.post(
        '$_baseUrl$path',
        data: data,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// Multipart/form-data 上传。跟 post 分开：post 强设 Content-Type=
  /// application/json 会打断 Dio 对 FormData 的 boundary 自动协商。
  Future<Response> postFormData(String path, FormData data) async {
    try {
      final headers = <String, dynamic>{
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      return await _dio.post(
        '$_baseUrl$path',
        data: data,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> put(String path, dynamic data) async {
    try {
      return await _dio.put(
        '$_baseUrl$path',
        data: data,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(
        '$_baseUrl$path',
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception('网络连接超时，请检查网络设置');
    }

    if (e.response?.statusCode == 401) {
      throw Exception('认证失败，请重新登录');
    }

    if (e.response?.statusCode == 404) {
      throw Exception('请求的资源不存在');
    }

    if (e.response?.statusCode == 500) {
      throw Exception('服务器错误，请稍后重试');
    }
  }
}
