import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../data/call_repository.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();
  @override List<Object?> get props => [];
}

class CallStarted extends CallEvent {
  final String receiverId, receiverName;
  final CallType type;
  const CallStarted({
    required this.receiverId,
    required this.receiverName,
    required this.type,
  });
  @override List<Object?> get props => [receiverId, receiverName, type];
}

class CallAnswered extends CallEvent {
  final CallModel call;
  const CallAnswered(this.call);
  @override List<Object?> get props => [call];
}

class CallEnded extends CallEvent {
  const CallEnded();
}

class CallDeclined extends CallEvent {
  const CallDeclined();
}

class _CallDocUpdated extends CallEvent {
  final Map<String, dynamic> data;
  const _CallDocUpdated(this.data);
  @override List<Object?> get props => [data];
}

class _RemoteIceCandidateAdded extends CallEvent {
  final RTCIceCandidate candidate;
  const _RemoteIceCandidateAdded(this.candidate);
  @override List<Object?> get props => [candidate];
}

class _RemoteStreamArrived extends CallEvent {
  const _RemoteStreamArrived();
}

class CallMicToggled   extends CallEvent { const CallMicToggled(); }
class CallCameraToggled extends CallEvent { const CallCameraToggled(); }
class CallCameraSwitched extends CallEvent { const CallCameraSwitched(); }

class IncomingCallReceived extends CallEvent {
  final CallModel call;
  const IncomingCallReceived(this.call);
  @override List<Object?> get props => [call];
}

class IncomingCallDismissed extends CallEvent {
  const IncomingCallDismissed();
}

class CallState extends Equatable {
  final CallStatus status;
  final CallModel? currentCall;
  final CallModel? incomingCall;  
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;

  final bool micMuted;
  final bool cameraOff;
  final bool isCaller;
  final String? error;

  const CallState({
    this.status = CallStatus.idle,
    this.currentCall,
    this.incomingCall,
    this.localRenderer,
    this.remoteRenderer,
    this.micMuted = false,
    this.cameraOff = false,
    this.isCaller = false,
    this.error,
  });

  bool get isActive =>
      status == CallStatus.calling ||
      status == CallStatus.ringing ||
      status == CallStatus.connected;

  CallState copyWith({
    CallStatus? status,
    CallModel? currentCall,
    bool clearCurrentCall = false,
    CallModel? incomingCall,
    bool clearIncoming = false,
    RTCVideoRenderer? localRenderer,
    RTCVideoRenderer? remoteRenderer,
    bool? micMuted,
    bool? cameraOff,
    bool? isCaller,
    String? error,
    bool clearError = false,
  }) =>
      CallState(
        status:         status         ?? this.status,
        currentCall:    clearCurrentCall ? null : (currentCall ?? this.currentCall),
        incomingCall:   clearIncoming    ? null : (incomingCall ?? this.incomingCall),
        localRenderer:  localRenderer  ?? this.localRenderer,
        remoteRenderer: remoteRenderer ?? this.remoteRenderer,
        micMuted:       micMuted       ?? this.micMuted,
        cameraOff:      cameraOff      ?? this.cameraOff,
        isCaller:       isCaller       ?? this.isCaller,
        error:          clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [
        status, currentCall, incomingCall,
        micMuted, cameraOff, isCaller, error,
      ];
}


class CallBloc extends Bloc<CallEvent, CallState> {
  final CallRepository repo;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _callId;

