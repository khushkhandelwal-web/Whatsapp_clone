import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/chat_repository.dart';
import 'data/call_repository.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/call_bloc.dart';
import 'screens/call_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    final res = await ChatRepository().askGemini("Hello");
    debugPrint("SUCCESS: $res");
  } catch (e) {
    debugPrint("FAILED: $e");
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => RepositoryProvider<ChatRepository>(
    create: (_) => ChatRepository(),
    child: RepositoryProvider<CallRepository>(
      create: (_) => CallRepository(),
      child: BlocProvider<AuthBloc>(
        create: (ctx) => AuthBloc(repo: ctx.read<ChatRepository>())
          ..add(const AuthSubscriptionRequested()),
        child: BlocProvider<CallBloc>(
          create: (ctx) => CallBloc(repo: ctx.read<CallRepository>()),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
              useMaterial3: true,
            ),
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (ctx, state) {
                if (state.status == AuthStatus.unknown) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                return state.status == AuthStatus.authenticated
                    ? const HomeScreen()
                    : const LoginScreen();
              },
            ),
          ),
        ),
      ),
    ),
  );
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();

  void _err(String e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e)));

  @override
  Widget build(BuildContext context) => BlocListener<AuthBloc, AuthState>(
    listenWhen: (prev, curr) => curr.error != null && curr.error != prev.error,
    listener: (ctx, state) { if (state.error != null) _err(state.error!); },
    child: Scaffold(
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400),
          child: Column(children: [
            const Icon(Icons.chat_rounded, size: 80, color: kGreen),
            const SizedBox(height: 8),
            const Text('Khush Chat', style: TextStyle(fontSize: 28,
                fontWeight: FontWeight.bold, color: kGreen)),
            const SizedBox(height: 32),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true,
                decoration: const InputDecoration(labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder())),
            const SizedBox(height: 20),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (ctx, state) {
                if (state.submitting) {
                  return const CircularProgressIndicator();
                }
                return Column(children: [
                  _bigBtn('Login', kGreen, Colors.white, () =>
                      ctx.read<AuthBloc>().add(AuthLoginRequested(
                          email: _email.text, password: _pass.text))),
                  const SizedBox(height: 10),
                  _bigBtn('Sign Up', Colors.white, kGreen, () =>
                      ctx.read<AuthBloc>().add(AuthSignupRequested(
                          email: _email.text, password: _pass.text)),
                      outlined: true),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    onPressed: () => ctx.read<AuthBloc>()
                        .add(const AuthGoogleSignInRequested()),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                    label: const Text('Continue with Google'))),
                ]);
              },
            ),
          ]),
        ),
      )),
    ),
  );

  Widget _bigBtn(String label, Color bg, Color fg, VoidCallback cb,
      {bool outlined = false}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final pad   = const EdgeInsets.symmetric(vertical: 14);
    return SizedBox(width: double.infinity,
      child: outlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(padding: pad, shape: shape),
              onPressed: cb,
              child: Text(label, style: const TextStyle(fontSize: 16)))
          : ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: bg,
                  foregroundColor: fg, padding: pad, shape: shape),
              onPressed: cb,
              child: Text(label, style: const TextStyle(fontSize: 16))));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  final _pages = const [ChatsPage(), _StatusPage(), _AccountPage()];

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ChatRepository>().setPresence(online: true);
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<ChatRepository>().setPresence(online: false);
    super.dispose();
  }
  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    context.read<ChatRepository>()
        .setPresence(online: s == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: kGreen,
      title: const Text('Khush Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ChatSearchScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
        ),
      ],
    ),
    body: IndexedStack(index: _idx, children: _pages),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _idx,
      selectedItemColor: kGreen,
      onTap: (i) => setState(() => _idx = i),
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        BottomNavigationBarItem(
            icon: Icon(Icons.circle_outlined), label: 'Status'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Account'),
      ],
    ),
  );
}

class _StatusPage extends StatelessWidget {
  const _StatusPage();
  @override Widget build(BuildContext ctx) =>
      const Center(child: Text('Status coming soon'));
}

class _AccountPage extends StatelessWidget {
  const _AccountPage();
  @override Widget build(BuildContext ctx) {
    final u = FirebaseAuth.instance.currentUser;
    final n = u?.displayName ?? u?.email?.split('@')[0] ?? '?';
    return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
      CircleAvatar(radius: 44, backgroundColor: kGreen,
          child: Text(n[0].toUpperCase(), style: const TextStyle(
              color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))),
      const SizedBox(height: 12),
      Text(n, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(u?.email ?? '', style: const TextStyle(color: Colors.grey)),
    ]));
  }
}

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});
  @override State<ChatSearchScreen> createState() => _ChatSearchState();
}

class _ChatSearchState extends State<ChatSearchScreen> {
  final _ctrl    = TextEditingController();
  final _listKey = GlobalKey<AnimatedListState>();
  final List<Map<String, dynamic>> _displayed = [];
  List<Map<String, dynamic>> _allUsers = [];

  @override void initState() { super.initState(); _loadUsers(); }

