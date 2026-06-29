import 'dart:io';
import 'package:flutter/material.dart' show Color;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

const kGreen = Color(0xff075E54);
const kGreen2 = Color(0xff25D366);
const kBubbleMe = Color(0xffDCF8C6);
const kBgChat = Color(0xffECE5DD);
const kReactions = ['❤️', '😂', '😮', '😢', '🙏', '👍', '😁', '🥳'];

enum DisappearTimer { off, h24, d7, d90 }

extension DisappearTimerX on DisappearTimer {
  String get label {
    switch (this) {
      case DisappearTimer.off:
        return 'Off';
      case DisappearTimer.h24:
        return '24 hours';
      case DisappearTimer.d7:
        return '7 days';
      case DisappearTimer.d90:
        return '90 days';
    }
  }

  String get shortLabel {
    switch (this) {
      case DisappearTimer.off:
        return 'Off';
      case DisappearTimer.h24:
        return '24h';
      case DisappearTimer.d7:
        return '7d';
      case DisappearTimer.d90:
        return '90d';
    }
  }

  Duration? get duration {
    switch (this) {
      case DisappearTimer.off:
        return null;
      case DisappearTimer.h24:
        return const Duration(hours: 24);
      case DisappearTimer.d7:
        return const Duration(days: 7);
      case DisappearTimer.d90:
        return const Duration(days: 90);
    }
  }

  String get val => name;

  static DisappearTimer fromString(String? s) {
    switch (s) {
      case 'h24':
        return DisappearTimer.h24;
      case 'd7':
        return DisappearTimer.d7;
      case 'd90':
        return DisappearTimer.d90;
      default:
        return DisappearTimer.off;
    }
  }
}

enum MsgType { text, image, audio, video, file, deleted }

enum MsgStatus { sent, delivered, read }

MsgType typeFrom(String? s) {
  switch (s) {
    case 'image':
      return MsgType.image;
    case 'audio':
      return MsgType.audio;
    case 'video':
      return MsgType.video;
    case 'file':
      return MsgType.file;
    case 'deleted':
      return MsgType.deleted;
    default:
      return MsgType.text;
  }
}

extension MsgTypeX on MsgType {
  String get val => name;
}

class Msg {
  final String id, senderId, receiverId, text;
  final MsgType type;
  final String? fileUrl, fileName;
  final bool isRead;
  final Timestamp sentAt;
  final Timestamp? deliveredAt, readAt, editedAt;
  final String? replyToId, replyToText, replyToSender;
  final Map<String, List<String>> reactions;
  final bool isEdited;
  final Timestamp? expiresAt;

  const Msg({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.type,
    this.fileUrl,
    this.fileName,
    required this.isRead,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
    this.isEdited = false,
    this.expiresAt,
  });

  MsgStatus get status {
    if (isRead) return MsgStatus.read;
    if (deliveredAt != null) return MsgStatus.delivered;
    return MsgStatus.sent;
  }

  factory Msg.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawR = d['reactions'] as Map<String, dynamic>? ?? {};
    final reactions =
        rawR.map((k, v) => MapEntry(k, List<String>.from(v as List? ?? [])));
    return Msg(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      receiverId: d['receiverId'] as String? ?? '',
      text: d['message'] as String? ?? '',
      type: typeFrom(d['type'] as String?),
      fileUrl: d['fileUrl'] as String?,
      fileName: d['fileName'] as String?,
      isRead: d['isRead'] as bool? ?? false,
      sentAt: d['sentAt'] as Timestamp? ?? Timestamp.now(),
      deliveredAt: d['deliveredAt'] as Timestamp?,
      readAt: d['readAt'] as Timestamp?,
      editedAt: d['editedAt'] as Timestamp?,
      replyToId: d['replyToId'] as String?,
      replyToText: d['replyToText'] as String?,
      replyToSender: d['replyToSender'] as String?,
      reactions: reactions,
      isEdited: d['isEdited'] as bool? ?? false,
      expiresAt: d['expiresAt'] as Timestamp?,
    );
  }
}
class DioService {
  static final DioService _instance = DioService._internal();
  factory DioService() => _instance;
  late final Dio dio;

