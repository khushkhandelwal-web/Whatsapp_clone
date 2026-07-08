import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khush_chat/features/chat/data/%20models/repositories/chat_repository.dart';
import 'package:path/path.dart' as p;
import '../data/models/message_model.dart';
import '../data/repositories/chat_repository.dart';



abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

/// Call once when ChatScreen opens. Wires up the messages stream,
/// presence stream, marks read, purges expired msgs, loads timer setting.
class ChatStarted extends ChatEvent {
  final String myUid, peerUid, peerName;
  const ChatStarted(
      {required this.myUid, required this.peerUid, required this.peerName});
  @override
  List<Object?> get props => [myUid, peerUid, peerName];
}

class _MessagesUpdated extends ChatEvent {
  final List<Msg> messages;
  const _MessagesUpdated(this.messages);
  @override
  List<Object?> get props => [messages];
}

class _PeerPresenceUpdated extends ChatEvent {
  final bool online, typing, recording;
  final Timestamp? lastSeen;
  const _PeerPresenceUpdated({
    required this.online,
    required this.typing,
    required this.recording,
    this.lastSeen,
  });
  @override
  List<Object?> get props => [online, typing, recording, lastSeen];
}

class _DisappearTimerLoaded extends ChatEvent {
  final DisappearTimer timer;
  const _DisappearTimerLoaded(this.timer);
  @override
  List<Object?> get props => [timer];
}

class ChatTextChanged extends ChatEvent {
  final String text;
  const ChatTextChanged(this.text);
  @override
  List<Object?> get props => [text];
}

class ChatSendOrEditPressed extends ChatEvent {
  final String text;
  const ChatSendOrEditPressed(this.text);
  @override
  List<Object?> get props => [text];
}

class ChatAskAiPressed extends ChatEvent {
  final String text;
  const ChatAskAiPressed(this.text);
  @override
  List<Object?> get props => [text];
}

class ChatFilePicked extends ChatEvent {
  final File file;
  final MsgType type;
  final String? fileName;
  const ChatFilePicked(this.file, this.type, {this.fileName});
  @override
  List<Object?> get props => [file, type, fileName];
}

class ChatReplyStarted extends ChatEvent {
  final Msg msg;
  const ChatReplyStarted(this.msg);
  @override
  List<Object?> get props => [msg];
}

class ChatEditStarted extends ChatEvent {
  final Msg msg;
  const ChatEditStarted(this.msg);
  @override
  List<Object?> get props => [msg];
}

class ChatDraftCancelled extends ChatEvent {
  const ChatDraftCancelled();
}

class ChatReactionToggled extends ChatEvent {
  final Msg msg;
  final String emoji;
  const ChatReactionToggled(this.msg, this.emoji);
  @override
  List<Object?> get props => [msg, emoji];
}

class ChatMessageDeletedForEveryone extends ChatEvent {
  final Msg msg;
  const ChatMessageDeletedForEveryone(this.msg);
  @override
  List<Object?> get props => [msg];
}

class ChatDisappearTimerSet extends ChatEvent {
  final DisappearTimer timer;
  const ChatDisappearTimerSet(this.timer);
  @override
  List<Object?> get props => [timer];
}

class ChatSearchToggled extends ChatEvent {
  final bool searching;
  const ChatSearchToggled(this.searching);
  @override
  List<Object?> get props => [searching];
}

class ChatSearchQueryChanged extends ChatEvent {
  final String query;
  const ChatSearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class ChatAppResumed extends ChatEvent {
  const ChatAppResumed();
}

class ChatAppPaused extends ChatEvent {
  const ChatAppPaused();
}

class ChatClosed extends ChatEvent {
  const ChatClosed();
}

// ───────────────────────────── State ─────────────────────────────

class ChatState extends Equatable {
  final List<Msg> allMessages;
  final List<Msg> visibleMessages; // filtered by search query
  final bool loadingMessages;

