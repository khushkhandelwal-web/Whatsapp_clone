import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType   { voice, video }
enum CallStatus { idle, calling, ringing, connected, ended, declined, missed }

CallStatus callStatusFrom(String? s) {
  switch (s) {
    case 'calling':   return CallStatus.calling;
    case 'ringing':   return CallStatus.ringing;
    case 'connected': return CallStatus.connected;
    case 'ended':     return CallStatus.ended;
    case 'declined':  return CallStatus.declined;
    case 'missed':    return CallStatus.missed;
    default:          return CallStatus.idle;
  }
}

String callStatusStr(CallStatus s) {
  switch (s) {
    case CallStatus.calling:   return 'calling';
    case CallStatus.ringing:   return 'ringing';
    case CallStatus.connected: return 'connected';
    case CallStatus.ended:     return 'ended';
    case CallStatus.declined:  return 'declined';
    case CallStatus.missed:    return 'missed';
    default:                   return 'idle';
  }
}

class CallModel {
  final String     callId, callerId, callerName, receiverId, receiverName;
  final CallType   type;
  final CallStatus status;
  final DateTime   createdAt;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory CallModel.fromMap(Map<String, dynamic> d) => CallModel(
    callId:       d['callId']       as String,
    callerId:     d['callerId']     as String,
    callerName:   d['callerName']   as String,
    receiverId:   d['receiverId']   as String,
    receiverName: d['receiverName'] as String,
    type:   (d['type'] as String?) == 'video'
        ? CallType.video : CallType.voice,
    status:    callStatusFrom(d['status'] as String?),
    createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'callId':       callId,
    'callerId':     callerId,
    'callerName':   callerName,
    'receiverId':   receiverId,
    'receiverName': receiverName,
    'type':         type == CallType.video ? 'video' : 'voice',
    'status':       callStatusStr(status),
    'createdAt':    FieldValue.serverTimestamp(),
  };
}