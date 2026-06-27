// ============================================================
//  SMART MEDICINE REMINDER — Complete App v2.0
//  Single-file Flutter • DartPad compatible
//  Features: Dark Mode, Family Members, Dose History, Streak,
//            Refill Reminder, Photo (placeholder), PDF Export,
//            Notifications (local), Premium/Free tier, AdMob UI
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartMedApp());
}

// ══════════════════════════════════════════════════════════════
//  CONSTANTS & THEME
// ══════════════════════════════════════════════════════════════
const kAdMobAppId   = 'ca-app-pub-5546625842490070~9288688882';
const kAdMobBanner  = 'ca-app-pub-5546625842490070/1473622513';

class AppColors {
  static const primary   = Color(0xFF2D7DD2);
  static const primaryDk = Color(0xFF1A5FA8);
  static const accent    = Color(0xFF00C896);
  static const danger    = Color(0xFFFF6B6B);
  static const warning   = Color(0xFFFFB347);
  static const purple    = Color(0xFF9B59B6);
  static const gold      = Color(0xFFF4C430);

  // Light
  static const bgLight   = Color(0xFFF5F7FB);
  static const cardLight = Colors.white;
  static const textLight = Color(0xFF1A1E2E);
  static const subLight  = Color(0xFF8A94A6);

  // Dark
  static const bgDark    = Color(0xFF0F1117);
  static const cardDark  = Color(0xFF1C2030);
  static const textDark  = Color(0xFFEEF0F5);
  static const subDark   = Color(0xFF6B7280);
}

ThemeData buildTheme(bool dark) => ThemeData(
  useMaterial3: true,
  brightness: dark ? Brightness.dark : Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
  ),
  scaffoldBackgroundColor: dark ? AppColors.bgDark : AppColors.bgLight,
  fontFamily: 'Roboto',
  cardColor: dark ? AppColors.cardDark : AppColors.cardLight,
);

// ══════════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════════
enum MedType   { tablet, capsule, syrup, injection, drops, cream, inhaler }
enum DoseStatus{ taken, missed, pending, skipped }
enum PlanTier  { free, premium }

class FamilyMember {
  String id, name, relation, avatar, bloodGroup, allergies;
  int age;
  FamilyMember({
    required this.id, required this.name, required this.relation,
    required this.avatar, this.age = 0,
    this.bloodGroup = '', this.allergies = '',
  });
}

class Medicine {
  String  id, name, brandName, doctorName, disease, notes;
  MedType type;
  String  strength;
  int     quantity;          // pills per dose
  int     totalStock;        // total remaining
  int     refillAt;          // alert when stock <= this
  List<String> times;
  String  familyMemberId;
  Color   color;
  bool    active;
  String  photoPath;         // placeholder

  Medicine({
    required this.id, required this.name, required this.brandName,
    required this.doctorName, required this.disease, required this.notes,
    required this.type, required this.strength, required this.quantity,
    required this.totalStock, required this.refillAt,
    required this.times, required this.familyMemberId,
    required this.color, this.active = true, this.photoPath = '',
  });

  bool get needsRefill => totalStock <= refillAt;
  int  get daysLeft    => quantity > 0 ? (totalStock / (quantity * times.length)).floor() : 0;
}

class DoseRecord {
  final String   medicineId;
  final DateTime dateTime;
  DoseStatus     status;
  DoseRecord({required this.medicineId, required this.dateTime, required this.status});
}

class TodayDose {
  final Medicine medicine;
  final String   time;
  DoseStatus     status;
  TodayDose({required this.medicine, required this.time, this.status = DoseStatus.pending});
}

// ══════════════════════════════════════════════════════════════
//  APP STATE
// ══════════════════════════════════════════════════════════════
class AppState extends ChangeNotifier {
  // Auth / onboarding
  bool _onboarded = false;
  bool _loggedIn  = false;

  // Theme
  bool _darkMode  = false;
  bool get darkMode => _darkMode;
  void toggleDark() { _darkMode = !_darkMode; notifyListeners(); }

  // Premium
  PlanTier _plan = PlanTier.free;
  PlanTier get plan => _plan;
  bool get isPremium => _plan == PlanTier.premium;
  void upgradePremium() { _plan = PlanTier.premium; notifyListeners(); }

  // Navigation
  int _nav = 0;
  int get nav => _nav;
  void setNav(int i) { _nav = i; notifyListeners(); }

  // Family
  final List<FamilyMember> family = [
    FamilyMember(id:'f1', name:'Me (Main User)', relation:'Self',    avatar:'👤', age:30, bloodGroup:'O+'),
    FamilyMember(id:'f2', name:'Ammi Jan',       relation:'Mother',  avatar:'👩', age:58, bloodGroup:'A+', allergies:'Penicillin'),
    FamilyMember(id:'f3', name:'Abbu Jan',       relation:'Father',  avatar:'👨', age:62, bloodGroup:'B+'),
  ];

  // Selected family member filter (null = all)
  String? _filterMember;
  String? get filterMember => _filterMember;
  void setFilter(String? id) { _filterMember = id; notifyListeners(); }

  // Medicines
  final List<Medicine> medicines = [
    Medicine(
      id:'m1', name:'Paracetamol',  brandName:'Panadol',   doctorName:'Dr. Ahmed',
      disease:'Fever',    notes:'After meals',
      type:MedType.tablet, strength:'500mg', quantity:2, totalStock:60, refillAt:10,
      times:['08:00 AM','02:00 PM','09:00 PM'], familyMemberId:'f1',
      color:AppColors.primary,
    ),
    Medicine(
      id:'m2', name:'Amoxicillin',  brandName:'Amoxil',    doctorName:'Dr. Sara',
      disease:'Infection', notes:'With water',
      type:MedType.capsule, strength:'250mg', quantity:1, totalStock:8, refillAt:10,
      times:['07:00 AM','07:00 PM'], familyMemberId:'f1',
      color:AppColors.purple,
    ),
    Medicine(
      id:'m3', name:'Cough Syrup',  brandName:'Benadryl',  doctorName:'Dr. Khan',
      disease:'Cough',    notes:'5ml spoon',
      type:MedType.syrup, strength:'100mg/5ml', quantity:1, totalStock:30, refillAt:5,
      times:['10:00 AM','04:00 PM','10:00 PM'], familyMemberId:'f2',
      color:AppColors.accent,
    ),
    Medicine(
      id:'m4', name:'Metformin',    brandName:'Glucophage', doctorName:'Dr. Malik',
      disease:'Diabetes', notes:'With breakfast',
      type:MedType.tablet, strength:'1g', quantity:1, totalStock:25, refillAt:7,
      times:['08:00 AM','08:00 PM'], familyMemberId:'f3',
      color:AppColors.warning,
    ),
  ];

  // Dose records (history)
  final List<DoseRecord> history = [];

  // Today doses
  List<TodayDose> _todayDoses = [];
  List<TodayDose> get todayDoses {
    if (_filterMember == null) return _todayDoses;
    return _todayDoses.where((d) => d.medicine.familyMemberId == _filterMember).toList();
  }

  // Streak
  int _streak = 7;
  int get streak => _streak;

  // Notifications list
  final List<String> notifications = [
    '🕗 08:00 AM — Paracetamol 500mg is due',
    '❌ Missed — Amoxicillin 07:00 AM',
    '🔔 Refill needed — Amoxicillin (8 pills left)',
    '✅ Taken — Paracetamol 500mg at 08:05 AM',
  ];

  AppState() { _buildToday(); }

  void _buildToday() {
    _todayDoses = [];
    for (final m in medicines.where((m) => m.active)) {
      for (final t in m.times) {
        _todayDoses.add(TodayDose(medicine: m, time: t));
      }
    }
    if (_todayDoses.isNotEmpty) _todayDoses[0].status = DoseStatus.taken;
    if (_todayDoses.length > 1) _todayDoses[1].status = DoseStatus.missed;
  }

  // Getters
  int get takenCount   => _todayDoses.where((d) => d.status == DoseStatus.taken).length;
  int get missedCount  => _todayDoses.where((d) => d.status == DoseStatus.missed).length;
  int get pendingCount => _todayDoses.where((d) => d.status == DoseStatus.pending).length;
  int get totalCount   => _todayDoses.length;
  List<Medicine> get refillNeeded => medicines.where((m) => m.needsRefill && m.active).toList();

  void markDose(TodayDose dose, DoseStatus status) {
    dose.status = status;
    history.add(DoseRecord(
      medicineId: dose.medicine.id,
      dateTime: DateTime.now(),
      status: status,
    ));
    if (status == DoseStatus.taken) {
      dose.medicine.totalStock = max(0, dose.medicine.totalStock - dose.medicine.quantity);
    }
    notifyListeners();
  }

  void addMedicine(Medicine m) {
    medicines.add(m);
    _buildToday();
    notifyListeners();
  }

  void deleteMedicine(String id) {
    medicines.removeWhere((m) => m.id == id);
    _buildToday();
    notifyListeners();
  }