  Future<void> _loadUsers() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final myUid = context.read<ChatRepository>().me.uid;
    final users = snap.docs.map((d) => d.data() as Map<String, dynamic>)
        .where((d) => d['uid'] != myUid).toList();
    setState(() => _allUsers = users);
    _animateTo(users);
  }

  void _animateTo(List<Map<String, dynamic>> newList) {
    
    for (int i = _displayed.length - 1; i >= 0; i--) {
      if (!newList.any((u) => u['uid'] == _displayed[i]['uid'])) {
        final removed = _displayed.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (ctx, anim) => _buildTile(ctx, removed, anim),
          duration: const Duration(milliseconds: 220),
        );
      }
    }
    for (int i = 0; i < newList.length; i++) {
      if (!_displayed.any((u) => u['uid'] == newList[i]['uid'])) {
        _displayed.insert(i, newList[i]);
        _listKey.currentState?.insertItem(i,
            duration: const Duration(milliseconds: 280));
      }
    }
  }

  void _search(String q) {
    final filtered = q.isEmpty
        ? _allUsers
        : _allUsers.where((d) =>
            (d['name']  as String).toLowerCase().contains(q.toLowerCase()) ||
            (d['email'] as String).toLowerCase().contains(q.toLowerCase()))
          .toList();
    _animateTo(filtered);
  }

  Widget _buildTile(BuildContext ctx,
      Map<String, dynamic> d, Animation<double> anim) =>
      SizeTransition(
        sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: kGreen,
                  child: Text(d['name'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white))),
              title:    Text(d['name']  as String),
              subtitle: Text(d['email'] as String),
              onTap: () => Navigator.pushReplacement(ctx,
                  MaterialPageRoute(builder: (_) => ChatScreen(
                      rid:   d['uid']  as String,
                      rname: d['name'] as String))),
            ),
            const Divider(height: 0, indent: 72, thickness: 0.5),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: kGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      title: TextField(
        controller: _ctrl, autofocus: true,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          hintText: 'Search users…',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        onChanged: _search,
      ),
    ),
    body: _displayed.isEmpty && _ctrl.text.isEmpty
        ? const Center(child: CircularProgressIndicator(color: kGreen))
        : _displayed.isEmpty
            ? const Center(
                child: Text('No results',
                    style: TextStyle(color: Colors.grey)))
            : AnimatedList(
                key:              _listKey,
                initialItemCount: _displayed.length,
                itemBuilder: (ctx, i, anim) {
                  if (i >= _displayed.length) return const SizedBox.shrink();
                  return _buildTile(ctx, _displayed[i], anim);
                },
              ),
  );
}


