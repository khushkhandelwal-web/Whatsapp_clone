import 'package:cloud_firestore/cloud_firestore.dart';

class AppUtils {
  AppUtils._();

  static String chatId(String a, String b) => ([a, b]..sort()).join('_');

  static String formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt  = ts.toDate();
    final now = DateTime.now();
    final h   = dt.hour.toString().padLeft(2, '0');
    final mn  = dt.minute.toString().padLeft(2, '0');
    if (now.difference(dt).inDays == 0) return '$h:$mn';
    if (now.difference(dt).inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String formatLastSeen(Timestamp? ts) {
    if (ts == null) return '';
    final dt  = ts.toDate();
    final now = DateTime.now();
    final h   = dt.hour.toString().padLeft(2, '0');
    final mn  = dt.minute.toString().padLeft(2, '0');
    return now.difference(dt).inDays == 0
        ? 'last seen today at $h:$mn'
        : 'last seen ${dt.day}/${dt.month}';
  }
}