  void addFamilyMember(FamilyMember m) { family.add(m); notifyListeners(); }

  void completeOnboarding() { _onboarded = true; notifyListeners(); }
  void login()              { _loggedIn  = true; notifyListeners(); }
  void logout()             { _loggedIn  = false; _onboarded = false; notifyListeners(); }

  bool get onboarded => _onboarded;
  bool get loggedIn  => _loggedIn;

  // Dummy 7-day adherence data
  List<int> get weekAdherence => [90, 75, 100, 60, 85, 100, 70];
}

// ══════════════════════════════════════════════════════════════
//  ROOT APP
// ══════════════════════════════════════════════════════════════
class SmartMedApp extends StatefulWidget {
  const SmartMedApp({Key? key}) : super(key: key);
  @override State<SmartMedApp> createState() => _SmartMedAppState();
}

class _SmartMedAppState extends State<SmartMedApp> {
  final AppState _state = AppState();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (_, __) => MaterialApp(
        title: 'Smart Medicine Reminder',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(_state.darkMode),
        home: _root(),
      ),
    );
  }
  Widget _root() {
    if (!_state.onboarded) return OnboardingScreen(s: _state);
    if (!_state.loggedIn)  return LoginScreen(s: _state);
    return MainShell(s: _state);
  }
}

// ══════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════
Color cardColor(BuildContext ctx) => Theme.of(ctx).cardColor;
Color textColor(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark ? AppColors.textDark : AppColors.textLight;
Color subColor(BuildContext ctx)  => Theme.of(ctx).brightness == Brightness.dark ? AppColors.subDark  : AppColors.subLight;
Color bgColor(BuildContext ctx)   => Theme.of(ctx).scaffoldBackgroundColor;

String medEmoji(MedType t) => const {
  MedType.tablet:'💊', MedType.capsule:'🔴', MedType.syrup:'🧴',
  MedType.injection:'💉', MedType.drops:'💧', MedType.cream:'🧫', MedType.inhaler:'🫁',
}[t]!;

String medTypeLabel(MedType t) => const {
  MedType.tablet:'Tablet', MedType.capsule:'Capsule', MedType.syrup:'Syrup',
  MedType.injection:'Injection', MedType.drops:'Drops', MedType.cream:'Cream', MedType.inhaler:'Inhaler',
}[t]!;

Widget sectionTitle(BuildContext ctx, String title, {String? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor(ctx))),
    if (trailing != null) Text(trailing, style: TextStyle(fontSize: 12, color: subColor(ctx))),
  ]),
);

// AdMob Banner Widget (UI placeholder — real AdMob needs plugin)
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52, color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C2030) : const Color(0xFFE8F0FE),
      child: Center(child: Text(
        '📢 Advertisement  •  AdMob: $kAdMobBanner',
        style: TextStyle(fontSize: 10, color: subColor(context)),
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ONBOARDING
// ══════════════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  final AppState s;
  const OnboardingScreen({Key? key, required this.s}) : super(key: key);
  @override State<OnboardingScreen> createState() => _OnboardingState();
}
class _OnboardingState extends State<OnboardingScreen> with TickerProviderStateMixin {
  int _pg = 0;
  late AnimationController _ac;
  late Animation<double>   _fa;

  static const _pages = [
    {'emoji':'💊','title':'Never Miss\nYour Medicine','sub':'Smart reminders morning, afternoon & night. Stay healthy with timely doses.','color':AppColors.primary},
    {'emoji':'👨‍👩‍👧','title':'Manage Your\nWhole Family','sub':'Track medicines for parents, kids, and everyone — all in one place.','color':AppColors.purple},
    {'emoji':'📊','title':'Smart Reports\n& Streaks','sub':'See your history, track streaks, and share PDF reports with your doctor.','color':AppColors.accent},
  ];

  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync:this, duration:const Duration(milliseconds:380));
    _fa = CurvedAnimation(parent:_ac, curve:Curves.easeIn);
    _ac.forward();
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  void _next() {
    if (_pg < 2) { _ac.reset(); setState(() => _pg++); _ac.forward(); }
    else widget.s.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final p = _pages[_pg];
    final color = p['color'] as Color;
    return Scaffold(
      backgroundColor: color,
      body: SafeArea(child: FadeTransition(
        opacity: _fa,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28,0,28,28),
          child: Column(children: [
            Align(alignment:Alignment.topRight,
              child: TextButton(onPressed: widget.s.completeOnboarding,
                child: const Text('Skip', style: TextStyle(color:Colors.white70, fontSize:15)))),
            const Spacer(),
            Text(p['emoji'] as String, style:const TextStyle(fontSize:96)),
            const SizedBox(height:36),
            Text(p['title'] as String, textAlign:TextAlign.center,
              style:const TextStyle(fontSize:30, fontWeight:FontWeight.w900, color:Colors.white, height:1.2)),
            const SizedBox(height:14),
            Text(p['sub'] as String, textAlign:TextAlign.center,
              style:const TextStyle(fontSize:15, color:Colors.white70, height:1.55)),
            const Spacer(),
            Row(mainAxisAlignment:MainAxisAlignment.center,
              children: List.generate(3,(i) => AnimatedContainer(
                duration:const Duration(milliseconds:300),
                margin:const EdgeInsets.symmetric(horizontal:4),
                width: i==_pg ? 24 : 8, height:8,
                decoration:BoxDecoration(
                  color: i==_pg ? Colors.white : Colors.white38,
                  borderRadius:BorderRadius.circular(4)),
              ))),
            const SizedBox(height:28),
            SizedBox(width:double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor:Colors.white, foregroundColor:color,
                  padding:const EdgeInsets.symmetric(vertical:16),
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
                  elevation:0,
                ),
                child: Text(_pg==2 ? 'Get Started →' : 'Next →',
                  style:const TextStyle(fontSize:16, fontWeight:FontWeight.w800)),
              )),
          ]),
        ),
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  LOGIN
// ══════════════════════════════════════════════════════════════
class LoginScreen extends StatelessWidget {
  final AppState s;
  const LoginScreen({Key? key, required this.s}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const SizedBox(height:32),
          Container(
            width:88, height:88,
            decoration:BoxDecoration(
              gradient:const LinearGradient(colors:[AppColors.primary, AppColors.primaryDk]),
              borderRadius:BorderRadius.circular(24),
              boxShadow:[BoxShadow(color:AppColors.primary.withOpacity(.35), blurRadius:20, offset:const Offset(0,8))],
            ),
            child:const Center(child:Text('💊', style:TextStyle(fontSize:44))),
          ),
          const SizedBox(height:22),
          const Text('Smart Medicine\nReminder', textAlign:TextAlign.center,
            style:TextStyle(fontSize:26, fontWeight:FontWeight.w900, height:1.2)),
          const SizedBox(height:6),
          Text('Never Miss Your Medicine Again',
            style:TextStyle(color:subColor(context), fontSize:13)),
          const SizedBox(height:48),
          _loginBtn('🔵  Continue with Google',    const Color(0xFF4285F4), () => s.login()),
          const SizedBox(height:12),
          _loginBtn('📱  Continue with Phone',     const Color(0xFF25D366), () => s.login()),
          const SizedBox(height:12),
          OutlinedButton(
            onPressed: s.login,
            style:OutlinedButton.styleFrom(
              minimumSize:const Size(double.infinity,52),
              side:const BorderSide(color:Colors.grey),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
            ),
            child:const Text('👤  Continue as Guest',
              style:TextStyle(fontWeight:FontWeight.w700, fontSize:14)),
          ),
          const SizedBox(height:32),
          Container(
            padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(
              color:AppColors.primary.withOpacity(.08),
              borderRadius:BorderRadius.circular(14),
              border:Border.all(color:AppColors.primary.withOpacity(.15)),
            ),
            child:Row(children:[
              const Text('⭐', style:TextStyle(fontSize:22)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                const Text('Premium Members', style:TextStyle(fontWeight:FontWeight.w700, fontSize:13)),
                Text('Cloud Sync • Family Sharing • PDF Export',
                  style:TextStyle(color:subColor(context), fontSize:11)),
              ])),
            ]),
          ),
        ]),
      )),
    );
  }

  Widget _loginBtn(String label, Color color, VoidCallback fn) =>
    ElevatedButton(
      onPressed: fn,
      style:ElevatedButton.styleFrom(
        backgroundColor:color, foregroundColor:Colors.white,
        minimumSize:const Size(double.infinity,52),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
        elevation:0,
      ),
      child:Text(label, style:const TextStyle(fontSize:14, fontWeight:FontWeight.w700)),
    );
}