  final bool peerOnline, peerTyping, peerRecording;
  final Timestamp? peerLastSeen;

  final DisappearTimer disappearTimer;

  final Msg? replyMsg;
  final Msg? editMsg;

  final bool aiLoading;
  final bool uploading;
  final double uploadProgress;

  final bool searching;
  final String searchQuery;

  final String? error;
  final String? infoMessage; // for one-off snackbar-style messages

  const ChatState({
    this.allMessages = const [],
    this.visibleMessages = const [],
    this.loadingMessages = true,
    this.peerOnline = false,
    this.peerTyping = false,
    this.peerRecording = false,
    this.peerLastSeen,
    this.disappearTimer = DisappearTimer.off,
    this.replyMsg,
    this.editMsg,
    this.aiLoading = false,
    this.uploading = false,
    this.uploadProgress = 0,
    this.searching = false,
    this.searchQuery = '',
    this.error,
    this.infoMessage,
  });

  ChatState copyWith({
    List<Msg>? allMessages,
    List<Msg>? visibleMessages,
    bool? loadingMessages,
    bool? peerOnline,
    bool? peerTyping,
    bool? peerRecording,
    Timestamp? peerLastSeen,
    DisappearTimer? disappearTimer,
    Msg? replyMsg,
    bool clearReply = false,
    Msg? editMsg,
    bool clearEdit = false,
    bool? aiLoading,
    bool? uploading,
    double? uploadProgress,
    bool? searching,
    String? searchQuery,
    String? error,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) =>
      ChatState(
        allMessages: allMessages ?? this.allMessages,
        visibleMessages: visibleMessages ?? this.visibleMessages,
        loadingMessages: loadingMessages ?? this.loadingMessages,
        peerOnline: peerOnline ?? this.peerOnline,
        peerTyping: peerTyping ?? this.peerTyping,
        peerRecording: peerRecording ?? this.peerRecording,
        peerLastSeen: peerLastSeen ?? this.peerLastSeen,
        disappearTimer: disappearTimer ?? this.disappearTimer,
        replyMsg: clearReply ? null : (replyMsg ?? this.replyMsg),
        editMsg: clearEdit ? null : (editMsg ?? this.editMsg),
        aiLoading: aiLoading ?? this.aiLoading,
        uploading: uploading ?? this.uploading,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        searching: searching ?? this.searching,
        searchQuery: searchQuery ?? this.searchQuery,
        error: clearError ? null : (error ?? this.error),
        infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      );

  @override
  List<Object?> get props => [
        allMessages,
        visibleMessages,
        loadingMessages,
        peerOnline,
        peerTyping,
        peerRecording,
        peerLastSeen,
        disappearTimer,
        replyMsg,
        editMsg,
        aiLoading,
        uploading,
        uploadProgress,
        searching,
        searchQuery,
        error,
        infoMessage,
      ];
}

// ───────────────────────────── Bloc ─────────────────────────────

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repo;

  late String _myUid;
  late String _peerUid;
  late String _peerName;
  late String _cid;
  bool _isTyping = false;

  StreamSubscription<QuerySnapshot>? _msgSub;
  StreamSubscription<DocumentSnapshot>? _presenceSub;

  String get cid => _cid;

