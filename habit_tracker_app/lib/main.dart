import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitTrackerApp());
}

// ============================================================================
// THEME SYSTEM
// ============================================================================
enum AppThemeKey { emerald, ocean, amethyst, gold, light }

class AppThemeData {
  final String name;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;
  final Brightness brightness;

  const AppThemeData({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    required this.brightness,
  });
}

final Map<AppThemeKey, AppThemeData> appThemes = {
  AppThemeKey.emerald: const AppThemeData(
    name: '🌿 Emerald Oasis',
    primary: Color(0xFF10B981),
    secondary: Color(0xFF06B6D4),
    background: Color(0xFF0B131E),
    cardColor: Color(0xFF111D2E),
    textColor: Colors.white,
    subtitleColor: Color(0xFF94A3B8),
    brightness: Brightness.dark,
  ),
  AppThemeKey.ocean: const AppThemeData(
    name: '🌌 Midnight Ocean',
    primary: Color(0xFF38BDF8),
    secondary: Color(0xFF6366F1),
    background: Color(0xFF030712),
    cardColor: Color(0xFF0F172A),
    textColor: Colors.white,
    subtitleColor: Color(0xFF94A3B8),
    brightness: Brightness.dark,
  ),
  AppThemeKey.amethyst: const AppThemeData(
    name: '🔮 Royal Amethyst',
    primary: Color(0xFFA855F7),
    secondary: Color(0xFFEC4899),
    background: Color(0xFF0F0B1E),
    cardColor: Color(0xFF1F1735),
    textColor: Colors.white,
    subtitleColor: Color(0xFFCBD5E1),
    brightness: Brightness.dark,
  ),
  AppThemeKey.gold: const AppThemeData(
    name: '⚜️ Obsidian Gold',
    primary: Color(0xFFF59E0B),
    secondary: Color(0xFFD97706),
    background: Color(0xFF0A0A0A),
    cardColor: Color(0xFF1A1A1A),
    textColor: Colors.white,
    subtitleColor: Color(0xFFA3A3A3),
    brightness: Brightness.dark,
  ),
  AppThemeKey.light: const AppThemeData(
    name: '☀️ Aesthetic Light',
    primary: Color(0xFF059669),
    secondary: Color(0xFF0284C7),
    background: Color(0xFFF8FAFC),
    cardColor: Colors.white,
    textColor: Color(0xFF0F172A),
    subtitleColor: Color(0xFF64748B),
    brightness: Brightness.light,
  ),
};

// ============================================================================
// DATA MODELS
// ============================================================================
class CustomHabit {
  final String id;
  final String title;
  final String emoji;
  final String category;
  final bool isDefault;

  CustomHabit({
    required this.id,
    required this.title,
    required this.emoji,
    required this.category,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'category': category,
        'isDefault': isDefault,
      };

  factory CustomHabit.fromJson(Map<String, dynamic> json) => CustomHabit(
        id: json['id'],
        title: json['title'],
        emoji: json['emoji'],
        category: json['category'],
        isDefault: json['isDefault'] ?? false,
      );
}

class AlarmItem {
  final String id;
  final TimeOfDay time;
  final String reason;
  final bool isEnabled;