  StreamSubscription<DocumentSnapshot>?  _callDocSub;
  StreamSubscription<QuerySnapshot>?     _candidatesSub;
  StreamSubscription<QuerySnapshot>?     _incomingSub;

  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  CallBloc({required this.repo}) : super(const CallState()) {
    on<CallStarted>(_onCallStarted);
    on<CallAnswered>(_onCallAnswered);
    on<CallEnded>(_onCallEnded);
    on<CallDeclined>(_onCallDeclined);
    on<_CallDocUpdated>(_onCallDocUpdated);
    on<_RemoteIceCandidateAdded>(_onRemoteIceCandidate);
    on<_RemoteStreamArrived>((_, emit) =>
        emit(state.copyWith(remoteRenderer: _remoteRenderer)));
    on<CallMicToggled>(_onMicToggled);
    on<CallCameraToggled>(_onCameraToggled);
    on<CallCameraSwitched>(_onCameraSwitched);
    on<IncomingCallReceived>(_onIncomingCallReceived);
    on<IncomingCallDismissed>((_, emit) => emit(state.copyWith(clearIncoming: true)));

    _initRenderers();
    _listenForIncomingCalls();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  void _listenForIncomingCalls() {
    _incomingSub = repo.incomingCallStream().listen((snap) {
      if (snap.docs.isEmpty) return;
      if (state.isActive) return; 
      final data = snap.docs.first.data() as Map<String, dynamic>;
      final call = CallModel.fromMap(data);
      add(IncomingCallReceived(call));
    });
  }

  void _onIncomingCallReceived(
      IncomingCallReceived event, Emitter<CallState> emit) {
    emit(state.copyWith(incomingCall: event.call));
  }
  Future<void> _onCallStarted(
      CallStarted event, Emitter<CallState> emit) async {
    try {
      await _initRenderers();
      emit(state.copyWith(
        status: CallStatus.calling,
        isCaller: true,
        localRenderer: _localRenderer,
        remoteRenderer: _remoteRenderer,
      ));

      
      _localStream = await repo.getUserMedia(
          video: event.type == CallType.video);
      _localRenderer.srcObject = _localStream;
      emit(state.copyWith(localRenderer: _localRenderer));

      _pc = await repo.createPeerConnection();
      _setupPeerConnectionHandlers(isCaller: true);

      _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

      _callId = await repo.createCall(
        receiverId:   event.receiverId,
        receiverName: event.receiverName,
        type:         event.type,
      );

      final model = CallModel(
        callId:       _callId!,
        callerId:     repo.iceServers.toString(), 
        callerName:   '',
        receiverId:   event.receiverId,
        receiverName: event.receiverName,
        type:         event.type,
        status:       CallStatus.calling,
        createdAt:    DateTime.now(),
      );
      emit(state.copyWith(currentCall: model));

      final offer = await _pc!.createOffer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': 1});
      await _pc!.setLocalDescription(offer);
      await repo.setOffer(_callId!, offer);

      _listenToCallDoc();
      _listenToCalleeCandidates();

    } catch (e) {
      emit(state.copyWith(status: CallStatus.ended, error: e.toString()));
      await _cleanup();
    }
  }
  Future<void> _onCallAnswered(
      CallAnswered event, Emitter<CallState> emit) async {
    try {
      _callId = event.call.callId;
      await _initRenderers();
      emit(state.copyWith(
        status:         CallStatus.ringing,
        currentCall:    event.call,
        isCaller:       false,
        clearIncoming:  true,
        localRenderer:  _localRenderer,
        remoteRenderer: _remoteRenderer,
      ));

      
      _localStream = await repo.getUserMedia(
          video: event.call.type == CallType.video);
      _localRenderer.srcObject = _localStream;
      emit(state.copyWith(localRenderer: _localRenderer));

      
      _pc = await repo.createPeerConnection();
      _setupPeerConnectionHandlers(isCaller: false);

      _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

      final snap = await FirebaseFirestore.instance
          .collection('calls').doc(_callId).get();
      final data   = snap.data() as Map<String, dynamic>;
      final offerMap = data['offer'] as Map<String, dynamic>;
      final offer    = RTCSessionDescription(
          offerMap['sdp'] as String, offerMap['type'] as String);
      await _pc!.setRemoteDescription(offer);

      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await repo.setAnswer(_callId!, answer);
      await repo.updateStatus(_callId!, CallStatus.connected);

      _listenToCallerCandidates();
      _listenToCallDoc();

    } catch (e) {
      emit(state.copyWith(status: CallStatus.ended, error: e.toString()));
      await _cleanup();
    }
  }

  Future<void> _onCallEnded(CallEnded event, Emitter<CallState> emit) async {
    if (_callId != null) {
      await repo.updateStatus(_callId!, CallStatus.ended);
    }
    emit(state.copyWith(
        status: CallStatus.ended, clearCurrentCall: true, clearError: true));
    await _cleanup();
    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(status: CallStatus.idle));
  }

