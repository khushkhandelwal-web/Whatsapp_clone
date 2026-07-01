import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';


enum CallType { voice, video }
enum CallStatus { idle, calling, ringing, connected, ended, declined, missed }

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;

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
        callId: d['callId'] as String,
        callerId: d['callerId'] as String,
        callerName: d['callerName'] as String,
        receiverId: d['receiverId'] as String,
        receiverName: d['receiverName'] as String,
        type: (d['type'] as String?) == 'video' ? CallType.video : CallType.voice,
        status: _statusFrom(d['status'] as String?),
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'type': type == CallType.video ? 'video' : 'voice',
        'status': _statusStr(status),
        'createdAt': FieldValue.serverTimestamp(),
      };

  static CallStatus _statusFrom(String? s) => callStatusFrom(s);
  static String _statusStr(CallStatus s)   => callStatusStr(s);
}

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

const _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
  ]
};


class CallRepository {
  final _db   = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  User get _me => FirebaseAuth.instance.currentUser!;

  DocumentReference _callDoc(String callId) =>
      _db.collection('calls').doc(callId);

  CollectionReference _callerCandidates(String callId) =>
      _callDoc(callId).collection('callerCandidates');

  CollectionReference _calleeCandidates(String callId) =>
      _callDoc(callId).collection('calleeCandidates');

  Future<String> createCall({
    required String receiverId,
    required String receiverName,
    required CallType type,
  }) async {
    final callId = _uuid.v4();
    final model = CallModel(
      callId: callId,
      callerId: _me.uid,
      callerName: _me.displayName ?? _me.email!.split('@')[0],
      receiverId: receiverId,
      receiverName: receiverName,
      type: type,
      status: CallStatus.calling,
      createdAt: DateTime.now(),
    );
    await _callDoc(callId).set(model.toMap());
    return callId;
  }

  Future<void> updateStatus(String callId, CallStatus status) =>
      _callDoc(callId).update({'status': callStatusStr(status)});

  Future<void> setOffer(String callId, RTCSessionDescription offer) =>
      _callDoc(callId).update({
        'offer': {'type': offer.type, 'sdp': offer.sdp}
      });

  Future<void> setAnswer(String callId, RTCSessionDescription answer) =>
      _callDoc(callId).update({
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      });

  Future<void> addCallerCandidate(String callId, RTCIceCandidate c) =>
      _callerCandidates(callId).add({
        'candidate':     c.candidate,
        'sdpMid':        c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });

  Future<void> addCalleeCandidate(String callId, RTCIceCandidate c) =>
      _calleeCandidates(callId).add({
        'candidate':     c.candidate,
        'sdpMid':        c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });

  Stream<DocumentSnapshot> callStream(String callId) =>
      _callDoc(callId).snapshots();

  Stream<QuerySnapshot> callerCandidatesStream(String callId) =>
      _callerCandidates(callId).snapshots();

  Stream<QuerySnapshot> calleeCandidatesStream(String callId) =>
      _calleeCandidates(callId).snapshots();

  Stream<QuerySnapshot> incomingCallStream() => _db
      .collection('calls')
      .where('receiverId', isEqualTo: _me.uid)
      .where('status', isEqualTo: 'calling')
      .snapshots();

  Future<RTCPeerConnection> createPeerConnection() =>
      createPeerConnectionFromMap(_iceServers);

  Future<MediaStream> getUserMedia({required bool video}) =>
      navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      });

  Future<void> deleteCall(String callId) async {
    final callerSnap = await _callerCandidates(callId).get();
    final calleeSnap = await _calleeCandidates(callId).get();
    final batch = _db.batch();
    for (final d in callerSnap.docs) { batch.delete(d.reference); }
    for (final d in calleeSnap.docs)  { batch.delete(d.reference); }
    batch.delete(_callDoc(callId));
    await batch.commit();
  }

  Map<String, dynamic> get iceServers => _iceServers;
}
Future<RTCPeerConnection> createPeerConnectionFromMap(
        Map<String, dynamic> config) =>
    createPeerConnection(config);