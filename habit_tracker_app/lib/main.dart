import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF111827),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TodayHabitScreen(),
    FocusTimerScreen(),
    StatsHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'আজকের তালিকা',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'স্টাডি ও ব্যায়াম',
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

// ----------------------------------------------------
// SCREEN 1: TODAY'S HABIT SCREEN
// ----------------------------------------------------
class TodayHabitScreen extends StatefulWidget {
  const TodayHabitScreen({super.key});

  @override
  State<TodayHabitScreen> createState() => _TodayHabitScreenState();
}

class _TodayHabitScreenState extends State<TodayHabitScreen> {
  bool fajr = false;
  bool dhuhr = false;
  bool asr = false;
  bool maghrib = false;
  bool isha = false;
  bool study = false;
  bool exercise = false;

  final TextEditingController _studyNoteController = TextEditingController();
  final TextEditingController _exerciseNoteController = TextEditingController();

  String get todayDateStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fajr = prefs.getBool('${todayDateStr}_fajr') ?? false;
      dhuhr = prefs.getBool('${todayDateStr}_dhuhr') ?? false;
      asr = prefs.getBool('${todayDateStr}_asr') ?? false;
      maghrib = prefs.getBool('${todayDateStr}_maghrib') ?? false;
      isha = prefs.getBool('${todayDateStr}_isha') ?? false;
      study = prefs.getBool('${todayDateStr}_study') ?? false;
      exercise = prefs.getBool('${todayDateStr}_exercise') ?? false;
      _studyNoteController.text = prefs.getString('${todayDateStr}_study_note') ?? '';
      _exerciseNoteController.text = prefs.getString('${todayDateStr}_exercise_note') ?? '';
    });
  }

  Future<void> _saveHabit(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${todayDateStr}_$key', value);
  }

  Future<void> _saveNote(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${todayDateStr}_$key', value);
  }

  int get completedCount {
    int count = 0;
    if (fajr) count++;
    if (dhuhr) count++;
    if (asr) count++;
    if (maghrib) count++;
    if (isha) count++;
    if (study) count++;
    if (exercise) count++;
    return count;
  }

  double get completionRate => completedCount / 7.0;

  @override
  Widget build(BuildContext context) {
    final dateDisplay = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Habit Tracker 🎯',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              dateDisplay,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Progress Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: completionRate,
                          strokeWidth: 7,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      Text(
                        '${(completionRate * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'আজকের অগ্রগতি',
                          style: TextStyle(fontSize: 14, color: Color(0xFFE0E7FF), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount / ৭ টি কাজ সম্পন্ন',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          completionRate == 1.0
                              ? '🌟 অসাধারণ! সব টার্গেট পূরণ হয়েছে'
                              : 'ধাপে ধাপে এগিয়ে চলুন!',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 1: 5 Daily Prayers
            const Text(
              '🕌 ৫ ওয়াক্ত নামাজ (Daily Prayers)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD)),
            ),
            const SizedBox(height: 12),
            _buildHabitItem('১. ফজরের নামাজ (ভোর)', '🌅', fajr, (val) {
              setState(() => fajr = val);
              _saveHabit('fajr', val);
            }),
            _buildHabitItem('২. যোহরের নামাজ (দুপুর)', '☀️', dhuhr, (val) {
              setState(() => dhuhr = val);
              _saveHabit('dhuhr', val);
            }),
            _buildHabitItem('৩. আসরের নামাজ (বিকাল)', '🌤️', asr, (val) {
              setState(() => asr = val);
              _saveHabit('asr', val);
            }),
            _buildHabitItem('৪. মাগরিবের নামাজ (সন্ধ্যা)', '🌇', maghrib, (val) {
              setState(() => maghrib = val);
              _saveHabit('maghrib', val);
            }),
            _buildHabitItem('৫. এশার নামাজ (রাত)', '🌙', isha, (val) {
              setState(() => isha = val);
              _saveHabit('isha', val);
            }),
            const SizedBox(height: 20),

            // SECTION 2: 1 Hour Study Time
            const Text(
              '📚 পড়াশোনা ও স্কিল (Study Time)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A)),
            ),
            const SizedBox(height: 12),
            _buildDetailedHabitItem(
              title: '১ ঘণ্টা স্টাডি সম্পন্ন',
              icon: '📖',
              accentColor: const Color(0xFFF59E0B),
              value: study,
              onChanged: (val) {
                setState(() => study = val);
                _saveHabit('study', val);
              },
              controller: _studyNoteController,
              hintText: 'আজ কী কী পড়লেন? (উদা: বই, কোডিং, ইংরেজি)',
              onNoteChanged: (text) => _saveNote('study_note', text),
            ),
            const SizedBox(height: 20),

            // SECTION 3: 10 Min Workout
            const Text(
              '🏃‍♂️ শরীরচর্চা ও ফিটনেস (Fitness)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFA7F3D0)),
            ),
            const SizedBox(height: 12),
            _buildDetailedHabitItem(
              title: '১০ মিনিট ব্যায়াম সম্পন্ন',
              icon: '💪',
              accentColor: const Color(0xFF10B981),
              value: exercise,
              onChanged: (val) {
                setState(() => exercise = val);
                _saveHabit('exercise', val);
              },
              controller: _exerciseNoteController,
              hintText: 'ব্যায়ামের বিবরণ (উদা: পুশ-আপ, স্ট্রেচিং, দ্রুত হাঁটা)',
              onNoteChanged: (text) => _saveNote('exercise_note', text),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitItem(String title, String emoji, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF111827),
        border: Border.all(
          color: value ? const Color(0xFF10B981).withOpacity(0.4) : Colors.white.withOpacity(0.06),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 22)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: value ? const Color(0xFF34D399) : Colors.white,
          ),
        ),
        trailing: Checkbox(
          value: value,
          onChanged: (val) => onChanged(val ?? false),
          activeColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }

  Widget _buildDetailedHabitItem({
    required String title,
    required String icon,
    required Color accentColor,
    required bool value,
    required Function(bool) onChanged,
    required TextEditingController controller,
    required String hintText,
    required Function(String) onNoteChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? accentColor.withOpacity(0.08) : const Color(0xFF111827),
        border: Border.all(
          color: value ? accentColor.withOpacity(0.4) : Colors.white.withOpacity(0.06),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: value ? accentColor : Colors.white,
                  ),
                ),
              ),
              Checkbox(
                value: value,
                onChanged: (val) => onChanged(val ?? false),
                activeColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onNoteChanged,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFF1E293B).withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// SCREEN 2: IN-APP STOPWATCH / FOCUS TIMERS
// ----------------------------------------------------
class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  // Study Timer (60 mins = 3600 secs)
  int _studySeconds = 3600;
  Timer? _studyTimer;
  bool _isStudyRunning = false;

  // Exercise Timer (10 mins = 600 secs)
  int _exerciseSeconds = 600;
  Timer? _exerciseTimer;
  bool _isExerciseRunning = false;

  void _toggleStudyTimer() {
    if (_isStudyRunning) {
      _studyTimer?.cancel();
      setState(() => _isStudyRunning = false);
    } else {
      _studyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_studySeconds > 0) {
          setState(() => _studySeconds--);
        } else {
          timer.cancel();
          setState(() => _isStudyRunning = false);
          _showCongratsDialog('অভিনন্দন!', '১ ঘণ্টা স্টাডি সম্পন্ন হয়েছে! মাশাআল্লাহ!');
        }
      });
      setState(() => _isStudyRunning = true);
    }
  }

  void _resetStudyTimer() {
    _studyTimer?.cancel();
    setState(() {
      _studySeconds = 3600;
      _isStudyRunning = false;
    });
  }

  void _toggleExerciseTimer() {
    if (_isExerciseRunning) {
      _exerciseTimer?.cancel();
      setState(() => _isExerciseRunning = false);
    } else {
      _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_exerciseSeconds > 0) {
          setState(() => _exerciseSeconds--);
        } else {
          timer.cancel();
          setState(() => _isExerciseRunning = false);
          _showCongratsDialog('অভিনন্দন!', '১০ মিনিটের শরীরচর্চা সম্পন্ন হয়েছে!');
        }
      });
      setState(() => _isExerciseRunning = true);
    }
  }

  void _resetExerciseTimer() {
    _exerciseTimer?.cancel();
    setState(() {
      _exerciseSeconds = 600;
      _isExerciseRunning = false;
    });
  }

  void _showCongratsDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ঠিক আছে', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    _exerciseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('⏱️ ফোকাস টাইমার', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Study 1 Hour Timer Card
            _buildTimerCard(
              title: '📚 ১ ঘণ্টা স্টাডি ফোকাস টাইমার',
              subtitle: 'কোনোরকম সোশ্যাল মিডিয়া ডিস্ট্রাকশন ছাড়া পড়ুন',
              formattedTime: _formatTime(_studySeconds),
              isRunning: _isStudyRunning,
              accentColor: const Color(0xFFF59E0B),
              progress: 1.0 - (_studySeconds / 3600.0),
              onStartPause: _toggleStudyTimer,
              onReset: _resetStudyTimer,
            ),
            const SizedBox(height: 24),

            // Exercise 10 Min Timer Card
            _buildTimerCard(
              title: '🏃‍♂️ ১০ মিনিট শরীরচর্চা টাইমার',
              subtitle: 'দ্রুত ফ্রি-হ্যান্ড, পুশ-আপ ও স্ট্রেচিং করুন',
              formattedTime: _formatTime(_exerciseSeconds),
              isRunning: _isExerciseRunning,
              accentColor: const Color(0xFF10B981),
              progress: 1.0 - (_exerciseSeconds / 600.0),
              onStartPause: _toggleExerciseTimer,
              onReset: _resetExerciseTimer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard({
    required String title,
    required String subtitle,
    required String formattedTime,
    required bool isRunning,
    required Color accentColor,
    required double progress,
    required VoidCallback onStartPause,
    required VoidCallback onReset,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onStartPause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRunning ? const Color(0xFFE11D48) : accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
                label: Text(
                  isRunning ? 'পজ করুন' : 'শুরু করুন',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white70),
                label: const Text('রিসেট', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// SCREEN 3: STATS & STREAKS
// ----------------------------------------------------
class StatsHistoryScreen extends StatelessWidget {
  const StatsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('📊 পরিসংখ্যান ও ধারাবাহিকতা', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Streak Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('🔥', style: TextStyle(fontSize: 40)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('বর্তমান স্ট্রিক (Streak)', style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 13)),
                        SizedBox(height: 2),
                        Text('ধারাবাহিকতা গড়ে তুলুন', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('প্রতিদিন ৫ ওয়াক্ত সালাত, ১ ঘণ্টা স্টাডি ও ব্যায়াম পূর্ণ করুন।', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Motivation Quotes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 হাদিস ও প্রেরণা', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF60A5FA), fontSize: 15)),
                  SizedBox(height: 8),
                  Text(
                    '“আল্লাহর নিকট সর্বাধিক প্রিয় আমল তা-ই, যা নিয়মিত করা হয়—যদিও তা অল্প হয়।”\n— সহীহ বুখারী',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📱 অফলাইন ডাটা স্টোরেজ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399), fontSize: 15)),
                  SizedBox(height: 6),
                  Text(
                    'আপনার ফোনের মেমোরিতে (SharedPreferences) প্রতিদিনের সব টিক ও নোট নিরাপদে সংরক্ষিত থাকে। নেট ছাড়াও অ্যাপটি সবসময় কাজ করবে।',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
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