// ══════════════════════════════════════════════════════════════
//  MAIN SHELL
// ══════════════════════════════════════════════════════════════
class MainShell extends StatelessWidget {
  final AppState s;
  const MainShell({Key? key, required this.s}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: s,
      builder: (ctx, _) {
        final screens = [
          HomeScreen(s:s),
          MedicinesScreen(s:s),
          CalendarScreen(s:s),
          ReportsScreen(s:s),
          ProfileScreen(s:s),
        ];
        return Scaffold(
          body: screens[s.nav],
          bottomNavigationBar: Column(mainAxisSize:MainAxisSize.min, children:[
            if (!s.isPremium) const AdBannerWidget(),
            NavigationBar(
              selectedIndex: s.nav,
              onDestinationSelected: s.setNav,
              destinations: const [
                NavigationDestination(icon:Icon(Icons.home_rounded),        label:'Home'),
                NavigationDestination(icon:Icon(Icons.medication_rounded),   label:'Medicines'),
                NavigationDestination(icon:Icon(Icons.calendar_month_rounded),label:'Calendar'),
                NavigationDestination(icon:Icon(Icons.bar_chart_rounded),    label:'Reports'),
                NavigationDestination(icon:Icon(Icons.person_rounded),       label:'Profile'),
              ],
            ),
          ]),
          floatingActionButton: s.nav <= 1
            ? FloatingActionButton.extended(
                onPressed: () => _openAdd(ctx),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Add Medicine', style:TextStyle(fontWeight:FontWeight.w700)),
              )
            : null,
        );
      },
    );
  }

  void _openAdd(BuildContext ctx) => showModalBottomSheet(
    context:ctx, isScrollControlled:true, backgroundColor:Colors.transparent,
    builder:(_) => AddMedicineSheet(s:s),
  );
}

// ══════════════════════════════════════════════════════════════
//  HOME SCREEN
// ══════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  final AppState s;
  const HomeScreen({Key? key, required this.s}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final hour = now.hour;
    final greeting = hour<12 ? 'Good Morning ☀️' : hour<17 ? 'Good Afternoon 🌤️' : 'Good Evening 🌙';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dateStr = '${days[(now.weekday-1)%7]}, ${now.day} ${months[now.month-1]} ${now.year}';

    return AnimatedBuilder(
      animation: s,
      builder: (ctx, _) => Scaffold(
        body: CustomScrollView(slivers:[
          SliverToBoxAdapter(child: _header(ctx, greeting, dateStr)),
          if (s.refillNeeded.isNotEmpty)
            SliverToBoxAdapter(child: _refillBanner(ctx)),
          SliverToBoxAdapter(child: _stats(ctx)),
          SliverToBoxAdapter(child: _streak(ctx)),
          SliverToBoxAdapter(child: _familyFilter(ctx)),
          SliverToBoxAdapter(child: _quickActions(ctx)),
          SliverToBoxAdapter(child: sectionTitle(ctx, "Today's Schedule", trailing:'${s.todayDoses.length} doses')),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx,i) => DoseCard(dose:s.todayDoses[i], s:s),
            childCount: s.todayDoses.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height:110)),
        ]),
      ),
    );
  }

  Widget _header(BuildContext ctx, String greeting, String date) => Container(
    decoration:const BoxDecoration(
      gradient:LinearGradient(colors:[AppColors.primary, AppColors.primaryDk]),
      borderRadius:BorderRadius.only(bottomLeft:Radius.circular(28), bottomRight:Radius.circular(28)),
    ),
    padding:const EdgeInsets.fromLTRB(22,56,22,26),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text(greeting, style:const TextStyle(color:Colors.white70, fontSize:13, fontWeight:FontWeight.w500)),
        const SizedBox(height:4),
        const Text('Amanullah Family', style:TextStyle(color:Colors.white, fontSize:22, fontWeight:FontWeight.w900)),
        const SizedBox(height:2),
        Text(date, style:const TextStyle(color:Colors.white60, fontSize:11)),
      ])),
      IconButton(
        icon:const Icon(Icons.notifications_outlined, color:Colors.white),
        onPressed:() => _showNotifications(ctx),
      ),
    ]),
  );

  void _showNotifications(BuildContext ctx) => showModalBottomSheet(
    context:ctx, backgroundColor:Colors.transparent,
    builder:(_) => _NotifSheet(s:s),
  );

  Widget _refillBanner(BuildContext ctx) => Container(
    margin:const EdgeInsets.fromLTRB(16,14,16,0),
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(
      color:AppColors.warning.withOpacity(.12),
      borderRadius:BorderRadius.circular(14),
      border:Border.all(color:AppColors.warning.withOpacity(.3)),
    ),
    child:Row(children:[
      const Text('🔁', style:TextStyle(fontSize:22)),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        const Text('Refill Needed!', style:TextStyle(fontWeight:FontWeight.w800, color:AppColors.warning, fontSize:13)),
        Text('${s.refillNeeded.map((m)=>m.name).join(', ')} running low',
          style:TextStyle(color:subColor(ctx), fontSize:11)),
      ])),
    ]),
  );

  Widget _stats(BuildContext ctx) => Padding(
    padding:const EdgeInsets.fromLTRB(16,16,16,0),
    child:Row(children:[
      _sc(ctx,'Total','${s.totalCount}','💊',AppColors.primary),
      const SizedBox(width:8),
      _sc(ctx,'Taken','${s.takenCount}','✅',AppColors.accent),
      const SizedBox(width:8),
      _sc(ctx,'Missed','${s.missedCount}','❌',AppColors.danger),
      const SizedBox(width:8),
      _sc(ctx,'Pending','${s.pendingCount}','⏰',AppColors.warning),
    ]),
  );

  Widget _sc(BuildContext ctx, String label, String val, String emoji, Color color) =>
    Expanded(child:Container(
      padding:const EdgeInsets.all(10),
      decoration:BoxDecoration(
        color:color.withOpacity(.1), borderRadius:BorderRadius.circular(14),
        border:Border.all(color:color.withOpacity(.18)),
      ),
      child:Column(children:[
        Text(emoji, style:const TextStyle(fontSize:18)),
        const SizedBox(height:4),
        Text(val, style:TextStyle(fontSize:20, fontWeight:FontWeight.w900, color:color)),
        Text(label, style:TextStyle(fontSize:9, color:subColor(ctx), fontWeight:FontWeight.w600)),
      ]),
    ));

  Widget _streak(BuildContext ctx) => Padding(
    padding:const EdgeInsets.fromLTRB(16,14,16,0),
    child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[AppColors.gold.withOpacity(.15), AppColors.warning.withOpacity(.08)]),
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:AppColors.gold.withOpacity(.3)),
      ),
      child:Row(children:[
        const Text('🔥', style:TextStyle(fontSize:32)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text('${s.streak} Day Streak!', style:const TextStyle(fontSize:17, fontWeight:FontWeight.w900, color:AppColors.warning)),
          Text('Keep it up! You\'re doing great.', style:TextStyle(fontSize:11, color:subColor(ctx))),
        ])),
        Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
          Text('${(s.takenCount / max(1,s.totalCount)*100).round()}%',
            style:const TextStyle(fontSize:22, fontWeight:FontWeight.w900, color:AppColors.accent)),
          Text('today', style:TextStyle(fontSize:10, color:subColor(ctx))),
        ]),
      ]),
    ),
  );

  Widget _familyFilter(BuildContext ctx) => Padding(
    padding:const EdgeInsets.fromLTRB(16,14,16,0),
    child:SingleChildScrollView(scrollDirection:Axis.horizontal, child:Row(children:[
      _fChip(ctx, null, '👥 All'),
      ...s.family.map((m) => _fChip(ctx, m.id, '${m.avatar} ${m.name.split(' ').first}')),
    ])),
  );

  Widget _fChip(BuildContext ctx, String? id, String label) {
    final sel = s.filterMember == id;
    return GestureDetector(
      onTap:() => s.setFilter(id),
      child:Container(
        margin:const EdgeInsets.only(right:8),
        padding:const EdgeInsets.symmetric(horizontal:14, vertical:8),
        decoration:BoxDecoration(
          color: sel ? AppColors.primary : cardColor(ctx),
          borderRadius:BorderRadius.circular(20),
          border:Border.all(color: sel ? AppColors.primary : Colors.grey.withOpacity(.2)),
          boxShadow:sel ? [BoxShadow(color:AppColors.primary.withOpacity(.25), blurRadius:8)] : [],
        ),
        child:Text(label, style:TextStyle(fontSize:12, fontWeight:FontWeight.w700,
          color: sel ? Colors.white : textColor(ctx))),
      ),
    );
  }

  Widget _quickActions(BuildContext ctx) => Padding(
    padding:const EdgeInsets.fromLTRB(16,14,16,0),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      sectionTitle(ctx, 'Quick Actions'),
      Row(children:[
        _qa(ctx,'➕','Add\nMedicine',AppColors.primary,  () => showModalBottomSheet(context:ctx, isScrollControlled:true, backgroundColor:Colors.transparent, builder:(_)=>AddMedicineSheet(s:s))),
        const SizedBox(width:8),
        _qa(ctx,'📊','Reports',     AppColors.purple,    () => s.setNav(3)),
        const SizedBox(width:8),
        _qa(ctx,'👨‍👩‍👧','Family',     AppColors.warning,   () => s.setNav(4)),
        const SizedBox(width:8),
        _qa(ctx,'🔔','Reminders',   AppColors.accent,    () => _showNotifications(ctx)),
      ]),
    ]),
  );

  Widget _qa(BuildContext ctx, String ico, String label, Color color, VoidCallback fn) =>
    Expanded(child:GestureDetector(
      onTap:fn,
      child:Container(
        padding:const EdgeInsets.symmetric(vertical:14),
        decoration:BoxDecoration(
          color:color.withOpacity(.1), borderRadius:BorderRadius.circular(14),
          border:Border.all(color:color.withOpacity(.15)),
        ),
        child:Column(children:[
          Text(ico, style:const TextStyle(fontSize:24)),
          const SizedBox(height:5),
          Text(label, textAlign:TextAlign.center,
            style:TextStyle(fontSize:10, color:color, fontWeight:FontWeight.w700, height:1.3)),
        ]),
      ),
    ));
}

