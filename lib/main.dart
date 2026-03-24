import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── ENTRY POINT ────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrimeYardBootstrapApp());
}

// ─── BOOTSTRAP ──────────────────────────────────────────────────────────────

class PrimeYardBootstrapApp extends StatefulWidget {
  const PrimeYardBootstrapApp({super.key});
  @override
  State<PrimeYardBootstrapApp> createState() => _PrimeYardBootstrapAppState();
}

class _PrimeYardBootstrapAppState extends State<PrimeYardBootstrapApp> {
  late final Future<_BootstrapPayload> _future = _init();

  Future<_BootstrapPayload> _init() async {
    String? startupError;
    try {
      await BackendService.initialize().timeout(const Duration(seconds: 12));
    } catch (e) {
      startupError = 'Firebase init failed: $e';
    }
    final session = await AppSession.load();
    return _BootstrapPayload(session: session, startupError: startupError);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Palette.deepGreen,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo-mark.png', width: 120, height: 120),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text('Starting PrimeYard Workspace...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        }
        return PrimeYardApp(
          initialSession: snapshot.data!.session,
          startupError: snapshot.data!.startupError,
        );
      },
    );
  }
}

class _BootstrapPayload {
  final AppSession session;
  final String? startupError;
  const _BootstrapPayload({required this.session, this.startupError});
}

// ─── FIREBASE CONFIG ─────────────────────────────────────────────────────────

class FirebaseConfig {
  static const options = FirebaseOptions(
    apiKey: 'AIzaSyAf0ziL9na5z7CPodC33T1SjQVBOCXUFCg',
    appId: '1:1063126418476:android:d42f77528438d22ac7bd89',
    messagingSenderId: '1063126418476',
    projectId: 'primeyard-521ea',
    storageBucket: 'primeyard-521ea.firebasestorage.app',
  );
}

// ─── PALETTE ─────────────────────────────────────────────────────────────────

class Palette {
  static const green = Color(0xFF1A6B30);
  static const deepGreen = Color(0xFF0D3B1A);
  static const softGreen = Color(0xFF2F8A4B);
  static const gold = Color(0xFFF2B632);
  static const khaki = Color(0xFFD9CFB8);
  static const cream = Color(0xFFF5F1E8);
  static const card = Colors.white;
  static const text = Color(0xFF171717);
  static const muted = Color(0xFF6D665D);
  static const border = Color(0xFFE6DED0);
  static const danger = Color(0xFFC62828);
}

// ─── APP SESSION ─────────────────────────────────────────────────────────────

class AppSession {
  final bool loggedIn;
  final String id;
  final String username;
  final String displayName;
  final String role;

  const AppSession({
    this.loggedIn = false,
    this.id = '',
    this.username = '',
    this.displayName = '',
    this.role = '',
  });

  static Future<AppSession> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSession(
      loggedIn: prefs.getBool('loggedIn') ?? false,
      id: prefs.getString('uid') ?? '',
      username: prefs.getString('username') ?? '',
      displayName: prefs.getString('displayName') ?? '',
      role: prefs.getString('role') ?? '',
    );
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', loggedIn);
    await prefs.setString('uid', id);
    await prefs.setString('username', username);
    await prefs.setString('displayName', displayName);
    await prefs.setString('role', role);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  bool get isAdmin => role == 'admin' || role == 'master_admin';
  bool get isMasterAdmin => role == 'master_admin';
  bool get isSupervisor => role == 'supervisor';
  bool get isWorker => role == 'worker';
}

// ─── WORKSPACE STATE ─────────────────────────────────────────────────────────

class WorkspaceState {
  final List<dynamic> clients;
  final List<dynamic> invoices;
  final List<dynamic> jobs;
  final List<dynamic> emps;
  final List<dynamic> quotes;
  final List<dynamic> equipment;
  final List<dynamic> checkLogs;
  final List<dynamic> clockEntries;
  final List<dynamic> users;
  final String schedDate;
  final DateTime? updatedAt;

  const WorkspaceState({
    required this.clients,
    required this.invoices,
    required this.jobs,
    required this.emps,
    required this.quotes,
    required this.equipment,
    required this.checkLogs,
    required this.clockEntries,
    required this.users,
    required this.schedDate,
    this.updatedAt,
  });

  factory WorkspaceState.empty() => WorkspaceState(
        clients: const [],
        invoices: const [],
        jobs: const [],
        emps: const [],
        quotes: const [],
        equipment: const [],
        checkLogs: const [],
        clockEntries: const [],
        users: const [],
        schedDate: _today(),
      );

  factory WorkspaceState.fromMap(Map<String, dynamic>? map) {
    final data = map ?? <String, dynamic>{};
    return WorkspaceState(
      clients: List<dynamic>.from(data['clients'] ?? const []),
      invoices: List<dynamic>.from(data['invoices'] ?? const []),
      jobs: List<dynamic>.from(data['jobs'] ?? const []),
      emps: List<dynamic>.from(data['emps'] ?? const []),
      quotes: List<dynamic>.from(data['quotes'] ?? const []),
      equipment: List<dynamic>.from(data['equipment'] ?? const []),
      checkLogs: List<dynamic>.from(data['checkLogs'] ?? const []),
      clockEntries: List<dynamic>.from(data['clockEntries'] ?? const []),
      users: List<dynamic>.from(data['users'] ?? const []),
      schedDate: (data['schedDate'] ?? _today()).toString(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['updatedAt'] is String ? DateTime.tryParse(data['updatedAt']) : null),
    );
  }

  Map<String, dynamic> toMap() => {
        'clients': clients,
        'invoices': invoices,
        'jobs': jobs,
        'emps': emps,
        'quotes': quotes,
        'equipment': equipment,
        'checkLogs': checkLogs,
        'clockEntries': clockEntries,
        'users': users,
        'schedDate': schedDate,
      };