  DioService._internal() {
    dio = Dio(
      BaseOptions(
        
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          "Content-Type": "application/json",
          
        },
      ),
    );
    dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
    ));
  }

  Future<String> askGemini(String prompt) async {
    final response = await dio.post(
      "/v1beta/models/gemini-2.5-flash:generateContent",
      data: {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      },
    );
    return response.data["candidates"][0]["content"]["parts"][0]["text"];
  }

  Future<String> uploadFile({
    required File file,
    required String storagePath,
    void Function(double)? onProgress,
  }) async {
    final uploadDio = Dio();
    uploadDio.interceptors.add(PrettyDioLogger(error: true));

    final ref = FirebaseStorage.instance.ref(storagePath);
    final meta = SettableMetadata(contentType: _mimeFor(file.path));

    final task = ref.putFile(file, meta);
    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }
    await task;
    return await ref.getDownloadURL();
  }

  String _mimeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    const map = {
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.gif': 'image/gif', '.webp': 'image/webp',
      '.mp4': 'video/mp4', '.mov': 'video/quicktime',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.txt': 'text/plain',
      '.zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

class ChatRepository {
  final _db = FirebaseFirestore.instance;
  final DioService _dio = DioService();

  User get me => FirebaseAuth.instance.currentUser!;

  DioService get dio => _dio;

  String chatId(String a, String b) => ([a, b]..sort()).join('_');

  Stream<QuerySnapshot> messages(String cid) => _db
      .collection('chats')
      .doc(cid)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots();

  Future<String> sendMsg({
    required String receiverId,
    required String message,
    required MsgType type,
    String? fileUrl,
    String? fileName,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final cid = chatId(me.uid, receiverId);
    final ref = _db.collection('chats').doc(cid).collection('messages').doc();

    final chatDoc = await _db.collection('chats').doc(cid).get();
    final timerStr = chatDoc.exists
        ? (chatDoc.data() as Map<String, dynamic>)['disappearTimer'] as String?
        : null;
    final timer = DisappearTimerX.fromString(timerStr);
    final now = DateTime.now();
    final expires = timer.duration != null
        ? Timestamp.fromDate(now.add(timer.duration!))
        : null;

    await ref.set({
      'messageId': ref.id,
      'senderId': me.uid,
      'receiverId': receiverId,
      'message': message,
      'type': type.val,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (replyToId != null) ...{
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSender': replyToSender,
      },
      if (expires != null) 'expiresAt': expires,
      'reactions': {},
      'isEdited': false,
      'isRead': false,
      'sentAt': FieldValue.serverTimestamp(),
      'deliveredAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
    return ref.id;
  }

  Future<void> setDisappearTimer(String cid, DisappearTimer timer) async {
    await _db.collection('chats').doc(cid).set({
      'disappearTimer': timer.val,
      'disappearTimerSetBy': me.uid,
      'disappearTimerSetAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> chatSettingsStream(String cid) =>
      _db.collection('chats').doc(cid).snapshots();

  Future<int> purgeExpiredMessages(String cid) async {
    final now = Timestamp.now();
    final snap = await _db
        .collection('chats')
        .doc(cid)
        .collection('messages')
        .where('expiresAt', isLessThanOrEqualTo: now)
        .get();
    if (snap.docs.isEmpty) return 0;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }

  Future<void> editMsg(String cid, String msgId, String newText) async {
    await _db.collection('chats').doc(cid).collection('messages').doc(msgId).update({
      'message': newText,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteForEveryone(String cid, String msgId) async {
    await _db.collection('chats').doc(cid).collection('messages').doc(msgId).update({
      'message': 'This message was deleted',
      'type': 'deleted',
    });
  }

  Future<void> toggleReaction(
      String cid, String msgId, String emoji, Msg msg) async {
    final uid = me.uid;
    final cur = Map<String, List<String>>.from(msg.reactions);
    final users = List<String>.from(cur[emoji] ?? []);
    if (users.contains(uid)) {
      users.remove(uid);
    } else {
      for (final k in cur.keys) {
        cur[k]?.remove(uid);
      }
      users.add(uid);
    }
    cur[emoji] = users;
    cur.removeWhere((_, v) => v.isEmpty);
    await _db
        .collection('chats')
        .doc(cid)
        .collection('messages')
        .doc(msgId)
        .update({'reactions': cur});
  }

  Future<void> markRead(String cid, String senderUid) async {
    final snap = await _db
        .collection('chats')
        .doc(cid)
        .collection('messages')
        .where('senderId', isEqualTo: senderUid)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true, 'readAt': Timestamp.now()});
    }
    await batch.commit();
  }

  Stream<int> unreadCount(String cid, String myUid) => _db
      .collection('chats')
      .doc(cid)
      .collection('messages')
      .where('receiverId', isEqualTo: myUid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> setPresence({
    bool online = true,
    bool typing = false,
    bool recording = false,
    String? typingIn,
  }) async {
    await _db.collection('presence').doc(me.uid).set({
      'uid': me.uid,
      'online': online,
      'typing': typing,
      'recording': recording,
      'typingIn': typingIn ?? '',
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> presenceStream(String uid) =>
      _db.collection('presence').doc(uid).snapshots();

  Stream<QuerySnapshot> users() => _db.collection('users').snapshots();

  Future<void> saveUser(User u) async {
    await _db.collection('users').doc(u.uid).set({
      'uid': u.uid,
      'email': u.email ?? '',
      'name': u.displayName ?? u.email!.split('@')[0],
    }, SetOptions(merge: true));
    await setPresence(online: true);
  }

  Future<String> uploadAndGetUrl({
    required File file,
    required String storagePath,
    void Function(double)? onProgress,
  }) =>
      _dio.uploadFile(file: file, storagePath: storagePath, onProgress: onProgress);

  Future<String> askGemini(String prompt) => _dio.askGemini(prompt);
}