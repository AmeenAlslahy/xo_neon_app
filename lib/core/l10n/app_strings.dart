import '../../features/game/domain/models/board_config.dart';

/// Centralized bilingual string dictionary with Arabic (primary/RTL) and English support.
class AppStrings {
  final bool isArabic;

  const AppStrings({this.isArabic = true});

  // App Header & Branding
  String get appTitle => isArabic ? 'XO نيون' : 'XO Neon';
  String get appSubtitle =>
      isArabic ? 'لعبة الإكس أو بألوان النيون العصرية' : 'Modern Cyber-Neon Tic-Tac-Toe';

  // Game Modes
  String get modeLocal => isArabic ? 'لعب محلي' : 'Local Play';
  String get modeLocalDesc =>
      isArabic ? 'لاعبان يتنافسان على نفس الهاتف' : 'Two players on the same device';

  String get modeFriend => isArabic ? 'اللعب مع صديق' : 'Play with a Friend';
  String get modeFriendDesc =>
      isArabic ? 'إنشاء غرفة ودعوة صديق برمز سري' : 'Create a room and invite a friend by code';
  String get comingSoonBadge =>
      isArabic ? 'قريباً (مرحلة الأونلاين)' : 'Coming Soon (Online Phase)';

  // Settings & Toggles
  String get settingsTitle => isArabic ? 'الإعدادات السريعة' : 'Quick Settings';
  String get reducedMotion => isArabic ? 'تقليل الحركة' : 'Reduced Motion';
  String get soundEffects => isArabic ? 'المؤثرات الصوتية' : 'Sound Effects';
  String get languageToggle => isArabic ? 'English' : 'عربي';

