import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'equipment_catalog_page.dart';
import 'new_booking_page.dart';
import 'booking_management_page.dart';
import 'conflict_detection_page.dart';
import 'booking_calendar_page.dart';
import 'operations_page.dart';
import 'role_permissions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VenueVaultApp());
}

class VenueVaultApp extends StatelessWidget {
  const VenueVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VenueVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff4f46e5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7f8fc),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffe5e7eb)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xff4f46e5), width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class MyApp extends VenueVaultApp {
  const MyApp({super.key});
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const AuthPage()
            : HomePage(user: snapshot.data!);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final token = await credential.user!.getIdTokenResult(true);
      final role = token.claims?['role'] ?? 'role not set';
      debugPrint('Role claim: $role');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _authErrorMessage(error.code));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (_validateEmail(email) != null) {
      setState(
        () => _errorMessage =
            'Enter a valid email address to reset your password.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showResetConfirmation();
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found') {
        _showResetConfirmation();
      } else {
        setState(() => _errorMessage = _authErrorMessage(error.code));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showResetConfirmation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'If an account exists for this email, password reset instructions have been sent.',
        ),
      ),
    );
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a little and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Enter a valid email address';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: isWide
                  ? Row(
                      children: [
                        Expanded(child: _welcomePanel(context)),
                        const SizedBox(width: 72),
                        SizedBox(width: 410, child: _authForm(context)),
                      ],
                    )
                  : _authForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomePanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.event_available_rounded,
          size: 52,
          color: Color(0xff4f46e5),
        ),
        const SizedBox(height: 24),
        Text(
          'VenueVault',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Your operations hub for\\neffortless event logistics.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Manage bookings, inventory, dispatches, and returns from one clear workspace.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: const Color(0xff6b7280), height: 1.5),
        ),
      ],
    );
  }

  Widget _authForm(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue to VenueVault.',
                style: const TextStyle(color: Color(0xff6b7280)),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Work email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Use at least 6 characters'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _sendPasswordReset,
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xffb42318)),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.user});

  final User? user;

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VenueVault'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Here is today’s venue overview.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              _OperationsDashboard(user: user),
              const SizedBox(height: 28),
              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _HomeActions(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationsDashboard extends StatefulWidget {
  const _OperationsDashboard({required this.user});

  final User? user;

  @override
  State<_OperationsDashboard> createState() => _OperationsDashboardState();
}

class _OperationsDashboardState extends State<_OperationsDashboard> {
  late Future<_OperationsDashboardData?> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = _loadDashboard();
  }

  Future<_OperationsDashboardData?> _loadDashboard() async {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to load the operations dashboard.');
    }

    final token = await user.getIdTokenResult(true);
    final role = token.claims?['role'] as String?;
    if (!hasRolePermission(role, 'dashboard.view')) return null;

    final result = await FirebaseFunctions.instance
        .httpsCallable('getOperationsDashboard')
        .call({
          'timeZoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        });
    return _OperationsDashboardData.from(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OperationsDashboardData?>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Could not load the operations dashboard.'),
                  const SizedBox(height: 4),
                  Text('${snapshot.error}'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _dashboard = _loadDashboard());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
                    ),
                  ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                  Expanded(
                  child: Text(
                    'Operations dashboard',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                    ),
                IconButton(
                  tooltip: 'Refresh dashboard',
                  onPressed: () {
                    setState(() => _dashboard = _loadDashboard());
                  },
                  icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
                children: [
                _SummaryCard(
                  label: 'Upcoming events (30 days)',
                  value: '${data.upcomingEventCount}',
                  icon: Icons.calendar_month,
                  color: Colors.indigo,
                    ),
                _SummaryCard(
                  label: 'Equipment records',
                  value: '${data.equipmentCount}',
                  icon: Icons.category_outlined,
                  color: Colors.blueGrey,
                  ),
                _SummaryCard(
                  label: 'Usable / total units',
                  value: '${data.availableUnits} / ${data.totalUnits}',
                      icon: Icons.inventory_2_outlined,
                  color: Colors.teal,
                ),
                _SummaryCard(
                  label: 'Unavailable units',
                  value: '${data.unavailableUnits}',
                  icon: Icons.report_gmailerrorred_outlined,
                  color: Colors.orange,
                ),
                _SummaryCard(
                  label: 'Open dispatches',
                  value: '${data.pendingDispatchCount}',
                  icon: Icons.local_shipping_outlined,
                  color: Colors.blue,
                ),
                _SummaryCard(
                  label: 'Overdue returns',
                  value: '${data.overdueReturnCount}',
                  icon: Icons.assignment_return_outlined,
                  color: Colors.deepOrange,
                ),
                _SummaryCard(
                  label: 'Conflicting bookings',
                  value: '${data.conflictCount}',
                  icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    ),
                _SummaryCard(
                  label: 'Returns awaiting inspection',
                  value: '${data.returnsPendingInspectionCount}',
                  icon: Icons.fact_check_outlined,
                  color: Colors.purple,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            _DashboardEntryList(
              title: 'Upcoming events',
              emptyMessage: 'No confirmed events in the next 30 days.',
              entries: data.upcomingEvents,
              datePrefix: 'Starts',
              ),
              const SizedBox(height: 12),
            _DashboardEntryList(
              title: 'Overdue returns',
              emptyMessage: 'No overdue returns.',
              entries: data.overdueReturns,
              datePrefix: 'Ended',
            ),
          ],
        );
      },
    );
  }
}

class _HomeActions extends StatefulWidget {
  const _HomeActions({required this.user});

  final User? user;

  @override
  State<_HomeActions> createState() => _HomeActionsState();
}

class _HomeActionsState extends State<_HomeActions> {
  late final Future<IdTokenResult?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _loadToken();
  }

  Future<IdTokenResult?> _loadToken() async {
    final user = widget.user ?? FirebaseAuth.instance.currentUser;
    return user?.getIdTokenResult(true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdTokenResult?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load your role permissions.');
        }
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.done ||
              snapshot.connectionState == ConnectionState.none) {
            return const Text('Sign in to view available actions.');
          }
          return const Center(child: CircularProgressIndicator());
        }
        final role = snapshot.data!.claims?['role'] as String?;
        final actions = <Widget>[];

        void addAction({
          required String permission,
          required IconData icon,
          required String title,
          required String subtitle,
          required WidgetBuilder builder,
        }) {
          if (!hasRolePermission(role, permission)) return;
          if (actions.isNotEmpty) {
            actions.add(const SizedBox(height: 10));
          }
          actions.add(
              _ActionTile(
              icon: icon,
              title: title,
              subtitle: subtitle,
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: builder)),
            ),
          );
        }

        addAction(
          permission: 'bookings.create',
                icon: Icons.add_circle_outline,
                title: 'Create booking',
                subtitle: 'Reserve equipment for a new event',
                      builder: (_) => const NewBookingPage(),
                  );
        addAction(
          permission: 'inventory.view',
                icon: Icons.inventory_2_outlined,
                title: 'View inventory',
                subtitle: 'Check availability and stock levels',
                      builder: (_) => const EquipmentCatalogPage(),
                  );
        addAction(
          permission: 'bookings.view',
                icon: Icons.calendar_month_outlined,
                title: 'Manage bookings',
          subtitle: 'View bookings and permitted booking actions',
                      builder: (_) => const BookingManagementPage(),
                  );
        addAction(
          permission: 'bookings.view',
                icon: Icons.date_range_outlined,
                title: 'Booking calendar',
          subtitle: 'See reservations and event dates',
                      builder: (_) => const BookingCalendarPage(),
                  );
        if (hasRolePermission(role, 'bookings.view') &&
            hasRolePermission(role, 'inventory.view')) {
          addAction(
            permission: 'bookings.view',
                icon: Icons.warning_amber_rounded,
            title: 'Conflict detection',
            subtitle: 'Review shortages, booking conflicts, and time windows',
                      builder: (_) => const ConflictDetectionPage(),
                  );
        }
        if (hasRolePermission(role, 'dispatch.viewAll') ||
            hasRolePermission(role, 'dispatch.viewAssigned') ||
            hasRolePermission(role, 'returns.record') ||
            hasRolePermission(role, 'returns.approve')) {
          addAction(
            permission: hasRolePermission(role, 'dispatch.viewAll')
                ? 'dispatch.viewAll'
                : 'dispatch.viewAssigned',
                icon: Icons.local_shipping_outlined,
                title: 'Operations',
            subtitle: 'Open dispatch, checklist, and return tasks',
                      builder: (_) => const OperationsPage(),
          );
        }

        if (actions.isEmpty) {
          return const Text(
            'No workspace modules are assigned to your account. '
            'Ask an Admin to review your role.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions,
                  );
                },
    );
  }
}

