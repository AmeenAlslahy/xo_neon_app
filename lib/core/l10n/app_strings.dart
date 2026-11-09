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

  // Game mode & system opponent (P2)
  String get chooseMode => isArabic ? 'نمط اللعب' : 'Game Mode';
  String get modeLocalShort => isArabic ? 'لاعبان محليًا' : 'Two Players';
  String get modeSystem => isArabic ? 'ضد النظام' : 'vs System';
  String get systemLevelTitle => isArabic ? 'مستوى النظام' : 'System Level';
  String get difficultyEasy => isArabic ? 'سهل' : 'Easy';
  String get difficultyMedium => isArabic ? 'متوسط' : 'Medium';
  String get difficultyHard => isArabic ? 'صعب' : 'Hard';
  String get chooseYourMark => isArabic ? 'اختر علامتك' : 'Choose Your Mark';
  String get playAsX => isArabic ? 'تلعب X' : 'You play X';
  String get playAsO => isArabic ? 'تلعب O' : 'You play O';

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
  String get chessClockBadge => isArabic ? 'ساعة شطرنج' : 'Chess Clock';
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

  // Difficulty & Auto-Progression
  String get difficultyLabel => isArabic ? 'مستوى الصعوبة' : 'Difficulty Level';
  String difficultyTitle(String name) {
    switch (name.toLowerCase()) {
      case 'easy':
        return difficultyEasy;
      case 'hard':
        return difficultyHard;
      case 'expert':
        return isArabic ? 'خبير' : 'Expert';
      case 'master':
        return isArabic ? 'أستاذ' : 'Master';
      case 'medium':
      default:
        return difficultyMedium;
    }
  }
  String get autoProgression =>
      isArabic ? 'التدرج التلقائي للصعوبة' : 'Auto Difficulty Progression';
  String difficultyPromoted(String level) => isArabic
      ? 'أداء رائع! تم رفع مستوى التحدي إلى: $level'
      : 'Great performance! Challenge level increased to: $level';
  String get systemThinking => isArabic ? 'النظام يفكر...' : 'System is thinking...';
  String movesCount(int count) =>
      isArabic ? '${toArabicDigits(count)} حركات' : '$count moves';
  String winRateLabel(int percentage) =>
      isArabic ? 'نسبة الفوز: ${toArabicDigits(percentage)}%' : 'Win Rate: $percentage%';
  String get defeatEncouragement =>
      isArabic ? 'حظ أوفر! كنت قريباً من الفوز' : 'Good effort! You were close!';
  String streakWins(int count) => isArabic
      ? '${toArabicDigits(count)} انتصارات متتالية'
      : '$count win streak';

  // Online & Connection strings
  String get connectionConnected => isArabic ? 'متصل' : 'Connected';
  String get connectionConnecting =>
      isArabic ? 'جارٍ الاتصال...' : 'Connecting...';
  String get connectionDisconnected => isArabic ? 'غير متصل' : 'Disconnected';
  String get connectionReconnecting =>
      isArabic ? 'إعادة الاتصال...' : 'Reconnecting...';

  // Online Multiplayer (Phase 2)
  String get onlineLobbyTitle => isArabic ? 'اللعب أونلاين' : 'Play Online';
  String get onlineLobbySubtitle =>
      isArabic ? 'تحدَّ أصدقاءك في غرف خاصة' : 'Challenge friends in private rooms';
  String get createRoom => isArabic ? 'إنشاء غرفة' : 'Create Room';
  String get createRoomDesc => isArabic
      ? 'أنشئ غرفة وشارك الرمز مع صديقك'
      : 'Create a room and share the code';
  String get joinRoom => isArabic ? 'الانضمام إلى غرفة' : 'Join Room';
  String get joinRoomDesc => isArabic
      ? 'ادخل رمز الغرفة للانضمام إلى صديقك'
      : 'Enter a room code to join a friend';
  String get enterRoomCode => isArabic ? 'أدخل رمز الغرفة' : 'Enter Room Code';
  String get roomCodeHint => isArabic ? 'مثال: A7K9X2' : 'e.g. A7K9X2';
  String get roomCodeLabel =>
      isArabic ? 'رمز الغرفة (6 خانات)' : 'Room Code (6 chars)';
  String get joinButton => isArabic ? 'انضمام' : 'Join';
  String get createButton => isArabic ? 'إنشاء الغرفة' : 'Create Room';
  String get copyCode => isArabic ? 'نسخ الرمز' : 'Copy Code';
  String get codeCopied =>
      isArabic ? 'تم نسخ رمز الغرفة إلى الحافظة' : 'Room code copied to clipboard';
  String get waitingForPlayer =>
      isArabic ? 'بانتظار انضمام الصديق...' : 'Waiting for friend to join...';
  String get playerJoined =>
      isArabic ? 'انضم الصديق! الغرفة جاهزة' : 'Friend joined! Ready to play';
  String get host => isArabic ? 'المضيف (X)' : 'Host (X)';
  String get guest => isArabic ? 'الضيف (O)' : 'Guest (O)';
  String get you => isArabic ? 'أنت' : 'You';
  String get waitingForHost =>
      isArabic ? 'بانتظار أن يبدأ المضيف المباراة...' : 'Waiting for host to start...';
  String get roomNotFound =>
      isArabic ? 'الغرفة غير موجودة أو انتهت صلاحيتها' : 'Room not found or expired';
  String get roomFull => isArabic ? 'الغرفة ممتلئة بالفعل' : 'Room is already full';
  String get invalidRoomCode => isArabic
      ? 'رمز الغرفة غير صحيح (يجب أن يتكون من 6 خانات)'
      : 'Invalid room code (must be 6 characters)';
  String get leaveRoom => isArabic ? 'مغادرة الغرفة' : 'Leave Room';
  String get leaveRoomConfirm => isArabic
      ? 'هل أنت متأكد من مغادرة هذه الغرفة؟'
      : 'Are you sure you want to leave this room?';
  String get boardSizeLabel => isArabic ? 'حجم اللوحة' : 'Board Size';
  String get roundsToWinLabel => isArabic ? 'جولات الفوز' : 'Rounds to Win';
  String get roomStatusAbandoned =>
      isArabic ? 'تم إلغاء الغرفة من قبل المضيف' : 'Room was abandoned by host';
}
