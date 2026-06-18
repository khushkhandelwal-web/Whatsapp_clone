import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}

const kGreen  = Color(0xff075E54);
const kGreen2 = Color(0xff25D366);
const kBubbleMe  = Color(0xffDCF8C6);
const kBgChat    = Color(0xffECE5DD);

const kReactions = ['❤️','😂','😮','😢','🙏','👍' ,'😁'];

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

enum MsgType   { text, image, audio, video, file, deleted }
enum MsgStatus { sent, delivered, read }

MsgType _typeFrom(String? s) {
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

class Msg {
  final String   id, senderId, receiverId, text;
  final MsgType  type;
  final String?  fileUrl, fileName;
  final bool     isRead;
  final Timestamp sentAt;
  final Timestamp? deliveredAt, readAt, editedAt;
  // Reply
  final String? replyToId, replyToText, replyToSender;
  // Reactions: {'❤️': ['uid1','uid2'], ...}
  final Map<String, List<String>> reactions;
  final bool isEdited;
  // Disappearing messages
  final Timestamp? expiresAt;

  const Msg({
    required this.id, required this.senderId, required this.receiverId,
    required this.text, required this.type,
    this.fileUrl, this.fileName,
    required this.isRead, required this.sentAt,
    this.deliveredAt, this.readAt, this.editedAt,
    this.replyToId, this.replyToText, this.replyToSender,
    this.reactions = const {},
    this.isEdited = false,
    this.expiresAt,
  });

  MsgStatus get status {
    if (isRead)              return MsgStatus.read;
    if (deliveredAt != null) return MsgStatus.delivered;
    return MsgStatus.sent;
  }

  factory Msg.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    // Parse reactions map
    final rawR = d['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawR.map((k, v) =>
        MapEntry(k, List<String>.from(v as List? ?? [])));
    return Msg(
      id:            doc.id,
      senderId:      d['senderId']    as String?  ?? '',
      receiverId:    d['receiverId']  as String?  ?? '',
      text:          d['message']     as String?  ?? '',
      type:          _typeFrom(d['type'] as String?),
      fileUrl:       d['fileUrl']     as String?,
      fileName:      d['fileName']    as String?,
      isRead:        d['isRead']      as bool?    ?? false,
      sentAt:        d['sentAt']      as Timestamp? ?? Timestamp.now(),
      deliveredAt:   d['deliveredAt'] as Timestamp?,
      readAt:        d['readAt']      as Timestamp?,
      editedAt:      d['editedAt']    as Timestamp?,
      replyToId:     d['replyToId']   as String?,
      replyToText:   d['replyToText'] as String?,
      replyToSender: d['replyToSender'] as String?,
      reactions:     reactions,
      isEdited:      d['isEdited']    as bool? ?? false,
      expiresAt:     d['expiresAt']   as Timestamp?,
    );
  }
}

class FS {
  static final _db = FirebaseFirestore.instance;
  static User get me => FirebaseAuth.instance.currentUser!;

  static String chatId(String a, String b) => ([a, b]..sort()).join('_');

  static Stream<QuerySnapshot> messages(String cid) =>
      _db.collection('chats').doc(cid).collection('messages')
         .orderBy('sentAt').snapshots();