  ChatBloc({required this.repo}) : super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<_MessagesUpdated>(_onMessagesUpdated);
    on<_PeerPresenceUpdated>(_onPeerPresenceUpdated);
    on<_DisappearTimerLoaded>((e, emit) =>
        emit(state.copyWith(disappearTimer: e.timer)));
    on<ChatTextChanged>(_onTextChanged);
    on<ChatSendOrEditPressed>(_onSendOrEditPressed);
    on<ChatAskAiPressed>(_onAskAiPressed);
    on<ChatFilePicked>(_onFilePicked);
    on<ChatReplyStarted>((e, emit) =>
        emit(state.copyWith(replyMsg: e.msg, clearEdit: true)));
    on<ChatEditStarted>((e, emit) =>
        emit(state.copyWith(editMsg: e.msg, clearReply: true)));
    on<ChatDraftCancelled>((e, emit) =>
        emit(state.copyWith(clearReply: true, clearEdit: true)));
    on<ChatReactionToggled>(_onReactionToggled);
    on<ChatMessageDeletedForEveryone>(_onMessageDeleted);
    on<ChatDisappearTimerSet>(_onDisappearTimerSet);
    on<ChatSearchToggled>(_onSearchToggled);
    on<ChatSearchQueryChanged>(_onSearchQueryChanged);
    on<ChatAppResumed>(_onAppResumed);
    on<ChatAppPaused>(_onAppPaused);
    on<ChatClosed>(_onClosed);
  }

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    _myUid = event.myUid;
    _peerUid = event.peerUid;
    _peerName = event.peerName;
    _cid = repo.chatId(_myUid, _peerUid);

    await repo.setPresence(online: true);
    await repo.markRead(_cid, _peerUid);
    await repo.purgeExpiredMessages(_cid);

    final doc = await FirebaseFirestore.instance.collection('chats').doc(_cid).get();
    if (doc.exists) {
      final t = (doc.data() as Map<String, dynamic>)['disappearTimer'] as String?;
      add(_DisappearTimerLoaded(DisappearTimerX.fromString(t)));
    }

    await _msgSub?.cancel();
    _msgSub = repo.messages(_cid).listen((snap) {
      final msgs = snap.docs.map(Msg.fromDoc).toList();
      add(_MessagesUpdated(msgs));
      // Mark read whenever the stream emits, matching original behavior.
      repo.markRead(_cid, _peerUid);
    });