class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});
  @override State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _listKey = GlobalKey<AnimatedListState>();
  final List<Map<String, dynamic>> _users = [];

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ChatRepository>();
    final myUid = repo.me.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: repo.users(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final fresh = snap.data!.docs
            .where((d) => d['uid'] != myUid)
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        for (int i = 0; i < fresh.length; i++) {
          final uid = fresh[i]['uid'] as String;
          if (!_users.any((u) => u['uid'] == uid)) {
            _users.insert(i, fresh[i]);
            _listKey.currentState?.insertItem(i,
                duration: const Duration(milliseconds: 380));
          }
        }
   
        for (int i = _users.length - 1; i >= 0; i--) {
          final uid = _users[i]['uid'] as String;
          if (!fresh.any((u) => u['uid'] == uid)) {
            final removed = _users.removeAt(i);
            _listKey.currentState?.removeItem(
              i,
              (ctx2, anim) => _buildTile(ctx, removed, myUid, anim),
              duration: const Duration(milliseconds: 300),
            );
          }
        }

        if (_users.isEmpty) {
          return const Center(
              child: Text('No users yet',
                  style: TextStyle(color: Colors.grey)));
        }

        return AnimatedList(
          key: _listKey,
          initialItemCount: _users.length,
          itemBuilder: (ctx2, i, anim) {
            if (i >= _users.length) return const SizedBox.shrink();
            return _buildTile(ctx, _users[i], myUid, anim);
          },
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, Map<String, dynamic> d, String myUid,
      Animation<double> anim) {
    final cid = context.read<ChatRepository>().chatId(myUid, d['uid'] as String);
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _ChatTile(cid: cid, myUid: myUid,
              rid:   d['uid']  as String,
              rname: d['name'] as String),
          const Divider(height: 0, indent: 72, thickness: 0.5),
        ]),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String cid, myUid, rid, rname;
  const _ChatTile({required this.cid, required this.myUid,
      required this.rid, required this.rname});

  String _preview(Map<String, dynamic> d) {
    if (d['type'] == 'deleted') return '🚫 This message was deleted';
    switch (d['type'] as String? ?? 'text') {
      case 'image': return '📷 Photo';
      case 'video': return '🎥 Video';
      case 'audio': return '🎤 Voice message';
      case 'file':  return '📄 ${d['fileName'] ?? 'File'}';
      default:      return d['message'] as String? ?? '';
    }
  }

  String _time(dynamic ts) {
    if (ts == null) return '';
    final dt  = (ts as Timestamp).toDate();
    final now = DateTime.now();
    final h   = dt.hour.toString().padLeft(2, '0');
    final m   = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
      return '$h:$m';
    if (now.difference(dt).inDays < 7) {
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return days[(dt.weekday - 1).clamp(0, 6)];
    }
    return '${dt.day.toString().padLeft(2,'0')}/'
           '${dt.month.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ChatRepository>();
    final lastStream = FirebaseFirestore.instance
        .collection('chats').doc(cid).collection('messages')
        .orderBy('sentAt', descending: true).limit(1).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: lastStream,
      builder: (ctx, lastSnap) {
        String subtitle = 'Tap to chat', timeStr = '';
        if (lastSnap.hasData && lastSnap.data!.docs.isNotEmpty) {
          final d = lastSnap.data!.docs.first.data() as Map<String, dynamic>;
          subtitle = _preview(d); timeStr = _time(d['sentAt']);
        }
        return StreamBuilder<int>(
          stream: repo.unreadCount(cid, myUid),
          builder: (ctx, us) {
            final count = us.data ?? 0;
            final has   = count > 0;
            return StreamBuilder<DocumentSnapshot>(
              stream: repo.presenceStream(rid),
              builder: (ctx, presSnap) {
                bool   online = false, typing = false, recording = false;
                String lastSeenStr = '';
                if (presSnap.hasData && presSnap.data!.exists) {
                  final p = presSnap.data!.data() as Map<String, dynamic>;
                  online    = p['online']    as bool? ?? false;
                  typing    = (p['typing']   as bool? ?? false) &&
                              (p['typingIn'] as String? ?? '') == cid;
                  recording = (p['recording'] as bool? ?? false) &&
                              (p['typingIn']  as String? ?? '') == cid;
                  final ls = p['lastSeen'] as Timestamp?;
                  if (!online && ls != null) {
                    final dt  = ls.toDate();
                    final now = DateTime.now();
                    final h   = dt.hour.toString().padLeft(2,'0');
                    final mn  = dt.minute.toString().padLeft(2,'0');
                    lastSeenStr = now.difference(dt).inDays == 0
                        ? 'last seen today at $h:$mn'
                        : 'last seen ${dt.day}/${dt.month}';
                  }
                }
                final sub = typing ? '✏️ typing…'
                          : recording ? '🎤 recording…' : subtitle;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Hero(
                    tag: 'avatar_$rid',
                    child: Stack(children: [
                      CircleAvatar(radius: 26, backgroundColor: kGreen,
                          child: Text(rname[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 18, fontWeight: FontWeight.bold))),
                      if (online) Positioned(right: 0, bottom: 0,
                        child: Container(width: 13, height: 13,
                          decoration: BoxDecoration(color: kGreen2,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)))),
                    ]),
                  ),
                  title: Text(rname, style: TextStyle(
                      fontWeight: has ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: typing || recording
                              ? kGreen : (has ? Colors.black87 : Colors.grey),
                          fontStyle: typing || recording
                              ? FontStyle.italic : FontStyle.normal,
                          fontWeight: has ? FontWeight.w500 : FontWeight.normal,
                          fontSize: 13)),
                  trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(timeStr, style: TextStyle(fontSize: 11,
                        color: has ? kGreen : Colors.grey,
                        fontWeight: has ? FontWeight.w600 : FontWeight.normal)),
                    const SizedBox(height: 4),
                    if (has) Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: kGreen2, shape: BoxShape.circle),
                      child: Text(count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ) else if (!online && lastSeenStr.isNotEmpty)
                      Text(lastSeenStr,
                          style: const TextStyle(fontSize: 10, color: Colors.grey))
                    else const SizedBox(height: 20),
                  ]),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(rid: rid, rname: rname))),
                );
              },
            );
          },
        );
      },
    );
  }
}


class ChatScreen extends StatelessWidget {
  final String rid, rname;
  const ChatScreen({super.key, required this.rid, required this.rname});

  @override
  Widget build(BuildContext context) => BlocProvider<ChatBloc>(
    create: (ctx) => ChatBloc(repo: ctx.read<ChatRepository>())
      ..add(ChatStarted(
          myUid: ctx.read<ChatRepository>().me.uid,
          peerUid: rid,
          peerName: rname)),
    child: _ChatView(rid: rid, rname: rname),
  );
}

class _ChatView extends StatefulWidget {
  final String rid, rname;
  const _ChatView({required this.rid, required this.rname});
  @override State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  late final _me = context.read<ChatRepository>().me;

  final _searchCtrl = TextEditingController();

