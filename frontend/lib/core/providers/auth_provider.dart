import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_config.dart';
import '../../shared/theme/theme_provider.dart';

class AuthState {
  final String? token; // Firebase UID
  final String? email;
  final String? name;
  final String? favouriteTeam;
  final String? favouriteDriver;
  final String? country;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.token,
    this.email,
    this.name,
    this.favouriteTeam,
    this.favouriteDriver,
    this.country,
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
    String? country,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      token: token ?? this.token,
      email: email ?? this.email,
      name: name ?? this.name,
      favouriteTeam: favouriteTeam ?? this.favouriteTeam,
      favouriteDriver: favouriteDriver ?? this.favouriteDriver,
      country: country ?? this.country,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  static const String _userKey = 'auth_user';

  AuthNotifier(this._ref) : super(AuthState()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      // Check cached profile so the UI doesn't flash
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson);
          state = AuthState(
            token: userData['uid'],
            email: userData['email'],
            name: userData['name'],
            favouriteTeam: userData['favourite_team'],
            favouriteDriver: userData['favourite_driver'],
            country: userData['country']);
          _updateAppTheme(userData['favourite_team']);
        } catch (_) {}
      }
      return;
    }

    try {
      final idToken = await firebaseUser.getIdToken();
      final response = await _dio.post('/api/auth/firebase', data: {
        'firebase_token': idToken,
      });
      final data = response.data as Map<String, dynamic>;
      await _persistAndSetState(firebaseUser.uid, data);
    } catch (e) {
      debugPrint('Auto-login refresh error: $e');
      // Use cached profile if available
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson);
          state = AuthState(
            token: userData['uid'],
            email: userData['email'],
            name: userData['name'],
            favouriteTeam: userData['favourite_team'],
            favouriteDriver: userData['favourite_driver'],
            country: userData['country']);
          _updateAppTheme(userData['favourite_team']);
        } catch (_) {}
      }
    }
  }

  void _updateAppTheme(String? teamName) {
    if (teamName == null) return;
    try {
      final team = F1Team.values.firstWhere(
        (t) => t.name.toLowerCase() == teamName.toLowerCase());
      _ref.read(themeProvider.notifier).selectTeam(team);
    } catch (_) {}
  }

  Future<void> _persistAndSetState(String uid, Map<String, dynamic> data) async {
    final toStore = {...data, 'uid': uid};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(toStore));
    await prefs.setBool('onboarding_completed', true);

    state = AuthState(
      token: uid,
      email: data['email'],
      name: data['name'],
      favouriteTeam: data['favourite_team'],
      favouriteDriver: data['favourite_driver'],
      country: data['country']);
    _updateAppTheme(data['favourite_team']);
  }

  String _extractErrorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          final detail = data['detail'];
          if (detail is Map && detail.containsKey('error')) return detail['error'].toString();
          if (detail is String) return detail;
        }
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Cannot connect to server. Check your internet connection.';
      }
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use': return 'Email is already registered.';
        case 'user-not-found': return 'No account found with this email.';
        case 'wrong-password': return 'Incorrect password.';
        case 'weak-password': return 'Password must be at least 6 characters.';
        case 'invalid-email': return 'Invalid email address.';
        case 'too-many-requests': return 'Too many attempts. Please try again later.';
        case 'network-request-failed': return 'Network error. Check your internet connection.';
        default: return e.message ?? fallback;
      }
    }
    return fallback;
  }

  Future<bool> register(
    String email,
    String password,
    String name,
    String favouriteTeam,
    String favouriteDriver, {
    String? country,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Create Firebase user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password);
      final user = cred.user!;

      // 2. Get Firebase ID token
      final idToken = await user.getIdToken();

      // 3. Sync profile with backend
      final response = await _dio.post('/api/auth/firebase', data: {
        'firebase_token': idToken,
        'name': name.isNotEmpty ? name : null,
        'favourite_team': favouriteTeam,
        if (favouriteDriver.isNotEmpty) 'favourite_driver': favouriteDriver,
        if (country != null) 'country': country,
      });

      await _persistAndSetState(user.uid, response.data as Map<String, dynamic>);
      return true;
    } catch (e) {
      final msg = _extractErrorMessage(e, 'Registration failed');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Sign in with Firebase
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password);
      final user = cred.user!;

      // 2. Get Firebase ID token
      final idToken = await user.getIdToken();

      // 3. Fetch profile from backend
      final response = await _dio.post('/api/auth/firebase', data: {
        'firebase_token': idToken,
      });

      await _persistAndSetState(user.uid, response.data as Map<String, dynamic>);
      return true;
    } catch (e) {
      final msg = _extractErrorMessage(e, 'Login failed');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? favouriteDriver,
    String? newPassword,
    String? country,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw Exception('Not authenticated');

      final idToken = await firebaseUser.getIdToken();

      if (newPassword != null && newPassword.isNotEmpty) {
        await firebaseUser.updatePassword(newPassword);
      }

      final response = await _dio.put(
        '/api/auth/profile',
        data: {
          if (name != null) 'name': name,
          if (favouriteDriver != null) 'favourite_driver': favouriteDriver,
          if (country != null) 'country': country,
        },
        options: Options(headers: {'Authorization': 'Bearer $idToken'}));

      final data = response.data as Map<String, dynamic>;
      await _persistAndSetState(firebaseUser.uid, {
        'email': state.email,
        'name': data['name'] ?? state.name,
        'favourite_team': data['favourite_team'] ?? state.favouriteTeam,
        'favourite_driver': data['favourite_driver'] ?? state.favouriteDriver,
        'country': data['country'] ?? state.country,
      });
      return true;
    } catch (e) {
      final msg = _extractErrorMessage(e, 'Profile update failed');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> updateFavouriteTeam(String teamName) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return false;
      final idToken = await firebaseUser.getIdToken();
      await _dio.put(
        '/api/auth/theme',
        data: {'favourite_team': teamName},
        options: Options(headers: {'Authorization': 'Bearer $idToken'}));
      state = state.copyWith(favouriteTeam: teamName);
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        userData['favourite_team'] = teamName;
        await prefs.setString(_userKey, jsonEncode(userData));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Not signed in.');
      return false;
    }
    try {
      // Delete Neon profile — best-effort, don't block if backend is unreachable
      try {
        final idToken = await firebaseUser.getIdToken();
        await _dio.delete(
          '/api/auth/delete',
          options: Options(headers: {'Authorization': 'Bearer $idToken'}));
      } catch (backendErr) {
        debugPrint('Backend delete notice (proceeding): $backendErr');
      }
      // Always delete the Firebase account regardless of backend result
      await firebaseUser.delete();
      await logout();
      return true;
    } on FirebaseAuthException catch (e) {
      // re-authentication may be required for sensitive operations
      String msg = e.code == 'requires-recent-login'
          ? 'Please sign out and sign back in, then try deleting again.'
          : e.message ?? 'Failed to delete account.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      final msg = _extractErrorMessage(e, 'Failed to delete account');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove('onboarding_completed');
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Returns the user's country name string if set.
final userCountryTzProvider = Provider<dynamic>((ref) {
  final country = ref.watch(authProvider).country;
  return country;
});