    await _presenceSub?.cancel();
    _presenceSub = repo.presenceStream(_peerUid).listen((snap) {
      if (!snap.exists) return;
      final p = snap.data() as Map<String, dynamic>;
      final online = p['online'] as bool? ?? false;
      final typing = (p['typing'] as bool? ?? false) &&
          (p['typingIn'] as String? ?? '') == _cid;
      final recording = (p['recording'] as bool? ?? false) &&
          (p['typingIn'] as String? ?? '') == _cid;
      add(_PeerPresenceUpdated(
        online: online,
        typing: typing,
        recording: recording,
        lastSeen: p['lastSeen'] as Timestamp?,
      ));
    });
  }

  void _onMessagesUpdated(_MessagesUpdated event, Emitter<ChatState> emit) {
    final visible = state.searchQuery.isEmpty
        ? event.messages
        : event.messages
            .where((m) => m.text.toLowerCase().contains(state.searchQuery))
            .toList();
    emit(state.copyWith(
      allMessages: event.messages,
      visibleMessages: visible,
      loadingMessages: false,
    ));
  }

  void _onPeerPresenceUpdated(
      _PeerPresenceUpdated event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      peerOnline: event.online,
      peerTyping: event.typing,
      peerRecording: event.recording,
      peerLastSeen: event.lastSeen,
    ));
  }

  Future<void> _onTextChanged(
      ChatTextChanged event, Emitter<ChatState> emit) async {
    final hasText = event.text.trim().isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      await repo.setPresence(online: true, typing: true, typingIn: _cid);
    } else if (!hasText && _isTyping) {
      _isTyping = false;
      await repo.setPresence(online: true, typing: false, typingIn: '');
    }
  }

  Future<void> _onSendOrEditPressed(
      ChatSendOrEditPressed event, Emitter<ChatState> emit) async {
    final t = event.text.trim();
    if (t.isEmpty) return;

    if (state.editMsg != null) {
      await repo.editMsg(_cid, state.editMsg!.id, t);
      emit(state.copyWith(clearEdit: true));
    } else {
      await repo.sendMsg(
        receiverId: _peerUid,
        message: t,
        type: MsgType.text,
        replyToId: state.replyMsg?.id,
        replyToText: state.replyMsg?.text,
        replyToSender:
            state.replyMsg?.senderId == _myUid ? 'You' : _peerName,
      );
      emit(state.copyWith(clearReply: true));
    }

    _isTyping = false;
    await repo.setPresence(online: true, typing: false, typingIn: '');
  }

  Future<void> _onAskAiPressed(
      ChatAskAiPressed event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    if (text.isEmpty) return;
    emit(state.copyWith(aiLoading: true, clearError: true));
    try {
      await repo.sendMsg(receiverId: _peerUid, message: text, type: MsgType.text);
      final reply = await repo.askGemini(text);
      await repo.sendMsg(
          receiverId: _peerUid, message: "🤖 $reply", type: MsgType.text);
      emit(state.copyWith(aiLoading: false));
    } catch (e) {
      emit(state.copyWith(aiLoading: false, error: e.toString()));
    }
  }

  Future<void> _onFilePicked(
      ChatFilePicked event, Emitter<ChatState> emit) async {
    emit(state.copyWith(uploading: true, uploadProgress: 0, clearError: true));
    try {
      final name = event.fileName ?? p.basename(event.file.path);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'chat_files/$_cid/${ts}_$name';

      final url = await repo.uploadAndGetUrl(
        file: event.file,
        storagePath: path,
        onProgress: (v) => emit(state.copyWith(uploadProgress: v)),
      );

      await repo.sendMsg(
        receiverId: _peerUid,
        message: event.type == MsgType.image
            ? '📷 Photo'
            : event.type == MsgType.video
                ? '🎥 Video'
                : '📄 $name',
        type: event.type,
        fileUrl: url,
        fileName: name,
      );
      emit(state.copyWith(uploading: false, uploadProgress: 0));
    } catch (e) {
      emit(state.copyWith(
          uploading: false, uploadProgress: 0, error: 'Upload failed: $e'));
    }
  }

  Future<void> _onReactionToggled(
      ChatReactionToggled event, Emitter<ChatState> emit) async {
    await repo.toggleReaction(_cid, event.msg.id, event.emoji, event.msg);
  }

  Future<void> _onMessageDeleted(
      ChatMessageDeletedForEveryone event, Emitter<ChatState> emit) async {
    await repo.deleteForEveryone(_cid, event.msg.id);
  }

  Future<void> _onDisappearTimerSet(
      ChatDisappearTimerSet event, Emitter<ChatState> emit) async {
    await repo.setDisappearTimer(_cid, event.timer);
    emit(state.copyWith(
      disappearTimer: event.timer,
      infoMessage: event.timer == DisappearTimer.off
          ? 'Disappearing messages turned off'
          : 'Messages will disappear after ${event.timer.label}',
    ));
  }

  void _onSearchToggled(ChatSearchToggled event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      searching: event.searching,
      searchQuery: event.searching ? state.searchQuery : '',
      visibleMessages: event.searching ? state.visibleMessages : state.allMessages,
    ));
  }

  void _onSearchQueryChanged(
      ChatSearchQueryChanged event, Emitter<ChatState> emit) {
    final q = event.query.toLowerCase();
    final visible = q.isEmpty
        ? state.allMessages
        : state.allMessages.where((m) => m.text.toLowerCase().contains(q)).toList();
    emit(state.copyWith(searchQuery: q, visibleMessages: visible));
  }

  Future<void> _onAppResumed(
      ChatAppResumed event, Emitter<ChatState> emit) async {
    await repo.setPresence(online: true);
    await repo.markRead(_cid, _peerUid);
  }

  Future<void> _onAppPaused(
      ChatAppPaused event, Emitter<ChatState> emit) async {
    await repo.setPresence(online: false, typing: false);
  }

  Future<void> _onClosed(ChatClosed event, Emitter<ChatState> emit) async {
    await repo.setPresence(online: true, typing: false, typingIn: '');
  }

  @override
  Future<void> close() {
    _msgSub?.cancel();
    _presenceSub?.cancel();
    return super.close();
  }
}