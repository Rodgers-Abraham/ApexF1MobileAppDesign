import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/api_config.dart';
import '../../shared/theme/theme_provider.dart';


class AuthState {
  final String? token;
  final String? email;
  final String? name;
  final String? favouriteTeam;
  final String? favouriteDriver;
  final bool isPro;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.token,
    this.email,
    this.name,
    this.favouriteTeam,
    this.favouriteDriver,
    this.isPro = false,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    String? token,
    String? email,
    String? name,
    String? favouriteTeam,
    String? favouriteDriver,
    bool? isPro,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      token: token ?? this.token,
      email: email ?? this.email,
      name: name ?? this.name,
      favouriteTeam: favouriteTeam ?? this.favouriteTeam,
      favouriteDriver: favouriteDriver ?? this.favouriteDriver,
      isPro: isPro ?? this.isPro,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  AuthNotifier(this._ref) : super(AuthState()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    if (token != null && userJson != null) {
      try {
        final userData = jsonDecode(userJson);
        state = AuthState(
          token: token,
          email: userData['email'],
          name: userData['name'],
          favouriteTeam: userData['favourite_team'],
          favouriteDriver: userData['favourite_driver'],
          isPro: userData['is_pro'] ?? false,
        );
        
        // Also update ThemeProvider to match user preference
        _updateAppTheme(userData['favourite_team']);
      } catch (e) {
        logout();
      }
    }
  }

  void _updateAppTheme(String? teamName) {
    if (teamName == null) return;
    try {
      final team = F1Team.values.firstWhere((t) => t.name.toLowerCase() == teamName.toLowerCase());
      _ref.read(themeProvider.notifier).selectTeam(team);
    } catch (_) {}
  }

  String _extractErrorMessage(DioException e, String fallback) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map && detail.containsKey('error')) {
          return detail['error'].toString();
        } else if (detail is String) {
          return detail;
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            return first['msg'].toString();
          }
        } else if (data.containsKey('message')) {
          return data['message'].toString();
        }
      } else if (data is String) {
        return data;
      }
    } else if (e.type == DioExceptionType.connectionError ||
               e.type == DioExceptionType.connectionTimeout ||
               e.type == DioExceptionType.sendTimeout ||
               e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot connect to backend server. Make sure the backend is running.';
    }
    return fallback;
  }

  Future<bool> register(String email, String password, String name, String favouriteTeam, String favouriteDriver) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'email': email,
        'password': password,
        'name': name.isNotEmpty ? name : null,
        'favourite_team': favouriteTeam,
        'favourite_driver': favouriteDriver.isNotEmpty ? favouriteDriver : null,
      });

      final data = response.data;
      final token = data['token'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(data));
      await prefs.setBool('onboarding_completed', true);

      state = AuthState(
        token: token,
        email: data['email'],
        name: data['name'],
        favouriteTeam: data['favourite_team'],
        favouriteDriver: data['favourite_driver'],
        isPro: data['is_pro'] ?? false,
      );

      _updateAppTheme(data['favourite_team']);
      return true;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Registration failed');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final token = data['token'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(data));
      await prefs.setBool('onboarding_completed', true);

      state = AuthState(
        token: token,
        email: data['email'],
        name: data['name'],
        favouriteTeam: data['favourite_team'],
        favouriteDriver: data['favourite_driver'],
        isPro: data['is_pro'] ?? false,
      );

      _updateAppTheme(data['favourite_team']);
      return true;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Login failed');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred');
      return false;
    }
  }

  Future<bool> updateProfile({String? name, String? favouriteDriver, String? newPassword}) async {
    if (!state.isAuthenticated) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.put(
        '/api/auth/profile',
        data: {
          'name': name,
          'favourite_driver': favouriteDriver,
          'new_password': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer ${state.token}'}),
      );

      final data = response.data;
      
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        userData['name'] = data['name'];
        userData['favourite_driver'] = data['favourite_driver'];
        await prefs.setString(_userKey, jsonEncode(userData));
      }

      state = state.copyWith(
        isLoading: false,
        name: data['name'],
        favouriteDriver: data['favourite_driver'],
      );
      return true;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Failed to update profile');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred');
      return false;
    }
  }

  Future<void> updateFavouriteTeam(String teamName) async {
    if (!state.isAuthenticated) return;
    try {
      await _dio.put(
        '/api/auth/theme',
        data: {'favourite_team': teamName},
        options: Options(headers: {'Authorization': 'Bearer ${state.token}'}),
      );

      state = state.copyWith(favouriteTeam: teamName);
      _updateAppTheme(teamName);

      // Save updated user data locally
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        userData['favourite_team'] = teamName;
        await prefs.setString(_userKey, jsonEncode(userData));
      }
    } catch (e) {
      debugPrint('Failed to update favourite team on server: $e');
    }
  }

  Future<void> upgradeToPro() async {
    if (!state.isAuthenticated) return;
    try {
      await _dio.put(
        '/api/auth/pro',
        data: {'is_pro': true},
        options: Options(headers: {'Authorization': 'Bearer ${state.token}'}),
      );

      state = state.copyWith(isPro: true);

      // Save updated user data locally
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        userData['is_pro'] = true;
        await prefs.setString(_userKey, jsonEncode(userData));
      }
    } catch (e) {
      debugPrint('Failed to update pro tier status: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove('onboarding_completed');
    state = AuthState();
  }

  Future<bool> deleteAccount() async {
    if (!state.isAuthenticated) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _dio.delete(
        '/api/auth/delete',
        options: Options(headers: {'Authorization': 'Bearer ${state.token}'}),
      );
      await logout();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?['error'] ?? 'Failed to delete account';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'An unexpected error occurred');
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});