// Notification sheet
class _NotifSheet extends StatelessWidget {
  final AppState s;
  const _NotifSheet({required this.s});
  @override
  Widget build(BuildContext context) => Container(
    decoration:BoxDecoration(color:cardColor(context), borderRadius:const BorderRadius.vertical(top:Radius.circular(24))),
    padding:const EdgeInsets.all(20),
    child:Column(mainAxisSize:MainAxisSize.min, children:[
      Container(width:40, height:4, decoration:BoxDecoration(color:Colors.grey.shade300, borderRadius:BorderRadius.circular(2))),
      const SizedBox(height:14),
      Text('Notifications', style:TextStyle(fontSize:17, fontWeight:FontWeight.w800, color:textColor(context))),
      const SizedBox(height:14),
      ...s.notifications.map((n) => Padding(
        padding:const EdgeInsets.only(bottom:10),
        child:Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:bgColor(context), borderRadius:BorderRadius.circular(12)),
          child:Text(n, style:TextStyle(fontSize:13, color:textColor(context))),
        ),
      )),
      const SizedBox(height:8),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  DOSE CARD
// ══════════════════════════════════════════════════════════════
class DoseCard extends StatelessWidget {
  final TodayDose dose;
  final AppState  s;
  const DoseCard({Key? key, required this.dose, required this.s}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final med = dose.medicine;
    Color statusColor; String statusLabel;
    switch (dose.status) {
      case DoseStatus.taken:   statusColor=AppColors.accent;   statusLabel='Taken ✅';   break;
      case DoseStatus.missed:  statusColor=AppColors.danger;   statusLabel='Missed ❌';  break;
      case DoseStatus.skipped: statusColor=AppColors.purple;   statusLabel='Skipped ⏭️'; break;
      default:                 statusColor=AppColors.warning;  statusLabel='Pending ⏰'; break;
    }
    return Container(
      margin:const EdgeInsets.symmetric(horizontal:16, vertical:5),
      decoration:BoxDecoration(
        color:cardColor(context), borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(.05), blurRadius:8, offset:const Offset(0,2))],
      ),
      child:ListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:14, vertical:6),
        leading:Container(
          width:46, height:46,
          decoration:BoxDecoration(color:med.color.withOpacity(.12), borderRadius:BorderRadius.circular(12)),
          child:Center(child:Text(medEmoji(med.type), style:const TextStyle(fontSize:22))),
        ),
        title:Text(med.name, style:TextStyle(fontWeight:FontWeight.w800, fontSize:14, color:textColor(context))),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text('${med.strength} • ${dose.time}', style:TextStyle(fontSize:11, color:subColor(context))),
          const SizedBox(height:4),
          Row(children:[
            Container(
              padding:const EdgeInsets.symmetric(horizontal:8, vertical:3),
              decoration:BoxDecoration(color:statusColor.withOpacity(.1), borderRadius:BorderRadius.circular(6)),
              child:Text(statusLabel, style:TextStyle(color:statusColor, fontSize:10, fontWeight:FontWeight.w700)),
            ),
            if (med.needsRefill) ...[
              const SizedBox(width:6),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:8, vertical:3),
                decoration:BoxDecoration(color:AppColors.warning.withOpacity(.1), borderRadius:BorderRadius.circular(6)),
                child:const Text('🔁 Refill!', style:TextStyle(color:AppColors.warning, fontSize:10, fontWeight:FontWeight.w700)),
              ),
            ],
          ]),
        ]),
        trailing: dose.status == DoseStatus.pending
          ? PopupMenuButton<DoseStatus>(
              icon:Icon(Icons.more_vert, color:subColor(context)),
              onSelected:(st) => s.markDose(dose, st),
              itemBuilder:(_) => const [
                PopupMenuItem(value:DoseStatus.taken,   child:Text('✅  Mark as Taken')),
                PopupMenuItem(value:DoseStatus.missed,  child:Text('❌  Mark as Missed')),
                PopupMenuItem(value:DoseStatus.skipped, child:Text('⏭️  Skip this Dose')),
              ],
            )
          : Icon(dose.status==DoseStatus.taken ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color:statusColor),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ADD MEDICINE SHEET
// ══════════════════════════════════════════════════════════════
class AddMedicineSheet extends StatefulWidget {
  final AppState s;
  const AddMedicineSheet({Key? key, required this.s}) : super(key: key);
  @override State<AddMedicineSheet> createState() => _AddMedState();
}
class _AddMedState extends State<AddMedicineSheet> {
  final _nameC    = TextEditingController();
  final _brandC   = TextEditingController();
  final _docC     = TextEditingController();
  final _diseaseC = TextEditingController();
  final _notesC   = TextEditingController();
  final _stockC   = TextEditingController(text:'30');
  final _refillC  = TextEditingController(text:'7');
  MedType _type   = MedType.tablet;
  String  _str    = '500mg';
  int     _qty    = 1;
  String  _member = 'f1';
  List<String> _times = ['08:00 AM'];
  bool _hasPhoto = false;

  static const _strengths = ['125mg','250mg','500mg','1g','Custom'];
  static const _colors = [AppColors.primary, AppColors.purple, AppColors.accent, AppColors.warning, AppColors.danger];