  WorkspaceState copyWith({
    List<dynamic>? clients,
    List<dynamic>? invoices,
    List<dynamic>? jobs,
    List<dynamic>? emps,
    List<dynamic>? quotes,
    List<dynamic>? equipment,
    List<dynamic>? checkLogs,
    List<dynamic>? clockEntries,
    List<dynamic>? users,
    String? schedDate,
    DateTime? updatedAt,
  }) {
    return WorkspaceState(
      clients: clients ?? this.clients,
      invoices: invoices ?? this.invoices,
      jobs: jobs ?? this.jobs,
      emps: emps ?? this.emps,
      quotes: quotes ?? this.quotes,
      equipment: equipment ?? this.equipment,
      checkLogs: checkLogs ?? this.checkLogs,
      clockEntries: clockEntries ?? this.clockEntries,
      users: users ?? this.users,
      schedDate: schedDate ?? this.schedDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─── BACKEND SERVICE ──────────────────────────────────────────────────────────

class BackendBootstrap {
  final WorkspaceState state;
  final String? error;
  final bool hasRemoteData;
  const BackendBootstrap({required this.state, this.error, required this.hasRemoteData});
  bool get hasUsers => state.users.isNotEmpty;
}

class BackendService {
  static final _auth = fb.FirebaseAuth.instance;
  static final _doc = FirebaseFirestore.instance.collection('primeyard').doc('sharedState');

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
  }

  static Future<void> ensureAnonymousSession() async {
    await initialize();
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
    if (_auth.currentUser != null) return;
    await _auth.authStateChanges().firstWhere((user) => user != null);
  }

  static Future<void> _cacheStateMap(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedWorkspaceState', jsonEncode(_jsonSafeMap(data)));
  }

  static Future<void> _cacheUsers(List<dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedUsers', jsonEncode(_jsonSafe(users)));
  }

  static Future<WorkspaceState> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cachedWorkspaceState');
    if (raw == null || raw.isEmpty) return WorkspaceState.empty();
    try {
      return WorkspaceState.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WorkspaceState.empty();
    }
  }

  static Future<List<Map<String, dynamic>>> _loadCachedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cachedUsers');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<BackendBootstrap> bootstrap() async {
    try {
      await ensureAnonymousSession();
      final snap = await _doc.get(const GetOptions(source: Source.serverAndCache));
      if (!snap.exists) {
        final cached = await _loadCachedState();
        return BackendBootstrap(state: cached, hasRemoteData: false, error: 'No live sharedState document found.');
      }
      final data = Map<String, dynamic>.from(snap.data() ?? const {});
      await _cacheStateMap(data);
      await _cacheUsers(List<dynamic>.from(data['users'] ?? const []));
      final state = WorkspaceState.fromMap(data);
      final hasRemoteData = state.users.isNotEmpty || state.clients.isNotEmpty || state.jobs.isNotEmpty;
      return BackendBootstrap(state: state, hasRemoteData: hasRemoteData);
    } on fb.FirebaseAuthException catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(state: cached, hasRemoteData: false, error: '[auth/${e.code}] ${e.message}');
    } on FirebaseException catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(state: cached, hasRemoteData: false, error: '[firebase/${e.code}] ${e.message}');
    } catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(state: cached, hasRemoteData: false, error: e.toString());
    }
  }

  static Stream<WorkspaceState> streamState() async* {
    try {
      await ensureAnonymousSession();
      yield* _doc.snapshots().asyncMap((snapshot) async {
        if (!snapshot.exists) return await _loadCachedState();
        final data = Map<String, dynamic>.from(snapshot.data() ?? const {});
        await _cacheStateMap(data);
        await _cacheUsers(List<dynamic>.from(data['users'] ?? const []));
        return WorkspaceState.fromMap(data);
      });
    } catch (_) {
      yield await _loadCachedState();
    }
  }

  static Future<WorkspaceState> getState() async {
    try {
      await ensureAnonymousSession();
      final snap = await _doc.get(const GetOptions(source: Source.serverAndCache));
      if (!snap.exists) return await _loadCachedState();
      final data = Map<String, dynamic>.from(snap.data() ?? const {});
      await _cacheStateMap(data);
      await _cacheUsers(List<dynamic>.from(data['users'] ?? const []));
      return WorkspaceState.fromMap(data);
    } catch (_) {
      return await _loadCachedState();
    }
  }

  static Future<Map<String, dynamic>?> login(String username, String password) async {
    final inputUser = username.toLowerCase();
    final inputHash = _hash(password);

    Future<Map<String, dynamic>?> fromUsers(List<dynamic> users) async {
      for (final entry in users) {
        if (entry is Map) {
          final u = Map<String, dynamic>.from(entry);
          final userName = (u['username'] ?? '').toString().toLowerCase();
          final passwordHash = (u['passwordHash'] ?? '').toString();
          if (userName == inputUser && passwordHash == inputHash) return u;
        }
      }
      return null;
    }

    final state = await getState();
    final hit = await fromUsers(state.users);
    if (hit != null) return hit;
    final cached = await _loadCachedUsers();
    return await fromUsers(cached);
  }

  static Future<void> saveState(WorkspaceState state, {String updatedBy = 'flutter_v5'}) async {
    await ensureAnonymousSession();
    final data = {...state.toMap(), 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': updatedBy};
    await _doc.set(data, SetOptions(merge: true));
    await _cacheStateMap(state.toMap());
    await _cacheUsers(state.users);
  }

  // Upload photo to Firebase Storage, return download URL
  static Future<String?> uploadPhoto(String jobId, String type, File file) async {
    try {
      await ensureAnonymousSession();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref('jobs/$jobId/${type}_$ts.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}

// ─── MAIN APP ─────────────────────────────────────────────────────────────────

class PrimeYardApp extends StatefulWidget {
  final AppSession initialSession;
  final String? startupError;
  const PrimeYardApp({super.key, required this.initialSession, this.startupError});
  @override
  State<PrimeYardApp> createState() => _PrimeYardAppState();
}

class _PrimeYardAppState extends State<PrimeYardApp> {
  late AppSession session = widget.initialSession;
  void onSignedIn(AppSession value) => setState(() => session = value);
  Future<void> onSignedOut() async {
    await AppSession.clear();
    setState(() => session = const AppSession());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.green,
      primary: Palette.green,
      secondary: Palette.gold,
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PrimeYard Workspace',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.cream,
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Palette.text),
        cardTheme: CardThemeData(
          color: Palette.card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Palette.border)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Palette.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Palette.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Palette.green, width: 1.5)),
        ),
      ),
      home: session.loggedIn
          ? WorkspaceShell(session: session, onSignOut: onSignedOut, onSessionUpdate: onSignedIn)
          : LoginScreen(onSignedIn: onSignedIn, startupError: widget.startupError),
    );
  }
}

// ─── LOGIN ────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final ValueChanged<AppSession> onSignedIn;
  final String? startupError;
  const LoginScreen({super.key, required this.onSignedIn, this.startupError});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = true;
  String? error;
  BackendBootstrap? bootstrap;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final info = await BackendService.bootstrap();
    if (!mounted) return;
    setState(() {
      bootstrap = info;
      loading = false;
      if (info.error != null && info.state.users.isEmpty) error = info.error;
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() { loading = true; error = null; });
    final user = await BackendService.login(userCtrl.text, passCtrl.text);
    if (user == null) {
      setState(() { error = 'Incorrect username or password.'; loading = false; });
      return;
    }
    final session = AppSession(
      loggedIn: true,
      id: (user['id'] ?? '').toString(),
      username: (user['username'] ?? '').toString(),
      displayName: (user['displayName'] ?? user['name'] ?? user['username'] ?? 'PrimeYard').toString(),
      role: (user['role'] ?? 'worker').toString(),
    );
    await session.persist();
    widget.onSignedIn(session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Palette.deepGreen, Palette.green, Palette.softGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: Image.asset('assets/logo-full.png', height: 64)),
                        const SizedBox(height: 8),
                        Text('Business Manager', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Palette.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text('Your property, our pride.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 18),
                        Image.asset('assets/mascot.png', height: 160, fit: BoxFit.contain),
                        const SizedBox(height: 18),
                        if (bootstrap != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFFF7F4EC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.border)),
                            child: Row(
                              children: [
                                Icon(bootstrap!.hasRemoteData ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: bootstrap!.hasRemoteData ? Palette.green : Palette.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(bootstrap!.hasRemoteData ? 'Live workspace connected' : 'Using cached data', style: const TextStyle(fontWeight: FontWeight.w800))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextField(controller: userCtrl, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username')),
                        const SizedBox(height: 12),
                        TextField(controller: passCtrl, obscureText: true, onSubmitted: (_) => _login(), decoration: const InputDecoration(labelText: 'Password')),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(14)), child: Text(error!, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w700))),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: loading ? null : _login,
                          icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                          label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(loading ? 'Signing in...' : 'Sign in')),
                          style: FilledButton.styleFrom(backgroundColor: Palette.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── WORKSPACE SHELL ──────────────────────────────────────────────────────────

class WorkspaceShell extends StatefulWidget {
  final AppSession session;
  final Future<void> Function() onSignOut;
  final ValueChanged<AppSession> onSessionUpdate;
  const WorkspaceShell({super.key, required this.session, required this.onSignOut, required this.onSessionUpdate});
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkspaceState>(
      stream: BackendService.streamState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final state = snapshot.data ?? WorkspaceState.empty();
        final pages = _pagesForRole(widget.session, state);
        if (index >= pages.length) index = 0;
        final current = pages[index];
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                Image.asset('assets/logo-mark.png', width: 28, height: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(current.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(widget.session.displayName, style: const TextStyle(fontSize: 12, color: Palette.muted)),
                  ]),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => _showProfileMenu(context, state),
                icon: CircleAvatar(backgroundColor: Palette.green, radius: 16, child: Text(_initials(widget.session.displayName), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
              ),
            ],
          ),
          body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: current.builder(context, state)),
          bottomNavigationBar: NavigationBar(
            height: 72,
            selectedIndex: index,
            destinations: [for (final p in pages) NavigationDestination(icon: Icon(p.icon), label: p.shortLabel)],
            onDestinationSelected: (v) => setState(() => index = v),
          ),
        );
      },
    );
  }

  void _showProfileMenu(BuildContext context, WorkspaceState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                CircleAvatar(backgroundColor: Palette.green, radius: 24, child: Text(_initials(widget.session.displayName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.session.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('@${widget.session.username} · ${widget.session.role}', style: const TextStyle(color: Palette.muted)),
                ]),
              ]),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Change password'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePassword(context, state);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Palette.danger),
                title: const Text('Sign out', style: TextStyle(color: Palette.danger)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () { Navigator.pop(context); widget.onSignOut(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context, WorkspaceState state) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            const SizedBox(height: 10),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
            const SizedBox(height: 10),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
            if (err != null) ...[const SizedBox(height: 10), Text(err!, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w700))],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) { setS(() => err = 'All fields required.'); return; }
                if (newCtrl.text != confirmCtrl.text) { setS(() => err = 'Passwords do not match.'); return; }
                if (newCtrl.text.length < 6) { setS(() => err = 'Min 6 characters.'); return; }
                final currentUser = state.users.whereType<Map>().firstWhere((u) => (u['username'] ?? '').toString().toLowerCase() == widget.session.username.toLowerCase(), orElse: () => {});
                if (currentUser.isEmpty) { setS(() => err = 'User not found.'); return; }
                if (_hash(oldCtrl.text) != (currentUser['passwordHash'] ?? '').toString()) { setS(() => err = 'Current password incorrect.'); return; }
                final newHash = _hash(newCtrl.text);
                final updatedUsers = state.users.whereType<Map>().map((u) {
                  final row = Map<String, dynamic>.from(u);
                  if ((row['username'] ?? '').toString().toLowerCase() == widget.session.username.toLowerCase()) row['passwordHash'] = newHash;
                  return row;
                }).toList();
                await BackendService.saveState(state.copyWith(users: updatedUsers), updatedBy: widget.session.username);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!')));
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  List<_PageDef> _pagesForRole(AppSession s, WorkspaceState state) {
    if (s.isWorker) {
      return [
        _PageDef('My Route', 'Route', Icons.route_rounded, (c, st) => WorkerTodayPage(session: s, state: st)),
        _PageDef('Clock', 'Clock', Icons.access_time_rounded, (c, st) => ClockPage(session: s, state: st)),
        _PageDef('Equipment', 'Equipment', Icons.handyman_rounded, (c, st) => EquipmentPage(state: st, session: s)),
      ];
    }
    if (s.isSupervisor) {
      return [
        _PageDef('Dashboard', 'Home', Icons.dashboard_rounded, (c, st) => DashboardPage(state: st)),
        _PageDef('Schedule', 'Jobs', Icons.calendar_month_rounded, (c, st) => SchedulerPage(state: st, session: s)),
        _PageDef('Equipment', 'Checks', Icons.handyman_rounded, (c, st) => EquipmentPage(state: st, session: s)),
        _PageDef('Jobs log', 'Log', Icons.task_alt_rounded, (c, st) => JobsLogPage(state: st)),
        _PageDef('Clock', 'Clock', Icons.punch_clock_rounded, (c, st) => ClockEntriesPage(state: st)),
      ];
    }
    // admin / master_admin
    return [
      _PageDef('Dashboard', 'Home', Icons.dashboard_rounded, (c, st) => DashboardPage(state: st)),
      _PageDef('Clients', 'Clients', Icons.people_alt_rounded, (c, st) => ClientsPage(state: st, session: s)),
      _PageDef('Invoices', 'Bills', Icons.receipt_long_rounded, (c, st) => InvoicesPage(state: st, session: s)),
      _PageDef('Schedule', 'Jobs', Icons.calendar_month_rounded, (c, st) => SchedulerPage(state: st, session: s)),
      _PageDef('Staff', 'Staff', Icons.badge_rounded, (c, st) => EmployeesPage(state: st, session: s)),
      _PageDef('More', 'More', Icons.tune_rounded, (c, st) => MorePage(state: st, session: s)),
    ];
  }
}