class _OperationsDashboardData {
  const _OperationsDashboardData({
    required this.upcomingEventCount,
    required this.equipmentCount,
    required this.totalUnits,
    required this.availableUnits,
    required this.unavailableUnits,
    required this.pendingDispatchCount,
    required this.overdueReturnCount,
    required this.conflictCount,
    required this.returnsPendingInspectionCount,
    required this.upcomingEvents,
    required this.overdueReturns,
  });

  final int upcomingEventCount;
  final int equipmentCount;
  final int totalUnits;
  final int availableUnits;
  final int unavailableUnits;
  final int pendingDispatchCount;
  final int overdueReturnCount;
  final int conflictCount;
  final int returnsPendingInspectionCount;
  final List<_DashboardEntry> upcomingEvents;
  final List<_DashboardEntry> overdueReturns;

  factory _OperationsDashboardData.from(Object? value) {
    if (value is! Map) {
      throw const FormatException('Dashboard response must be an object.');
    }
    final data = Map<String, dynamic>.from(value);

    int readCount(String key) {
      final count = data[key];
      if (count is! num || !count.isFinite || count < 0 || count % 1 != 0) {
        throw FormatException('Dashboard response has an invalid $key.');
      }
      return count.toInt();
    }

    List<_DashboardEntry> readEntries(
      String key,
      String idKey,
      String dateKey,
    ) {
      final entries = data[key];
      if (entries is! List) {
        throw FormatException('Dashboard response has invalid $key.');
      }
      return entries.map((entry) {
        if (entry is! Map) {
          throw FormatException('Dashboard response has invalid $key entry.');
        }
        final row = Map<String, dynamic>.from(entry);
        final id = row[idKey];
        final eventName = row['eventName'];
        final venue = row['venue'];
        final date = row[dateKey];
        if (id is! String ||
            eventName is! String ||
            venue is! String ||
            date is! num ||
            !date.isFinite) {
          throw FormatException('Dashboard response has invalid $key entry.');
        }
        return _DashboardEntry(
          eventName: eventName,
          venue: venue,
          dateMillis: date.toInt(),
        );
      }).toList();
    }

    return _OperationsDashboardData(
      upcomingEventCount: readCount('upcomingEventCount'),
      equipmentCount: readCount('equipmentCount'),
      totalUnits: readCount('totalUnits'),
      availableUnits: readCount('availableUnits'),
      unavailableUnits: readCount('unavailableUnits'),
      pendingDispatchCount: readCount('pendingDispatchCount'),
      overdueReturnCount: readCount('overdueReturnCount'),
      conflictCount: readCount('conflictCount'),
      returnsPendingInspectionCount: readCount('returnsPendingInspectionCount'),
      upcomingEvents: readEntries('upcomingEvents', 'id', 'startDateMillis'),
      overdueReturns: readEntries(
        'overdueReturns',
        'bookingId',
        'endDateMillis',
              ),
    );
  }
}

class _DashboardEntry {
  const _DashboardEntry({
    required this.eventName,
    required this.venue,
    required this.dateMillis,
  });

  final String eventName;
  final String venue;
  final int dateMillis;

  String get dateLabel {
    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis).toLocal();
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DashboardEntryList extends StatelessWidget {
  const _DashboardEntryList({
    required this.title,
    required this.emptyMessage,
    required this.entries,
    required this.datePrefix,
  });

  final String title;
  final String emptyMessage;
  final List<_DashboardEntry> entries;
  final String datePrefix;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(emptyMessage),
              )
            else
              ...entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.eventName),
                  subtitle: Text(
                    '${entry.venue}\n$datePrefix ${entry.dateLabel}',
          ),
                  isThreeLine: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