  static Future<String> sendMsg({
    required String  receiverId,
    required String  message,
    required MsgType type,
    String? fileUrl, String? fileName,
    String? replyToId, String? replyToText, String? replyToSender,
  }) async {
    final cid = chatId(me.uid, receiverId);
    final ref = _db.collection('chats').doc(cid).collection('messages').doc();

    final chatDoc = await _db.collection('chats').doc(cid).get();
    final timerStr = chatDoc.exists
        ? (chatDoc.data() as Map<String, dynamic>)['disappearTimer'] as String?
        : null;
    final timer   = DisappearTimerX.fromString(timerStr);
    final now     = DateTime.now();
    final expires = timer.duration != null
        ? Timestamp.fromDate(now.add(timer.duration!))
        : null;

    await ref.set({
      'messageId':     ref.id,
      'senderId':      me.uid,
      'receiverId':    receiverId,
      'message':       message,
      'type':          type.val,
      if (fileUrl   != null) 'fileUrl':  fileUrl,
      if (fileName  != null) 'fileName': fileName,
      if (replyToId != null) ...{
        'replyToId':     replyToId,
        'replyToText':   replyToText,
        'replyToSender': replyToSender,
      },
      if (expires   != null) 'expiresAt': expires,
      'reactions':     {},
      'isEdited':      false,
      'isRead':        false,
      'sentAt':        FieldValue.serverTimestamp(),
      'deliveredAt':   FieldValue.serverTimestamp(),
      'readAt':        null,
    });
    return ref.id;
  }
  static Future<void> setDisappearTimer(
      String cid, DisappearTimer timer) async {
    await _db.collection('chats').doc(cid).set({
      'disappearTimer': timer.val,
      'disappearTimerSetBy': me.uid,
      'disappearTimerSetAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot> chatSettingsStream(String cid) =>
      _db.collection('chats').doc(cid).snapshots();

  static Future<int> purgeExpiredMessages(String cid) async {
    final now  = Timestamp.now();
    final snap = await _db
        .collection('chats')
        .doc(cid)
        .collection('messages')
        .where('expiresAt', isLessThanOrEqualTo: now)
        .get();
    if (snap.docs.isEmpty) return 0;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snap.docs.length;
  }
  static Future<void> editMsg(String cid, String msgId, String newText) async {
    await _db.collection('chats').doc(cid)
        .collection('messages').doc(msgId).update({
      'message':  newText,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }
  static Future<void> deleteForEveryone(String cid, String msgId) async {
    await _db.collection('chats').doc(cid)
        .collection('messages').doc(msgId).update({
      'message': 'This message was deleted',
      'type':    'deleted',
    });
  }

  static Future<void> toggleReaction(
      String cid, String msgId, String emoji, Msg msg) async {
    final uid    = me.uid;
    final cur    = Map<String, List<String>>.from(msg.reactions);
    final users  = List<String>.from(cur[emoji] ?? []);
    if (users.contains(uid)) {
      users.remove(uid);
    } else {
      // Remove from any other emoji first
      for (final k in cur.keys) {
        cur[k]?.remove(uid);
      }
      users.add(uid);
    }
    cur[emoji] = users;
    // Clean empty
    cur.removeWhere((_, v) => v.isEmpty);
    await _db.collection('chats').doc(cid)
        .collection('messages').doc(msgId).update({'reactions': cur});
  }
  static Future<void> markRead(String cid, String senderUid) async {
    final snap = await _db.collection('chats').doc(cid)
        .collection('messages')
        .where('senderId', isEqualTo: senderUid)
        .where('isRead', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true, 'readAt': Timestamp.now()});
    }
    await batch.commit();
  }
  static Stream<int> unreadCount(String cid, String myUid) =>
      _db.collection('chats').doc(cid).collection('messages')
         .where('receiverId', isEqualTo: myUid)
         .where('isRead', isEqualTo: false)
         .snapshots().map((s) => s.docs.length);

  static Future<void> setPresence({
    bool online = true,
    bool typing = false,
    bool recording = false,
    String? typingIn, // chatId currently typing in
  }) async {
    await _db.collection('presence').doc(me.uid).set({
      'uid':       me.uid,
      'online':    online,
      'typing':    typing,
      'recording': recording,
      'typingIn':  typingIn ?? '',
      'lastSeen':  FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  static Stream<DocumentSnapshot> presenceStream(String uid) =>
      _db.collection('presence').doc(uid).snapshots();
  static Stream<QuerySnapshot> users() =>
      _db.collection('users').snapshots();
  static Future<void> saveUser(User u) async {
    await _db.collection('users').doc(u.uid).set({
      'uid':   u.uid,
      'email': u.email ?? '',
      'name':  u.displayName ?? u.email!.split('@')[0],
    }, SetOptions(merge: true));
    await setPresence(online: true);
  }
}
class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
      useMaterial3: true,
    ),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snap.hasData ? const HomeScreen() : const LoginScreen();
      },
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
  bool _loading = false;

  void _err(dynamic e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString())));

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      await FS.saveUser(c.user!);
    } catch (e) { _err(e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _signup() async {
    setState(() => _loading = true);
    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      await FS.saveUser(c.user!);
    } catch (e) { _err(e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      final p = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      final c = await FirebaseAuth.instance.signInWithPopup(p);
      await FS.saveUser(c.user!);
    } catch (e) { _err(e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _pass, obscureText: true,
              decoration: const InputDecoration(labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
          const SizedBox(height: 20),
          if (_loading)
            const CircularProgressIndicator()
          else ...[
            _bigBtn('Login', kGreen, Colors.white, _login),
            const SizedBox(height: 10),
            _bigBtn('Sign Up', Colors.white, kGreen, _signup, outlined: true),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: _google,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
              label: const Text('Continue with Google'))),
          ],
        ]),
      ),
    )),
  );

  Widget _bigBtn(String label, Color bg, Color fg, VoidCallback cb,
      {bool outlined = false}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final pad   = const EdgeInsets.symmetric(vertical: 14);
    return SizedBox(width: double.infinity,
      child: outlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(padding: pad, shape: shape),
              onPressed: cb, child: Text(label, style: const TextStyle(fontSize: 16)))
          : ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: bg,
                  foregroundColor: fg, padding: pad, shape: shape),
              onPressed: cb, child: Text(label, style: const TextStyle(fontSize: 16))));
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
    FS.setPresence(online: true);
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FS.setPresence(online: false);
    super.dispose();
  }
  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    FS.setPresence(online: s == AppLifecycleState.resumed);
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
          onPressed: () async {
            await FS.setPresence(online: false);
            await FirebaseAuth.instance.signOut();
          },
        ),
      ],
    ),
    body: IndexedStack(index: _idx, children: _pages),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _idx,
      selectedItemColor: kGreen,
      onTap: (i) => setState(() => _idx = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.circle_outlined),     label: 'Status'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline),      label: 'Account'),
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
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _allUsers = [];

  @override void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final myUid = FS.me.uid;
    setState(() {
      _allUsers = snap.docs
          .map((d) => d.data())
          .where((d) => d['uid'] != myUid)
          .toList();
      _results  = _allUsers;
    });
  }

  void _search(String q) {
    setState(() {
      _results = q.isEmpty
          ? _allUsers
          : _allUsers.where((d) =>
              (d['name'] as String).toLowerCase().contains(q.toLowerCase()) ||
              (d['email'] as String).toLowerCase().contains(q.toLowerCase()))
            .toList();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: kGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      title: TextField(
        controller: _ctrl,
        autofocus: true,
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
    body: ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, indent: 72, thickness: 0.5),
      itemBuilder: (ctx, i) {
        final d = _results[i];
        return ListTile(
          leading: CircleAvatar(backgroundColor: kGreen,
              child: Text((d['name'] as String)[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white))),
          title: Text(d['name'] as String),
          subtitle: Text(d['email'] as String),
          onTap: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) =>
                  ChatScreen(rid: d['uid'] as String, rname: d['name'] as String))),
        );
      },
    ),
  );
}

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final myUid = FS.me.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FS.users(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final users = snap.data!.docs
            .where((d) => d['uid'] != myUid).toList();
        if (users.isEmpty) return const Center(
            child: Text('No users yet', style: TextStyle(color: Colors.grey)));
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 0, indent: 72, thickness: 0.5),
          itemBuilder: (ctx, i) {
            final d   = users[i].data() as Map<String, dynamic>;
            final cid = FS.chatId(myUid, d['uid'] as String);
            return _ChatTile(cid: cid, myUid: myUid,
                rid: d['uid'] as String, rname: d['name'] as String);
          },
        );
      },
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
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return '$h:$m';
    if (now.difference(dt).inDays < 7) {
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return days[(dt.weekday - 1).clamp(0, 6)];
    }
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lastStream = FirebaseFirestore.instance
        .collection('chats').doc(cid).collection('messages')
        .orderBy('sentAt', descending: true).limit(1).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: lastStream,
      builder: (ctx, lastSnap) {
        String subtitle = 'Tap to chat', timeStr = '';
        if (lastSnap.hasData && lastSnap.data!.docs.isNotEmpty) {
          final d  = lastSnap.data!.docs.first.data() as Map<String, dynamic>;
          subtitle = _preview(d); timeStr = _time(d['sentAt']);
        }
        return StreamBuilder<int>(
          stream: FS.unreadCount(cid, myUid),
          builder: (ctx, us) {
            final count = us.data ?? 0;
            final has   = count > 0;
            
            return StreamBuilder<DocumentSnapshot>(
              stream: FS.presenceStream(rid),
              builder: (ctx, presSnap) {
                bool online    = false;
                bool typing    = false;
                bool recording = false;
                String lastSeenStr = '';
                if (presSnap.hasData && presSnap.data!.exists) {
                  final p = presSnap.data!.data() as Map<String, dynamic>;
                  online    = p['online']    as bool? ?? false;
                  typing    = (p['typing']   as bool? ?? false) &&
                              (p['typingIn'] as String? ?? '') == cid;
                  recording = (p['recording'] as bool? ?? false) &&
                              (p['typingIn']  as String? ?? '') == cid;
                  final ls  = p['lastSeen'] as Timestamp?;
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
                String sub = typing    ? '✏️ typing…'
                           : recording ? '🎤 recording…'
                           : subtitle;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Stack(children: [
                    CircleAvatar(radius: 26, backgroundColor: kGreen,
                        child: Text(rname[0].toUpperCase(), style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    // Online dot
                    if (online) Positioned(right: 0, bottom: 0,
                      child: Container(width: 13, height: 13,
                        decoration: BoxDecoration(color: kGreen2,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)))),
                  ]),
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
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
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
                          textAlign: TextAlign.center, style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ) else if (!online && lastSeenStr.isNotEmpty)
                      Text(lastSeenStr, style: const TextStyle(
                          fontSize: 10, color: Colors.grey))
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
class ChatScreen extends StatefulWidget {
  final String rid, rname;
  const ChatScreen({super.key, required this.rid, required this.rname});
  @override State<ChatScreen> createState() => _ChatState();
}

class _ChatState extends State<ChatScreen> with WidgetsBindingObserver {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _me     = FirebaseAuth.instance.currentUser!;


  Msg? _replyMsg;
  
  Msg? _editMsg;
 
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _searchQ   = '';

  DisappearTimer _disappearTimer = DisappearTimer.off;

  String get _cid => FS.chatId(_me.uid, widget.rid);

  bool _isTyping = false;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markRead();
    FS.setPresence(online: true);
    _ctrl.addListener(_onTyping);
    
    FS.purgeExpiredMessages(_cid);
  
    _loadTimerSetting();
  }

  Future<void> _loadTimerSetting() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats').doc(_cid).get();
    if (doc.exists && mounted) {
      final t = (doc.data() as Map<String, dynamic>)['disappearTimer'] as String?;
      setState(() => _disappearTimer = DisappearTimerX.fromString(t));
    }
  }


  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.removeListener(_onTyping);
    _ctrl.dispose();
    _searchCtrl.dispose();
    _scroll.dispose();
    // Clear typing when leaving
    FS.setPresence(online: true, typing: false, typingIn: '');
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      FS.setPresence(online: true);
      _markRead();
    } else {
      FS.setPresence(online: false, typing: false);
    }
  }

  Future<void> _markRead() => FS.markRead(_cid, widget.rid);

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _onTyping() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      FS.setPresence(online: true, typing: true, typingIn: _cid);
    } else if (!hasText && _isTyping) {
      _isTyping = false;
      FS.setPresence(online: true, typing: false, typingIn: '');
    }
  }
  Future<void> _sendOrEdit() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;

    if (_editMsg != null) {
      // FEATURE 7: Edit sent message
      await FS.editMsg(_cid, _editMsg!.id, t);
      setState(() { _editMsg = null; });
    } else {
      await FS.sendMsg(
        receiverId:    widget.rid,
        message:       t,
        type:          MsgType.text,
        replyToId:     _replyMsg?.id,
        replyToText:   _replyMsg?.text,
        replyToSender: _replyMsg?.senderId == _me.uid ? 'You' : widget.rname,
      );
      setState(() { _replyMsg = null; });
      _scrollBottom();
    }
    _ctrl.clear();
    _isTyping = false;
    FS.setPresence(online: true, typing: false, typingIn: '');
  }

  Future<void> _deleteForEveryone(Msg msg) async {
    await FS.deleteForEveryone(_cid, msg.id);
  }
  Future<void> _react(Msg msg, String emoji) async {
    await FS.toggleReaction(_cid, msg.id, emoji, msg);
  }

  
  void _startEdit(Msg msg) {
    setState(() {
      _editMsg  = msg;
      _replyMsg = null;
    });
    _ctrl.text = msg.text;
    _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length));
  }


  void _startReply(Msg msg) {
    setState(() {
      _replyMsg = msg;
      _editMsg  = null;
    });
  }

  void _cancelAction() {
    setState(() { _replyMsg = null; _editMsg = null; });
    if (_editMsg != null) _ctrl.clear();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _showDisappearDialog() async {
    final chosen = await showDialog<DisappearTimer>(
      context: context,
      builder: (ctx) => _DisappearTimerDialog(current: _disappearTimer),
    );
    if (chosen == null) return;
    await FS.setDisappearTimer(_cid, chosen);
    setState(() => _disappearTimer = chosen);
    final msg = chosen == DisappearTimer.off
        ? 'Disappearing messages turned off'
        : 'Messages will disappear after ${chosen.label}';
    _snack(msg);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBgChat,
    appBar: _buildAppBar(),
    body: Column(children: [
      if (_disappearTimer != DisappearTimer.off)
        _DisappearBanner(timer: _disappearTimer, onTap: _showDisappearDialog),
      Expanded(child: _buildMsgList()),
      if (_replyMsg != null) _ReplyPreview(
        msg: _replyMsg!,
        rname: widget.rname,
        onCancel: _cancelAction,
      ),
      // Edit preview
      if (_editMsg != null) _EditPreview(onCancel: _cancelAction),
      _buildInput(),
    ]),
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: kGreen,
    titleSpacing: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    title: StreamBuilder<DocumentSnapshot>(
      stream: FS.presenceStream(widget.rid),
      builder: (ctx, snap) {
        String sub = '';
        if (snap.hasData && snap.data!.exists) {
          final p = snap.data!.data() as Map<String, dynamic>;
          final online    = p['online']    as bool? ?? false;
          final typing    = (p['typing']   as bool? ?? false) &&
                            (p['typingIn'] as String? ?? '') == _cid;
          final recording = (p['recording'] as bool? ?? false) &&
                            (p['typingIn']  as String? ?? '') == _cid;
          if (typing)         sub = 'typing…';
          else if (recording) sub = 'recording…';
          else if (online)    sub = 'online';
          else {
            final ls = p['lastSeen'] as Timestamp?;
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
        }
        return Row(children: [
          CircleAvatar(radius: 20, backgroundColor: Colors.white24,
              child: Text(widget.rname[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold))),
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
        tooltip: 'Disappearing messages',
        icon: Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.timer_outlined, color: Colors.white),
          if (_disappearTimer != DisappearTimer.off)
            Positioned(
              right: -2, top: -2,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: kGreen2, shape: BoxShape.circle),
              ),
            ),
        ]),
        onPressed: _showDisappearDialog,
      ),
      IconButton(
        icon: Icon(_searching ? Icons.close : Icons.search, color: Colors.white),
        onPressed: () => setState(() {
          _searching = !_searching;
          if (!_searching) { _searchQ = ''; _searchCtrl.clear(); }
        }),
      ),
    ],
  );

  Widget _buildMsgList() => Column(children: [
    // In-chat search bar
    if (_searching) Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search messages…',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onChanged: (v) => setState(() => _searchQ = v.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FS.messages(_cid),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        _markRead();
        var docs = snap.data!.docs;
        // Filter by search
        if (_searchQ.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['message'] as String? ?? '')
                .toLowerCase().contains(_searchQ);
          }).toList();
        }
        if (docs.isEmpty) return Center(
            child: Text(_searchQ.isNotEmpty ? 'No results' : 'No messages yet. Say hi! 👋',
                style: const TextStyle(color: Colors.grey)));
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final msg  = Msg.fromDoc(docs[i]);
            final isMe = msg.senderId == _me.uid;
            final showD = i == 0 || (i > 0 && _diffDay(
                Msg.fromDoc(docs[i-1]).sentAt.toDate(), msg.sentAt.toDate()));
            return Column(children: [
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
            ]);          },
        );
      },
    )),
  ]);

  bool _diffDay(DateTime a, DateTime b) =>
      a.day != b.day || a.month != b.month || a.year != b.year;

  Widget _buildInput() => Container(
    color: const Color(0xffF0F0F0),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(children: [
      Expanded(child: Container(
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(24)),
        child: TextField(
          controller: _ctrl,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: _editMsg != null ? 'Edit message…' : 'Message',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: InputBorder.none,
          ),
        ),
      )),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _sendOrEdit,
        child: CircleAvatar(radius: 22,
            backgroundColor: kGreen,
            child: Icon(_editMsg != null ? Icons.check : Icons.send_rounded,
                color: Colors.white, size: 20)),
      ),
    ]),
  );
}
class _ReplyPreview extends StatelessWidget {
  final Msg msg; final String rname; final VoidCallback onCancel;
  const _ReplyPreview({required this.msg, required this.rname, required this.onCancel});