class _PageDef {
  final String label, shortLabel;
  final IconData icon;
  final Widget Function(BuildContext, WorkspaceState) builder;
  _PageDef(this.label, this.shortLabel, this.icon, this.builder);
}

// ═══════════════════════════════════════════════════════════════════════════
// WORKER PAGES
// ═══════════════════════════════════════════════════════════════════════════

// ─── WORKER TODAY / ROUTE ────────────────────────────────────────────────────

class WorkerTodayPage extends StatelessWidget {
  final AppSession session;
  final WorkspaceState state;
  const WorkerTodayPage({super.key, required this.session, required this.state});

  @override
  Widget build(BuildContext context) {
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((job) {
      final worker = (job['workerName'] ?? '').toString().toLowerCase();
      return (worker == session.displayName.toLowerCase() || worker == session.username.toLowerCase() || worker.isEmpty) && (job['date'] ?? '') == state.schedDate;
    }).toList();

    final done = jobs.where((j) => j['done'] == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'My Route', subtitle: '${state.schedDate} · $done/${jobs.length} done'),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openJobDetail(context, job),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(job['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: job['done'] == true ? Palette.green : Palette.muted, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((job['name'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if ((job['address'] ?? '').toString().isNotEmpty) Text(job['address'].toString(), style: const TextStyle(color: Palette.muted)),
                          if ((job['notes'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Note: ${job['notes']}', style: const TextStyle(color: Palette.green, fontSize: 12)),
                          ],
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Palette.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (jobs.isEmpty)
          const _EmptyState(icon: Icons.route_rounded, title: 'No route assigned', subtitle: 'No jobs are assigned to you for today yet.'),
      ],
    );
  }

  void _openJobDetail(BuildContext context, Map<String, dynamic> job) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(job: job, session: session, state: state)));
  }
}

// ─── JOB DETAIL (WORKER) ─────────────────────────────────────────────────────

class JobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final AppSession session;
  final WorkspaceState state;
  const JobDetailPage({super.key, required this.job, required this.session, required this.state});
  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  late Map<String, dynamic> job;
  final notesCtrl = TextEditingController();
  bool saving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    job = Map<String, dynamic>.from(widget.job);
    notesCtrl.text = (job['notes'] ?? '').toString();
  }

  Future<void> _toggleDone() async {
    final newDone = !(job['done'] == true);
    setState(() {
      job['done'] = newDone;
      if (newDone) {
        job['completedAt'] = DateTime.now().toIso8601String();
        job['completedBy'] = widget.session.username;
      }
    });
    await _saveJob();
  }

  Future<void> _saveNotes() async {
    setState(() { job['notes'] = notesCtrl.text.trim(); saving = true; });
    await _saveJob();
    setState(() => saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved')));
  }

  Future<void> _pickPhoto(String type) async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;
    setState(() => saving = true);
    final url = await BackendService.uploadPhoto(job['id'].toString(), type, File(picked.path));
    if (url != null) {
      final key = type == 'before' ? 'beforePhotos' : 'afterPhotos';
      final existing = List<String>.from(job[key] ?? []);
      existing.add(url);
      setState(() { job[key] = existing; });
      await _saveJob();
    }
    setState(() => saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type == 'before' ? 'Before' : 'After'} photo uploaded')));
  }

  Future<void> _saveJob() async {
    final updatedJobs = widget.state.jobs.whereType<Map>().map((e) {
      final row = Map<String, dynamic>.from(e);
      if (row['id'] == job['id']) return Map<String, dynamic>.from(job);
      return row;
    }).toList();
    await BackendService.saveState(widget.state.copyWith(jobs: updatedJobs), updatedBy: widget.session.username);
  }

  @override
  Widget build(BuildContext context) {
    final beforePhotos = List<String>.from(job['beforePhotos'] ?? []);
    final afterPhotos = List<String>.from(job['afterPhotos'] ?? []);
    final isDone = job['done'] == true;

    return Scaffold(
      appBar: AppBar(title: Text((job['name'] ?? 'Job').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(isDone ? Icons.check_circle_rounded : Icons.circle_outlined, color: isDone ? Palette.green : Palette.muted, size: 24),
                  const SizedBox(width: 10),
                  Text(isDone ? 'Completed' : 'Pending', style: TextStyle(fontWeight: FontWeight.w800, color: isDone ? Palette.green : Palette.muted, fontSize: 16)),
                ]),
                if ((job['address'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [const Icon(Icons.location_on_rounded, color: Palette.muted, size: 18), const SizedBox(width: 6), Expanded(child: Text(job['address'].toString(), style: const TextStyle(color: Palette.muted)))]),
                ],
                if (isDone && (job['completedAt'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Completed at ${_fmtDateTime(job['completedAt'].toString())}', style: const TextStyle(color: Palette.green, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : _toggleDone,
                  icon: Icon(isDone ? Icons.undo_rounded : Icons.check_rounded),
                  label: Text(isDone ? 'Mark as pending' : 'Mark as done'),
                  style: FilledButton.styleFrom(backgroundColor: isDone ? Palette.muted : Palette.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Job notes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Add notes about this job...')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: saving ? null : _saveNotes,
                  icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                  label: const Text('Save notes'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Before photos
          _PhotoSection(title: 'Before photos', photos: beforePhotos, onAdd: saving ? null : () => _pickPhoto('before')),
          const SizedBox(height: 12),

          // After photos
          _PhotoSection(title: 'After photos', photos: afterPhotos, onAdd: saving ? null : () => _pickPhoto('after')),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final String title;
  final List<String> photos;
  final VoidCallback? onAdd;
  const _PhotoSection({required this.title, required this.photos, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (onAdd != null)
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.camera_alt_rounded, size: 16), label: const Text('Photo'), style: FilledButton.styleFrom(backgroundColor: Palette.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
          ]),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photos[i], width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: Palette.border, child: const Icon(Icons.broken_image_rounded))),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text('No photos yet', style: TextStyle(color: Palette.muted)),
          ],
        ]),
      ),
    );
  }
}