  @override void dispose() {
    for (final c in [_nameC,_brandC,_docC,_diseaseC,_notesC,_stockC,_refillC]) c.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please enter medicine name')));
      return;
    }
    final rnd = Random();
    widget.s.addMedicine(Medicine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameC.text.trim(), brandName: _brandC.text.trim(),
      doctorName: _docC.text.trim(), disease: _diseaseC.text.trim(),
      notes: _notesC.text.trim(), type: _type, strength: _str,
      quantity: _qty,
      totalStock: int.tryParse(_stockC.text) ?? 30,
      refillAt:   int.tryParse(_refillC.text) ?? 7,
      times: List.from(_times),
      familyMemberId: _member,
      color: _colors[rnd.nextInt(_colors.length)],
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text('${_nameC.text} added! ✅'),
      backgroundColor:AppColors.accent, behavior:SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      decoration:BoxDecoration(
        color:bgColor(context),
        borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),
      ),
      child:Column(children:[
        Container(margin:const EdgeInsets.only(top:10), width:40, height:4,
          decoration:BoxDecoration(color:Colors.grey.shade400, borderRadius:BorderRadius.circular(2))),
        Padding(
          padding:const EdgeInsets.symmetric(horizontal:18, vertical:14),
          child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
            Text('Add Medicine', style:TextStyle(fontSize:18, fontWeight:FontWeight.w800, color:textColor(context))),
            IconButton(icon:Icon(Icons.close, color:subColor(context)), onPressed:() => Navigator.pop(context)),
          ]),
        ),
        Expanded(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:18), children:[
          _sec('Basic Information'),
          _field('Medicine Name *', _nameC, hint:'e.g. Paracetamol'),
          _field('Brand Name',      _brandC, hint:'e.g. Panadol'),
          _field('Doctor Name',     _docC,   hint:'e.g. Dr. Ahmed'),
          _field('Disease / Condition', _diseaseC, hint:'e.g. Fever'),
          _field('Notes',           _notesC, hint:'e.g. Take after meals', lines:2),

          // Photo placeholder
          _sec('Medicine Photo'),
          GestureDetector(
            onTap:() => setState(() => _hasPhoto = !_hasPhoto),
            child:Container(
              height:80,
              decoration:BoxDecoration(
                color: _hasPhoto ? AppColors.accent.withOpacity(.1) : cardColor(context),
                borderRadius:BorderRadius.circular(12),
                border:Border.all(color: _hasPhoto ? AppColors.accent : Colors.grey.withOpacity(.3), style:BorderStyle.solid),
              ),
              child:Center(child: _hasPhoto
                ? const Column(mainAxisAlignment:MainAxisAlignment.center, children:[
                    Text('📸', style:TextStyle(fontSize:28)),
                    Text('Photo Added ✓', style:TextStyle(color:AppColors.accent, fontWeight:FontWeight.w700, fontSize:12)),
                  ])
                : const Column(mainAxisAlignment:MainAxisAlignment.center, children:[
                    Icon(Icons.add_a_photo_outlined, color:Colors.grey, size:28),
                    Text('Tap to add photo', style:TextStyle(color:Colors.grey, fontSize:12)),
                  ]),
              ),
            ),
          ),

          _sec('Medicine Type'),
          Wrap(spacing:8, runSpacing:8,
            children:MedType.values.map((t) => _chip(
              '${medEmoji(t)} ${medTypeLabel(t)}',
              t==_type, () => setState(()=>_type=t), AppColors.primary,
            )).toList(),
          ),

          _sec('Strength'),
          Wrap(spacing:8, runSpacing:8,
            children:_strengths.map((st) => _chip(
              st, st==_str, ()=>setState(()=>_str=st), AppColors.accent,
            )).toList(),
          ),

          _sec('Quantity per Dose'),
          Row(children:[
            _qBtn(Icons.remove, ()=>setState(()=>_qty=max(1,_qty-1))),
            const SizedBox(width:14),
            Text('$_qty', style:TextStyle(fontSize:24, fontWeight:FontWeight.w900, color:textColor(context))),
            const SizedBox(width:14),
            _qBtn(Icons.add,    ()=>setState(()=>_qty++)),
            const SizedBox(width:10),
            Text(medTypeLabel(_type).toLowerCase()+'(s)', style:TextStyle(color:subColor(context))),
          ]),

          _sec('Stock & Refill Reminder'),
          Row(children:[
            Expanded(child:_field('Total Stock', _stockC, hint:'30', keyboardType:TextInputType.number)),
            const SizedBox(width:10),
            Expanded(child:_field('Alert at (pills)', _refillC, hint:'7', keyboardType:TextInputType.number)),
          ]),

          _sec('For Family Member'),
          ...widget.s.family.map((m) => RadioListTile<String>(
            value:m.id, groupValue:_member,
            onChanged:(v)=>setState(()=>_member=v!),
            title:Text('${m.avatar} ${m.name}', style:TextStyle(fontWeight:FontWeight.w700, color:textColor(context))),
            subtitle:Text(m.relation, style:TextStyle(color:subColor(context), fontSize:11)),
            activeColor:AppColors.primary, contentPadding:EdgeInsets.zero, dense:true,
          )),

          _sec('Dose Times'),
          ..._times.asMap().entries.map((e) => Padding(
            padding:const EdgeInsets.only(bottom:8),
            child:Row(children:[
              Expanded(child:Container(
                padding:const EdgeInsets.symmetric(horizontal:14, vertical:13),
                decoration:BoxDecoration(color:cardColor(context), borderRadius:BorderRadius.circular(12),
                  border:Border.all(color:Colors.grey.withOpacity(.2))),
                child:Text('⏰ ${e.value}', style:TextStyle(fontWeight:FontWeight.w600, color:textColor(context))),
              )),
              if (_times.length>1) IconButton(
                icon:const Icon(Icons.remove_circle_outline, color:AppColors.danger),
                onPressed:()=>setState(()=>_times.removeAt(e.key)),
              ),
            ]),
          )),
          TextButton.icon(
            onPressed:()=>setState(()=>_times.add('12:00 PM')),
            icon:const Icon(Icons.add, color:AppColors.primary),
            label:const Text('Add Time', style:TextStyle(color:AppColors.primary, fontWeight:FontWeight.w700)),
          ),

          const SizedBox(height:24),
          SizedBox(width:double.infinity,
            child:ElevatedButton(
              onPressed:_save,
              style:ElevatedButton.styleFrom(
                backgroundColor:AppColors.primary, foregroundColor:Colors.white,
                padding:const EdgeInsets.symmetric(vertical:15),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
              ),
              child:const Text('Save Medicine ✓', style:TextStyle(fontSize:16, fontWeight:FontWeight.w800)),
            ),
          ),
          const SizedBox(height:40),
        ])),
      ]),
    );
  }

  Widget _sec(String t) => Padding(
    padding:const EdgeInsets.only(top:18, bottom:8),
    child:Text(t, style:const TextStyle(fontSize:13, fontWeight:FontWeight.w800, color:AppColors.primary)),
  );

  Widget _field(String label, TextEditingController ctrl,
    {String hint='', int lines=1, TextInputType? keyboardType}) =>
    Padding(
      padding:const EdgeInsets.only(bottom:10),
      child:TextField(
        controller:ctrl, maxLines:lines, keyboardType:keyboardType,
        decoration:InputDecoration(
          labelText:label, hintText:hint,
          filled:true, fillColor:cardColor(context),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),
            borderSide:BorderSide(color:Colors.grey.withOpacity(.2))),
          enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),
            borderSide:BorderSide(color:Colors.grey.withOpacity(.2))),
          contentPadding:const EdgeInsets.symmetric(horizontal:14, vertical:13),
        ),
      ),
    );

  Widget _chip(String label, bool sel, VoidCallback fn, Color color) =>
    GestureDetector(onTap:fn, child:Container(
      padding:const EdgeInsets.symmetric(horizontal:13, vertical:8),
      decoration:BoxDecoration(
        color: sel ? color : cardColor(context),
        borderRadius:BorderRadius.circular(10),
        border:Border.all(color: sel ? color : Colors.grey.withOpacity(.25)),
      ),
      child:Text(label, style:TextStyle(
        color: sel ? Colors.white : textColor(context),
        fontWeight:FontWeight.w700, fontSize:12,
      )),
    ));

  Widget _qBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap:fn,
    child:Container(
      width:36, height:36,
      decoration:BoxDecoration(color:AppColors.primary.withOpacity(.1), borderRadius:BorderRadius.circular(10)),
      child:Icon(icon, color:AppColors.primary, size:20),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  MEDICINES SCREEN
// ══════════════════════════════════════════════════════════════
class MedicinesScreen extends StatefulWidget {
  final AppState s;
  const MedicinesScreen({Key? key, required this.s}) : super(key: key);
  @override State<MedicinesScreen> createState() => _MedScreenState();
}
class _MedScreenState extends State<MedicinesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.s,
      builder: (ctx, _) {
        final filtered = widget.s.medicines.where((m) =>
          m.name.toLowerCase().contains(_search.toLowerCase()) ||
          m.disease.toLowerCase().contains(_search.toLowerCase()) ||
          m.brandName.toLowerCase().contains(_search.toLowerCase())
        ).toList();

        return Scaffold(
          appBar:AppBar(
            backgroundColor:AppColors.primary,
            title:const Text('My Medicines', style:TextStyle(color:Colors.white, fontWeight:FontWeight.w800)),
            bottom:PreferredSize(
              preferredSize:const Size.fromHeight(56),
              child:Padding(
                padding:const EdgeInsets.fromLTRB(16,0,16,10),
                child:TextField(
                  onChanged:(v)=>setState(()=>_search=v),
                  style:const TextStyle(color:Colors.white),
                  decoration:InputDecoration(
                    hintText:'Search medicines...',
                    hintStyle:const TextStyle(color:Colors.white54),
                    prefixIcon:const Icon(Icons.search, color:Colors.white54),
                    filled:true, fillColor:Colors.white.withOpacity(.15),
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:BorderSide.none),
                    contentPadding:const EdgeInsets.symmetric(vertical:10),
                  ),
                ),
              ),
            ),
          ),
          body: filtered.isEmpty
            ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center, children:[
                const Text('💊', style:TextStyle(fontSize:56)),
                const SizedBox(height:12),
                Text('No medicines found', style:TextStyle(color:subColor(ctx), fontSize:16)),
              ]))
            : ListView.builder(
                padding:const EdgeInsets.fromLTRB(16,14,16,100),
                itemCount:filtered.length,
                itemBuilder:(ctx,i) => _MedCard(med:filtered[i], s:widget.s),
              ),
        );
      },
    );
  }
}

class _MedCard extends StatelessWidget {
  final Medicine med;
  final AppState s;
  const _MedCard({required this.med, required this.s});