  final _msgListKey = GlobalKey<AnimatedListState>();
  final List<Msg>   _msgItems = [];

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.addListener(_onTyping);
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.removeListener(_onTyping);
    _ctrl.dispose(); _searchCtrl.dispose(); _scroll.dispose();
    context.read<ChatBloc>().add(const ChatClosed());
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    final bloc = context.read<ChatBloc>();
    if (s == AppLifecycleState.resumed) {
      bloc.add(const ChatAppResumed());
    } else {
      bloc.add(const ChatAppPaused());
    }
  }

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scroll.hasClients) _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _onTyping() =>
      context.read<ChatBloc>().add(ChatTextChanged(_ctrl.text));

  void _sendOrEdit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final wasEditing = context.read<ChatBloc>().state.editMsg != null;
    context.read<ChatBloc>().add(ChatSendOrEditPressed(t));
    _ctrl.clear();
    if (!wasEditing) _scrollBottom();
  }

  void _askAI() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatAskAiPressed(text));
    _ctrl.clear();
    _scrollBottom();
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Wrap(spacing: 16, runSpacing: 20, children: [
            _AttachOption(
              icon: Icons.photo_library_rounded,
              label: 'Gallery',
              color: Colors.purple,
              onTap: () { Navigator.pop(context); _pickImage(gallery: true); },
            ),
            _AttachOption(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              color: Colors.pink,
              onTap: () { Navigator.pop(context); _pickImage(gallery: false); },
            ),
            _AttachOption(
              icon: Icons.videocam_rounded,
              label: 'Video',
              color: Colors.orange,
              onTap: () { Navigator.pop(context); _pickVideo(); },
            ),
            _AttachOption(
              icon: Icons.insert_drive_file_rounded,
              label: 'Document',
              color: Colors.blue,
              onTap: () { Navigator.pop(context); _pickDocument(); },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool gallery}) async {
    final picker = ImagePicker();
    final xfile = gallery
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 85)
        : await picker.pickImage(source: ImageSource.camera,  imageQuality: 85);
    if (xfile == null) return;
    if (!mounted) return;
    context.read<ChatBloc>().add(ChatFilePicked(File(xfile.path), MsgType.image));
    _scrollBottom();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    if (!mounted) return;
    context.read<ChatBloc>().add(ChatFilePicked(File(xfile.path), MsgType.video));
    _scrollBottom();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf','doc','docx','xls','xlsx','txt','zip','ppt','pptx'],
      withData: true,
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    context.read<ChatBloc>().add(ChatFilePicked(
        File(result.files.single.path!), MsgType.file,
        fileName: result.files.single.name));
    _scrollBottom();
  }

  void _deleteForEveryone(Msg msg) =>
      context.read<ChatBloc>().add(ChatMessageDeletedForEveryone(msg));
  void _react(Msg msg, String emoji) =>
      context.read<ChatBloc>().add(ChatReactionToggled(msg, emoji));

  void _startEdit(Msg msg) {
    context.read<ChatBloc>().add(ChatEditStarted(msg));
    _ctrl.text = msg.text;
    _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length));
  }

  void _startReply(Msg msg) =>
      context.read<ChatBloc>().add(ChatReplyStarted(msg));

  void _cancelAction() {
    final wasEditing = context.read<ChatBloc>().state.editMsg != null;
    context.read<ChatBloc>().add(const ChatDraftCancelled());
    if (wasEditing) _ctrl.clear();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _showDisappearDialog(DisappearTimer current) async {
    final chosen = await showDialog<DisappearTimer>(
      context: context,
      builder: (ctx) => _DisappearTimerDialog(current: current),
    );
    if (chosen == null) return;
    if (!mounted) return;
    context.read<ChatBloc>().add(ChatDisappearTimerSet(chosen));
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<ChatBloc, ChatState>(
        listenWhen: (prev, curr) => curr.error != null && curr.error != prev.error,
        listener: (ctx, state) { if (state.error != null) _snack(state.error!); },
      ),
      BlocListener<ChatBloc, ChatState>(
        listenWhen: (prev, curr) =>
            curr.infoMessage != null && curr.infoMessage != prev.infoMessage,
        listener: (ctx, state) { if (state.infoMessage != null) _snack(state.infoMessage!); },
      ),
      BlocListener<ChatBloc, ChatState>(
        listenWhen: (prev, curr) => curr.allMessages.length != prev.allMessages.length,
        listener: (ctx, state) =>
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom()),
      ),
    ],
    child: BlocBuilder<CallBloc, CallState>(
      builder: (ctx, callState) => Stack(children: [
        Scaffold(
          backgroundColor: kBgChat,
          appBar: _buildAppBar(),
          body: BlocBuilder<ChatBloc, ChatState>(
            builder: (ctx, state) => Column(children: [
              if (state.disappearTimer != DisappearTimer.off)
                _DisappearBanner(
                    timer: state.disappearTimer,
                    onTap: () => _showDisappearDialog(state.disappearTimer)),
              Expanded(child: _buildMsgList(state)),
              if (state.replyMsg != null) _ReplyPreview(
                  msg: state.replyMsg!, rname: widget.rname, onCancel: _cancelAction),
              if (state.editMsg != null) _EditPreview(onCancel: _cancelAction),
              if (state.uploading) _UploadProgressBar(progress: state.uploadProgress),
              _buildInput(state),
            ]),
          ),
        ),
        if (callState.incomingCall != null)
          IncomingCallOverlay(call: callState.incomingCall!),
      ]),
    ),
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: kGreen,
    titleSpacing: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    title: BlocBuilder<ChatBloc, ChatState>(
      builder: (ctx, state) {
        String sub = '';
        if (state.peerTyping)         sub = 'typing…';
        else if (state.peerRecording) sub = 'recording…';
        else if (state.peerOnline)    sub = 'online';
        else {
          final ls = state.peerLastSeen;
          if (ls != null) {
            final dt  = ls.toDate();
            final now = DateTime.now();
            final h   = dt.hour.toString().padLeft(2,'0');
            final mn  = dt.minute.toString().padLeft(2,'0');
            sub = now.difference(dt).inDays == 0
                ? 'last seen today at $h:$mn'
                : 'last seen ${dt.day}/${dt.month}';
          }
        }
        return Row(children: [
          Hero(
            tag: 'avatar_${widget.rid}',
            child: CircleAvatar(radius: 20, backgroundColor: Colors.white24,
                child: Text(widget.rname[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.rname, style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            if (sub.isNotEmpty) Text(sub, style: TextStyle(
                color: sub == 'typing…' || sub == 'recording…'
                    ? Colors.greenAccent : Colors.white70,
                fontSize: 12,
                fontStyle: sub == 'typing…' || sub == 'recording…'
                    ? FontStyle.italic : FontStyle.normal)),
          ]),
        ]);
      },
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.call, color: Colors.white),
        tooltip: 'Voice call',
        onPressed: () {
          context.read<CallBloc>().add(CallStarted(
              receiverId:   widget.rid,
              receiverName: widget.rname,
              type:         CallType.voice));
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<CallBloc>(),
              child: CallScreen(
                call: CallModel(
                  callId:       '',
                  callerId:     _me.uid,
                  callerName:   _me.displayName ?? _me.email!.split('@')[0],
                  receiverId:   widget.rid,
                  receiverName: widget.rname,
                  type:         CallType.voice,
                  status:       CallStatus.calling,
                  createdAt:    DateTime.now(),
                ),
                isCaller: true,
              ),
            ),
          ));
        },
      ),
      IconButton(
        icon: const Icon(Icons.videocam, color: Colors.white),
        tooltip: 'Video call',
        onPressed: () {
          context.read<CallBloc>().add(CallStarted(
              receiverId:   widget.rid,
              receiverName: widget.rname,
              type:         CallType.video));
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<CallBloc>(),
              child: CallScreen(
                call: CallModel(
                  callId:       '',
                  callerId:     _me.uid,
                  callerName:   _me.displayName ?? _me.email!.split('@')[0],
                  receiverId:   widget.rid,
                  receiverName: widget.rname,
                  type:         CallType.video,
                  status:       CallStatus.calling,
                  createdAt:    DateTime.now(),
                ),
                isCaller: true,
              ),
            ),
          ));
        },
      ),
      BlocBuilder<ChatBloc, ChatState>(
        builder: (ctx, state) => IconButton(
          tooltip: 'Disappearing messages',
          icon: Stack(clipBehavior: Clip.none, children: [
            const Icon(Icons.timer_outlined, color: Colors.white),
            if (state.disappearTimer != DisappearTimer.off)
              Positioned(right: -2, top: -2,
                child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: kGreen2, shape: BoxShape.circle))),
          ]),
          onPressed: () => _showDisappearDialog(state.disappearTimer),
        ),
      ),
      BlocBuilder<ChatBloc, ChatState>(
        builder: (ctx, state) => IconButton(
          icon: Icon(state.searching ? Icons.close : Icons.search, color: Colors.white),
          onPressed: () {
            final next = !state.searching;
            ctx.read<ChatBloc>().add(ChatSearchToggled(next));
            if (!next) _searchCtrl.clear();
          },
        ),
      ),
    ],
  );

  Widget _buildMsgList(ChatState state) => Column(children: [
    if (state.searching) Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: _searchCtrl, autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search messages…',
          prefixIcon: const Icon(Icons.search),
          filled: true, fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onChanged: (v) =>
            context.read<ChatBloc>().add(ChatSearchQueryChanged(v)),
      ),
    ),
    Expanded(child: Builder(builder: (ctx) {
      if (state.loadingMessages) {
        return const Center(child: CircularProgressIndicator());
      }
      final freshMsgs = state.visibleMessages;
      if (freshMsgs.isEmpty) return Center(
          child: Text(
              state.searchQuery.isNotEmpty ? 'No results' : 'No messages yet. Say hi! 👋',
              style: const TextStyle(color: Colors.grey)));

      for (int i = 0; i < freshMsgs.length; i++) {
        if (i >= _msgItems.length || _msgItems[i].id != freshMsgs[i].id) {
          if (i <= _msgItems.length) {
            _msgItems.insert(i, freshMsgs[i]);
            _msgListKey.currentState?.insertItem(i,
                duration: const Duration(milliseconds: 320));
          }
        } else {
          _msgItems[i] = freshMsgs[i];
        }
      }
      for (int i = _msgItems.length - 1; i >= freshMsgs.length; i--) {
        final removed = _msgItems.removeAt(i);
        _msgListKey.currentState?.removeItem(
          i,
          (ctx2, anim) => _buildMsgItem(removed, i, anim),
          duration: const Duration(milliseconds: 260),
        );
      }

      return AnimatedList(
        key:              _msgListKey,
        controller:       _scroll,
        padding:          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        initialItemCount: _msgItems.length,
        itemBuilder: (ctx2, i, anim) {
          if (i >= _msgItems.length) return const SizedBox.shrink();
          return _buildMsgItem(_msgItems[i], i, anim);
        },
      );
    })),
  ]);

  bool _diffDay(DateTime a, DateTime b) =>
      a.day != b.day || a.month != b.month || a.year != b.year;

  Widget _buildMsgItem(Msg msg, int i, Animation<double> anim) {
    final isMe  = msg.senderId == _me.uid;
    final prevDate = i > 0 && i < _msgItems.length
        ? _msgItems[i - 1].sentAt.toDate() : null;
    final showD = prevDate == null ||
        _diffDay(prevDate, msg.sentAt.toDate());

    final slide = Tween<Offset>(
      begin: Offset(isMe ? 0.35 : -0.35, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));

    return SizeTransition(
      sizeFactor:    CurvedAnimation(parent: anim, curve: Curves.easeOut),
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: SlideTransition(
          position: slide,
          child: Column(children: [
            if (showD) _DateSep(date: msg.sentAt.toDate()),
            _BubbleWrapper(
              msg:      msg,
              isMe:     isMe,
              meUid:    _me.uid,
              rname:    widget.rname,
              onReply:  () => _startReply(msg),
              onEdit:   () => _startEdit(msg),
              onDelete: () => _deleteForEveryone(msg),
              onReact:  (e) => _react(msg, e),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildInput(ChatState state) => Container(
    color: const Color(0xffF0F0F0),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(children: [

      state.aiLoading
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kGreen)))
          : IconButton(
              icon: const Icon(Icons.auto_awesome, color: kGreen),
              onPressed: _askAI),


      state.uploading
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)))
          : IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
              onPressed: _showAttachSheet),


      Expanded(child: Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: TextField(
          controller: _ctrl,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: state.editMsg != null ? 'Edit message…' : 'Message',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: InputBorder.none,
          ),
        ),
      )),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _sendOrEdit,
        child: CircleAvatar(
          radius: 22, backgroundColor: kGreen,
          child: Icon(
            state.editMsg != null ? Icons.check : Icons.send_rounded,
            color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 32 - 48) / 4;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: w,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 28, backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ]),
      ),
    );
  }
}


