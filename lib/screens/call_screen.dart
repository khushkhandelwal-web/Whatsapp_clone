import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../bloc/call_bloc.dart';
import '../data/call_repository.dart';


class CallScreen extends StatelessWidget {
  final CallModel call;
  final bool isCaller;

  const CallScreen({super.key, required this.call, required this.isCaller});

  @override
  Widget build(BuildContext context) =>
      BlocListener<CallBloc, CallState>(
        listenWhen: (prev, curr) =>
            curr.status == CallStatus.ended ||
            curr.status == CallStatus.declined ||
            curr.status == CallStatus.missed,
        listener: (ctx, state) => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: BlocBuilder<CallBloc, CallState>(
            builder: (ctx, state) {
              final isVideo = call.type == CallType.video;
              return Stack(children: [
                if (isVideo && state.remoteRenderer != null)
                  Positioned.fill(
                    child: RTCVideoView(
                      state.remoteRenderer!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  )
                else
                  Positioned.fill(child: _VoiceBackground(call: call)),

                if (isVideo && state.localRenderer != null)
                  Positioned(
                    top: 60, right: 16,
                    width: 110, height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: state.cameraOff
                          ? Container(color: Colors.grey.shade800,
                              child: const Icon(Icons.videocam_off,
                                  color: Colors.white, size: 32))
                          : RTCVideoView(state.localRenderer!,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover),
                    ),
                  ),

                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(children: [
                        Text(
                          isCaller ? call.receiverName : call.callerName,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 28, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _StatusLabel(status: state.status),
                      ]),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [

                          
                          _CtrlBtn(
                            icon: state.micMuted
                                ? Icons.mic_off : Icons.mic,
                            label: state.micMuted ? 'Unmute' : 'Mute',
                            onTap: () =>
                                ctx.read<CallBloc>().add(const CallMicToggled()),
                          ),
                          _CtrlBtn(
                            icon: Icons.call_end_rounded,
                            label: 'End',
                            color: Colors.red,
                            size: 64,
                            onTap: () =>
                                ctx.read<CallBloc>().add(const CallEnded()),
                          ),

                          
                          if (isVideo)
                            _CtrlBtn(
                              icon: state.cameraOff
                                  ? Icons.videocam_off : Icons.videocam,
                              label: state.cameraOff ? 'Cam Off' : 'Cam On',
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

class _VoiceBackground extends StatelessWidget {
  final CallModel call;
  const _VoiceBackground({required this.call});

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
          radius: 60,
          backgroundColor: Colors.white24,
          child: Text(call.callerName.isNotEmpty
              ? call.callerName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 52,
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        Text(call.callerName,
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.w500)),
      ],
    )),
  );
}


class _StatusLabel extends StatelessWidget {
  final CallStatus status;
  const _StatusLabel({required this.status});

  String get _label {
    switch (status) {
      case CallStatus.calling:   return 'Calling…';
      case CallStatus.ringing:   return 'Ringing…';
      case CallStatus.connected: return 'Connected';
      case CallStatus.ended:     return 'Call ended';
      case CallStatus.declined:  return 'Declined';
      default:                   return '';
    }
  }

  @override
  Widget build(BuildContext context) => Text(_label,
      style: TextStyle(
          color: status == CallStatus.connected
              ? Colors.greenAccent : Colors.white70,
          fontSize: 16));
}


class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white24,
    this.size  = 56,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xff075E54),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, 4))],
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
                  Icon(
                    call.type == CallType.video
                        ? Icons.videocam : Icons.call,
                    color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    call.type == CallType.video
                        ? 'Incoming video call' : 'Incoming voice call',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ],
            )),

            GestureDetector(
              onTap: () => context.read<CallBloc>()
                  .add(const CallDeclined()),
              child: Container(
                width: 44, height: 44,
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
                  builder: (_) => CallScreen(call: call, isCaller: false),
                ));
              },
              child: Container(
                width: 44, height: 44,
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