  @override
  Widget build(BuildContext context) {
    final member = s.family.firstWhere((m)=>m.id==med.familyMemberId, orElse:()=>s.family.first);
    return Container(
      margin:const EdgeInsets.only(bottom:12),
      decoration:BoxDecoration(
        color:cardColor(context), borderRadius:BorderRadius.circular(16),
        border:Border(left:BorderSide(color:med.color, width:4)),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(.05), blurRadius:8, offset:const Offset(0,2))],
      ),
      child:Padding(
        padding:const EdgeInsets.all(14),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Text(medEmoji(med.type), style:const TextStyle(fontSize:28)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(med.name, style:TextStyle(fontSize:15, fontWeight:FontWeight.w800, color:textColor(context))),
              Text(med.brandName, style:TextStyle(fontSize:12, color:subColor(context))),
            ])),
            PopupMenuButton(
              icon:Icon(Icons.more_vert, color:subColor(context)),
              itemBuilder:(_)=>[
                const PopupMenuItem(value:'del', child:Text('🗑️  Delete')),
              ],
              onSelected:(v){ if(v=='del') s.deleteMedicine(med.id); },
            ),
          ]),
          const SizedBox(height:10),
          Wrap(spacing:6, runSpacing:6, children:[
            _tag('💊 ${med.strength}',  Colors.blue),
            _tag('🏥 ${med.disease}',   Colors.teal),
            _tag('👨‍⚕️ ${med.doctorName}', Colors.purple),
            _tag('${member.avatar} ${member.name.split(' ').first}', Colors.orange),
            ...med.times.map((t)=>_tag('⏰ $t', Colors.green)),
          ]),
          const SizedBox(height:10),
          // Stock bar
          Row(children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
                Text('Stock: ${med.totalStock} left', style:TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:textColor(context))),
                Text('~${med.daysLeft} days', style:TextStyle(fontSize:11, color:subColor(context))),
              ]),
              const SizedBox(height:4),
              ClipRRect(
                borderRadius:BorderRadius.circular(4),
                child:LinearProgressIndicator(
                  value: med.totalStock / max(1, med.totalStock + 30),
                  backgroundColor:Colors.grey.withOpacity(.2),
                  color: med.needsRefill ? AppColors.danger : AppColors.accent,
                  minHeight:6,
                ),
              ),
            ])),
          ]),
          if (med.needsRefill) Padding(
            padding:const EdgeInsets.only(top:8),
            child:Container(
              padding:const EdgeInsets.symmetric(horizontal:10, vertical:5),
              decoration:BoxDecoration(color:AppColors.warning.withOpacity(.1), borderRadius:BorderRadius.circular(8)),
              child:const Text('🔁 Refill Needed!', style:TextStyle(color:AppColors.warning, fontSize:11, fontWeight:FontWeight.w700)),
            ),
          ),
          if (med.notes.isNotEmpty) Padding(
            padding:const EdgeInsets.only(top:6),
            child:Text('📝 ${med.notes}', style:TextStyle(fontSize:11, color:subColor(context), fontStyle:FontStyle.italic)),
          ),
        ]),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding:const EdgeInsets.symmetric(horizontal:9, vertical:4),
    decoration:BoxDecoration(color:color.withOpacity(.08), borderRadius:BorderRadius.circular(20)),
    child:Text(label, style:TextStyle(color:color, fontSize:10, fontWeight:FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════════════════════
//  CALENDAR SCREEN
// ══════════════════════════════════════════════════════════════
class CalendarScreen extends StatefulWidget {
  final AppState s;
  const CalendarScreen({Key? key, required this.s}) : super(key: key);
  @override State<CalendarScreen> createState() => _CalState();
}
class _CalState extends State<CalendarScreen> {
  DateTime _selected = DateTime.now();
  static const _months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];
  static const _daysH  = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        backgroundColor:AppColors.primary,
        title:const Text('Calendar', style:TextStyle(color:Colors.white, fontWeight:FontWeight.w800)),
      ),
      body:Column(children:[
        _calHeader(),
        Expanded(child:_dayDetail()),
      ]),
    );
  }

  Widget _calHeader() => Container(
    color:AppColors.primary,
    padding:const EdgeInsets.fromLTRB(16,0,16,16),
    child:Column(children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
        IconButton(icon:const Icon(Icons.chevron_left, color:Colors.white),
          onPressed:()=>setState(()=>_selected=DateTime(_selected.year,_selected.month-1,1))),
        Text('${_months[_selected.month-1]} ${_selected.year}',
          style:const TextStyle(color:Colors.white, fontSize:16, fontWeight:FontWeight.w800)),
        IconButton(icon:const Icon(Icons.chevron_right, color:Colors.white),
          onPressed:()=>setState(()=>_selected=DateTime(_selected.year,_selected.month+1,1))),
      ]),
      Row(children:_daysH.map((d)=>Expanded(child:Center(child:Text(d,
        style:const TextStyle(color:Colors.white60, fontSize:11, fontWeight:FontWeight.w700))))).toList()),
      const SizedBox(height:6),
      _grid(),
    ]),
  );

  Widget _grid() {
    final first = DateTime(_selected.year, _selected.month, 1);
    final daysInMonth = DateTime(_selected.year, _selected.month+1, 0).day;
    final startWD = (first.weekday - 1) % 7;
    final now = DateTime.now();
    return GridView.builder(
      shrinkWrap:true, physics:const NeverScrollableScrollPhysics(),
      gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7, childAspectRatio:1.1),
      itemCount:startWD + daysInMonth,
      itemBuilder:(ctx, i){
        if (i < startWD) return const SizedBox();
        final day = i - startWD + 1;
        final isToday   = day==now.day && _selected.month==now.month && _selected.year==now.year;
        final isSel     = day==_selected.day;
        return GestureDetector(
          onTap:()=>setState(()=>_selected=DateTime(_selected.year,_selected.month,day)),
          child:Container(
            margin:const EdgeInsets.all(2),
            decoration:BoxDecoration(
              color: isSel ? Colors.white : isToday ? Colors.white24 : Colors.transparent,
              borderRadius:BorderRadius.circular(8),
            ),
            child:Center(child:Text('$day', style:TextStyle(
              color: isSel ? AppColors.primary : Colors.white,
              fontWeight: isToday||isSel ? FontWeight.w900 : FontWeight.w400,
              fontSize:12,
            ))),
          ),
        );
      },
    );
  }

  Widget _dayDetail() {
    final doses = widget.s.todayDoses;
    return ListView(padding:const EdgeInsets.all(16), children:[
      Text('${_selected.day} ${_months[_selected.month-1]} ${_selected.year}',
        style:TextStyle(fontSize:17, fontWeight:FontWeight.w800, color:textColor(context))),
      Text('${doses.length} doses scheduled', style:TextStyle(color:subColor(context), fontSize:12)),
      const SizedBox(height:12),
      ...doses.map((d) => DoseCard(dose:d, s:widget.s)),
      const SizedBox(height:80),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  REPORTS SCREEN
// ══════════════════════════════════════════════════════════════
class ReportsScreen extends StatelessWidget {
  final AppState s;
  const ReportsScreen({Key? key, required this.s}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: s,
      builder: (ctx, _) {
        final adherence = s.totalCount > 0 ? (s.takenCount / s.totalCount * 100).round() : 0;
        return Scaffold(
          appBar:AppBar(
            backgroundColor:AppColors.primary,
            title:const Text('Reports', style:TextStyle(color:Colors.white, fontWeight:FontWeight.w800)),
            actions:[
              TextButton.icon(
                onPressed: s.isPremium
                  ? () => _exportPDF(ctx)
                  : () => _premiumGate(ctx),
                icon:const Icon(Icons.picture_as_pdf, color:Colors.white, size:18),
                label:Text(s.isPremium ? 'Export PDF' : '⭐ PDF',
                  style:const TextStyle(color:Colors.white, fontSize:12)),
              ),
            ],
          ),
          body:ListView(children:[
            _summary(ctx, adherence),
            sectionTitle(ctx, 'Dose History (Today)'),
            _historyList(ctx),
            sectionTitle(ctx, 'This Week'),
            _weekChart(ctx),
            sectionTitle(ctx, 'Medicine-wise Adherence'),
            ...s.medicines.map((m) => _medStat(ctx, m)),
            const SizedBox(height:100),
          ]),
        );
      },
    );
  }

  void _exportPDF(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content:Text('📄 PDF exported! (Real PDF needs pdf plugin)'),
      backgroundColor:AppColors.accent, behavior:SnackBarBehavior.floating,
    ));
  }

  void _premiumGate(BuildContext ctx) => showDialog(
    context:ctx,
    builder:(_) => AlertDialog(
      title:const Text('⭐ Premium Feature'),
      content:const Text('PDF Export is available in Premium plan. Upgrade to unlock!'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text('Maybe Later')),
        ElevatedButton(
          onPressed:(){ s.upgradePremium(); Navigator.pop(ctx); },
          style:ElevatedButton.styleFrom(backgroundColor:AppColors.gold),
          child:const Text('Upgrade Now', style:TextStyle(color:Colors.black, fontWeight:FontWeight.w800)),
        ),
      ],
    ),
  );

  Widget _summary(BuildContext ctx, int adh) => Container(
    margin:const EdgeInsets.fromLTRB(16,16,16,0),
    padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[AppColors.primary, AppColors.primaryDk]),
      borderRadius:BorderRadius.circular(20),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      const Text("Today's Summary", style:TextStyle(color:Colors.white70, fontSize:12)),
      const SizedBox(height:4),
      Text('$adh% Adherence', style:const TextStyle(color:Colors.white, fontSize:30, fontWeight:FontWeight.w900)),
      const SizedBox(height:14),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
        _ss('Taken',   '${s.takenCount}',   AppColors.accent),
        _ss('Missed',  '${s.missedCount}',  AppColors.danger),
        _ss('Pending', '${s.pendingCount}', AppColors.warning),
        _ss('Streak',  '${s.streak} 🔥',    AppColors.gold),
      ]),
      const SizedBox(height:14),
      ClipRRect(borderRadius:BorderRadius.circular(8),
        child:LinearProgressIndicator(
          value:adh/100, backgroundColor:Colors.white24,
          color: adh>75 ? AppColors.accent : adh>50 ? AppColors.warning : AppColors.danger,
          minHeight:10,
        )),
    ]),
  );

  Widget _ss(String label, String val, Color color) => Column(children:[
    Text(val, style:TextStyle(color:color, fontSize:22, fontWeight:FontWeight.w900)),
    Text(label, style:const TextStyle(color:Colors.white70, fontSize:10)),
  ]);

  Widget _historyList(BuildContext ctx) => Padding(
    padding:const EdgeInsets.symmetric(horizontal:16),
    child:s.todayDoses.isEmpty
      ? Text('No doses yet', style:TextStyle(color:subColor(ctx)))
      : Column(children:s.todayDoses.map((d){
          Color c; String lbl;
          switch(d.status){
            case DoseStatus.taken:  c=AppColors.accent;  lbl='✅ Taken';   break;
            case DoseStatus.missed: c=AppColors.danger;  lbl='❌ Missed';  break;
            default:                c=AppColors.warning; lbl='⏰ Pending'; break;
          }
          return Container(
            margin:const EdgeInsets.only(bottom:6),
            padding:const EdgeInsets.symmetric(horizontal:14, vertical:10),
            decoration:BoxDecoration(color:cardColor(ctx), borderRadius:BorderRadius.circular(12),
              boxShadow:[BoxShadow(color:Colors.black.withOpacity(.04), blurRadius:4)]),
            child:Row(children:[
              Text(medEmoji(d.medicine.type), style:const TextStyle(fontSize:20)),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                Text(d.medicine.name, style:TextStyle(fontWeight:FontWeight.w700, color:textColor(ctx))),
                Text(d.time, style:TextStyle(color:subColor(ctx), fontSize:11)),
              ])),
              Container(padding:const EdgeInsets.symmetric(horizontal:10, vertical:4),
                decoration:BoxDecoration(color:c.withOpacity(.1), borderRadius:BorderRadius.circular(8)),
                child:Text(lbl, style:TextStyle(color:c, fontSize:11, fontWeight:FontWeight.w700))),
            ]),
          );
        }).toList()),
  );

  Widget _weekChart(BuildContext ctx) {
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final vals = s.weekAdherence;
    return Container(
      margin:const EdgeInsets.symmetric(horizontal:16),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:cardColor(ctx), borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(.05), blurRadius:8)]),
      child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceAround, crossAxisAlignment:CrossAxisAlignment.end,
          children:List.generate(7,(i){
            final h = vals[i] * 0.8;
            final c = vals[i]>=80 ? AppColors.accent : vals[i]>=60 ? AppColors.warning : AppColors.danger;
            return Column(mainAxisSize:MainAxisSize.min, children:[
              Text('${vals[i]}%', style:TextStyle(fontSize:8, color:subColor(ctx))),
              const SizedBox(height:4),
              AnimatedContainer(
                duration:const Duration(milliseconds:600),
                curve:Curves.easeOut,
                width:30, height:h,
                decoration:BoxDecoration(color:c, borderRadius:BorderRadius.circular(6)),
              ),
              const SizedBox(height:4),
              Text(days[i], style:TextStyle(fontSize:9, color:subColor(ctx), fontWeight:FontWeight.w700)),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _medStat(BuildContext ctx, Medicine m) {
    final adh = Random().nextInt(30)+70; // sample
    final color = adh>=80 ? AppColors.accent : adh>=60 ? AppColors.warning : AppColors.danger;
    return Container(
      margin:const EdgeInsets.fromLTRB(16,0,16,10),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:cardColor(ctx), borderRadius:BorderRadius.circular(14),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(.04), blurRadius:6)]),
      child:Row(children:[
        Container(width:40, height:40, decoration:BoxDecoration(color:m.color.withOpacity(.12), borderRadius:BorderRadius.circular(10)),
          child:Center(child:Text(medEmoji(m.type), style:const TextStyle(fontSize:20)))),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text(m.name, style:TextStyle(fontWeight:FontWeight.w800, color:textColor(ctx))),
          Text('${m.times.length}x/day • ${m.strength}', style:TextStyle(color:subColor(ctx), fontSize:11)),
          const SizedBox(height:6),
          ClipRRect(borderRadius:BorderRadius.circular(4),
            child:LinearProgressIndicator(value:adh/100, backgroundColor:Colors.grey.withOpacity(.15), color:color, minHeight:5)),
        ])),
        const SizedBox(width:12),
        Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
          Text('$adh%', style:TextStyle(color:color, fontWeight:FontWeight.w900, fontSize:16)),
          Text('adherence', style:TextStyle(color:subColor(ctx), fontSize:10)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PROFILE SCREEN
// ══════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  final AppState s;
  const ProfileScreen({Key? key, required this.s}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: s,
      builder: (ctx, _) => Scaffold(
        body: CustomScrollView(slivers:[
          SliverToBoxAdapter(child: _header(ctx)),
          if (!s.isPremium) SliverToBoxAdapter(child: _premBanner(ctx)),
          SliverToBoxAdapter(child: sectionTitle(ctx, 'Family Members')),
          SliverList(delegate:SliverChildBuilderDelegate(
            (ctx,i) => _familyCard(ctx, s.family[i]),
            childCount:s.family.length,
          )),
          SliverToBoxAdapter(child:Padding(
            padding:const EdgeInsets.symmetric(horizontal:16),
            child:TextButton.icon(
              onPressed:()=>_addMember(ctx),
              icon:const Icon(Icons.person_add, color:AppColors.primary),
              label:const Text('Add Family Member', style:TextStyle(color:AppColors.primary, fontWeight:FontWeight.w700)),
            ),
          )),
          SliverToBoxAdapter(child: sectionTitle(ctx, 'Settings')),
          SliverToBoxAdapter(child:_settings(ctx)),
          const SliverToBoxAdapter(child:SizedBox(height:80)),
        ]),
      ),
    );
  }

  Widget _header(BuildContext ctx) => Container(
    decoration:const BoxDecoration(
      gradient:LinearGradient(colors:[AppColors.primary, AppColors.primaryDk]),
      borderRadius:BorderRadius.only(bottomLeft:Radius.circular(28), bottomRight:Radius.circular(28)),
    ),
    padding:const EdgeInsets.fromLTRB(24,56,24,28),
    child:Row(children:[
      Container(width:64, height:64, decoration:BoxDecoration(color:Colors.white24, shape:BoxShape.circle),
        child:const Center(child:Text('👤', style:TextStyle(fontSize:32)))),
      const SizedBox(width:16),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        const Text('Amanullah Family', style:TextStyle(color:Colors.white, fontSize:20, fontWeight:FontWeight.w900)),
        Row(children:[
          Container(
            padding:const EdgeInsets.symmetric(horizontal:10, vertical:4),
            decoration:BoxDecoration(
              color: s.isPremium ? AppColors.gold.withOpacity(.25) : Colors.white24,
              borderRadius:BorderRadius.circular(12),
            ),
            child:Text(s.isPremium ? '⭐ Premium' : '👤 Free Plan',
              style:const TextStyle(color:Colors.white, fontSize:12, fontWeight:FontWeight.w700)),
          ),
        ]),
      ])),
      if (s.darkMode)
        const Icon(Icons.dark_mode, color:Colors.white70)
      else
        const Icon(Icons.light_mode, color:Colors.white70),
    ]),
  );

  Widget _premBanner(BuildContext ctx) => GestureDetector(
    onTap:() => showDialog(context:ctx, builder:(_)=>_PremiumDialog(s:s)),
    child:Container(
      margin:const EdgeInsets.fromLTRB(16,14,16,0),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[AppColors.gold.withOpacity(.2), AppColors.warning.withOpacity(.1)]),
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:AppColors.gold.withOpacity(.4)),
      ),
      child:Row(children:[
        const Text('⭐', style:TextStyle(fontSize:28)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          const Text('Upgrade to Premium', style:TextStyle(fontWeight:FontWeight.w800, fontSize:14, color:AppColors.warning)),
          Text('PDF Export • Cloud Sync • No Ads', style:TextStyle(fontSize:11, color:subColor(ctx))),
        ])),
        const Icon(Icons.arrow_forward_ios, size:14, color:AppColors.warning),
      ]),
    ),
  );

  Widget _familyCard(BuildContext ctx, FamilyMember m) => Container(
    margin:const EdgeInsets.fromLTRB(16,0,16,8),
    decoration:BoxDecoration(color:cardColor(ctx), borderRadius:BorderRadius.circular(14),
      boxShadow:[BoxShadow(color:Colors.black.withOpacity(.04), blurRadius:6)]),
    child:ListTile(
      leading:Text(m.avatar, style:const TextStyle(fontSize:30)),
      title:Text(m.name, style:TextStyle(fontWeight:FontWeight.w800, color:textColor(ctx))),
      subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text(m.relation, style:TextStyle(color:subColor(ctx), fontSize:11)),
        if (m.bloodGroup.isNotEmpty || m.allergies.isNotEmpty)
          Text('${m.bloodGroup.isNotEmpty ? '🩸 ${m.bloodGroup}' : ''}${m.allergies.isNotEmpty ? '  ⚠️ ${m.allergies}' : ''}',
            style:const TextStyle(fontSize:10, color:AppColors.danger)),
      ]),
      trailing:IconButton(
        icon:const Icon(Icons.edit_outlined),
        onPressed:() => _editMember(ctx, m),
      ),
    ),
  );

  void _editMember(BuildContext ctx, FamilyMember m) => showModalBottomSheet(
    context:ctx, isScrollControlled:true, backgroundColor:Colors.transparent,
    builder:(_) => _FamilySheet(s:s, existing:m),
  );

  void _addMember(BuildContext ctx) => showModalBottomSheet(
    context:ctx, isScrollControlled:true, backgroundColor:Colors.transparent,
    builder:(_) => _FamilySheet(s:s),
  );

  Widget _settings(BuildContext ctx) => Column(children:[
    _settingTile(ctx, Icons.dark_mode_rounded,    'Dark Mode',         'Comfortable for night use',
      trailing:Switch(value:s.darkMode, onChanged:(_)=>s.toggleDark(), activeColor:AppColors.primary)),
    _settingTile(ctx, Icons.notifications_rounded, 'Notifications',    'Alarm & reminder settings'),
    _settingTile(ctx, Icons.language_rounded,      'Language',         'English / Urdu'),
    _settingTile(ctx, Icons.share_rounded,         'Share App',        'Share with family & friends'),
    _settingTile(ctx, Icons.star_rounded,          'Rate the App',     'Your feedback matters',
      color:AppColors.gold),
    _settingTile(ctx, Icons.info_rounded,          'About',            'Smart Medicine Reminder v2.0'),
    const SizedBox(height:8),
    Padding(
      padding:const EdgeInsets.symmetric(horizontal:16),
      child:OutlinedButton(
        onPressed:s.logout,
        style:OutlinedButton.styleFrom(
          minimumSize:const Size(double.infinity,50),
          side:const BorderSide(color:AppColors.danger),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
        ),
        child:const Text('Logout', style:TextStyle(color:AppColors.danger, fontWeight:FontWeight.w800, fontSize:15)),
      ),
    ),
  ]);

  Widget _settingTile(BuildContext ctx, IconData icon, String title, String sub,
    {Widget? trailing, Color color = AppColors.primary}) =>
    Container(
      margin:const EdgeInsets.fromLTRB(16,0,16,8),
      decoration:BoxDecoration(color:cardColor(ctx), borderRadius:BorderRadius.circular(13),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(.03), blurRadius:4)]),
      child:ListTile(
        leading:Container(width:38, height:38, decoration:BoxDecoration(color:color.withOpacity(.1), borderRadius:BorderRadius.circular(10)),
          child:Icon(icon, color:color, size:20)),
        title:Text(title, style:TextStyle(fontWeight:FontWeight.w700, fontSize:13, color:textColor(ctx))),
        subtitle:Text(sub, style:TextStyle(color:subColor(ctx), fontSize:11)),
        trailing: trailing ?? Icon(Icons.chevron_right, color:subColor(ctx)),
        onTap:(){},
      ),
    );
}