// ─── CLOCK PAGE (WORKER) ─────────────────────────────────────────────────────

class ClockPage extends StatefulWidget {
  final AppSession session;
  final WorkspaceState state;
  const ClockPage({super.key, required this.session, required this.state});
  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  bool saving = false;

  List<Map<String, dynamic>> get _myEntries => widget.state.clockEntries
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((e) => (e['username'] ?? '').toString().toLowerCase() == widget.session.username.toLowerCase())
      .toList()
    ..sort((a, b) => (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));

  String? get _lastEntryType {
    final todayEntries = _myEntries.where((e) => (e['date'] ?? '') == _today()).toList();
    if (todayEntries.isEmpty) return null;
    return (todayEntries.first['type'] ?? '').toString();
  }

  bool get _isClockedIn => _lastEntryType == 'in';

  Future<void> _clock(String type) async {
    setState(() => saving = true);
    final now = DateTime.now();
    final entry = {
      'id': now.millisecondsSinceEpoch.toString(),
      'userId': widget.session.id,
      'username': widget.session.username,
      'displayName': widget.session.displayName,
      'type': type,
      'timestamp': now.toIso8601String(),
      'date': _today(),
    };
    final entries = [...widget.state.clockEntries, entry];
    await BackendService.saveState(widget.state.copyWith(clockEntries: entries), updatedBy: widget.session.username);
    setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final myEntries = _myEntries;
    final todayEntries = myEntries.where((e) => (e['date'] ?? '') == _today()).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'My Clock', subtitle: _today()),
        // Big clock in/out button
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isClockedIn ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(children: [
                    Icon(_isClockedIn ? Icons.login_rounded : Icons.logout_rounded, size: 48, color: _isClockedIn ? Palette.green : Palette.gold),
                    const SizedBox(height: 8),
                    Text(_isClockedIn ? 'You are clocked IN' : 'You are clocked OUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _isClockedIn ? Palette.green : const Color(0xFFE65100))),
                    const SizedBox(height: 4),
                    Text(DateFormat('HH:mm - EEEE d MMM').format(DateTime.now()), style: const TextStyle(color: Palette.muted)),
                  ]),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: saving ? null : () => _clock(_isClockedIn ? 'out' : 'in'),
                  icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_isClockedIn ? Icons.logout_rounded : Icons.login_rounded),
                  label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_isClockedIn ? 'Clock Out' : 'Clock In', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  style: FilledButton.styleFrom(backgroundColor: _isClockedIn ? Palette.danger : Palette.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionHeader(title: "Today's activity", subtitle: '${todayEntries.length} entries'),
        for (final entry in todayEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry['type'] == 'in' ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  child: Icon(entry['type'] == 'in' ? Icons.login_rounded : Icons.logout_rounded, color: entry['type'] == 'in' ? Palette.green : Palette.danger, size: 18),
                ),
                title: Text(entry['type'] == 'in' ? 'Clocked In' : 'Clocked Out', style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text(_fmtDateTime(entry['timestamp'] ?? ''), style: const TextStyle(color: Palette.muted, fontSize: 12)),
              ),
            ),
          ),
        if (todayEntries.isEmpty) const _EmptyState(icon: Icons.access_time_rounded, title: 'No clock entries today', subtitle: 'Tap the button above to clock in.'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADMIN / SUPERVISOR SHARED PAGES
// ═══════════════════════════════════════════════════════════════════════════

// ─── DASHBOARD ───────────────────────────────────────────────────────────────

class DashboardPage extends StatelessWidget {
  final WorkspaceState state;
  const DashboardPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final activeClients = state.clients.whereType<Map>().where((e) => (e['active'] ?? true) == true).length;
    final recurring = state.clients.whereType<Map>().fold<double>(0, (sum, e) => sum + _num(e['rate']));
    final outstanding = state.invoices.whereType<Map>().where((e) => (e['status'] ?? '') == 'unpaid').fold<double>(0, (sum, e) => sum + _num(e['amount']));
    final todayJobs = state.jobs.whereType<Map>().where((e) => (e['date'] ?? '') == state.schedDate).toList();
    final done = todayJobs.where((e) => (e['done'] ?? false) == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _HeroCard(state: state),
        const SizedBox(height: 14),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          shrinkWrap: true,
          children: [
            _StatCard(title: 'Active clients', value: '$activeClients', subtitle: 'Recurring accounts', icon: Icons.people_alt_rounded, accent: Palette.green),
            _StatCard(title: 'Monthly recurring', value: _money(recurring), subtitle: 'Expected monthly', icon: Icons.payments_rounded, accent: const Color(0xFF1565C0)),
            _StatCard(title: 'Outstanding', value: _money(outstanding), subtitle: 'Unpaid invoices', icon: Icons.receipt_long_rounded, accent: Palette.danger),
            _StatCard(title: 'Jobs today', value: '$done/${todayJobs.length}', subtitle: 'Completed jobs', icon: Icons.task_alt_rounded, accent: const Color(0xFF6A1B9A)),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(title: 'Mission', child: const Text('Deliver dependable lawn and property care with professional standards, honest communication, and visible pride in every finished result.', style: TextStyle(height: 1.6))),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Core values',
          child: Wrap(spacing: 8, runSpacing: 8, children: const [
            _Chip(text: 'Reliability'), _Chip(text: 'Professional presentation'),
            _Chip(text: 'Respect for property'), _Chip(text: 'Clear communication'), _Chip(text: 'Consistent quality'),
          ]),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final WorkspaceState state;
  const _HeroCard({required this.state});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Palette.deepGreen, Palette.green], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: const [BoxShadow(color: Color(0x25000000), blurRadius: 20, offset: Offset(0, 10))]),
      padding: const EdgeInsets.all(22),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PrimeYard Workspace', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Run quotes, jobs, staff, invoices, and equipment from one app.', style: TextStyle(color: Color(0xE6FFFFFF), height: 1.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
            child: Text(state.updatedAt == null ? 'Waiting for sync...' : 'Last sync ${DateFormat('HH:mm').format(state.updatedAt!)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ])),
        const SizedBox(width: 10),
        Image.asset('assets/mascot.png', height: 110),
      ]),
    );
  }
}

// ─── CLIENTS ─────────────────────────────────────────────────────────────────

class ClientsPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const ClientsPage({super.key, required this.state, required this.session});

  Future<void> _addOrEdit(BuildContext context, [Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final address = TextEditingController(text: existing?['address']?.toString() ?? '');
    final rate = TextEditingController(text: existing != null ? _num(existing['rate']).toStringAsFixed(0) : '');
    final active = ValueNotifier<bool>((existing?['active'] ?? true) == true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ValueListenableBuilder(
        valueListenable: active,
        builder: (ctx, activeVal, _) => _EditDialog(
          title: existing == null ? 'New client' : 'Edit client',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Client name *')),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address / area')),
            const SizedBox(height: 10),
            TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly rate (R)')),
            const SizedBox(height: 10),
            SwitchListTile(value: activeVal, onChanged: (v) => active.value = v, title: const Text('Active client'), contentPadding: EdgeInsets.zero),
          ]),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final items = List<dynamic>.from(state.clients);
    if (existing == null) {
      items.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': name.text.trim(), 'address': address.text.trim(), 'rate': double.tryParse(rate.text.trim()) ?? 0, 'active': active.value, 'createdAt': _today()});
    } else {
      final idx = items.indexWhere((e) => e is Map && e['id'] == existing['id']);
      if (idx >= 0) items[idx] = {...existing, 'name': name.text.trim(), 'address': address.text.trim(), 'rate': double.tryParse(rate.text.trim()) ?? 0, 'active': active.value};
    }
    await BackendService.saveState(state.copyWith(clients: items), updatedBy: session.username);
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> client) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete client'), content: Text('Delete "${client['name']}"? This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final items = state.clients.where((e) => e is Map && e['id'] != client['id']).toList();
    await BackendService.saveState(state.copyWith(clients: items), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final clients = state.clients.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Clients', subtitle: '${clients.length} total', action: FilledButton.icon(onPressed: () => _addOrEdit(context), icon: const Icon(Icons.add_rounded), label: const Text('Add'))),
        for (final client in clients)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(client['name']))),
                title: Text((client['name'] ?? 'Unnamed').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${client['address'] ?? 'No address'}\n${_money(_num(client['rate']))} / month')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  _StatusPill(text: (client['active'] ?? true) ? 'Active' : 'Paused'),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'edit') _addOrEdit(context, client); else _delete(context, client); },
                    itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Palette.danger)))],
                  ),
                ]),
              ),
            ),
          ),
        if (clients.isEmpty) const _EmptyState(icon: Icons.people_alt_rounded, title: 'No clients yet', subtitle: 'Add your first client to get started.'),
      ],
    );
  }
}

// ─── INVOICES ─────────────────────────────────────────────────────────────────

class InvoicesPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const InvoicesPage({super.key, required this.state, required this.session});

  Future<void> _addOrEdit(BuildContext context, [Map<String, dynamic>? existing]) async {
    final client = TextEditingController(text: existing?['client']?.toString() ?? '');
    final amount = TextEditingController(text: existing != null ? _num(existing['amount']).toStringAsFixed(2) : '');
    final status = ValueNotifier<String>((existing?['status'] ?? 'unpaid').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ValueListenableBuilder(
        valueListenable: status,
        builder: (ctx, statusVal, _) => _EditDialog(
          title: existing == null ? 'New invoice' : 'Edit invoice',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: client, decoration: const InputDecoration(labelText: 'Client name *')),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (R) *')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: statusVal, items: const [DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')), DropdownMenuItem(value: 'paid', child: Text('Paid'))], onChanged: (v) => status.value = v ?? 'unpaid', decoration: const InputDecoration(labelText: 'Status')),
          ]),
        ),
      ),
    );
    if (ok != true || client.text.trim().isEmpty) return;
    final items = List<dynamic>.from(state.invoices);
    if (existing == null) {
      items.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'client': client.text.trim(), 'amount': double.tryParse(amount.text.trim()) ?? 0, 'status': status.value, 'createdAt': _today()});
    } else {
      final idx = items.indexWhere((e) => e is Map && e['id'] == existing['id']);
      if (idx >= 0) items[idx] = {...existing, 'client': client.text.trim(), 'amount': double.tryParse(amount.text.trim()) ?? 0, 'status': status.value};
    }
    await BackendService.saveState(state.copyWith(invoices: items), updatedBy: session.username);
  }

  Future<void> _togglePaid(Map<String, dynamic> invoice) async {
    final newStatus = invoice['status'] == 'paid' ? 'unpaid' : 'paid';
    final items = state.invoices.whereType<Map>().map((e) {
      final row = Map<String, dynamic>.from(e);
      if (row['id'] == invoice['id']) row['status'] = newStatus;
      return row;
    }).toList();
    await BackendService.saveState(state.copyWith(invoices: items), updatedBy: session.username);
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> invoice) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete invoice'), content: Text('Delete invoice for "${invoice['client']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final items = state.invoices.where((e) => e is Map && e['id'] != invoice['id']).toList();
    await BackendService.saveState(state.copyWith(invoices: items), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final invoices = state.invoices.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final outstanding = invoices.where((e) => e['status'] == 'unpaid').fold<double>(0, (s, e) => s + _num(e['amount']));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Invoices', subtitle: '${invoices.length} records · ${_money(outstanding)} outstanding', action: FilledButton.icon(onPressed: () => _addOrEdit(context), icon: const Icon(Icons.add_rounded), label: const Text('Add'))),
        for (final invoice in invoices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                title: Text((invoice['client'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Created ${invoice['createdAt'] ?? '-'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_money(_num(invoice['amount'])), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    _StatusPill(text: (invoice['status'] ?? 'unpaid').toString()),
                  ]),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'toggle') _togglePaid(invoice); else if (v == 'edit') _addOrEdit(context, invoice); else _delete(context, invoice); },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'toggle', child: Text(invoice['status'] == 'paid' ? 'Mark unpaid' : 'Mark as paid')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Palette.danger))),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        if (invoices.isEmpty) const _EmptyState(icon: Icons.receipt_long_rounded, title: 'No invoices yet', subtitle: 'Add your first invoice to track payments.'),
      ],
    );
  }
}

// ─── SCHEDULER ────────────────────────────────────────────────────────────────

class SchedulerPage extends StatefulWidget {
  final WorkspaceState state;
  final AppSession session;
  const SchedulerPage({super.key, required this.state, required this.session});
  @override
  State<SchedulerPage> createState() => _SchedulerPageState();
}

class _SchedulerPageState extends State<SchedulerPage> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.tryParse(widget.state.schedDate) ?? DateTime.now();
  }

  String get dateStr => DateFormat('yyyy-MM-dd').format(selectedDate);

  void _prevDay() => setState(() => selectedDate = selectedDate.subtract(const Duration(days: 1)));
  void _nextDay() => setState(() => selectedDate = selectedDate.add(const Duration(days: 1)));
  void _today() => setState(() => selectedDate = DateTime.now());

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _addJob(BuildContext context) async {
    final clientCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final workerCtrl = TextEditingController();
    final workers = widget.state.emps.whereType<Map>().map((e) => (e['name'] ?? '').toString()).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        title: 'Schedule job',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client name *')),
          const SizedBox(height: 10),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: workerCtrl, decoration: InputDecoration(labelText: 'Worker name', hintText: workers.isEmpty ? 'e.g. John' : workers.join(', '))),
        ]),
      ),
    );
    if (ok != true || clientCtrl.text.trim().isEmpty) return;
    final jobs = List<dynamic>.from(widget.state.jobs);
    jobs.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': clientCtrl.text.trim(), 'address': addressCtrl.text.trim(), 'workerName': workerCtrl.text.trim(), 'date': dateStr, 'done': false, 'notes': '', 'beforePhotos': [], 'afterPhotos': []});
    await BackendService.saveState(widget.state.copyWith(jobs: jobs), updatedBy: widget.session.username);
  }

  Future<void> _editJob(BuildContext context, Map<String, dynamic> job) async {
    final clientCtrl = TextEditingController(text: job['name']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: job['address']?.toString() ?? '');
    final workerCtrl = TextEditingController(text: job['workerName']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        title: 'Edit job',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client name *')),
          const SizedBox(height: 10),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: workerCtrl, decoration: const InputDecoration(labelText: 'Worker name')),
        ]),
      ),
    );
    if (ok != true || clientCtrl.text.trim().isEmpty) return;
    final jobs = widget.state.jobs.whereType<Map>().map((e) {
      final row = Map<String, dynamic>.from(e);
      if (row['id'] == job['id']) { row['name'] = clientCtrl.text.trim(); row['address'] = addressCtrl.text.trim(); row['workerName'] = workerCtrl.text.trim(); }
      return row;
    }).toList();
    await BackendService.saveState(widget.state.copyWith(jobs: jobs), updatedBy: widget.session.username);
  }

  Future<void> _deleteJob(BuildContext context, Map<String, dynamic> job) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete job'), content: Text('Delete job for "${job['name']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final jobs = widget.state.jobs.where((e) => e is Map && e['id'] != job['id']).toList();
    await BackendService.saveState(widget.state.copyWith(jobs: jobs), updatedBy: widget.session.username);
  }

  Future<void> _toggleDone(Map<String, dynamic> job) async {
    final newDone = !(job['done'] == true);
    final jobs = widget.state.jobs.whereType<Map>().map((e) {
      final row = Map<String, dynamic>.from(e);
      if (row['id'] == job['id']) row['done'] = newDone;
      return row;
    }).toList();
    await BackendService.saveState(widget.state.copyWith(jobs: jobs), updatedBy: widget.session.username);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = widget.state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => (e['date'] ?? '') == dateStr).toList();
    final done = jobs.where((j) => j['done'] == true).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Date navigation
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _prevDay),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(children: [
                      Text(DateFormat('EEEE').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(DateFormat('d MMMM yyyy').format(selectedDate), style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _nextDay),
              TextButton(onPressed: _today, child: const Text('Today')),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _SectionHeader(
          title: 'Jobs',
          subtitle: '$done/${jobs.length} done',
          action: FilledButton.icon(onPressed: () => _addJob(context), icon: const Icon(Icons.add_rounded), label: const Text('Add')),
        ),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  value: job['done'] == true,
                  title: Text((job['name'] ?? 'Job').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((job['address'] ?? '').toString().isNotEmpty) Text(job['address'].toString()),
                    Text((job['workerName'] ?? 'Unassigned').toString(), style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    if ((job['notes'] ?? '').toString().isNotEmpty) Text('Note: ${job['notes']}', style: const TextStyle(color: Palette.green, fontSize: 12)),
                  ]),
                  secondary: PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'edit') _editJob(context, job); else _deleteJob(context, job); },
                    itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Palette.danger)))],
                  ),
                  onChanged: (_) => _toggleDone(job),
                ),
              ),
            ),
          ),
        if (jobs.isEmpty) const _EmptyState(icon: Icons.calendar_month_rounded, title: 'No jobs scheduled', subtitle: 'Add jobs to build the route for this day.'),
      ],
    );
  }
}

