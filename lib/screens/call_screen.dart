import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../features/call/bloc/call_bloc.dart';
import '../features/call/data/repositories/call_repository.dart';



class CallScreen extends StatelessWidget {
  final CallModel call;
  final bool isCaller;

  const CallScreen({super.key, required this.call, required this.isCaller});

  @override
  Widget build(BuildContext context) {
    final bloc    = context.read<CallBloc>();
    final isVideo = call.type == CallType.video;

    return BlocListener<CallBloc, CallState>(
      listenWhen: (_, curr) =>
          curr.status == CallStatus.ended    ||
          curr.status == CallStatus.declined ||
          curr.status == CallStatus.missed,
      listener: (_, __) => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<CallBloc, CallState>(
          builder: (ctx, state) {
            final remoteHasStream =
                bloc.remoteRenderer?.srcObject != null;

            return Stack(children: [

             
              if (isVideo)
                Positioned.fill(
                  child: remoteHasStream
                      ? RTCVideoView(
                          bloc.remoteRenderer!,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitCover,
                        )
                      : _Placeholder(
                          name: isCaller
                              ? call.receiverName : call.callerName,
                          label: state.status == CallStatus.connected
                              ? 'Camera loading…'
                              : 'Waiting…',
                        ),
                )
              else
                Positioned.fill(
                    child: _VoiceBackground(call: call, isCaller: isCaller)),
              if (isVideo && bloc.localRenderer != null)
                Positioned(
                  top: 56, right: 14,
                  width: 120, height: 170,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: state.cameraOff
                        ? Container(
                            color: Colors.grey.shade800,
                            child: const Center(child: Icon(
                                Icons.videocam_off,
                                color: Colors.white, size: 34)))
                        : RTCVideoView(
                            bloc.localRenderer!,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),

              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(children: [
                      Text(
                        isCaller
                            ? call.receiverName : call.callerName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(
                                blurRadius: 8, color: Colors.black54)]),
                      ),
                      const SizedBox(height: 6),
                      _StatusLabel(status: state.status),
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CtrlBtn(
                          icon: state.micMuted
                              ? Icons.mic_off : Icons.mic,
                          label: state.micMuted ? 'Unmute' : 'Mute',
                          active: state.micMuted,
                          onTap: () => ctx.read<CallBloc>()
                              .add(const CallMicToggled()),
                        ),
                        _CtrlBtn(
                          icon: Icons.call_end_rounded,
                          label: 'End',
                          color: Colors.red,
                          size: 68,
                          onTap: () => ctx.read<CallBloc>()
                              .add(const CallEnded()),
                        ),
                        if (isVideo)
                          _CtrlBtn(
                            icon: state.cameraOff
                                ? Icons.videocam_off : Icons.videocam,
                            label: state.cameraOff
                                ? 'Cam Off' : 'Cam On',
                            active: state.cameraOff,
                            onTap: () => ctx.read<CallBloc>()
                                .add(const CallCameraToggled()),
                          )
                        else
                          _CtrlBtn(
                            icon: Icons.volume_up_rounded,
                            label: 'Speaker',
                            onTap: () {},
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}


class _Placeholder extends StatelessWidget {
  final String name, label;
  const _Placeholder({required this.name, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xff1a1a2e), Color(0xff16213e)],
      ),
    ),
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white12,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 48,
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        Text(name,
            style: const TextStyle(color: Colors.white70, fontSize: 18)),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
      ],
    )),
  );
}


class _VoiceBackground extends StatelessWidget {
  final CallModel call;
  final bool isCaller;
  const _VoiceBackground({required this.call, required this.isCaller});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xff075E54), Color(0xff128C7E)],
      ),
    ),
    child: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 64,
          backgroundColor: Colors.white24,
          child: Text(
            isCaller
                ? call.receiverName[0].toUpperCase()
                : call.callerName[0].toUpperCase(),
            style: const TextStyle(fontSize: 52,
                color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        Text(isCaller ? call.receiverName : call.callerName,
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.w500)),
      ],
    )),
  );
}

class _StatusLabel extends StatelessWidget {
  final CallStatus status;
  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    String text; Color color;
    switch (status) {
      case CallStatus.calling:
        text = 'Calling…';   color = Colors.white70; break;
      case CallStatus.ringing:
        text = 'Ringing…';   color = Colors.white70; break;
      case CallStatus.connected:
        text = 'Connected';  color = Colors.greenAccent; break;
      case CallStatus.ended:
        text = 'Call ended'; color = Colors.redAccent; break;
      case CallStatus.declined:
        text = 'Declined';   color = Colors.redAccent; break;
      default:
        text = '';           color = Colors.transparent;
    }
    return Text(text, style: TextStyle(color: color, fontSize: 16,
        shadows: const [Shadow(blurRadius: 6, color: Colors.black45)]));
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final bool active;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color  = Colors.white24,
    this.size   = 58,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size, height: size,
        decoration: BoxDecoration(
          color: active ? Colors.white24 : color,
          shape: BoxShape.circle,
          border: active
              ? Border.all(color: Colors.white54, width: 1.5)
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.44),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(
          color: Colors.white70, fontSize: 12,
          fontWeight: FontWeight.w500)),
    ]),
  );
}


class IncomingCallOverlay extends StatelessWidget {
  final CallModel call;
  const IncomingCallOverlay({super.key, required this.call});

  @override
  Widget build(BuildContext context) => Positioned(
    top: 0, left: 0, right: 0,
    child: SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xff075E54),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              child: Text(call.callerName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(call.callerName,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Row(children: [
                  Icon(call.type == CallType.video
                      ? Icons.videocam : Icons.call,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(call.type == CallType.video
                      ? 'Incoming video call'
                      : 'Incoming voice call',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ]),
              ],
            )),
            GestureDetector(
              onTap: () => context.read<CallBloc>()
                  .add(const CallDeclined()),
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.call_end_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 10),
           
            GestureDetector(
              onTap: () {
                context.read<CallBloc>().add(CallAnswered(call));
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<CallBloc>(),
                    child: CallScreen(call: call, isCaller: false),
                  ),
                ));
              },
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.call_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}