class _UploadProgressBar extends StatelessWidget {
  final double progress;   
  const _UploadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.upload_rounded, size: 14, color: kGreen),
        const SizedBox(width: 6),
        Text('Uploading… ${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: kGreen)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(kGreen2),
          minHeight: 4,
        ),
      ),
    ]),
  );
}

class _ReplyPreview extends StatelessWidget {
  final Msg msg; final String rname; final VoidCallback onCancel;
  const _ReplyPreview(
      {required this.msg, required this.rname, required this.onCancel});

  @override Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final senderName = msg.senderId == me.uid ? 'You' : rname;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        Container(width: 4, height: 40, color: kGreen,
            margin: const EdgeInsets.only(right: 10)),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text('Reply to $senderName', style: const TextStyle(
              color: kGreen, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(msg.text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancel),
      ]),
    );
  }
}


class _EditPreview extends StatelessWidget {
  final VoidCallback onCancel;
  const _EditPreview({required this.onCancel});
  @override Widget build(BuildContext context) => Container(
    color: Colors.amber.shade50,
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    child: Row(children: [
      const Icon(Icons.edit, color: Colors.amber, size: 18),
      const SizedBox(width: 10),
      const Expanded(child: Text('Editing message…', style: TextStyle(
          color: Colors.amber, fontWeight: FontWeight.w600))),
      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancel),
    ]),
  );
}