  Future<void> _onCallDeclined(
      CallDeclined event, Emitter<CallState> emit) async {
    if (_callId != null) {
      await repo.updateStatus(_callId!, CallStatus.declined);
    }
    emit(state.copyWith(
        status: CallStatus.ended, clearCurrentCall: true, clearIncoming: true));
    await _cleanup();
    await Future.delayed(const Duration(seconds: 1));
    emit(state.copyWith(status: CallStatus.idle));
  }

  void _listenToCallDoc() {
    _callDocSub?.cancel();
    _callDocSub = repo.callStream(_callId!).listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      add(_CallDocUpdated(data));
    });
  }

  Future<void> _onCallDocUpdated(
      _CallDocUpdated event, Emitter<CallState> emit) async {
    final data   = event.data;
    final status = callStatusFrom(data['status'] as String?);


    if (state.isCaller &&
        _pc != null &&
        data['answer'] != null &&
        (await _pc!.getRemoteDescription()) == null) {
      final answerMap = data['answer'] as Map<String, dynamic>;
      final answer    = RTCSessionDescription(
          answerMap['sdp'] as String, answerMap['type'] as String);
      await _pc!.setRemoteDescription(answer);
      emit(state.copyWith(status: CallStatus.connected));
      return;
    }

    if (status == CallStatus.ended || status == CallStatus.declined) {
      emit(state.copyWith(status: status, clearCurrentCall: true));
      await _cleanup();
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(status: CallStatus.idle));
    }
  }
  void _listenToCalleeCandidates() {
    _candidatesSub?.cancel();
    _candidatesSub = repo.calleeCandidatesStream(_callId!).listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data() as Map<String, dynamic>;
          add(_RemoteIceCandidateAdded(RTCIceCandidate(
            d['candidate'] as String?,
            d['sdpMid'] as String?,
            d['sdpMLineIndex'] as int?,
          )));
        }
      }
    });
  }

  void _listenToCallerCandidates() {
    _candidatesSub?.cancel();
    _candidatesSub = repo.callerCandidatesStream(_callId!).listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data() as Map<String, dynamic>;
          add(_RemoteIceCandidateAdded(RTCIceCandidate(
            d['candidate'] as String?,
            d['sdpMid'] as String?,
            d['sdpMLineIndex'] as int?,
          )));
        }
      }
    });
  }

  Future<void> _onRemoteIceCandidate(
      _RemoteIceCandidateAdded event, Emitter<CallState> emit) async {
    try {
      await _pc?.addCandidate(event.candidate);
    } catch (_) {}
  }

  void _setupPeerConnectionHandlers({required bool isCaller}) {
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      if (isCaller) {
        repo.addCallerCandidate(_callId!, candidate);
      } else {
        repo.addCalleeCandidate(_callId!, candidate);
      }
    };

    _pc!.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
      add(const _RemoteStreamArrived());
    };

    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        add(const _CallDocUpdated({'status': 'connected'}));
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        add(const CallEnded());
      }
    };
  }

  void _onMicToggled(CallMicToggled event, Emitter<CallState> emit) {
    final muted = !state.micMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
    emit(state.copyWith(micMuted: muted));
  }

  void _onCameraToggled(CallCameraToggled event, Emitter<CallState> emit) {
    final off = !state.cameraOff;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !off);
    emit(state.copyWith(cameraOff: off));
  }

  Future<void> _onCameraSwitched(
      CallCameraSwitched event, Emitter<CallState> emit) async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> _cleanup() async {
    _callDocSub?.cancel();
    _candidatesSub?.cancel();
    _callDocSub    = null;
    _candidatesSub = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    await _pc?.close();
    _pc = null;

    _localRenderer.srcObject  = null;
    _remoteRenderer.srcObject = null;
    _callId = null;
  }

  @override
  Future<void> close() async {
    await _cleanup();
    _incomingSub?.cancel();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    return super.close();
  }
}