// ─── EQUIPMENT ────────────────────────────────────────────────────────────────

class EquipmentPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const EquipmentPage({super.key, required this.state, required this.session});

  Future<void> _seedEquipment() async {
    if (state.equipment.isNotEmpty) return;
    const seed = [
      {'id': 'eq1', 'name': 'Brush cutter', 'status': 'ok'},
      {'id': 'eq2', 'name': 'Lawn mower', 'status': 'ok'},
      {'id': 'eq3', 'name': 'Blower', 'status': 'ok'},
      {'id': 'eq4', 'name': 'Hedge trimmer', 'status': 'ok'},
    ];
    await BackendService.saveState(state.copyWith(equipment: seed), updatedBy: session.username);
  }

  Future<void> _submitCheck(BuildContext context, Map<String, dynamic> item, String status) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        title: 'Submit equipment check',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE8F3EA), borderRadius: BorderRadius.circular(12)), child: Row(children: [
            const Icon(Icons.handyman_rounded, color: Palette.green),
            const SizedBox(width: 10),
            Expanded(child: Text((item['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
            _StatusPill(text: status),
          ])),
          const SizedBox(height: 12),
          TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Any issues, comments...')),
        ]),
      ),
    );
    if (ok != true) return;
    // Update equipment status
    final updatedEquip = state.equipment.whereType<Map>().map((e) {
      final row = Map<String, dynamic>.from(e);
      if (row['id'] == item['id']) row['status'] = status;
      return row;
    }).toList();
    // Add check log
    final now = DateTime.now();
    final log = {
      'id': now.millisecondsSinceEpoch.toString(),
      'equipmentId': item['id'],
      'equipmentName': item['name'],
      'status': status,
      'notes': notesCtrl.text.trim(),
      'submittedBy': session.username,
      'submittedByName': session.displayName,
      'date': _today(),
      'timestamp': now.toIso8601String(),
    };
    final updatedLogs = [...state.checkLogs, log];
    await BackendService.saveState(state.copyWith(equipment: updatedEquip, checkLogs: updatedLogs), updatedBy: session.username);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check logged for ${item['name']}')));
  }

  @override
  Widget build(BuildContext context) {
    final items = state.equipment.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (items.isEmpty) _seedEquipment();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Equipment checks', subtitle: '${items.length} tracked items'),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.handyman_rounded, color: Palette.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text((item['name'] ?? 'Equipment').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    _StatusPill(text: (item['status'] ?? 'ok').toString()),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final status in const ['ok', 'issue', 'missing'])
                        ChoiceChip(
                          label: Text(status.toUpperCase()),
                          selected: (item['status'] ?? 'ok') == status,
                          onSelected: (_) => _submitCheck(context, item, status),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        if (items.isEmpty) const _EmptyState(icon: Icons.handyman_rounded, title: 'Preparing equipment list', subtitle: 'Default gear list is being created.'),
      ],
    );
  }
}

// ─── EMPLOYEES / STAFF ────────────────────────────────────────────────────────

class EmployeesPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const EmployeesPage({super.key, required this.state, required this.session});

  Future<void> _addOrEdit(BuildContext context, [Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final rate = TextEditingController(text: existing != null ? _num(existing['dailyRate']).toStringAsFixed(0) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        title: existing == null ? 'New employee' : 'Edit employee',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
          const SizedBox(height: 10),
          TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily rate (R)')),
        ]),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final items = List<dynamic>.from(state.emps);
    if (existing == null) {
      items.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': name.text.trim(), 'dailyRate': double.tryParse(rate.text.trim()) ?? 0, 'startDate': _today()});
    } else {
      final idx = items.indexWhere((e) => e is Map && e['id'] == existing['id']);
      if (idx >= 0) items[idx] = {...existing, 'name': name.text.trim(), 'dailyRate': double.tryParse(rate.text.trim()) ?? 0};
    }
    await BackendService.saveState(state.copyWith(emps: items), updatedBy: session.username);
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> emp) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Remove employee'), content: Text('Remove "${emp['name']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))]));
    if (ok != true) return;
    final items = state.emps.where((e) => e is Map && e['id'] != emp['id']).toList();
    await BackendService.saveState(state.copyWith(emps: items), updatedBy: session.username);
  }

  void _viewPayroll(BuildContext context, Map<String, dynamic> emp) {
    final empName = (emp['name'] ?? '').toString().toLowerCase();
    final entries = state.clockEntries.whereType<Map>().where((e) {
      final name = (e['displayName'] ?? e['username'] ?? '').toString().toLowerCase();
      return name == empName || name.contains(empName.split(' ').first);
    }).toList();
    final daysWorked = entries.where((e) => e['type'] == 'in').length;
    final totalWages = daysWorked * _num(emp['dailyRate']);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(emp['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 4),
          Text('Daily rate: ${_money(_num(emp['dailyRate']))}', style: const TextStyle(color: Palette.muted)),
          const Divider(height: 28),
          Row(children: [
            Expanded(child: _PayrollStatBox(label: 'Days worked', value: '$daysWorked')),
            const SizedBox(width: 12),
            Expanded(child: _PayrollStatBox(label: 'Total wages', value: _money(totalWages))),
          ]),
          const SizedBox(height: 20),
          const Text('Based on clock-in entries linked to this employee.', style: TextStyle(color: Palette.muted, fontSize: 12), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emps = state.emps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Employees', subtitle: '${emps.length} on record', action: FilledButton.icon(onPressed: () => _addOrEdit(context), icon: const Icon(Icons.add_rounded), label: const Text('Add'))),
        for (final emp in emps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(emp['name']))),
                title: Text((emp['name'] ?? 'Employee').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_money(_num(emp['dailyRate']))} / day · Started ${emp['startDate'] ?? '-'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.payments_rounded, color: Palette.green), tooltip: 'Payroll', onPressed: () => _viewPayroll(context, emp)),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'edit') _addOrEdit(context, emp); else _delete(context, emp); },
                    itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: Palette.danger)))],
                  ),
                ]),
              ),
            ),
          ),
        if (emps.isEmpty) const _EmptyState(icon: Icons.badge_rounded, title: 'No employees yet', subtitle: 'Add your team members to track payroll and schedules.'),
      ],
    );
  }
}

class _PayrollStatBox extends StatelessWidget {
  final String label, value;
  const _PayrollStatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFE8F3EA), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Palette.green)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Palette.muted, fontSize: 12)),
      ]),
    );
  }
}

// ─── MORE PAGE ────────────────────────────────────────────────────────────────