  @override Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final senderName = msg.senderId == me.uid ? 'You' : rname;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        Container(width: 4, height: 40, color: kGreen,
            margin: const EdgeInsets.only(right: 10)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text('Reply to $senderName', style: const TextStyle(
              color: kGreen, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(msg.text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        IconButton(icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel),
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
      const Expanded(child: Text('Editing message…',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600))),
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
    showModalBottomSheet(context: ctx, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (msg.type != MsgType.deleted) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: kReactions.map((e) => GestureDetector(
                onTap: () { Navigator.pop(ctx); onReact(e); },
                child: Text(e, style: const TextStyle(fontSize: 28)),
              )).toList(),
            ),
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
        if (isMe && msg.type != MsgType.deleted)
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete for Everyone',
                  style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); onDelete(); }),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () => _showMenu(context),
    // Swipe right to reply
    child: Dismissible(
      key: ValueKey('swipe_${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async { onReply(); return false; },
      background: Align(alignment: Alignment.centerLeft,
          child: Padding(padding: const EdgeInsets.only(left: 16),
            child: Icon(Icons.reply, color: kGreen.withOpacity(0.6)))),
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
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(left: isMe?60:8, right: isMe?8:60, top:2, bottom:0),
            decoration: BoxDecoration(
              color: msg.type == MsgType.deleted
                  ? Colors.grey.shade200
                  : (isMe ? kBubbleMe : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe?16:4),
                bottomRight: Radius.circular(isMe?4:16)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 3, offset: const Offset(0, 1))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe?16:4),
                bottomRight: Radius.circular(isMe?4:16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                
                if (msg.replyToId != null) _ReplyQuote(
                    text:   msg.replyToText ?? '',
                    sender: msg.replyToSender ?? ''),
                _content(),
                
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 5, left: 8, top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                   
                    if (msg.expiresAt != null) ...[
                      _ExpiryChip(expiresAt: msg.expiresAt!),
                      const SizedBox(width: 5),
                    ],
                    if (msg.isEdited && msg.type != MsgType.deleted)
                      const Text('edited ', style: TextStyle(
                          fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                    Text(_fmt(msg.sentAt.toDate()),
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      
                      Icon(
                        msg.status == MsgStatus.read ? Icons.done_all :
                        msg.status == MsgStatus.delivered ? Icons.done_all : Icons.done,
                        size: 13,
                        color: msg.status == MsgStatus.read
                            ? Colors.blue : Colors.grey,
                      ),
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
              child: Wrap(spacing: 4, children: msg.reactions.entries.map((e) {
                final users = e.value;
                if (users.isEmpty) return const SizedBox.shrink();
                final iReacted = users.contains(meUid);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iReacted ? kGreen.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: iReacted ? kGreen : Colors.grey.shade300),
                  ),
                  child: Text('${e.key} ${users.length}',
                      style: const TextStyle(fontSize: 12)),
                );
              }).toList()),
            ),
        ],
      ),
    );
  }

  Widget _content() {
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
    switch (msg.type) {
      case MsgType.image:
        return _mediaTile(Icons.image, 'Photo', Colors.purple);
      case MsgType.video:
        return _mediaTile(Icons.videocam, 'Video', Colors.orange);
      case MsgType.audio:
        return _mediaTile(Icons.mic, 'Voice message', Colors.teal);
      case MsgType.file:
        return _mediaTile(Icons.insert_drive_file,
            msg.fileName ?? 'File', Colors.blue);
      default:
        return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Text(msg.text,
              style: const TextStyle(fontSize: 15, height: 1.3)));
    }
  }

  Widget _mediaTile(IconData icon, String label, Color color) =>
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.w500, fontSize: 14)),
        ]));

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

