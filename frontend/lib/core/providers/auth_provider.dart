import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../../shared/theme/theme_provider.dart';

class AuthState {
  final String? token; // Firebase UID
  final String? email;
  final String? name;
  final String? favouriteTeam;
  final String? favouriteDriver;
  final String? country;
  final String? rivalDriver;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.token,
    this.email,
    this.name,
    this.favouriteTeam,
    this.favouriteDriver,
    this.country,
    this.rivalDriver,
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
    String? rivalDriver,
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
      rivalDriver: rivalDriver ?? this.rivalDriver,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  // Only used for backend session/picks operations — no longer for user profile.
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  static const String _userKey = 'auth_user';
  static const String _usersCollection = 'users';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  AuthNotifier(this._ref) : super(AuthState()) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson) as Map<String, dynamic>;
          state = AuthState(
            token: userData['uid'] as String?,
            email: userData['email'] as String?,
            name: userData['name'] as String?,
            favouriteTeam: userData['favourite_team'] as String?,
            favouriteDriver: userData['favourite_driver'] as String?,
            country: userData['country'] as String?,
            rivalDriver: userData['rival_driver'] as String?);
          _updateAppTheme(userData['favourite_team'] as String?);
        } catch (_) {}
      }
      return;
    }

    // Firebase user is logged in — read profile from Firestore.
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get();
      final data = doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};
      await _persistAndSetState(firebaseUser.uid, firebaseUser.email ?? '', data);
    } catch (e) {
      debugPrint('Firestore auto-login error: $e');
      // Fall back to local cache so the UI doesn't flash to onboarding.
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson) as Map<String, dynamic>;
          state = AuthState(
            token: userData['uid'] as String?,
            email: userData['email'] as String?,
            name: userData['name'] as String?,
            favouriteTeam: userData['favourite_team'] as String?,
            favouriteDriver: userData['favourite_driver'] as String?,
            country: userData['country'] as String?,
            rivalDriver: userData['rival_driver'] as String?);
          _updateAppTheme(userData['favourite_team'] as String?);
        } catch (_) {}
      }
    }
  }

  void _updateAppTheme(String? teamName) {
    if (teamName == null) return;
    try {
      final team = F1Team.values
          .firstWhere((t) => t.name.toLowerCase() == teamName.toLowerCase());
      _ref.read(themeProvider.notifier).selectTeam(team);
    } catch (_) {}
  }

  Future<void> _persistAndSetState(
      String uid, String email, Map<String, dynamic> data) async {
    final toStore = {
      'uid': uid,
      'email': email,
      'name': data['name'],
      'favourite_team': data['favourite_team'],
      'favourite_driver': data['favourite_driver'],
      'rival_driver': data['rival_driver'],
      'country': data['country'],
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(toStore));
    await prefs.setBool('onboarding_completed', true);

    state = AuthState(
      token: uid,
      email: email,
      name: data['name'] as String?,
      favouriteTeam: (data['favourite_team'] as String?) ?? 'Ferrari',
      favouriteDriver: data['favourite_driver'] as String?,
      country: data['country'] as String?,
      rivalDriver: data['rival_driver'] as String?);
    _updateAppTheme(data['favourite_team'] as String?);
  }

  String _extractErrorMessage(dynamic e, String fallback) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email is already registered.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        default:
          return e.message ?? fallback;
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
    String? rivalDriver,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password);
      final user = cred.user!;

      // Store profile in Firestore — this is the single source of truth.
      final profile = <String, dynamic>{
        'email': email.trim(),
        'name': name.isNotEmpty ? name : null,
        'favourite_team': favouriteTeam.isNotEmpty ? favouriteTeam : 'Ferrari',
        'favourite_driver': favouriteDriver.isNotEmpty ? favouriteDriver : null,
        'rival_driver': rivalDriver,
        'country': country,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      await _firestore.collection(_usersCollection).doc(user.uid).set(profile);

      await _persistAndSetState(user.uid, email.trim(), profile);
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
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password);
      final user = cred.user!;

      // Read profile from Firestore.
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      final data = doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};
      await _persistAndSetState(user.uid, user.email ?? email.trim(), data);
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
    String? rivalDriver,
    String? newPassword,
    String? country,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw Exception('Not authenticated');

      if (newPassword != null && newPassword.isNotEmpty) {
        await firebaseUser.updatePassword(newPassword);
      }

      final updates = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['name'] = name;
      if (favouriteDriver != null) updates['favourite_driver'] = favouriteDriver;
      if (rivalDriver != null) updates['rival_driver'] = rivalDriver;
      if (country != null) updates['country'] = country;

      await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .set(updates, SetOptions(merge: true));

      state = state.copyWith(
        isLoading: false,
        name: name ?? state.name,
        favouriteDriver: favouriteDriver ?? state.favouriteDriver,
        rivalDriver: rivalDriver ?? state.rivalDriver,
        country: country ?? state.country);

      // Update local cache.
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        if (name != null) userData['name'] = name;
        if (favouriteDriver != null) userData['favourite_driver'] = favouriteDriver;
        if (rivalDriver != null) userData['rival_driver'] = rivalDriver;
        if (country != null) userData['country'] = country;
        await prefs.setString(_userKey, jsonEncode(userData));
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Profile update failed');
      return false;
    }
  }

  Future<bool> updateFavouriteTeam(String teamName) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return false;

      await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .set({
        'favourite_team': teamName,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
      // 1. Delete Firestore profile.
      await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .delete();

      // 2. Best-effort: clean up backend picks/predictions.
      try {
        final idToken = await firebaseUser.getIdToken();
        await _dio.delete(
          '/api/auth/delete',
          options: Options(headers: {'Authorization': 'Bearer $idToken'}));
      } catch (backendErr) {
        debugPrint('Backend delete notice (proceeding): $backendErr');
      }

      // 3. Delete the Firebase Auth account.
      await firebaseUser.delete();
      await logout();
      return true;
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'requires-recent-login'
          ? 'Please sign out and sign back in, then try deleting again.'
          : e.message ?? 'Failed to delete account.';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to delete account');
      return false;
    }
  }

  /// Registers the given FCM token with the backend. Best-effort.
  Future<void> registerFcmToken(String token) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    try {
      final idToken = await firebaseUser.getIdToken();
      await _dio.put(
        '/api/auth/fcm-token',
        data: {'token': token},
        options: Options(headers: {'Authorization': 'Bearer $idToken'}));
    } catch (e) {
      debugPrint('FCM token register notice (non-fatal): $e');
    }
  }

  Future<void> _deleteFcmToken() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    try {
      final idToken = await firebaseUser.getIdToken();
      await _dio.delete(
        '/api/auth/fcm-token',
        options: Options(headers: {'Authorization': 'Bearer $idToken'}));
    } catch (e) {
      debugPrint('FCM token delete notice (non-fatal): $e');
    }
  }

  Future<void> logout() async {
    await _deleteFcmToken();
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
