import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const _secure = FlutterSecureStorage();

  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      try {
        await _secure.write(key: key, value: value);
      } catch (_) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      }
    }
  }

  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      try {
        final val = await _secure.read(key: key);
        if (val != null) return val;
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      try {
        await _secure.delete(key: key);
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  static Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } else {
      try {
        await _secure.deleteAll();
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }
}