// Premium dialog
class _PremiumDialog extends StatelessWidget {
  final AppState s;
  const _PremiumDialog({required this.s});
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
    title:const Row(children:[Text('⭐ '), Text('Go Premium', style:TextStyle(fontWeight:FontWeight.w900))]),
    content:Column(mainAxisSize:MainAxisSize.min, crossAxisAlignment:CrossAxisAlignment.start, children:[
      _f('📄 PDF Report Export'),
      _f('☁️ Cloud Sync & Backup'),
      _f('🚫 No Advertisements'),
      _f('👨‍👩‍👧 Unlimited Family Members'),
      _f('📊 Advanced Analytics'),
    ]),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Maybe Later')),
      ElevatedButton(
        onPressed:(){ s.upgradePremium(); Navigator.pop(context); },
        style:ElevatedButton.styleFrom(backgroundColor:AppColors.gold, foregroundColor:Colors.black),
        child:const Text('Upgrade — Free Trial', style:TextStyle(fontWeight:FontWeight.w800)),
      ),
    ],
  );
  Widget _f(String t) => Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Text(t, style:const TextStyle(fontSize:13, fontWeight:FontWeight.w500)),
  );
}

// ══════════════════════════════════════════════════════════════
//  FAMILY MEMBER SHEET (Add / Edit)
// ══════════════════════════════════════════════════════════════
class _FamilySheet extends StatefulWidget {
  final AppState s;
  final FamilyMember? existing;
  const _FamilySheet({required this.s, this.existing});
  @override State<_FamilySheet> createState() => _FamilySheetState();
}
class _FamilySheetState extends State<_FamilySheet> {
  late TextEditingController _nameC, _relC, _ageC, _bgC, _allergyC;
  String _avatar = '👤';
  final _avatars = ['👤','👩','👨','👦','👧','👴','👵','👶'];

