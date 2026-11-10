import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_config.dart';

class ApiClient {
  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20))) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final token = await user.getIdToken();
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            debugPrint('Firebase token fetch error: $e');
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          debugPrint('API Error calling ${error.requestOptions.path}: ${error.message}');
          return handler.next(error);
        }));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Exception _parseError(DioException error) {
    if (error.response != null && error.response!.data != null) {
      final detail = error.response!.data['detail'];
      if (detail is Map && detail.containsKey('error')) {
        return ApiException(detail['error'], detail['code'] ?? 'UNKNOWN_ERROR');
      }
      return ApiException(error.response!.statusMessage ?? 'API Error', 'HTTP_${error.response!.statusCode}');
    }
    return ApiException('Network connection failed. Please try again.', 'NETWORK_ERROR');
  }
}

class ApiException implements Exception {
  final String message;
  final String code;

  ApiException(this.message, this.code);

  @override
  String toString() => 'ApiException: [$code] $message';
}
