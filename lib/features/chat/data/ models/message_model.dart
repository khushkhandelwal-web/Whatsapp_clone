import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ─────────────────────────────────────

enum MsgType   { text, image, audio, video, file, deleted }
enum MsgStatus { sent, delivered, read }
enum DisappearTimer { off, h24, d7, d90 }

extension DisappearTimerX on DisappearTimer {
  String get label {
    switch (this) {
      case DisappearTimer.off: return 'Off';
      case DisappearTimer.h24: return '24 hours';
      case DisappearTimer.d7:  return '7 days';
      case DisappearTimer.d90: return '90 days';
    }
  }
  String get shortLabel {
    switch (this) {
      case DisappearTimer.off: return 'Off';
      case DisappearTimer.h24: return '24h';
      case DisappearTimer.d7:  return '7d';
      case DisappearTimer.d90: return '90d';
    }
  }
  Duration? get duration {
    switch (this) {
      case DisappearTimer.off: return null;
      case DisappearTimer.h24: return const Duration(hours: 24);
      case DisappearTimer.d7:  return const Duration(days: 7);
      case DisappearTimer.d90: return const Duration(days: 90);
    }
  }
  String get val => name;
  static DisappearTimer fromString(String? s) {
    switch (s) {
      case 'h24': return DisappearTimer.h24;
      case 'd7':  return DisappearTimer.d7;
      case 'd90': return DisappearTimer.d90;
      default:    return DisappearTimer.off;
    }
  }
}

MsgType typeFrom(String? s) {
  switch (s) {
    case 'image':   return MsgType.image;
    case 'audio':   return MsgType.audio;
    case 'video':   return MsgType.video;
    case 'file':    return MsgType.file;
    case 'deleted': return MsgType.deleted;
    default:        return MsgType.text;
  }
}

extension MsgTypeX on MsgType { String get val => name; }

// ── Msg model ─────────────────────────────────

class Msg {
  final String   id, senderId, receiverId, text;
  final MsgType  type;
  final String?  fileUrl, fileName;
  final bool     isRead;
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
    this.expiresAt,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
    this.isEdited  = false,
  });

  MsgStatus get status {
    if (isRead)              return MsgStatus.read;
    if (deliveredAt != null) return MsgStatus.delivered;
    return MsgStatus.sent;
  }

  factory Msg.fromDoc(DocumentSnapshot doc) {
    final d    = doc.data() as Map<String, dynamic>;
    final rawR = d['reactions'] as Map<String, dynamic>? ?? {};
    return Msg(
      id:            doc.id,
      senderId:      d['senderId']      as String?    ?? '',
      receiverId:    d['receiverId']    as String?    ?? '',
      text:          d['message']       as String?    ?? '',
      type:          typeFrom(d['type'] as String?),
      fileUrl:       d['fileUrl']       as String?,
      fileName:      d['fileName']      as String?,
      isRead:        d['isRead']        as bool?      ?? false,
      sentAt:        d['sentAt']        as Timestamp? ?? Timestamp.now(),
      deliveredAt:   d['deliveredAt']   as Timestamp?,
      readAt:        d['readAt']        as Timestamp?,
      editedAt:      d['editedAt']      as Timestamp?,
      expiresAt:     d['expiresAt']     as Timestamp?,
      replyToId:     d['replyToId']     as String?,
      replyToText:   d['replyToText']   as String?,
      replyToSender: d['replyToSender'] as String?,
      reactions:     rawR.map((k, v) =>
          MapEntry(k, List<String>.from(v as List? ?? []))),
      isEdited:      d['isEdited']      as bool?      ?? false,
    );
  }
}