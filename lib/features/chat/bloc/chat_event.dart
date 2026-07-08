import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:khush_chat/features/chat/bloc/chat_state.dart';
import 'package:khush_chat/features/chat/data/%20models/repositories/chat_repository.dart';
import '../data/models/message_model.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  final String myUid, peerUid, peerName;
  const ChatStarted({
    required this.myUid,
    required this.peerUid,
    required this.peerName,
  });
  @override List<Object?> get props => [myUid, peerUid, peerName];
}

class ChatMessagesUpdated extends ChatEvent {
  final List<MessageModel> messages;
  const ChatMessagesUpdated(this.messages);
  @override List<Object?> get props => [messages];
}

class ChatPeerPresenceUpdated extends ChatEvent {
  final bool online, typing, recording;
  final Timestamp? lastSeen;
  const ChatPeerPresenceUpdated({
    required this.online,
    required this.typing,
    required this.recording,
    this.lastSeen,
  });
  @override List<Object?> get props => [online, typing, recording, lastSeen];
}

class ChatTextChanged    extends ChatEvent {
  final String text;
  const ChatTextChanged(this.text);
  @override List<Object?> get props => [text];
}

class ChatMessageSent    extends ChatEvent {
  final String text;
  const ChatMessageSent(this.text);
  @override List<Object?> get props => [text];
}

class ChatAiRequested    extends ChatEvent {
  final String text;
  const ChatAiRequested(this.text);
  @override List<Object?> get props => [text];
}

class ChatFilePicked     extends ChatEvent {
  final File file;
  final MessageType type;
  final String? fileName;
  const ChatFilePicked(this.file, this.type, {this.fileName});
  @override List<Object?> get props => [file, type, fileName];
}

class ChatReplyStarted   extends ChatEvent {
  final MessageModel msg;
  const ChatReplyStarted(this.msg);
  @override List<Object?> get props => [msg];
}

class ChatEditStarted    extends ChatEvent {
  final MessageModel msg;
  const ChatEditStarted(this.msg);
  @override List<Object?> get props => [msg];
}

class ChatDraftCancelled extends ChatEvent { const ChatDraftCancelled(); }

class ChatReactionToggled extends ChatEvent {
  final MessageModel msg;
  final String emoji;
  const ChatReactionToggled(this.msg, this.emoji);
  @override List<Object?> get props => [msg, emoji];
}

class ChatMessageDeleted extends ChatEvent {
  final MessageModel msg;
  const ChatMessageDeleted(this.msg);
  @override List<Object?> get props => [msg];
}

class ChatDisappearTimerChanged extends ChatEvent {
  final DisappearTimer timer;
  const ChatDisappearTimerChanged(this.timer);
  @override List<Object?> get props => [timer];
}

class ChatSearchToggled  extends ChatEvent {
  final bool active;
  const ChatSearchToggled(this.active);
  @override List<Object?> get props => [active];
}

class ChatSearchQueryChanged extends ChatEvent {
  final String query;
  const ChatSearchQueryChanged(this.query);
  @override List<Object?> get props => [query];
}

class ChatAppResumed     extends ChatEvent { const ChatAppResumed(); }
class ChatAppPaused      extends ChatEvent { const ChatAppPaused(); }
class ChatClosed         extends ChatEvent { const ChatClosed(); }