class MorePage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const MorePage({super.key, required this.state, required this.session});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(), body: page)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'More tools', subtitle: 'Extra workspace controls'),
        _ActionTile(icon: Icons.format_quote_rounded, title: 'Quotes', subtitle: 'Manage client quotes and estimates', onTap: () => _go(context, QuotesPage(state: state, session: session))),
        _ActionTile(icon: Icons.handyman_rounded, title: 'Equipment', subtitle: 'Daily equipment checks and status', onTap: () => _go(context, EquipmentPage(state: state, session: session))),
        _ActionTile(icon: Icons.task_alt_rounded, title: 'Jobs log', subtitle: 'All jobs across all dates', onTap: () => _go(context, JobsLogPage(state: state))),
        _ActionTile(icon: Icons.punch_clock_rounded, title: 'Clock entries', subtitle: 'View all staff clock-in and out records', onTap: () => _go(context, ClockEntriesPage(state: state))),
        _ActionTile(icon: Icons.checklist_rounded, title: 'Equipment logs', subtitle: 'All submitted equipment check logs', onTap: () => _go(context, CheckLogsPage(state: state))),
        if (session.isMasterAdmin)
          _ActionTile(icon: Icons.manage_accounts_rounded, title: 'User management', subtitle: 'Add, edit, and remove staff accounts', onTap: () => _go(context, UserManagementPage(state: state, session: session))),
      ],
    );
  }
}

// ─── QUOTES ───────────────────────────────────────────────────────────────────

class QuotesPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const QuotesPage({super.key, required this.state, required this.session});

  Future<void> _addOrEdit(BuildContext context, [Map<String, dynamic>? existing]) async {
    final client = TextEditingController(text: existing?['client']?.toString() ?? '');
    final address = TextEditingController(text: existing?['address']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final amount = TextEditingController(text: existing != null ? _num(existing['amount']).toStringAsFixed(0) : '');
    final status = ValueNotifier<String>((existing?['status'] ?? 'pending').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ValueListenableBuilder(
        valueListenable: status,
        builder: (ctx, statusVal, _) => _EditDialog(
          title: existing == null ? 'New quote' : 'Edit quote',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: client, decoration: const InputDecoration(labelText: 'Client name *')),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Property address')),
            const SizedBox(height: 10),
            TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Work description')),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated amount (R)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: statusVal,
              items: const [DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'accepted', child: Text('Accepted')), DropdownMenuItem(value: 'declined', child: Text('Declined'))],
              onChanged: (v) => status.value = v ?? 'pending',
              decoration: const InputDecoration(labelText: 'Status'),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || client.text.trim().isEmpty) return;
    final items = List<dynamic>.from(state.quotes);
    if (existing == null) {
      items.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'client': client.text.trim(), 'address': address.text.trim(), 'description': description.text.trim(), 'amount': double.tryParse(amount.text.trim()) ?? 0, 'status': status.value, 'createdAt': _today(), 'createdBy': session.username});
    } else {
      final idx = items.indexWhere((e) => e is Map && e['id'] == existing['id']);
      if (idx >= 0) items[idx] = {...existing, 'client': client.text.trim(), 'address': address.text.trim(), 'description': description.text.trim(), 'amount': double.tryParse(amount.text.trim()) ?? 0, 'status': status.value};
    }
    await BackendService.saveState(state.copyWith(quotes: items), updatedBy: session.username);
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> quote) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete quote'), content: Text('Delete quote for "${quote['client']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final items = state.quotes.where((e) => e is Map && e['id'] != quote['id']).toList();
    await BackendService.saveState(state.copyWith(quotes: items), updatedBy: session.username);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'accepted': return Palette.green;
      case 'declined': return Palette.danger;
      default: return Palette.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = state.quotes.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Quotes', subtitle: '${quotes.length} total', action: FilledButton.icon(onPressed: () => _addOrEdit(context), icon: const Icon(Icons.add_rounded), label: const Text('Add'))),
        for (final quote in quotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text((quote['client'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _statusColor((quote['status'] ?? 'pending').toString()).withOpacity(.12), borderRadius: BorderRadius.circular(999)),
                      child: Text((quote['status'] ?? 'pending').toString().toUpperCase(), style: TextStyle(color: _statusColor((quote['status'] ?? 'pending').toString()), fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) { if (v == 'edit') _addOrEdit(context, quote); else _delete(context, quote); },
                      itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Palette.danger)))],
                    ),
                  ]),
                  if ((quote['address'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 4), Text(quote['address'].toString(), style: const TextStyle(color: Palette.muted, fontSize: 13))],
                  if ((quote['description'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 4), Text(quote['description'].toString(), style: const TextStyle(fontSize: 13))],
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_money(_num(quote['amount'])), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Palette.green)),
                    Text('${quote['createdAt'] ?? '-'} · ${quote['createdBy'] ?? ''}', style: const TextStyle(color: Palette.muted, fontSize: 11)),
                  ]),
                ]),
              ),
            ),
          ),
        if (quotes.isEmpty) const _EmptyState(icon: Icons.format_quote_rounded, title: 'No quotes yet', subtitle: 'Add your first quote to start tracking estimates.'),
      ],
    );
  }
}

// ─── JOBS LOG ─────────────────────────────────────────────────────────────────

class JobsLogPage extends StatelessWidget {
  final WorkspaceState state;
  const JobsLogPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Jobs log', subtitle: '${jobs.length} total jobs'),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(job['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: job['done'] == true ? Palette.green : Palette.muted, size: 28),
                title: Text((job['name'] ?? 'Job').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${job['date'] ?? '-'} · ${job['address'] ?? ''}'),
                  Text((job['workerName'] ?? 'Unassigned').toString(), style: const TextStyle(color: Palette.muted, fontSize: 12)),
                  if ((job['notes'] ?? '').toString().isNotEmpty) Text('Note: ${job['notes']}', style: const TextStyle(color: Palette.green, fontSize: 12)),
                  if (job['done'] == true && (job['completedAt'] ?? '').toString().isNotEmpty) Text('Done at ${_fmtDateTime(job['completedAt'].toString())}', style: const TextStyle(color: Palette.green, fontSize: 11)),
                ]),
              ),
            ),
          ),
        if (jobs.isEmpty) const _EmptyState(icon: Icons.task_alt_rounded, title: 'No jobs yet', subtitle: 'Jobs will appear here once scheduled.'),
      ],
    );
  }
}

// ─── CLOCK ENTRIES (ADMIN VIEW) ───────────────────────────────────────────────

class ClockEntriesPage extends StatelessWidget {
  final WorkspaceState state;
  const ClockEntriesPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = state.clockEntries.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Clock entries', subtitle: '${entries.length} total records'),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: entry['type'] == 'in' ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  child: Icon(entry['type'] == 'in' ? Icons.login_rounded : Icons.logout_rounded, color: entry['type'] == 'in' ? Palette.green : Palette.danger, size: 18),
                ),
                title: Text((entry['displayName'] ?? entry['username'] ?? 'Unknown').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('@${entry['username'] ?? ''} · ${entry['date'] ?? ''}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(entry['type'] == 'in' ? 'Clock In' : 'Clock Out', style: TextStyle(fontWeight: FontWeight.w800, color: entry['type'] == 'in' ? Palette.green : Palette.danger, fontSize: 12)),
                  Text(_fmtDateTime(entry['timestamp'] ?? ''), style: const TextStyle(color: Palette.muted, fontSize: 11)),
                ]),
              ),
            ),
          ),
        if (entries.isEmpty) const _EmptyState(icon: Icons.punch_clock_rounded, title: 'No clock entries', subtitle: 'Clock entries will appear here when staff clock in.'),
      ],
    );
  }
}

// ─── EQUIPMENT CHECK LOGS ─────────────────────────────────────────────────────

class CheckLogsPage extends StatelessWidget {
  final WorkspaceState state;
  const CheckLogsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final logs = state.checkLogs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (b['timestamp'] ?? '').toString().compareTo((a['timestamp'] ?? '').toString()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Equipment logs', subtitle: '${logs.length} submissions'),
        for (final log in logs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.handyman_rounded, color: Palette.green),
                title: Text((log['equipmentName'] ?? 'Equipment').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('By ${log['submittedByName'] ?? log['submittedBy'] ?? '?'} · ${log['date'] ?? ''}'),
                  if ((log['notes'] ?? '').toString().isNotEmpty) Text(log['notes'].toString(), style: const TextStyle(color: Palette.muted, fontSize: 12)),
                ]),
                trailing: _StatusPill(text: (log['status'] ?? 'ok').toString()),
              ),
            ),
          ),
        if (logs.isEmpty) const _EmptyState(icon: Icons.checklist_rounded, title: 'No check logs', subtitle: 'Equipment check submissions will appear here.'),
      ],
    );
  }
}

// ─── USER MANAGEMENT (MASTER ADMIN) ──────────────────────────────────────────

class UserManagementPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const UserManagementPage({super.key, required this.state, required this.session});

  Future<void> _addOrEdit(BuildContext context, [Map<String, dynamic>? existing]) async {
    final displayName = TextEditingController(text: existing?['displayName']?.toString() ?? '');
    final username = TextEditingController(text: existing?['username']?.toString() ?? '');
    final pw = TextEditingController();
    final pw2 = TextEditingController();
    final role = ValueNotifier<String>((existing?['role'] ?? 'worker').toString());
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(existing == null ? 'Create user' : 'Edit user', style: const TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Display name *')),
              const SizedBox(height: 10),
              TextField(controller: username, decoration: const InputDecoration(labelText: 'Username *'), enabled: existing == null),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: role,
                builder: (_, roleVal, __) => DropdownButtonFormField<String>(
                  value: roleVal,
                  items: const [
                    DropdownMenuItem(value: 'master_admin', child: Text('Master Admin')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'worker', child: Text('Worker')),
                  ],
                  onChanged: (v) => role.value = v ?? 'worker',
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: existing == null ? 'Password *' : 'New password (leave blank to keep)')),
              const SizedBox(height: 10),
              TextField(controller: pw2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
              if (err != null) ...[const SizedBox(height: 8), Text(err!, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w700))],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (displayName.text.trim().isEmpty || username.text.trim().isEmpty) { setS(() => err = 'Name and username required.'); return; }
                if (existing == null && pw.text.isEmpty) { setS(() => err = 'Password required.'); return; }
                if (pw.text.isNotEmpty && pw.text != pw2.text) { setS(() => err = 'Passwords do not match.'); return; }
                if (pw.text.isNotEmpty && pw.text.length < 6) { setS(() => err = 'Min 6 characters.'); return; }
                Navigator.pop(ctx, true);
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    // Check for duplicate username (new users only)
    if (existing == null) {
      final taken = state.users.whereType<Map>().any((u) => (u['username'] ?? '').toString().toLowerCase() == username.text.trim().toLowerCase());
      if (taken) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username already taken'))); return; }
    }

    final hash = pw.text.isNotEmpty ? _hash(pw.text) : (existing?['passwordHash'] ?? '').toString();
    final items = List<dynamic>.from(state.users);
    if (existing == null) {
      items.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'username': username.text.trim(), 'displayName': displayName.text.trim(), 'role': role.value, 'passwordHash': hash, 'createdAt': _today()});
    } else {
      final idx = items.indexWhere((e) => e is Map && e['id'] == existing['id']);
      if (idx >= 0) items[idx] = {...existing, 'displayName': displayName.text.trim(), 'role': role.value, 'passwordHash': hash};
    }
    await BackendService.saveState(state.copyWith(users: items), updatedBy: session.username);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'User created!' : 'User updated!')));
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> user) async {
    if ((user['username'] ?? '').toString().toLowerCase() == session.username.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't delete your own account")));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete user'), content: Text('Delete account "${user['displayName']}"? This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (ok != true) return;
    final items = state.users.where((e) => e is Map && e['id'] != user['id']).toList();
    await BackendService.saveState(state.copyWith(users: items), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final users = state.users.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'User management', subtitle: '${users.length} accounts', action: FilledButton.icon(onPressed: () => _addOrEdit(context), icon: const Icon(Icons.person_add_rounded), label: const Text('Add user'))),
        for (final user in users)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(user['displayName']))),
                title: Text((user['displayName'] ?? 'User').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('@${user['username'] ?? ''} · ${user['role'] ?? 'worker'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if ((user['username'] ?? '') == session.username) const _StatusPill(text: 'You'),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'edit') _addOrEdit(context, user); else _delete(context, user); },
                    itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Palette.danger)))],
                  ),
                ]),
              ),
            ),
          ),
        if (users.isEmpty) const _EmptyState(icon: Icons.manage_accounts_rounded, title: 'No users', subtitle: 'Add the first user account.'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const _SectionHeader({required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(subtitle, style: const TextStyle(color: Palette.muted)),
      ])),
      if (action != null) action!,
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10), child])));
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color accent;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.accent});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: accent), const Spacer(), Text(title, style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12, color: Palette.muted))])));
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFE8F3EA), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)));
}

class _StatusPill extends StatelessWidget {
  final String text;
  const _StatusPill({required this.text});
  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    Color bg, fg;
    switch (lower) {
      case 'paid': case 'ok': case 'active': case 'accepted': case 'you': bg = const Color(0xFFE8F5E9); fg = Palette.green; break;
      case 'issue': case 'pending': bg = const Color(0xFFFFF8E1); fg = const Color(0xFFE65100); break;
      case 'missing': case 'unpaid': case 'declined': bg = const Color(0xFFFFEBEE); fg = Palette.danger; break;
      default: bg = const Color(0xFFF1F1F1); fg = Palette.muted;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)));
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Icon(icon, color: Palette.green)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap)));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(icon, size: 42, color: Palette.green), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted))])));
}

class _EditDialog extends StatelessWidget {
  final String title;
  final Widget child;
  const _EditDialog({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), content: SingleChildScrollView(child: child), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]);
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

String _hash(String msg) {
  int n(int x) => x & 0xffffffff;
  const k = [
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
  ];
  var h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a;
  var h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;

  final bytes = <int>[];
  for (var i = 0; i < msg.length; i++) {
    final c = msg.codeUnitAt(i);
    if (c < 128) { bytes.add(c); }
    else if (c < 2048) { bytes.add((c >> 6) | 192); bytes.add((c & 63) | 128); }
    else { bytes.add((c >> 12) | 224); bytes.add(((c >> 6) & 63) | 128); bytes.add((c & 63) | 128); }
  }
  final bl = bytes.length;
  final bits = bl * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) bytes.add(0);
  bytes.addAll([0, 0, 0, 0, bits ~/ 0x100000000, (bits >> 24) & 0xff, (bits >> 16) & 0xff, (bits >> 8) & 0xff, bits & 0xff]);
  while (bytes.length % 64 != 0) bytes.add(0);

  for (var i = 0; i < bytes.length; i += 64) {
    final w = List<int>.filled(64, 0);
    for (var j = 0; j < 16; j++) {
      w[j] = (bytes[i+j*4] << 24) | (bytes[i+j*4+1] << 16) | (bytes[i+j*4+2] << 8) | bytes[i+j*4+3];
    }
    for (var j = 16; j < 64; j++) {
      final s0 = n(((w[j-15]>>7)|(w[j-15]<<25))^((w[j-15]>>18)|(w[j-15]<<14))^(w[j-15]>>3));
      final s1 = n(((w[j-2]>>17)|(w[j-2]<<15))^((w[j-2]>>19)|(w[j-2]<<13))^(w[j-2]>>10));
      w[j] = n(w[j-16]+s0+w[j-7]+s1);
    }
    var a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,g=h6,hh=h7;
    for (var j = 0; j < 64; j++) {
      final s1 = n(((e>>6)|(e<<26))^((e>>11)|(e<<21))^((e>>25)|(e<<7)));
      final ch = (e&f)^((~e)&g);
      final t1 = n(hh+s1+ch+k[j]+w[j]);
      final s0 = n(((a>>2)|(a<<30))^((a>>13)|(a<<19))^((a>>22)|(a<<10)));
      final maj = (a&b)^(a&c)^(b&d);
      final t2 = n(s0+maj);
      hh=g; g=f; f=e; e=n(d+t1); d=c; c=b; b=a; a=n(t1+t2);
    }
    h0=n(h0+a); h1=n(h1+b); h2=n(h2+c); h3=n(h3+d);
    h4=n(h4+e); h5=n(h5+f); h6=n(h6+g); h7=n(h7+hh);
  }
  return [h0,h1,h2,h3,h4,h5,h6,h7].map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}

dynamic _jsonSafe(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) return value.map((key, val) => MapEntry(key.toString(), _jsonSafe(val)));
  if (value is Iterable) return value.map(_jsonSafe).toList();
  return value;
}

Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> data) => Map<String, dynamic>.from(_jsonSafe(data) as Map);

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _money(double v) => 'R${v.toStringAsFixed(2)}';
String _initials(dynamic name) {
  final parts = (name ?? '').toString().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'P';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}
String _fmtDateTime(String iso) {
  try {
    return DateFormat('HH:mm · d MMM yyyy').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}