class _ReplyQuote extends StatelessWidget {
  final String text, sender;
  const _ReplyQuote({required this.text, required this.sender});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.06),
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
    final now = DateTime.now(); final d = now.difference(date).inDays;
    if (d == 0) return 'Today'; if (d == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
  @override Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xffD0E9C6).withOpacity(0.85),
          borderRadius: BorderRadius.circular(8)),
      child: Text(_lbl, style: const TextStyle(fontSize: 12,
          color: Color(0xff4A4A4A), fontWeight: FontWeight.w500)),
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
        Expanded(
          child: Text(
            'Disappearing messages: ${timer.label}',
            style: const TextStyle(fontSize: 12, color: Color(0xff7B6E00),
                fontWeight: FontWeight.w500),
          ),
        ),
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
    if (rem.inDays >= 1) {
      final d = rem.inDays;
      return '${d}d ${rem.inHours.remainder(24)}h';
    }
    if (rem.inHours >= 1) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
    }
    if (rem.inMinutes >= 1) {
      return '${rem.inMinutes}m ${rem.inSeconds.remainder(60)}s';
    }
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
            ? Colors.red.withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 10,
            color: expired ? Colors.red : Colors.orange),
        const SizedBox(width: 3),
        Text(_label,
            style: TextStyle(
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
        'Messages sent in this chat will automatically be deleted after the selected time.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 16),
      ...DisappearTimer.values.map((t) => _TimerOption(
        timer:     t,
        selected:  t == current,
        onTap:     () => Navigator.pop(context, t),
      )),
    ]),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _TimerOption extends StatelessWidget {
  final DisappearTimer timer;
  final bool           selected;
  final VoidCallback   onTap;
  const _TimerOption({required this.timer, required this.selected,
      required this.onTap});

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
        color: selected ? kGreen.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? kGreen : Colors.grey.shade200,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: Row(children: [
        Icon(_icon, size: 20,
            color: selected ? kGreen : Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timer.label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? kGreen : Colors.black87,
                    fontSize: 14)),
            if (timer != DisappearTimer.off)
              Text(_description(timer),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        )),
        if (selected)
          const Icon(Icons.check_circle, color: kGreen, size: 20),
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




// @override
//   Widget build(BuildContext context, q, onTap) => InkWell(
//     onTap: onTap,
//     borderRadius: BorderRadius.circular(10),
//     child: Container(
//       margin: const EdgeInsets.only(bottom: 6),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: BoxDecoration(
//         color: selected ? kGreen.withValues(alpha: 0.08) : Colors.transparent,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: selected ? kGreen : Colors.grey.shade200,
//           width: selected ? 1.5 : 0.5,
//         ),
//       ),w
//       child: Row(children: [
//         Icon(_icon, size: 20,
//             color: selected ? kGreen : Colors.grey),
//         const SizedBox(width: 12),
//         Expanded(child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(timer.label,
//                 style: TextStyle(
//                     fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
//                     color: selected ? kGreen : Colors.black87,
//                     fontSize: 14)),
//             if (timer != DisappearTimer.off)
//               Text(_description(timer),
//                   style: const TextStyle(fontSize: 11, color: Colors.grey)),
//           ],
//         )),
//         if (selected)
//           const Icon(Icons.check_circle, color: kGreen, size: 20),
//       ]),
//     ),
//   )ŵ
//   String _description (DisappearTimer t)
//   String _description(DisappearTimer t) {
//     switch (t) {
//       case DisappearTimer.h24: return 'Great for sensitive conversations';
//       case DisappearTimer.d7:  return 'Recommended — like WhatsApp default';
//       case DisappearTimer.d90: return 'Long-term but still disappears';
//       default:                 return '';
//     }
//   }