class _BubbleWrapper extends StatelessWidget {
  final Msg      msg;
  final bool     isMe;
  final String   meUid, rname;
  final VoidCallback onReply, onEdit, onDelete;
  final void Function(String) onReact;

  const _BubbleWrapper({
    required this.msg, required this.isMe, required this.meUid,
    required this.rname, required this.onReply, required this.onEdit,
    required this.onDelete, required this.onReact,
  });

  void _showMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        if (msg.type != MsgType.deleted) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: kReactions.map((e) => GestureDetector(
                onTap: () { Navigator.pop(ctx); onReact(e); },
                child: Text(e, style: const TextStyle(fontSize: 28)),
              )).toList()),
          ),
          const Divider(height: 0),
        ],
        if (msg.type != MsgType.deleted)
          ListTile(leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () { Navigator.pop(ctx); onReply(); }),
        if (isMe && msg.type == MsgType.text)
          ListTile(leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () { Navigator.pop(ctx); onEdit(); }),
        if (msg.type == MsgType.text)
          ListTile(leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.text));
              }),
        if (msg.fileUrl != null && msg.type != MsgType.deleted)
          ListTile(
            leading: const Icon(Icons.open_in_new, color: kGreen),
            title: const Text('Open'),
            onTap: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(msg.fileUrl!);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        if (isMe && msg.type != MsgType.deleted)
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete for Everyone',
                style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); onDelete(); }),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => _showMenu(context),
    child: Dismissible(
      key: ValueKey('swipe_${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async { onReply(); return false; },
      background: Align(alignment: Alignment.centerLeft,
          child: Padding(padding: const EdgeInsets.only(left: 16),
              child: Icon(Icons.reply, color: kGreen.withValues(alpha: 0.6)))),
      child: _Bubble(msg: msg, isMe: isMe, meUid: meUid),
    ),
  );
}