  AlarmItem({
    required this.id,
    required this.time,
    required this.reason,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': time.hour,
        'minute': time.minute,
        'reason': reason,
        'isEnabled': isEnabled,
      };

  factory AlarmItem.fromJson(Map<String, dynamic> json) => AlarmItem(
        id: json['id'],
        time: TimeOfDay(hour: json['hour'], minute: json['minute']),
        reason: json['reason'],
        isEnabled: json['isEnabled'] ?? true,
      );

  AlarmItem copyWith({bool? isEnabled, String? reason, TimeOfDay? time}) =>
      AlarmItem(
        id: id,
        time: time ?? this.time,
        reason: reason ?? this.reason,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}

// ============================================================================
// PRAYER TIMES & SUN CALCULATOR (OFFLINE ASTRONOMICAL ENGINE)
// ============================================================================
class PrayerTimesCalculator {
  static const double dhakaLat = 23.8103;
  static const double dhakaLng = 90.4125;
  static const double timezone = 6.0;

  static Map<String, DateTime> calculateForDate(DateTime date,
      {double lat = dhakaLat, double lng = dhakaLng, double tz = timezone}) {
    int dayOfYear = int.parse(DateFormat('D').format(date));
    double b = (360.0 / 365.0) * (dayOfYear - 81) * (math.pi / 180.0);
    double eot = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
    double decl = 23.45 * math.sin((360.0 / 365.0) * (dayOfYear - 81) * (math.pi / 180.0));
    double declRad = decl * (math.pi / 180.0);
    double latRad = lat * (math.pi / 180.0);

    double solarNoon = 12.0 + (4.0 * (tz * 15.0 - lng) - eot) / 60.0;

    double hourAngle(double altitudeDeg) {
      double altRad = altitudeDeg * (math.pi / 180.0);
      double cosH = (math.sin(altRad) - math.sin(latRad) * math.sin(declRad)) /
          (math.cos(latRad) * math.cos(declRad));
      cosH = cosH.clamp(-1.0, 1.0);
      return math.acos(cosH) * (180.0 / math.pi) / 15.0;
    }

    double sunriseH = hourAngle(-0.833);
    double fajrH = hourAngle(-18.0);
    double ishaH = hourAngle(-18.0);

    // Asr angle (Hanafi / 2 shadow ratio)
    double asrAltRad = math.atan(1.0 / (2.0 + math.tan((lat - decl).abs() * (math.pi / 180.0))));
    double asrH = hourAngle(asrAltRad * (180.0 / math.pi));

    DateTime toDate(double decHour) {
      int h = decHour.floor();
      int m = ((decHour - h) * 60).round();
      if (m >= 60) {
        h++;
        m = 0;
      }
      return DateTime(date.year, date.month, date.day, h, m);
    }

    return {
      'fajr': toDate(solarNoon - fajrH),
      'sunrise': toDate(solarNoon - sunriseH),
      'dhuhr': toDate(solarNoon + 0.05), // slightly after noon
      'asr': toDate(solarNoon + asrH),
      'sunset': toDate(solarNoon + sunriseH), // sunset equals maghrib
      'maghrib': toDate(solarNoon + sunriseH),
      'isha': toDate(solarNoon + ishaH),
    };
  }
}

// ============================================================================
// MAIN APPLICATION
// ============================================================================
class HabitTrackerApp extends StatefulWidget {
  const HabitTrackerApp({super.key});

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp> {
  AppThemeKey _currentThemeKey = AppThemeKey.emerald;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('selected_theme');
    if (savedKey != null) {
      final match = AppThemeKey.values.firstWhere(
        (e) => e.name == savedKey,
        orElse: () => AppThemeKey.emerald,
      );
      setState(() => _currentThemeKey = match);
    }
  }

  Future<void> _changeTheme(AppThemeKey newTheme) async {
    setState(() => _currentThemeKey = newTheme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', newTheme.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = appThemes[_currentThemeKey]!;

    return MaterialApp(
      title: 'Habit Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: theme.brightness,
        scaffoldBackgroundColor: theme.background,
        primaryColor: theme.primary,
        colorScheme: ColorScheme(
          brightness: theme.brightness,
          primary: theme.primary,
          onPrimary: Colors.white,
          secondary: theme.secondary,
          onSecondary: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
          surface: theme.cardColor,
          onSurface: theme.textColor,
        ),
        cardColor: theme.cardColor,
        fontFamily: 'Roboto',
      ),
      home: MainNavigationScreen(
        currentTheme: theme,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

// ============================================================================
// NAVIGATION SCREEN
// ============================================================================
class MainNavigationScreen extends StatefulWidget {
  final AppThemeData currentTheme;
  final Function(AppThemeKey) onThemeChanged;

  const MainNavigationScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<AlarmItem> _alarms = [];
  Timer? _alarmCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    _startAlarmListener();
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_alarms');
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        setState(() {
          _alarms = list.map((e) => AlarmItem.fromJson(e)).toList();
        });
      } catch (_) {}
    } else {
      // Default initial alarms
      _alarms = [
        AlarmItem(
          id: '1',
          time: const TimeOfDay(hour: 4, minute: 45),
          reason: 'ফজরের সালাতের প্রস্তুতি ও তাহাজ্জুদ',
          isEnabled: true,
        ),
        AlarmItem(
          id: '2',
          time: const TimeOfDay(hour: 20, minute: 0),
          reason: '১ ঘণ্টার ফোকাস স্টাডি ও স্কিল ডেভেলপমেন্ট',
          isEnabled: true,
        ),
      ];
      _saveAlarms();
    }
  }

  Future<void> _saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_alarms.map((e) => e.toJson()).toList());
    await prefs.setString('saved_alarms', encoded);
  }

  void _startAlarmListener() {
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      for (final alarm in _alarms) {
        if (alarm.isEnabled &&
            alarm.time.hour == now.hour &&
            alarm.time.minute == now.minute &&
            now.second < 20) {
          _triggerAlarmDialog(alarm);
          break;
        }
      }
    });
  }