  static String toArabicDigits(dynamic value) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value.toString().split('').map((c) {
      final digit = int.tryParse(c);
      return digit != null ? arabicDigits[digit] : c;
    }).join();
  }

  // Match Setup
  String get setupTitle => isArabic ? 'إعداد المباراة' : 'Match Setup';
  String get chooseGrid => isArabic ? 'اختر حجم الرقعة' : 'Choose Grid Size';
  String get winCondition => isArabic ? 'شرط الفوز:' : 'Win Condition:';
  String marksInRow(int count) =>
      isArabic ? '${toArabicDigits(count)} علامات متتالية' : '$count in a row';
  String get startGame => isArabic ? 'بدء المباراة' : 'Start Match';

  // Authorized Presets
  String get preset3x3 => isArabic ? '٣×٣ (كلاسيكي)' : '3x3 (Classic)';
  String get preset6x6 => isArabic ? '٦×٦ (تكتيكي)' : '6x6 (Tactical)';
  String get preset9x9 => isArabic ? '٩×٩ (احترافي)' : '9x9 (Pro)';
  String get preset11x11 => isArabic ? '١١×١١ (أسطوري)' : '11x11 (Master)';

  String presetTitle(BoardConfig config) {
    switch (config.rows) {
      case 3:
        return preset3x3;
      case 6:
        return preset6x6;
      case 9:
        return preset9x9;
      case 11:
        return preset11x11;
      default:
        return '${config.rows}×${config.cols}';
    }
  }

  // In-Game Screen HUD & Status
  String get playerX => isArabic ? 'اللاعب X' : 'Player X';
  String get playerO => isArabic ? 'اللاعب O' : 'Player O';
  String get currentTurn => isArabic ? 'الدور الآن' : 'Turn';
  String get activeTurn => isArabic ? 'دورك الآن' : 'Your Turn';
  String get waitingTurn => isArabic ? 'في الانتظار' : 'Waiting';
  String get winnerLabel => isArabic ? 'الفائز!' : 'Winner!';
  String winnerWon(String symbol) => isArabic ? 'فاز $symbol!' : '$symbol Won!';
  String get drawStatus => isArabic ? 'تعادل!' : 'Draw!';
  String get scoreLabel => isArabic ? 'النقاط' : 'Score';

  String boardInfo(int size, int winStreak) => isArabic
      ? '${toArabicDigits(size)}×${toArabicDigits(size)} • ${toArabicDigits(winStreak)} للفوز'
      : '$size×$size • $winStreak in a row';

  String get zoomHint => isArabic ? 'اسحب للتكبير والتحريك' : 'Pinch to zoom & pan';
  String get resetGame => isArabic ? 'إعادة الجولة' : 'Replay Round';
  String get exitToHome => isArabic ? 'الرئيسية' : 'Home';
  String get viewBoard => isArabic ? 'رؤية الرقعة' : 'View Board';
  String get viewResult => isArabic ? 'عرض النتيجة' : 'View Result';

  // Exit & Replay Confirmation Dialogs
  String get exitDialogTitle => isArabic ? 'مغادرة الجولة؟' : 'Leave Round?';
  String get exitDialogMessage => isArabic
      ? 'هل أنت متأكد من العودة إلى القائمة الرئيسية؟ ستفقد التقدم في الجولة الحالية.'
      : 'Are you sure you want to return to the home screen? Current round progress will be lost.';
  String get replayConfirmTitle => isArabic ? 'إعادة تشغيل الجولة؟' : 'Restart Round?';
  String get replayConfirmMessage => isArabic
      ? 'هل أنت متأكد من إعادة تشغيل الجولة الحالية؟ ستفقد الحركات التي تم لعبها.'
      : 'Are you sure you want to restart the current round? Played moves will be lost.';
  String get cancel => isArabic ? 'متابعة اللعب' : 'Keep Playing';
  String get confirmExit => isArabic ? 'مغادرة' : 'Leave';
  String get confirmRestart => isArabic ? 'إعادة البدء' : 'Restart';

  // Result Dialog
  String get victoryTitle => isArabic ? 'فوز مستحق!' : 'Victory!';
  String winnerIs(String symbol) =>
      isArabic ? 'الفائز بالجولة هو اللاعب $symbol' : 'Round Winner is Player $symbol';
  String get drawTitle => isArabic ? 'تعادل حاسم!' : 'It\'s a Draw!';
  String get drawSubtitle =>
      isArabic ? 'امتلأت الرقعة دون تحقيق شرط الفوز' : 'The board is full without a winner';
  String get playAgain => isArabic ? 'العب مجدداً' : 'Play Again';

  // Multi-Round Match Settings & Progression
  String get chooseRounds => isArabic ? 'عدد الجولات' : 'Total Rounds';
  String get oneRound => isArabic ? 'جولة واحدة' : '1 Round';
  String get threeRounds => isArabic ? '٣ جولات (افتراضي)' : '3 Rounds (Default)';
  String get fiveRounds => isArabic ? '٥ جولات' : '5 Rounds';
  String roundsCount(int count) => isArabic ? '${toArabicDigits(count)} جولات' : '$count Rounds';
  String roundProgress(int current, int total) => isArabic
      ? 'الجولة ${toArabicDigits(current)} من ${toArabicDigits(total)}'
      : 'Round $current of $total';
  String nextRoundIn(int sec) => isArabic
      ? 'الجولة التالية خلال ${toArabicDigits(sec)} ثوانٍ...'
      : 'Next round in ${sec}s...';
  String get nextRoundNow => isArabic ? 'الجولة التالية ⏩' : 'Next Round ⏩';

  // Chess-Clock Style Timer
  String get timerOption => isArabic ? 'المؤقت (ساعة شطرنج)' : 'Timer (Chess Clock)';
  String get noTimer => isArabic ? 'بدون مؤقت' : 'No Timer';
  String get oneMinutePerPlayer => isArabic ? 'دقيقة لكل لاعب' : '1 min per player';
  String get threeMinutesPerPlayer => isArabic ? '٣ دقائق لكل لاعب' : '3 mins per player';
  String get fiveMinutesPerPlayer => isArabic ? '٥ دقائق لكل لاعب' : '5 mins per player';
  String get customTimer => isArabic ? 'وقت مخصص' : 'Custom Time';
  String customTimerBounds(int minSec, int maxSec) => isArabic
      ? 'من ${toArabicDigits(minSec)} ثانية إلى ${toArabicDigits(maxSec ~/ 60)} دقيقة'
      : 'From ${minSec}s to ${maxSec ~/ 60}m';
  String get timeWarning => isArabic ? 'الوقت ينفد!' : 'Time running low!';
  String timeoutMessage(String symbol) =>
      isArabic ? 'انتهى وقت اللاعب $symbol!' : 'Player $symbol ran out of time!';
  String get timeoutLabel => isArabic ? 'انتهاء الوقت' : 'Timeout';
  String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return isArabic ? '${toArabicDigits(mm)}:${toArabicDigits(ss)}' : '$mm:$ss';
  }

  // Pause & Resume
  String get pauseGame => isArabic ? 'إيقاف مؤقت' : 'Pause';
  String get resumeGame => isArabic ? 'استئناف اللعب' : 'Resume Play';
  String get matchPaused => isArabic ? 'المباراة متوقفة مؤقتاً' : 'Match Paused';
  String get matchPausedDesc => isArabic
      ? 'تم إيقاف المؤقت وحركات المباراة. اضغط استئناف للمتابعة.'
      : 'Timer and moves are paused. Tap resume to continue.';

  // Final Match Result Dialog
  String get finalMatchTitle => isArabic ? 'النتيجة النهائية للمباراة' : 'Final Match Result';
  String matchWinnerIs(String symbol, int scoreWinner, int scoreLoser) => isArabic
      ? 'فاز اللاعب $symbol بالمباراة (${toArabicDigits(scoreWinner)} - ${toArabicDigits(scoreLoser)})'
      : 'Player $symbol won the match ($scoreWinner - $scoreLoser)';
  String matchDrawResult(int score) => isArabic
      ? 'تعادل نهائي في المباراة (${toArabicDigits(score)} - ${toArabicDigits(score)})'
      : 'Final Match Draw ($score - $score)';
  String get roundDrawMessage => isArabic ? 'تعادل في هذه الجولة!' : 'Draw in this round!';
}