  @override void initState() {
    super.initState();
    final e = widget.existing;
    _nameC    = TextEditingController(text:e?.name ?? '');
    _relC     = TextEditingController(text:e?.relation ?? '');
    _ageC     = TextEditingController(text:e != null ? '${e.age}' : '');
    _bgC      = TextEditingController(text:e?.bloodGroup ?? '');
    _allergyC = TextEditingController(text:e?.allergies ?? '');
    _avatar   = e?.avatar ?? '👤';
  }
  @override void dispose() {
    for (final c in [_nameC,_relC,_ageC,_bgC,_allergyC]) c.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameC.text.trim().isEmpty) return;
    widget.s.addFamilyMember(FamilyMember(
      id:   DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameC.text.trim(), relation: _relC.text.trim(),
      avatar: _avatar, age: int.tryParse(_ageC.text)??0,
      bloodGroup: _bgC.text.trim(), allergies: _allergyC.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Container(
    height:MediaQuery.of(context).size.height*0.75,
    decoration:BoxDecoration(color:bgColor(context), borderRadius:const BorderRadius.vertical(top:Radius.circular(24))),
    child:Column(children:[
      Container(margin:const EdgeInsets.only(top:10), width:40, height:4,
        decoration:BoxDecoration(color:Colors.grey.shade400, borderRadius:BorderRadius.circular(2))),
      Padding(padding:const EdgeInsets.all(18),
        child:Text(widget.existing!=null ? 'Edit Member' : 'Add Family Member',
          style:TextStyle(fontSize:17, fontWeight:FontWeight.w800, color:textColor(context)))),
      Expanded(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:18), children:[
        // Avatar picker
        Row(mainAxisAlignment:MainAxisAlignment.center, children:_avatars.map((a) =>
          GestureDetector(
            onTap:()=>setState(()=>_avatar=a),
            child:Container(
              margin:const EdgeInsets.all(4),
              padding:const EdgeInsets.all(8),
              decoration:BoxDecoration(
                color: a==_avatar ? AppColors.primary.withOpacity(.15) : Colors.transparent,
                borderRadius:BorderRadius.circular(12),
                border:Border.all(color: a==_avatar ? AppColors.primary : Colors.transparent),
              ),
              child:Text(a, style:const TextStyle(fontSize:26)),
            ),
          )).toList()),
        const SizedBox(height:8),
        _f('Full Name *',   _nameC,    'e.g. Ammi Jan'),
        _f('Relation',      _relC,     'e.g. Mother'),
        _f('Age',           _ageC,     '45', type:TextInputType.number),
        _f('Blood Group',   _bgC,      'e.g. O+'),
        _f('Allergies',     _allergyC, 'e.g. Penicillin'),
        const SizedBox(height:16),
        SizedBox(width:double.infinity,
          child:ElevatedButton(
            onPressed:_save,
            style:ElevatedButton.styleFrom(backgroundColor:AppColors.primary, foregroundColor:Colors.white,
              padding:const EdgeInsets.symmetric(vertical:14), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))),
            child:const Text('Save Member', style:TextStyle(fontWeight:FontWeight.w800, fontSize:15)),
          )),
        const SizedBox(height:30),
      ])),
    ]),
  );

  Widget _f(String label, TextEditingController c, String hint, {TextInputType? type}) => Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:TextField(
      controller:c, keyboardType:type,
      decoration:InputDecoration(
        labelText:label, hintText:hint, filled:true, fillColor:cardColor(context),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:BorderSide(color:Colors.grey.withOpacity(.2))),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12), borderSide:BorderSide(color:Colors.grey.withOpacity(.2))),
        contentPadding:const EdgeInsets.symmetric(horizontal:14, vertical:12),
      ),
    ),
  );
}