class _Bubble extends StatelessWidget {
  final Msg msg; final bool isMe; final String meUid;
  const _Bubble({required this.msg, required this.isMe, required this.meUid});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
                left: isMe ? 60 : 8, right: isMe ? 8 : 60, top: 2, bottom: 0),
            decoration: BoxDecoration(
              color: msg.type == MsgType.deleted
                  ? Colors.grey.shade200
                  : (isMe ? kBubbleMe : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(16),
                topRight:    const Radius.circular(16),
                bottomLeft:  Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 3, offset: const Offset(0, 1))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(16),
                topRight:    const Radius.circular(16),
                bottomLeft:  Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                if (msg.replyToId != null) _ReplyQuote(
                    text: msg.replyToText ?? '', sender: msg.replyToSender ?? ''),
                _content(context),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 5, left: 8, top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (msg.expiresAt != null) ...[
                      _ExpiryChip(expiresAt: msg.expiresAt!),
                      const SizedBox(width: 5),
                    ],
                    if (msg.isEdited && msg.type != MsgType.deleted)
                      const Text('edited ', style: TextStyle(
                          fontSize: 10, color: Colors.grey,
                          fontStyle: FontStyle.italic)),
                    Text(_fmt(msg.sentAt.toDate()),
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        msg.status == MsgStatus.read      ? Icons.done_all :
                        msg.status == MsgStatus.delivered ? Icons.done_all : Icons.done,
                        size: 13,
                        color: msg.status == MsgStatus.read ? Colors.blue : Colors.grey),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 60 : 8, right: isMe ? 8 : 60, bottom: 4),
              child: Wrap(spacing: 4,
                  children: msg.reactions.entries.map((e) {
                final users    = e.value;
                if (users.isEmpty) return const SizedBox.shrink();
                final iReacted = users.contains(meUid);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iReacted ? kGreen.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: iReacted ? kGreen : Colors.grey.shade300)),
                  child: Text('${e.key} ${users.length}',
                      style: const TextStyle(fontSize: 12)),
                );
              }).toList()),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (msg.type == MsgType.deleted) {
      return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text('This message was deleted', style: TextStyle(
              fontSize: 14, color: Colors.grey.shade500,
              fontStyle: FontStyle.italic)),
        ]));
    }

    if (msg.type == MsgType.image && msg.fileUrl != null) {
      return GestureDetector(
        onTap: () => Navigator.push(context, PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => _FullImageViewer(
              url: msg.fileUrl!, heroTag: 'img_\${msg.id}'),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
        )),
        child: Hero(
          tag: 'img_\${msg.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              msg.fileUrl!,
              width: 220, height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(width: 220, height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => _mediaTile(
                  Icons.broken_image, 'Image', Colors.purple),
            ),
          ),
        ),
      );
    }

    if (msg.type == MsgType.video && msg.fileUrl != null) {
      return GestureDetector(
        onTap: () => _openUrl(msg.fileUrl!),
        child: Stack(alignment: Alignment.center, children: [
          Container(width: 220, height: 140,
              color: Colors.black87,
              child: const Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 56)),
          Positioned(bottom: 6, left: 8,
            child: Text(msg.fileName ?? 'Video',
                style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ]),
      );
    }
    if (msg.type == MsgType.file && msg.fileUrl != null) {
      return GestureDetector(
        onTap: () => _openUrl(msg.fileUrl!),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            _fileIcon(msg.fileName ?? ''),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(msg.fileName ?? 'File',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              const Text('Tap to open',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
          ]),
        ),
      );
    }

    if (msg.type == MsgType.audio) {
      return _mediaTile(Icons.mic, 'Voice message', Colors.teal);
    }

    return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Text(msg.text,
            style: const TextStyle(fontSize: 15, height: 1.3)));
  }

  Widget _fileIcon(String name) {
    final fileExt = p.extension(name).toLowerCase();
    IconData icon; Color color;
    if (['.pdf'].contains(fileExt))              { icon = Icons.picture_as_pdf_rounded; color = Colors.red; }
    else if (['.doc','.docx'].contains(fileExt)) { icon = Icons.description_rounded;    color = Colors.blue; }
    else if (['.xls','.xlsx'].contains(fileExt)) { icon = Icons.table_chart_rounded;    color = Colors.green; }
    else if (['.zip'].contains(fileExt))         { icon = Icons.folder_zip_rounded;     color = Colors.orange; }
    else                                         { icon = Icons.insert_drive_file_rounded; color = Colors.blueGrey; }
    return Icon(icon, color: color, size: 32);
  }

  Widget _mediaTile(IconData icon, String label, Color color) =>
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.w500, fontSize: 14)),
        ]));

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:'
      '${dt.minute.toString().padLeft(2,'0')}';
}


class _ReplyQuote extends StatelessWidget {
  final String text, sender;
  const _ReplyQuote({required this.text, required this.sender});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: const Border(left: BorderSide(color: kGreen, width: 3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
      Text(sender, style: const TextStyle(
          color: kGreen, fontWeight: FontWeight.w600, fontSize: 12)),
      const SizedBox(height: 2),
      Text(text, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]),
  );
}


class _DateSep extends StatelessWidget {
  final DateTime date;
  const _DateSep({required this.date});
  String get _lbl {
    final now = DateTime.now();
    final d   = now.difference(date).inDays;
    if (d == 0) return 'Today';
    if (d == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
  @override Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xffD0E9C6).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8)),
      child: Text(_lbl, style: const TextStyle(
          fontSize: 12, color: Color(0xff4A4A4A),
          fontWeight: FontWeight.w500)),
    ),
  );
}


class _DisappearBanner extends StatelessWidget {
  final DisappearTimer timer;
  final VoidCallback   onTap;
  const _DisappearBanner({required this.timer, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      color: const Color(0xffFFF8C4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        const Icon(Icons.timer_outlined, size: 15, color: Color(0xff7B6E00)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Disappearing messages: ${timer.label}',
          style: const TextStyle(fontSize: 12, color: Color(0xff7B6E00),
              fontWeight: FontWeight.w500),
        )),
        const Icon(Icons.chevron_right, size: 16, color: Color(0xff7B6E00)),
      ]),
    ),
  );
}


