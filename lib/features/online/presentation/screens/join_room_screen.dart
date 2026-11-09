import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../core/widgets/neon_card.dart';
import '../../application/auth_service.dart';
import '../../application/room_service.dart';
import '../../domain/models/room_code.dart';
import 'room_lobby_screen.dart';

/// Screen allowing a guest player to enter a 6-character code and join a room.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      final normalized = RoomCode.normalize(text);
      if (normalized.length <= RoomCode.codeLength) {
        _codeController.text = normalized;
        setState(() => _errorMessage = null);
      }
    }
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    final strings = ref.read(stringsProvider);

    if (!RoomCode.isValid(code)) {
      setState(() => _errorMessage = strings.invalidRoomCode);
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.ensureSignedIn();
      final uid = user?.uid ?? auth.currentUid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';

      final roomService = ref.read(roomServiceProvider);
      final result = await roomService.joinRoom(
        rawCode: code,
        guestUid: uid,
        guestName: 'Guest ($uid)'.substring(0, 11),
      );

      if (!mounted) return;

      switch (result) {
        case JoinRoomSuccess(:final room):
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RoomLobbyScreen(
                roomCode: room.code,
                isHost: room.isHost(uid),
              ),
            ),
          );
        case JoinRoomNotFound():
          setState(() => _errorMessage = strings.roomNotFound);
        case JoinRoomAlreadyFull():
          setState(() => _errorMessage = strings.roomFull);
        case JoinRoomError(:final message):
          setState(() => _errorMessage = message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to join: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final code = _codeController.text.trim();
    final bool canJoin = RoomCode.isValid(code) && !_isJoining;

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          strings.joinRoom,
          style: const TextStyle(
            color: NeonColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: NeonColors.cyanX),
      ),
      body: Container(
        decoration: NeonColors.cyberBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instruction card
                NeonCard(
                  borderColor: NeonColors.borderSubtle,
                  hasGlow: false,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.enterRoomCode,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.joinRoomDesc,
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Code Input Field (LTR for Latin codes)
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textDirection: TextDirection.ltr,
                        maxLength: 6,
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[A-Za-z0-9]'),
                          ),
                        ],
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: strings.roomCodeHint,
                          hintStyle: TextStyle(
                            color: NeonColors.textSecondary.withValues(alpha: 0.5),
                            fontSize: 16,
                            letterSpacing: 3,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: NeonColors.surfaceElevated,
                          suffixIcon: IconButton(
                            tooltip: strings.copyCode,
                            icon: const Icon(
                              Icons.paste_rounded,
                              color: NeonColors.cyanX,
                            ),
                            onPressed: _pasteFromClipboard,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: NeonColors.borderSubtle,
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: NeonColors.cyanX,
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),

                      // Error message banner
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: NeonColors.dangerRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: NeonColors.dangerRed,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: NeonColors.dangerRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: NeonColors.dangerRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Join Button (Disabled/neutral until valid 6-char code entered, cyan solid when active)
                NeonButton(
                  label: _isJoining ? strings.connectionConnecting : strings.joinButton,
                  color: NeonColors.cyanX,
                  isSolid: canJoin,
                  isDisabled: !canJoin,
                  onPressed: canJoin ? _handleJoin : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