  void _triggerAlarmDialog(AlarmItem alarm) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.currentTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('⏰ ', style: TextStyle(fontSize: 28)),
            Expanded(
              child: Text(
                'অ্যালার্ম বাজছে!',
                style: TextStyle(
                  color: widget.currentTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.currentTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.currentTheme.primary.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'অ্যালার্মের উদ্দেশ্য / কারণ:',
                    style: TextStyle(fontSize: 12, color: widget.currentTheme.subtitleColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alarm.reason,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.currentTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '“সময় মূল্যবান, আপনার আজকের উদ্দেশ্যটি সফলভাবে পূরণ করুন!”',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('৫ মিনিট পরে (Snooze)', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.currentTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বন্ধ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showThemePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.currentTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'পছন্দের থিম নির্বাচন করুন',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.currentTheme.textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...AppThemeKey.values.map((key) {
              final item = appThemes[key]!;
              final isSelected = widget.currentTheme.name == item.name;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? item.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? item.primary : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.primary,
                    radius: 12,
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: widget.currentTheme.textColor,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: item.primary)
                      : null,
                  onTap: () {
                    widget.onThemeChanged(key);
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayHabitScreen(theme: widget.currentTheme),
      PrayerAndAlarmScreen(
        theme: widget.currentTheme,
        alarms: _alarms,
        onAlarmsChanged: (newAlarms) {
          setState(() => _alarms = newAlarms);
          _saveAlarms();
        },
      ),
      FocusStopwatchScreen(theme: widget.currentTheme),
      StatsHistoryScreen(theme: widget.currentTheme),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.currentTheme.cardColor,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Habit Oasis 🎯',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: widget.currentTheme.textColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'থিম পরিবর্তন',
            icon: Icon(Icons.palette_outlined, color: widget.currentTheme.primary),
            onPressed: _showThemePickerModal,
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: widget.currentTheme.cardColor,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: widget.currentTheme.primary,
          unselectedItemColor: widget.currentTheme.subtitleColor,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.location_city_outlined),
              activeIcon: Icon(Icons.location_city),
              label: 'রুটিন ও শহর',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mosque_outlined),
              activeIcon: Icon(Icons.mosque),
              label: 'নামাজ ও অ্যালার্ম',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'টাইমার',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'পরিসংখ্যান',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 1: TODAY'S HABITS + THE LIVING CITY GAMIFICATION
// ============================================================================
class TodayHabitScreen extends StatefulWidget {
  final AppThemeData theme;
  const TodayHabitScreen({super.key, required this.theme});

  @override
  State<TodayHabitScreen> createState() => _TodayHabitScreenState();
}

class _TodayHabitScreenState extends State<TodayHabitScreen> {
  List<CustomHabit> _habits = [];
  Map<String, bool> _completed = {};
  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadHabitsAndState();
  }

  Future<void> _loadHabitsAndState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHabits = prefs.getString('custom_habits_v2');

    if (rawHabits != null) {
      try {
        final List list = jsonDecode(rawHabits);
        _habits = list.map((e) => CustomHabit.fromJson(e)).toList();
      } catch (_) {}
    }

    if (_habits.isEmpty) {
      _habits = [
        CustomHabit(id: 'fajr', title: '১. ফজরের নামাজ (ভোর)', emoji: '🌅', category: 'ইবাদত', isDefault: true),
        CustomHabit(id: 'dhuhr', title: '২. যোহরের নামাজ (দুপুর)', emoji: '☀️', category: 'ইবাদত', isDefault: true),
        CustomHabit(id: 'asr', title: '৩. আসরের নামাজ (বিকাল)', emoji: '🌤️', category: 'ইবাদত', isDefault: true),
        CustomHabit(id: 'maghrib', title: '৪. মাগরিবের নামাজ (সন্ধ্যা)', emoji: '🌇', category: 'ইবাদত', isDefault: true),
        CustomHabit(id: 'isha', title: '৫. এশার নামাজ (রাত)', emoji: '🌙', category: 'ইবাদত', isDefault: true),
        CustomHabit(id: 'study', title: '১ ঘণ্টা স্টাডি সম্পন্ন', emoji: '📖', category: 'পড়াশোনা', isDefault: true),
        CustomHabit(id: 'exercise', title: '১০ মিনিট শরীরচর্চা ও পুশ-আপ', emoji: '💪', category: 'স্বাস্থ্য', isDefault: true),
      ];
      _saveHabitsList();
    }

    // Load checked state
    final Map<String, bool> loaded = {};
    for (final h in _habits) {
      loaded[h.id] = prefs.getBool('${todayKey}_${h.id}') ?? false;
    }

    setState(() {
      _completed = loaded;
    });
  }

  Future<void> _saveHabitsList() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_habits.map((e) => e.toJson()).toList());
    await prefs.setString('custom_habits_v2', encoded);
  }

  Future<void> _toggleHabit(String id, bool val) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${todayKey}_$id', val);
    setState(() {
      _completed[id] = val;
    });
  }

  void _showAddHabitModal() {
    final titleController = TextEditingController();
    String selectedEmoji = '🎯';
    String selectedCategory = 'ইবাদত';

    final emojis = ['🎯', '📖', '🤲', '💧', '💪', '🏃‍♂️', '🍏', '✍️', '💡', '🌙', '🕌', '📚'];
    final categories = ['ইবাদত', 'পড়াশোনা', 'স্বাস্থ্য', 'ব্যক্তিগত'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'নতুন অভ্যাস যোগ করুন ➕',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textColor,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                style: TextStyle(color: widget.theme.textColor),
                decoration: InputDecoration(
                  labelText: 'অভ্যাসের নাম লিখুন',
                  hintText: 'উদা: কুরআন তেলাওয়াত, ২ লিটার পানি পান',
                  labelStyle: TextStyle(color: widget.theme.subtitleColor),
                  hintStyle: TextStyle(color: widget.theme.subtitleColor.withOpacity(0.6)),
                  filled: true,
                  fillColor: widget.theme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.theme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('ইমোজি সিলেক্ট করুন:', style: TextStyle(fontSize: 13, color: widget.theme.subtitleColor)),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: emojis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final e = emojis[i];
                    final isSel = selectedEmoji == e;
                    return InkWell(
                      onTap: () => setModalState(() => selectedEmoji = e),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? widget.theme.primary.withOpacity(0.2) : widget.theme.background,
                          border: Border.all(
                            color: isSel ? widget.theme.primary : Colors.white.withOpacity(0.08),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text('ক্যাটাগরি:', style: TextStyle(fontSize: 13, color: widget.theme.subtitleColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: categories.map((cat) {
                  final isSel = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    selectedColor: widget.theme.primary.withOpacity(0.25),
                    labelStyle: TextStyle(
                      color: isSel ? widget.theme.primary : widget.theme.subtitleColor,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setModalState(() => selectedCategory = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      final newHabit = CustomHabit(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        emoji: selectedEmoji,
                        category: selectedCategory,
                      );
                      setState(() {
                        _habits.add(newHabit);
                        _completed[newHabit.id] = false;
                      });
                      _saveHabitsList();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('সংরক্ষণ করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteHabit(CustomHabit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.theme.cardColor,
        title: Text('অভ্যাসটি মুছে ফেলবেন?', style: TextStyle(color: widget.theme.textColor)),
        content: Text('"${habit.title}" অভ্যাসটি আপনার তালিকা থেকে মুছে ফেলা হবে।',
            style: TextStyle(color: widget.theme.subtitleColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _habits.removeWhere((h) => h.id == habit.id);
                _completed.remove(habit.id);
              });
              _saveHabitsList();
              Navigator.pop(ctx);
            },
            child: const Text('মুছে ফেলুন', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  int get completedCount => _completed.values.where((v) => v).length;
  int get totalCount => _habits.isEmpty ? 1 : _habits.length;
  double get progressRatio => (completedCount / totalCount).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final dateDisplay = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.theme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('নতুন অভ্যাস', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddHabitModal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header date
            Text(
              dateDisplay,
              style: TextStyle(fontSize: 13, color: widget.theme.subtitleColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // THE LIVING CITY - INSPIRATIONAL GAMIFICATION CANVAS
            TheLivingCityCard(
              progress: progressRatio,
              completedCount: completedCount,
              totalCount: totalCount,
              theme: widget.theme,
            ),
            const SizedBox(height: 24),

            // HABITS LIST HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'আজকের অভ্যাসের তালিকা',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: widget.theme.textColor,
                  ),
                ),
                Text(
                  '$completedCount / $totalCount সম্পন্ন',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Habit Items
            ..._habits.map((habit) {
              final isDone = _completed[habit.id] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDone ? widget.theme.primary.withOpacity(0.12) : widget.theme.cardColor,
                  border: Border.all(
                    color: isDone ? widget.theme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.theme.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(habit.emoji, style: const TextStyle(fontSize: 22))),
                  ),
                  title: Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDone ? widget.theme.primary : widget.theme.textColor,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    habit.category,
                    style: TextStyle(fontSize: 11, color: widget.theme.subtitleColor),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: isDone,
                        onChanged: (val) => _toggleHabit(habit.id, val ?? false),
                        activeColor: widget.theme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      if (!habit.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                          onPressed: () => _deleteHabit(habit),
                        ),
                    ],
                  ),
                  onTap: () => _toggleHabit(habit.id, !isDone),
                ),
              );
            }),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// THE LIVING CITY BUILDER GAMIFICATION CARD & PAINTER
// ============================================================================
class TheLivingCityCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;
  final AppThemeData theme;

  const TheLivingCityCard({
    super.key,
    required this.progress,
    required this.completedCount,
    required this.totalCount,
    required this.theme,
  });

  String get _motivationalTitle {
    if (progress == 0) return '🌱 একটি শান্ত খালি প্রান্তর...';
    if (progress < 0.3) return '🏗️ রাস্তা ও ভিত্তি তৈরি হচ্ছে!';
    if (progress < 0.6) return '🏡 বাড়ি-ঘর ও সবুজ উদ্যান গড়ে উঠছে!';
    if (progress < 0.9) return '🕌 মিনার ও আধুনিক টাওয়ার মাথা তুলছে!';
    return '🌟 মাশাআল্লাহ! আপনার শহরটি আলোয় উজ্জ্বল!';
  }

  String get _motivationalSubtitle {
    if (progress == 0) return 'প্রথম অভ্যাসটি পূরণ করুন, খালি জায়গায় শহর গড়ে তোলা শুরু হবে!';
    if (progress < 0.3) return 'দারুণ শুরু! আপনার প্রতিটি অভ্যাসের সাথে শহরটি বড় হচ্ছে।';
    if (progress < 0.6) return 'অর্ধেক পথ পার হয়েছেন, শহরের গাছপালা ও ফোয়ারা সতেজ হয়ে উঠেছে।';
    if (progress < 0.9) return 'অসাধারণ ধারাবাহিকতা! শহরের মূল আকর্ষণগুলো স্থাপিত হয়ে গেছে।';
    return 'অভিনন্দন! আজকের সব কাজ সম্পূর্ণ করে শহরটিকে সফলতায় ভরিয়ে দিয়েছেন!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canvas Area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: CityScenePainter(
                  progress: progress,
                  themePrimary: theme.primary,
                  themeSecondary: theme.secondary,
                ),
              ),
            ),
          ),

          // Details info below canvas
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _motivationalTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(progress * 100).toInt()}% শহর নির্মিত',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _motivationalSubtitle,
                  style: TextStyle(fontSize: 12.5, color: theme.subtitleColor, height: 1.3),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: theme.background,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CityScenePainter extends CustomPainter {
  final double progress;
  final Color themePrimary;
  final Color themeSecondary;

  CityScenePainter({
    required this.progress,
    required this.themePrimary,
    required this.themeSecondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sky Gradient based on progress (from barren dusk to thriving twilight city)
    final skyPaint = Paint();
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: progress >= 0.8
          ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B), const Color(0xFF312E81)]
          : progress >= 0.4
              ? [const Color(0xFF0C192E), const Color(0xFF162D4A), const Color(0xFF1E3A5F)]
              : [const Color(0xFF080D1A), const Color(0xFF111827), const Color(0xFF1F2937)],
    );
    skyPaint.shader = skyGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Stars & Moon in sky
    final starPaint = Paint()..color = Colors.white.withOpacity(0.8);
    final rng = math.Random(42);
    for (int i = 0; i < 30; i++) {
      double sx = rng.nextDouble() * w;
      double sy = rng.nextDouble() * (h * 0.55);
      double radius = (i % 3 == 0) ? 1.5 : 0.8;
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);
    }

    // Moon / Crescent
    final moonPaint = Paint()..color = const Color(0xFFFDE68A);
    canvas.drawCircle(Offset(w * 0.82, h * 0.25), 14, moonPaint);
    final moonMask = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(w * 0.86, h * 0.22), 12, moonMask);

    // 3. Ground / Distant Hills
    final hillPaint = Paint()
      ..color = progress >= 0.2 ? const Color(0xFF064E3B).withOpacity(0.7) : const Color(0xFF1E293B);
    final hillPath = Path()
      ..moveTo(0, h * 0.7)
      ..quadraticBezierTo(w * 0.25, h * 0.62, w * 0.5, h * 0.68)
      ..quadraticBezierTo(w * 0.75, h * 0.74, w, h * 0.65)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    // 4. LEVEL 1: Road & Green Meadow (progress >= 0.15)
    if (progress >= 0.15) {
      final groundPaint = Paint()..color = const Color(0xFF065F46);
      canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), groundPaint);

      // Highway / Road
      final roadPaint = Paint()..color = const Color(0xFF334155);
      final roadPath = Path()
        ..moveTo(0, h * 0.88)
        ..lineTo(w, h * 0.85)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(roadPath, roadPaint);

      // Road dashed line
      final roadDash = Paint()
        ..color = const Color(0xFFFACC15).withOpacity(0.8)
        ..strokeWidth = 2;
      for (double rx = 10; rx < w; rx += 25) {
        canvas.drawLine(Offset(rx, h * 0.93), Offset(rx + 14, h * 0.92), roadDash);
      }
    }

    // 5. LEVEL 2: Cozy Houses & Cottages (progress >= 0.3)
    if (progress >= 0.3) {
      final housePaint = Paint()..color = const Color(0xFF1E293B);
      final roofPaint = Paint()..color = const Color(0xFF991B1B);
      final windowPaint = Paint()..color = const Color(0xFFFDE047);

      void drawHouse(double x, double y, double width, double height) {
        // Body
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, width, height), const Radius.circular(4)), housePaint);
        // Roof
        final roof = Path()
          ..moveTo(x - 4, y)
          ..lineTo(x + width / 2, y - height * 0.5)
          ..lineTo(x + width + 4, y)
          ..close();
        canvas.drawPath(roof, roofPaint);
        // Window
        canvas.drawRect(
            Rect.fromLTWH(x + width * 0.25, y + height * 0.3, width * 0.5, height * 0.35), windowPaint);
      }

