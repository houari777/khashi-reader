// قارئ النصوص الخاشع: نسخة فلاتر عصرية.
// الحزم: flutter pub add flutter_tts google_fonts

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

const _primary = Color(0xFF0F766E);
const _deep = Color(0xFF042F2E);
const _soft = Color(0xFFF1F5F9);
const _text = Color(0xFF1E293B);
const _textLight = Color(0xFF64748B);
const _red = Color(0xFFEF4444);

// التشكيل: الأول يشمل الشدّة والسكون، والثاني بلا شدّة
const _marks = r'[\u064B-\u0652\u0670]*';
const _mk = r'[\u064B-\u0650\u0652\u0670]*';
const _stop = r'[\u0621-\u064A\u064B-\u0652\u0670]';

/// يجهّز النص للقراءة بجعل الشدّة صريحة، فينطق المحرّك الحرف المشدّد مرتين.
String prepareArabic(String input) {
  var t = input.replaceAll('\u0671', '\u0627'); // ألف الوصل ← ألف
  // لفظ الجلالة (الله، اللَّهِ، اللَّهُمَّ ...): لام مضاعفة صريحة + ألف المدّ
  t = t.replaceAllMapped(
    RegExp('\u0627$_marks\u0644$_marks\u0644$_marks\u0647($_marks)'
        '(?:(?!$_stop)|(?=\u0645))'),
    (m) => '\u0627\u0644\u0652\u0644\u064E\u0627\u0647${m[1]}',
  );
  // أي حرف مشدّد ← الحرف + سكون + الحرف (إلا بعد "ال" التعريف فيتولاه المحرّك)
  t = t.replaceAllMapped(
    RegExp('(?<!\u0627\u0644[\u064B-\u0652]*)([\u0621-\u064A])($_mk)\u0651($_mk)'),
    (m) => '${m[1]}\u0652${m[1]}${m[2]}${m[3]}',
  );
  return t;
}

void main() => runApp(const KhashiApp());

class KhashiApp extends StatelessWidget {
  const KhashiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'قارئ النصوص الخاشع',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _primary)
            .copyWith(primary: _primary, onSurface: _text),
        textTheme: GoogleFonts.tajawalTextTheme()
            .apply(bodyColor: _text, displayColor: _text),
        sliderTheme: const SliderThemeData(
          trackHeight: 4,
          activeTrackColor: _primary,
          inactiveTrackColor: Color(0xFFCBD5E1),
          thumbColor: _primary,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
        ),
      ),
      // الواجهة من اليمين إلى اليسار
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const ReaderPage(),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _input =
      TextEditingController(text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ');
  late final AnimationController _wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  Map<String, String>? _arabicVoice;
  double _rate = 0.4;
  double _pitch = 0.8;
  bool _quiet = false; // قراءة سرّية
  bool _shadda = true; // تفخيم الشدّة
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tts.stop();
    _wave.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((_) => _setSpeaking(false));

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // يسمح بسماع الصوت حتى لو كان زر الصامت مفعّلًا
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, []);
    }

    // نختار أول صوت عربي متوفر على الهاتف
    final raw = await _tts.getVoices;
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          final voice = v.map((k, val) => MapEntry('$k', '$val'));
          if ((voice['locale'] ?? '').toLowerCase().startsWith('ar')) {
            _arabicVoice = voice;
            break;
          }
        }
      }
    }
  }

  void _setSpeaking(bool value) {
    if (!mounted) return;
    setState(() => _speaking = value);
    if (value) {
      _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  Future<void> _setPreset(String text) async {
    _input.text = text;
    if (_speaking) {
      await _tts.stop();
      _setSpeaking(false);
    }
  }

  Future<void> _toggle() async {
    if (_speaking) {
      await _tts.stop();
      _setSpeaking(false);
      return;
    }
    if (_input.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اكتب نصًا أولًا')));
      return;
    }
    final spoken = _shadda ? prepareArabic(_input.text) : _input.text;
    await _tts.setLanguage('ar-SA');
    final voice = _arabicVoice;
    if (voice != null) await _tts.setVoice(voice);
    await _tts.setVolume(_quiet ? 0.25 : 1.0); // السرّية: صوت خفيض
    await _tts.setSpeechRate(_rate * 0.5); // في flutter_tts: 0.5 = سرعة عادية
    await _tts.setPitch(_pitch);
    await _tts.speak(spoken);
  }

  Widget _chip(String label, String text) {
    return Material(
      color: _soft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        splashColor: _primary.withAlpha(50),
        onTap: () => _setPreset(text),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: const TextStyle(fontSize: 13.5)),
        ),
      ),
    );
  }

  Widget _control(String label, double value, double min, double max,
      int divisions, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                    color: _primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _mainButton() {
    final color = _speaking ? _red : _primary;
    return Semantics(
      button: true,
      label: _speaking ? 'إيقاف' : 'تشغيل',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(90),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggle,
            child: Center(
              child: Icon(
                _speaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(36),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        const Text(
          'قارئ النصوص الخاشع',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'قراءة بالتشكيل الكامل وبنبرة هادئة',
          style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(190)),
        ),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 20)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _primary,
                selectedForegroundColor: Colors.white,
              ),
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.volume_up_rounded),
                    label: Text('جهرية')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.volume_down_rounded),
                    label: Text('سرّية')),
              ],
              selected: {_quiet},
              onSelectionChanged: (s) => setState(() => _quiet = s.first),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('بِسْمِ اللَّهِ', 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
              _chip('التعوذ', 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ'),
              _chip('الفاتحة', 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ'),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _input,
            minLines: 5,
            maxLines: 8,
            maxLength: 3900, // أندرويد لا يقبل أكثر من ~4000 حرف في المرة
            buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            style: GoogleFonts.amiri(fontSize: 21, height: 1.9, color: _text),
            decoration: InputDecoration(
              hintText: 'اكتب أو الصق النص المشكول هنا...',
              hintStyle:
                  GoogleFonts.amiri(fontSize: 19, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: _soft,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _control('السرعة', _rate, 0.2, 1.0, 8,
              (v) => setState(() => _rate = v)),
          _control('حدة الصوت', _pitch, 0.5, 1.5, 10,
              (v) => setState(() => _pitch = v)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _shadda,
            onChanged: (v) => setState(() => _shadda = v),
            title: const Text('تفخيم الشدّة',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text(
              'يُنطق الحرف المشدّد مضاعفًا، مثل: اللَّه',
              style: TextStyle(fontSize: 12.5, color: _textLight),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _mainButton()),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _speaking
                  ? 'جارٍ القراءة…'
                  : (_quiet ? 'قراءة سرّية' : 'قراءة جهرية'),
              style: const TextStyle(fontSize: 13, color: _textLight),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: _Wave(controller: _wave, active: _speaking)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_deep, _primary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    _card(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// خمسة أشرطة تتحرك أثناء القراءة (دورة 1.2 ثانية، تأخير 0.1 ثانية بين شريط وآخر)
class _Wave extends StatelessWidget {
  const _Wave({required this.controller, required this.active});

  final Animation<double> controller;
  final bool active;

  static const _delays = [0.0, 0.1, 0.2, 0.3, 0.4];

  double _barHeight(int i) {
    final t = (controller.value - _delays[i] / 1.2) % 1.0;
    final tri = t < 0.5 ? t * 2 : (1 - t) * 2;
    return 10 + 18 * Curves.easeInOut.transform(tri);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: 30,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _delays.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 4,
                  height: _barHeight(i),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
