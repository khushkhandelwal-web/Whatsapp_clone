import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:khush_chat/features/chat/data/%20models/repositories/chat_repository.dart';
import '../data/models/message_model.dart';

class ChatState extends Equatable {
  final List<MessageModel> allMessages;
  final List<MessageModel> visibleMessages;
  final bool               loadingMessages;

  // Peer presence
  final bool       peerOnline, peerTyping, peerRecording;
  final Timestamp? peerLastSeen;

  // Disappear timer
  final DisappearTimer disappearTimer;

  // Reply / edit drafts
  final MessageModel? replyMsg;
  final MessageModel? editMsg;

  // AI / upload
  final bool   aiLoading;
  final bool   uploading;
  final double uploadProgress;

  // Search
  final bool   searching;
  final String searchQuery;

  // Feedback
  final String? error;
  final String? infoMessage;

  const ChatState({
    this.allMessages      = const [],
    this.visibleMessages  = const [],
    this.loadingMessages  = true,
    this.peerOnline       = false,
    this.peerTyping       = false,
    this.peerRecording    = false,
    this.peerLastSeen,
    this.disappearTimer   = DisappearTimer.off,
    this.replyMsg,
    this.editMsg,
    this.aiLoading        = false,
    this.uploading        = false,
    this.uploadProgress   = 0,
    this.searching        = false,
    this.searchQuery      = '',
    this.error,
    this.infoMessage,
  });

  ChatState copyWith({
    List<MessageModel>? allMessages,
    List<MessageModel>? visibleMessages,
    bool?               loadingMessages,
    bool?               peerOnline,
    bool?               peerTyping,
    bool?               peerRecording,
    Timestamp?          peerLastSeen,
    DisappearTimer?     disappearTimer,
    MessageModel?       replyMsg,
    bool                clearReply   = false,
    MessageModel?       editMsg,
    bool                clearEdit    = false,
    bool?               aiLoading,
    bool?               uploading,
    double?             uploadProgress,
    bool?               searching,
    String?             searchQuery,
    String?             error,
    bool                clearError   = false,
    String?             infoMessage,
    bool                clearInfo    = false,
  }) => ChatState(
    allMessages:     allMessages     ?? this.allMessages,
    visibleMessages: visibleMessages ?? this.visibleMessages,
    loadingMessages: loadingMessages ?? this.loadingMessages,
    peerOnline:      peerOnline      ?? this.peerOnline,
    peerTyping:      peerTyping      ?? this.peerTyping,
    peerRecording:   peerRecording   ?? this.peerRecording,
    peerLastSeen:    peerLastSeen    ?? this.peerLastSeen,
    disappearTimer:  disappearTimer  ?? this.disappearTimer,
    replyMsg:        clearReply  ? null : (replyMsg  ?? this.replyMsg),
    editMsg:         clearEdit   ? null : (editMsg   ?? this.editMsg),
    aiLoading:       aiLoading       ?? this.aiLoading,
    uploading:       uploading       ?? this.uploading,
    uploadProgress:  uploadProgress  ?? this.uploadProgress,
    searching:       searching       ?? this.searching,
    searchQuery:     searchQuery     ?? this.searchQuery,
    error:           clearError  ? null : (error     ?? this.error),
    infoMessage:     clearInfo   ? null : (infoMessage ?? this.infoMessage),
  );

  @override
  List<Object?> get props => [
    allMessages, visibleMessages, loadingMessages,
    peerOnline, peerTyping, peerRecording, peerLastSeen,
    disappearTimer, replyMsg, editMsg,
    aiLoading, uploading, uploadProgress,
    searching, searchQuery, error, infoMessage,
  ];
}

class MessageModel {
}