class _ExpiryChip extends StatefulWidget {
  final Timestamp expiresAt;
  const _ExpiryChip({required this.expiresAt});
  @override State<_ExpiryChip> createState() => _ExpiryChipState();
}

class _ExpiryChipState extends State<_ExpiryChip> {
  late String _label;
  late final _timer = Stream.periodic(const Duration(seconds: 1));
  late final _sub   = _timer.listen((_) { if (mounted) setState(_refresh); });

  void _refresh() => _label = _buildLabel();

  String _buildLabel() {
    final rem = widget.expiresAt.toDate().difference(DateTime.now());
    if (rem.isNegative) return 'Expired';
    if (rem.inDays >= 1)    return '${rem.inDays}d ${rem.inHours.remainder(24)}h';
    if (rem.inHours >= 1)   return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
    if (rem.inMinutes >= 1) return '${rem.inMinutes}m ${rem.inSeconds.remainder(60)}s';
    return '${rem.inSeconds}s';
  }

  @override void initState() { super.initState(); _label = _buildLabel(); }
  @override void dispose()   { _sub.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final expired = _label == 'Expired';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: expired
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 10,
            color: expired ? Colors.red : Colors.orange),
        const SizedBox(width: 3),
        Text(_label, style: TextStyle(
            fontSize: 10,
            color: expired ? Colors.red : Colors.orange,
            fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _DisappearTimerDialog extends StatelessWidget {
  final DisappearTimer current;
  const _DisappearTimerDialog({required this.current});

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Row(children: [
      Icon(Icons.timer_outlined, color: kGreen, size: 22),
      SizedBox(width: 8),
      Text('Disappearing messages',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        'Messages sent in this chat will automatically be deleted '
        'after the selected time.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 16),
      ...DisappearTimer.values.map((t) => _TimerOption(
        timer: t, selected: t == current,
        onTap: () => Navigator.pop(context, t),
      )),
    ]),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
    ],
  );
}
class _TimerOption extends StatelessWidget {
  final DisappearTimer timer;
  final bool           selected;
  final VoidCallback   onTap;
  const _TimerOption(
      {required this.timer, required this.selected, required this.onTap});

  IconData get _icon {
    switch (timer) {
      case DisappearTimer.off: return Icons.timer_off_outlined;
      case DisappearTimer.h24: return Icons.looks_one_outlined;
      case DisappearTimer.d7:  return Icons.filter_7_outlined;
      case DisappearTimer.d90: return Icons.calendar_month_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? kGreen.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? kGreen : Colors.grey.shade200,
          width: selected ? 1.5 : 0.5),
      ),
      child: Row(children: [
        Icon(_icon, size: 20, color: selected ? kGreen : Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(timer.label, style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? kGreen : Colors.black87, fontSize: 14)),
          if (timer != DisappearTimer.off)
            Text(_description(timer),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        if (selected) const Icon(Icons.check_circle, color: kGreen, size: 20),
      ]),
    ),
  );

  String _description(DisappearTimer t) {
    switch (t) {
      case DisappearTimer.h24: return 'Great for sensitive conversations';
      case DisappearTimer.d7:  return 'Recommended — like WhatsApp default';
      case DisappearTimer.d90: return 'Long-term but still disappears';
      default:                 return '';
    }
  }
}


class _FullImageViewer extends StatefulWidget {
  final String url, heroTag;
  const _FullImageViewer({required this.url, required this.heroTag});
  @override State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer>
    with SingleTickerProviderStateMixin {

  double _dy     = 0;
  double _scale  = 1.0;
  bool   _dismiss = false;
  late final AnimationController _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220), value: 1.0);
  late final Animation<double> _bgFade =
      CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

  @override void dispose() { _bgCtrl.dispose(); super.dispose(); }

  void _onVerticalDrag(DragUpdateDetails d) {
    setState(() {
      _dy    += d.delta.dy;
      _scale  = (1.0 - (_dy.abs() / 600)).clamp(0.6, 1.0);
    });
    _bgCtrl.value = (1.0 - _dy.abs() / 400).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dy.abs() > 120 || d.velocity.pixelsPerSecond.dy.abs() > 800) {
      setState(() => _dismiss = true);
      Navigator.pop(context);
    } else {
      setState(() { _dy = 0; _scale = 1.0; });
      _bgCtrl.animateTo(1.0);
    }
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _bgFade,
    child: GestureDetector(
      onTap: () => Navigator.pop(context),
      onVerticalDragUpdate: _onVerticalDrag,
      onVerticalDragEnd:    _onDragEnd,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: _dismiss ? 0 : 0.92),
        body: Stack(children: [
          Center(
            child: Transform.translate(
              offset: Offset(0, _dy),
              child: Transform.scale(
                scale: _scale,
                child: Hero(
                  tag: widget.heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_dismiss ? 12 : 0),
                    child: Image.network(
                      widget.url,
                      fit: BoxFit.contain,
                      width:  MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8, right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  onPressed: () async {
                    final uri = Uri.parse(widget.url);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0, right: 0,
            child: const Center(
              child: Text('Swipe down to close',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ),
          ),
        ]),
      ),
    ),
  );
}