      drawHouse(w * 0.08, h * 0.65, 26, 20);
      drawHouse(w * 0.22, h * 0.67, 30, 22);
    }

    // 6. LEVEL 3: Trees, Gardens & Flowers (progress >= 0.45)
    if (progress >= 0.45) {
      final trunkPaint = Paint()..color = const Color(0xFF78350F);
      final foliagePaint = Paint()..color = const Color(0xFF10B981);

      void drawTree(double x, double y, double scale) {
        canvas.drawRect(Rect.fromLTWH(x - 2 * scale, y, 4 * scale, 14 * scale), trunkPaint);
        canvas.drawCircle(Offset(x, y - 4 * scale), 10 * scale, foliagePaint);
        canvas.drawCircle(Offset(x - 6 * scale, y), 8 * scale, foliagePaint);
        canvas.drawCircle(Offset(x + 6 * scale, y), 8 * scale, foliagePaint);
      }

      drawTree(w * 0.04, h * 0.72, 1.0);
      drawTree(w * 0.18, h * 0.74, 1.2);
      drawTree(w * 0.34, h * 0.73, 0.9);
      drawTree(w * 0.92, h * 0.75, 1.1);
    }

    // 7. LEVEL 4: Modern Skyline Towers & City Buildings (progress >= 0.6)
    if (progress >= 0.6) {
      final bldgPaint = Paint()..color = const Color(0xFF0F172A);
      final glassPaint = Paint()..color = const Color(0xFF38BDF8).withOpacity(0.85);

      void drawTower(double x, double width, double height) {
        final bRect = Rect.fromLTWH(x, h * 0.72 - height, width, height);
        canvas.drawRect(bRect, bldgPaint);

        // Windows grid
        for (double wy = bRect.top + 6; wy < bRect.bottom - 8; wy += 9) {
          for (double wx = bRect.left + 5; wx < bRect.right - 5; wx += 8) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 5), glassPaint);
          }
        }
      }

      drawTower(w * 0.38, 38, 65);
      drawTower(w * 0.78, 32, 55);
      drawTower(w * 0.88, 30, 72);
    }

    // 8. LEVEL 5: Grand Landmark - Islamic Mosque with Minaret & Dome (progress >= 0.75)
    if (progress >= 0.75) {
      final mosqueX = w * 0.52;
      final mosqueY = h * 0.48;
      final mosqueBase = Paint()..color = const Color(0xFF042F2E);
      final domeGold = Paint()..color = const Color(0xFFF59E0B);
      final minaretPaint = Paint()..color = const Color(0xFF0D9488);

      // Main Hall
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(mosqueX, mosqueY + 16, 54, 34), const Radius.circular(5)),
          mosqueBase);

      // Main Dome
      final domePath = Path()
        ..moveTo(mosqueX + 8, mosqueY + 16)
        ..quadraticBezierTo(mosqueX + 27, mosqueY - 6, mosqueX + 46, mosqueY + 16)
        ..close();
      canvas.drawPath(domePath, domeGold);

      // Crescent on top of dome
      canvas.drawCircle(Offset(mosqueX + 27, mosqueY - 8), 3, domeGold);

      // Left Minaret
      final minaretLeft = Path()
        ..moveTo(mosqueX - 8, mosqueY + 50)
        ..lineTo(mosqueX - 8, mosqueY + 2)
        ..lineTo(mosqueX - 5, mosqueY - 12)
        ..lineTo(mosqueX - 2, mosqueY + 2)
        ..lineTo(mosqueX - 2, mosqueY + 50)
        ..close();
      canvas.drawPath(minaretLeft, minaretPaint);

      // Right Minaret
      final minaretRight = Path()
        ..moveTo(mosqueX + 56, mosqueY + 50)
        ..lineTo(mosqueX + 56, mosqueY + 2)
        ..lineTo(mosqueX + 59, mosqueY - 12)
        ..lineTo(mosqueX + 62, mosqueY + 2)
        ..lineTo(mosqueX + 62, mosqueY + 50)
        ..close();
      canvas.drawPath(minaretRight, minaretPaint);

      // Arch door
      final doorPath = Path()
        ..moveTo(mosqueX + 20, mosqueY + 50)
        ..lineTo(mosqueX + 20, mosqueY + 32)
        ..quadraticBezierTo(mosqueX + 27, mosqueY + 24, mosqueX + 34, mosqueY + 32)
        ..lineTo(mosqueX + 34, mosqueY + 50)
        ..close();
      canvas.drawPath(doorPath, domeGold);
    }

    // 9. LEVEL 6 & 7: Cars, Street Lights, Hot Air Balloon & Fireworks (progress >= 0.9)
    if (progress >= 0.9) {
      // Hot Air Balloon in Sky
      final balloonPaint = Paint()..color = const Color(0xFFEC4899);
      canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.18, 18, 22), balloonPaint);
      final basketPaint = Paint()..color = const Color(0xFF78350F);
      canvas.drawRect(Rect.fromLTWH(w * 0.12 + 6, h * 0.18 + 24, 6, 5), basketPaint);

      // Moving Car on Road
      final carPaint = Paint()..color = const Color(0xFFEF4444);
      final carBody = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.65, h * 0.88, 28, 10), const Radius.circular(3));
      canvas.drawRRect(carBody, carPaint);
      final wheelPaint = Paint()..color = Colors.black;
      canvas.drawCircle(Offset(w * 0.65 + 6, h * 0.88 + 10), 3, wheelPaint);
      canvas.drawCircle(Offset(w * 0.65 + 22, h * 0.88 + 10), 3, wheelPaint);

      // Fireworks Burst (100% celebration)
      if (progress >= 1.0) {
        final fwCenter = Offset(w * 0.45, h * 0.22);
        final fwColors = [
          const Color(0xFFF59E0B),
          const Color(0xFF10B981),
          const Color(0xFF38BDF8),
          const Color(0xFFEC4899),
        ];

        for (int i = 0; i < 16; i++) {
          double angle = (i * 22.5) * (math.pi / 180.0);
          double dist = 18.0;
          final p = Offset(fwCenter.dx + math.cos(angle) * dist, fwCenter.dy + math.sin(angle) * dist);
          final pPaint = Paint()
            ..color = fwColors[i % fwColors.length]
            ..strokeWidth = 2.2;
          canvas.drawLine(fwCenter, p, pPaint);
          canvas.drawCircle(p, 1.8, pPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CityScenePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.themePrimary != themePrimary;
}

// ============================================================================
// SCREEN 2: PRAYER TIMES + LABELED ALARM MANAGER
// ============================================================================
class PrayerAndAlarmScreen extends StatefulWidget {
  final AppThemeData theme;
  final List<AlarmItem> alarms;
  final Function(List<AlarmItem>) onAlarmsChanged;

  const PrayerAndAlarmScreen({
    super.key,
    required this.theme,
    required this.alarms,
    required this.onAlarmsChanged,
  });

  @override
  State<PrayerAndAlarmScreen> createState() => _PrayerAndAlarmScreenState();
}

class _PrayerAndAlarmScreenState extends State<PrayerAndAlarmScreen> {
  late Map<String, DateTime> _prayerTimes;

  @override
  void initState() {
    super.initState();
    _prayerTimes = PrayerTimesCalculator.calculateForDate(DateTime.now());
  }

  void _showAddAlarmDialog() {
    TimeOfDay selectedTime = TimeOfDay.now();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: widget.theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'নতুন অ্যালার্ম যোগ করুন ⏰',
            style: TextStyle(fontWeight: FontWeight.bold, color: widget.theme.textColor, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Selector Button
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setDialogState(() => selectedTime = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: widget.theme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.theme.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'সময় নির্বাচন করুন:',
                        style: TextStyle(color: widget.theme.subtitleColor, fontSize: 13),
                      ),
                      Text(
                        selectedTime.format(context),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.theme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reason / Label input
              Text(
                'আমি কেন অ্যালার্ম দিয়েছি (উদ্দেশ্য):',
                style: TextStyle(fontSize: 13, color: widget.theme.subtitleColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                style: TextStyle(color: widget.theme.textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'উদা: ফজরের জামাতে যাওয়া, ইংরেজি পড়ার সময়',
                  hintStyle: TextStyle(color: widget.theme.subtitleColor.withOpacity(0.6), fontSize: 12),
                  filled: true,
                  fillColor: widget.theme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: widget.theme.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.theme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isNotEmpty) {
                  final newAlarm = AlarmItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    time: selectedTime,
                    reason: reason,
                  );
                  final updated = List<AlarmItem>.from(widget.alarms)..add(newAlarm);
                  widget.onAlarmsChanged(updated);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('সেট করুন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteAlarm(String id) {
    final updated = widget.alarms.where((a) => a.id != id).toList();
    widget.onAlarmsChanged(updated);
  }

  void _toggleAlarm(String id, bool val) {
    final updated = widget.alarms.map((a) => a.id == id ? a.copyWith(isEnabled: val) : a).toList();
    widget.onAlarmsChanged(updated);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final sunrise = _prayerTimes['sunrise'];
    final sunset = _prayerTimes['sunset'];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SUNRISE & SUNSET BANNER
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB45309).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('☀️', style: TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('আজকের সূর্যোদয়', style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 12)),
                              Text(_formatDateTime(sunrise),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      Container(height: 36, width: 1, color: Colors.white.withOpacity(0.2)),
                      Row(
                        children: [
                          const Text('🌇', style: TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('আজকের সূর্যাস্ত', style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 12)),
                              Text(_formatDateTime(sunset),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PRAYER TIMES LIST
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🕌 নামাজের সঠিক সময়সূচি',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: widget.theme.textColor),
                ),
                Text('অফলাইন ক্যালকুলেশন',
                    style: TextStyle(fontSize: 11, color: widget.theme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),

            _buildPrayerRow('১. ফজরের নামাজ', '🌅', _prayerTimes['fajr']),
            _buildPrayerRow('২. যোহরের নামাজ', '☀️', _prayerTimes['dhuhr']),
            _buildPrayerRow('৩. আসরের নামাজ', '🌤️', _prayerTimes['asr']),
            _buildPrayerRow('৪. মাগরিবের নামাজ', '🌇', _prayerTimes['maghrib']),
            _buildPrayerRow('৫. এশার নামাজ', '🌙', _prayerTimes['isha']),

            const SizedBox(height: 30),

            // ALARM SECTION HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⏰ উদ্দেশ্যযুক্ত কাস্টম অ্যালার্ম',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: widget.theme.textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'অ্যালার্মে লেখা থাকবে কেন অ্যালার্ম দেওয়া হয়েছে',
                      style: TextStyle(fontSize: 11.5, color: widget.theme.subtitleColor),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.alarm_add, color: Colors.white, size: 18),
                  label: const Text('যোগ করুন', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: _showAddAlarmDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Alarms list
            if (widget.alarms.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Center(
                  child: Text(
                    'কোনো অ্যালার্ম সেট করা নেই। ওপরের "যোগ করুন" বাটনে ক্লিক করুন।',
                    style: TextStyle(color: widget.theme.subtitleColor, fontSize: 13),
                  ),
                ),
              )
            else
              ...widget.alarms.map((alarm) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: alarm.isEnabled
                        ? widget.theme.primary.withOpacity(0.08)
                        : widget.theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: alarm.isEnabled
                          ? widget.theme.primary.withOpacity(0.3)
                          : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.theme.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alarm.time.format(context),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: alarm.isEnabled ? widget.theme.primary : widget.theme.subtitleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alarm.reason,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: widget.theme.textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alarm.isEnabled ? 'অ্যালার্ম চালু আছে' : 'বন্ধ আছে',
                              style: TextStyle(
                                fontSize: 11,
                                color: alarm.isEnabled ? const Color(0xFF10B981) : widget.theme.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: alarm.isEnabled,
                        activeColor: widget.theme.primary,
                        onChanged: (val) => _toggleAlarm(alarm.id, val),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        onPressed: () => _deleteAlarm(alarm.id),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(String title, String emoji, DateTime? dt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: widget.theme.textColor, fontSize: 14)),
            ],
          ),
          Text(
            _formatDateTime(dt),
            style: TextStyle(fontWeight: FontWeight.bold, color: widget.theme.primary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 3: CUSTOM STOPWATCH & FLEXIBLE FOCUS TIMER
// ============================================================================
class FocusStopwatchScreen extends StatefulWidget {
  final AppThemeData theme;
  const FocusStopwatchScreen({super.key, required this.theme});

  @override
  State<FocusStopwatchScreen> createState() => _FocusStopwatchScreenState();
}

class _FocusStopwatchScreenState extends State<FocusStopwatchScreen> {
  int _tabIndex = 0; // 0 = Focus Timer, 1 = Stopwatch

  // Timer Variables
  int _selectedMinutes = 25;
  int _timerSeconds = 25 * 60;
  Timer? _countdownTimer;
  bool _isTimerRunning = false;

  // Stopwatch Variables
  int _stopwatchMilliseconds = 0;
  Timer? _stopwatchTimer;
  bool _isStopwatchRunning = false;
  final List<String> _laps = [];

  void _setTimerDuration(int minutes) {
    _countdownTimer?.cancel();
    setState(() {
      _selectedMinutes = minutes;
      _timerSeconds = minutes * 60;
      _isTimerRunning = false;
    });
  }

  void _toggleCountdown() {
    if (_isTimerRunning) {
      _countdownTimer?.cancel();
      setState(() => _isTimerRunning = false);
    } else {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_timerSeconds > 0) {
          setState(() => _timerSeconds--);
        } else {
          timer.cancel();
          setState(() => _isTimerRunning = false);
          _showDoneDialog('টাইমার শেষ!', 'মাশাআল্লাহ! আপনার $_selectedMinutes মিনিটের সেশন সম্পন্ন হয়েছে!');
        }
      });
      setState(() => _isTimerRunning = true);
    }
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _timerSeconds = _selectedMinutes * 60;
      _isTimerRunning = false;
    });
  }

  void _toggleStopwatch() {
    if (_isStopwatchRunning) {
      _stopwatchTimer?.cancel();
      setState(() => _isStopwatchRunning = false);
    } else {
      _stopwatchTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() => _stopwatchMilliseconds += 100);
      });
      setState(() => _isStopwatchRunning = true);
    }
  }

  void _resetStopwatch() {
    _stopwatchTimer?.cancel();
    setState(() {
      _stopwatchMilliseconds = 0;
      _isStopwatchRunning = false;
      _laps.clear();
    });
  }

  void _addLap() {
    if (_isStopwatchRunning) {
      setState(() {
        _laps.insert(0, _formatStopwatch(_stopwatchMilliseconds));
      });
    }
  }

  void _showDoneDialog(String title, String message) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.theme.cardColor,
        title: Text(title, style: TextStyle(color: widget.theme.primary, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: widget.theme.textColor)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('আলহামদুলিল্লাহ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTimer(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatStopwatch(int ms) {
    final totalSecs = ms ~/ 1000;
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    final f = (ms % 1000) ~/ 100;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$f';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Switcher Tabs: Timer vs Stopwatch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: widget.theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tabIndex = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0 ? widget.theme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '⏱️ ফোকাস টাইমার',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _tabIndex == 0 ? Colors.white : widget.theme.subtitleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tabIndex = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tabIndex == 1 ? widget.theme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '⏳ স্টপওয়াচ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _tabIndex == 1 ? Colors.white : widget.theme.subtitleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_tabIndex == 0) ...[
              // PRESET CHIPS
              Wrap(
                spacing: 8,
                children: [10, 15, 25, 45, 60].map((mins) {
                  final isSel = _selectedMinutes == mins;
                  return ChoiceChip(
                    label: Text('$mins মিনিট'),
                    selected: isSel,
                    selectedColor: widget.theme.primary,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : widget.theme.subtitleColor,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => _setTimerDuration(mins),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),

              // CIRCULAR TIMER DISPLAY
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: _timerSeconds / (_selectedMinutes * 60.0),
                      strokeWidth: 10,
                      backgroundColor: widget.theme.cardColor,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.theme.primary),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimer(_timerSeconds),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: widget.theme.textColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isTimerRunning ? 'মনোযোগ দিয়ে চালিয়ে যান' : 'শুরু করতে ট্যাপ করুন',
                        style: TextStyle(fontSize: 12, color: widget.theme.subtitleColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // CONTROLS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTimerRunning ? Colors.redAccent : widget.theme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    label: Text(
                      _isTimerRunning ? 'পজ করুন' : 'শুরু করুন',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    onPressed: _toggleCountdown,
                  ),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('রিসেট'),
                    onPressed: _resetCountdown,
                  ),
                ],
              ),
            ] else ...[
              // STOPWATCH VIEW
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: widget.theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatStopwatch(_stopwatchMilliseconds),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: widget.theme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isStopwatchRunning ? Colors.redAccent : widget.theme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(_isStopwatchRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          label: Text(_isStopwatchRunning ? 'থামান' : 'স্টার্ট',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _toggleStopwatch,
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _addLap,
                          child: const Text('ল্যাপ (Lap)'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _resetStopwatch,
                          child: const Text('রিসেট'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // LAPS LIST
              if (_laps.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ল্যাপ রেকর্ডসমূহ (${_laps.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, color: widget.theme.textColor, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                ..._laps.asMap().entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.theme.cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ল্যাপ ${_laps.length - entry.key}',
                            style: TextStyle(color: widget.theme.subtitleColor, fontSize: 13)),
                        Text(entry.value,
                            style: TextStyle(fontWeight: FontWeight.bold, color: widget.theme.primary, fontSize: 14)),
                      ],
                    ),
                  );
                }),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 4: STATS & STREAK SCREEN
// ============================================================================
class StatsHistoryScreen extends StatelessWidget {
  final AppThemeData theme;
  const StatsHistoryScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Streak card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Text('🔥', style: TextStyle(fontSize: 42)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('বর্তমান ধারাবাহিকতা (Streak)', style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 13)),
                        SizedBox(height: 2),
                        Text('ধারাবাহিক থাকুন প্রতিদিন', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('প্রতিদিনের অভ্যাসই গড়ে তোলে সফল একটি জীবন।', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Motivation Quotes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 হাদিস ও জীবনের দিশা', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF60A5FA), fontSize: 15)),
                  SizedBox(height: 8),
                  Text(
                    '“আল্লাহর নিকট সর্বাধিক প্রিয় আমল তা-ই, যা নিয়মিত করা হয়—যদিও তা অল্প হয়।”\n— সহীহ বুখারী',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // City explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🏙️ শহর গড়ার নিয়মাবলি', style: TextStyle(fontWeight: FontWeight.bold, color: theme.primary, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    '• প্রতিটি কাজে টিক দেওয়ার সাথে সাথে আপনার স্ক্রিনে খালি জায়গাটি জীবন্ত শহরে রূপ নেবে।\n• ১০০% কাজ সম্পন্ন হলে রাতে আতশবাজি ও আলোয় পুরো শহর উদ্ভাসিত হবে!\n• এই অনুপ্রেরণাকে কাজে লাগিয়ে প্রতিদিনের রুটিন বজায় রাখুন।',
                    style: TextStyle(color: theme.subtitleColor, fontSize: 12.5, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
