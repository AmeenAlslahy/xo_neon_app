import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../../../core/l10n/locale_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/xo_engine.dart';
import 'animated_cell_mark.dart';
import 'celebration_particles.dart';

/// Unified cyber-neon game board widget featuring a single glowing container,
/// crisp inner grid lines, accessible touch targets, and a centered glowing winning line.
///
/// Coordinate System:
/// (0, 0) corresponds strictly to the top-left cell in the logical Cartesian matrix.
/// - row indices go from 0 (top) to rows - 1 (bottom).
/// - col indices go from 0 (left) to cols - 1 (right).
/// Enforced via `Directionality(textDirection: TextDirection.ltr)` on the grid container,
/// guaranteeing that touch targets, winning line geometry, and test fixtures are 100%
/// synchronized and invariant to device text direction (RTL or LTR).
class GameGridWidget extends ConsumerStatefulWidget {
  final BoardConfig config;
  final GameBoard board;
  final WinningLine? winningLine;
  final List<WinningLine>? allWinningLines;
  final Player? winner;
  final Player currentPlayer;
  final void Function(Position position)? onCellTap;

  const GameGridWidget({
    super.key,
    required this.config,
    required this.board,
    this.winningLine,
    this.allWinningLines,
    this.winner,
    this.currentPlayer = Player.x,
    this.onCellTap,
  });

  @override
  ConsumerState<GameGridWidget> createState() => _GameGridWidgetState();
}

class _GameGridWidgetState extends ConsumerState<GameGridWidget>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late AnimationController _winAnimController;
  late Animation<double> _winProgress;
  bool _isZoomed = false;
  bool _isInteracting = false;
  DateTime _lastInteractionEndTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Bilingual labels/semantics read straight from Riverpod (no prop drilling).
  bool get _isArabic => ref.watch(localeProvider);

  @override
  void initState() {
    super.initState();
    _winAnimController = AnimationController(
      vsync: this,
      duration: AppMotion.winLine, // 420ms
    );
    _winProgress = CurvedAnimation(
      parent: _winAnimController,
      curve: AppMotion.enter,
    );

    if (widget.winningLine != null) {
      _winAnimController.forward(from: 1.0);
    }
  }

  @override
  void didUpdateWidget(covariant GameGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.winningLine != null && oldWidget.winningLine == null) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        _winAnimController.value = 1.0;
      } else {
        _winAnimController.forward(from: 0.0);
      }
    } else if (widget.winningLine == null && oldWidget.winningLine != null) {
      _winAnimController.reset();
    }
  }

  @override
  void dispose() {
    _winAnimController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _toggleZoom(double boardSize) {
    setState(() {
      if (_isZoomed) {
        _transformController.value = Matrix4.identity();
        _isZoomed = false;
      } else {
        // Zoom in 1.75x centered
        final scale = 1.75;
        final translation = -(boardSize * (scale - 1.0)) / 2;
        final matrix = Matrix4.diagonal3Values(scale, scale, 1.0);
        matrix.setTranslationRaw(translation, translation, 0.0);
        _transformController.value = matrix;
        _isZoomed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final winningPositions = <Position>{};
    if (widget.allWinningLines != null && widget.allWinningLines!.isNotEmpty) {
      for (final line in widget.allWinningLines!) {
        winningPositions.addAll(line.positions);
      }
    } else if (widget.winningLine != null) {
      winningPositions.addAll(widget.winningLine!.positions);
    }

    final isLargeGrid = widget.config.rows >= 9;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate maximum square dimension available with safety margin
        final availableSize = math.min(constraints.maxWidth, constraints.maxHeight);
        // Leave room for padding and border glow, ensuring board remains square and fits within constraints
        final boardSize = math.max(0.0, availableSize - 8.0);
        final cellSize = widget.config.rows > 0 && boardSize > 0
            ? boardSize / widget.config.rows
            : 0.0;

        final isDraw = widget.board.isFull && widget.winningLine == null;
        final Color boardBorderColor;
        if (widget.winningLine != null) {
          boardBorderColor = AppTokens.amberGold;
        } else if (isDraw) {
          boardBorderColor = AppTokens.cyan;
        } else {
          boardBorderColor = NeonColors.purpleBorder;
        }

        final boardContainer = AnimatedContainer(
          duration: AppMotion.winLine,
          width: boardSize,
          height: boardSize,
          decoration: BoxDecoration(
            color: NeonColors.boardSurface,
            borderRadius: BorderRadius.circular(widget.config.rows <= 6 ? 20 : 14),
            border: Border.all(
              color: boardBorderColor,
              width: (widget.winningLine != null || isDraw) ? 2.4 : 1.8,
            ),
            boxShadow: [
              // Purple atmospheric outer glow
              BoxShadow(
                color: NeonColors.purpleNeon.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              // Dynamic player/winner aura (Gold on win, calm cyan on draw)
              BoxShadow(
                color: widget.winningLine != null
                    ? AppTokens.amberGold.withValues(alpha: 0.35)
                    : (isDraw
                        ? AppTokens.cyan.withValues(alpha: 0.30)
                        : (widget.currentPlayer == Player.x
                            ? NeonColors.cyanGlow.withValues(alpha: 0.15)
                            : NeonColors.orangeGlow.withValues(alpha: 0.15))),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Inner Neon Grid Lines
              CustomPaint(
                painter: _GridLinesPainter(
                  rows: widget.config.rows,
                  cols: widget.config.cols,
                  cellSize: cellSize,
                ),
              ),

              // 2. Cell Touch Targets & Marks (Enforced LTR coordinate alignment)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: List.generate(widget.config.rows, (r) {
                    return Expanded(
                      child: Row(
                        children: List.generate(widget.config.cols, (c) {
                          final pos = Position(r, c);
                          final playerInCell = widget.board.cellAt(pos);
                          final isWinning = winningPositions.contains(pos);

                          return Expanded(
                            child: _buildCellItem(
                              position: pos,
                              player: playerInCell,
                              isWinning: isWinning,
                              cellSize: cellSize,
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),

              // 3. Centered Glowing Winning Laser Line (Gold)
              if (widget.winningLine != null)
                AnimatedBuilder(
                  animation: _winProgress,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WinningLinePainter(
                        winningLine: widget.winningLine!,
                        allWinningLines: widget.allWinningLines,
                        winner: widget.winner ?? Player.x,
                        cellSize: cellSize,
                        progress: _winProgress.value,
                        rows: widget.config.rows,
                      ),
                    );
                  },
                ),

              // 4. Meso Celebration Particles (Behind IgnorePointer, at line center)
              if (widget.winningLine != null) ...[
                Builder(builder: (ctx) {
                  final line = widget.winningLine!;
                  final centerOffset = Offset(
                    ((line.start.col + line.end.col) / 2.0 + 0.5) * cellSize,
                    ((line.start.row + line.end.row) / 2.0 + 0.5) * cellSize,
                  );
                  return CelebrationParticlesOverlay(origin: centerOffset);
                }),
              ],
            ],
          ),
        );

        final bool canPan = _isZoomed || _transformController.value.getMaxScaleOnAxis() > 1.01;

        final boardWidget = isLargeGrid
            ? InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 3.0,
                panEnabled: canPan,
                scaleEnabled: true,
                clipBehavior: Clip.none,
                onInteractionStart: (_) {
                  _isInteracting = true;
                },
                onInteractionEnd: (_) {
                  final currentScale = _transformController.value.getMaxScaleOnAxis();
                  setState(() {
                    _isZoomed = currentScale > 1.05;
                    _isInteracting = false;
                    _lastInteractionEndTime = DateTime.now();
                  });
                },
                child: boardContainer,
              )
            : boardContainer;

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Center(
                child: boardWidget,
              ),
            ),
            if (isLargeGrid) ...[
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: _isZoomed
                    ? (_isArabic ? 'إعادة ضبط الرؤية' : 'Reset View')
                    : (_isArabic ? 'تكبير الرقعة' : 'Tap to Zoom In'),
                child: GestureDetector(
                  onTap: () => _toggleZoom(boardSize),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTokens.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isZoomed ? AppTokens.amberGold : AppTokens.cyan,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isZoomed ? Icons.zoom_out_map : Icons.zoom_in,
                          size: 15,
                          color: _isZoomed ? AppTokens.amberGold : AppTokens.cyan,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isZoomed
                              ? (_isArabic ? 'إعادة ضبط الرؤية' : 'Reset View')
                              : (_isArabic ? 'تكبير الرقعة' : 'Tap to Zoom In'),
                          style: TextStyle(
                            color: _isZoomed ? AppTokens.amberGold : AppTokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCellItem({
    required Position position,
    required Player? player,
    required bool isWinning,
    required double cellSize,
  }) {
    // Proportional mark size based on cell dimension
    final markSize = cellSize * (widget.config.rows <= 3 ? 0.65 : 0.72);
    final row1Based = position.row + 1;
    final col1Based = position.col + 1;

    final cellSemanticLabel = _isArabic
        ? 'الخانة: الصف $row1Based، العمود $col1Based'
        : 'Cell row $row1Based column $col1Based';
    final cellValue = player?.symbol ?? (_isArabic ? 'فارغة' : 'Empty');
    final hasGlow = cellSize >= 40 || isWinning;

    return Semantics(
      label: cellSemanticLabel,
      value: cellValue,
      button: player == null,
      enabled: player == null && widget.winningLine == null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('cell-${position.row}-${position.col}'),
          onTap: (widget.winningLine == null && player == null && widget.onCellTap != null)
              ? () {
                  if (_isInteracting ||
                      DateTime.now().difference(_lastInteractionEndTime).inMilliseconds < 180) {
                    return;
                  }
                  Haptics.markPlaced();
                  widget.onCellTap!(position);
                }
              : null,
          splashColor: (widget.currentPlayer == Player.x
                  ? AppTokens.cyan
                  : AppTokens.coral)
              .withValues(alpha: 0.25),
          highlightColor: (widget.currentPlayer == Player.x
                  ? AppTokens.cyan
                  : AppTokens.coral)
              .withValues(alpha: 0.12),
          child: Container(
            color: isWinning
                ? AppTokens.amberGold.withValues(alpha: 0.14)
                : Colors.transparent,
            alignment: Alignment.center,
            child: player == null
                ? const SizedBox.shrink()
                : AnimatedCellMark(
                    key: ValueKey('grid-mark-${position.row}-${position.col}-${player.symbol}'),
                    player: player,
                    size: markSize,
                    isWinning: isWinning,
                    hasGlow: hasGlow,
                  ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering crisp inner grid lines dividing the board.
class _GridLinesPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;

  _GridLinesPainter({
    required this.rows,
    required this.cols,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Line width scales gracefully with board density
    final lineWidth = rows <= 3
        ? 2.6
        : rows <= 6
            ? 1.8
            : rows <= 9
                ? 1.3
                : 1.0;

    // Outer subtle line glow
    final glowPaint = Paint()
      ..color = NeonColors.boardGridLineGlow
      ..strokeWidth = lineWidth * 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Sharp crisp line
    final linePaint = Paint()
      ..color = NeonColors.boardGridLine
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.square;

    // Draw horizontal dividers
    for (var r = 1; r < rows; r++) {
      final y = r * cellSize;
      final p1 = Offset(0, y);
      final p2 = Offset(size.width, y);
      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, linePaint);
    }

    // Draw vertical dividers
    for (var c = 1; c < cols; c++) {
      final x = c * cellSize;
      final p1 = Offset(x, 0);
      final p2 = Offset(x, size.height);
      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.cols != cols ||
      oldDelegate.cellSize != cellSize;
}

/// CustomPainter drawing the brilliant glowing winning laser line centered exactly over winning cells.
class _WinningLinePainter extends CustomPainter {
  final WinningLine winningLine;
  final List<WinningLine>? allWinningLines;
  final Player winner;
  final double cellSize;
  final double progress;
  final int rows;

  _WinningLinePainter({
    required this.winningLine,
    this.allWinningLines,
    required this.winner,
    required this.cellSize,
    required this.progress,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ticket UX-DELIGHT-01: Winning line is Gold (#F4BD3E) + subtle halo
    const effectiveColor = AppTokens.amberGold;
    final strokeWidth = rows <= 3
        ? 8.0
        : rows <= 6
            ? 6.0
            : rows <= 9
                ? 4.5
                : 3.5;

    final linesToDraw = (allWinningLines != null && allWinningLines!.isNotEmpty)
        ? allWinningLines!
        : [winningLine];

    for (final line in linesToDraw) {
      _drawSingleWinningLine(
        canvas: canvas,
        line: line,
        color: effectiveColor,
        strokeWidth: strokeWidth,
        progress: progress,
      );
    }
  }

  void _drawSingleWinningLine({
    required Canvas canvas,
    required WinningLine line,
    required Color color,
    required double strokeWidth,
    required double progress,
  }) {
    final startPos = line.start;
    final endPos = line.end;

    // Center coordinates for start and end cells
    final startCenter = Offset(
      (startPos.col + 0.5) * cellSize,
      (startPos.row + 0.5) * cellSize,
    );
    final endCenter = Offset(
      (endPos.col + 0.5) * cellSize,
      (endPos.row + 0.5) * cellSize,
    );

    // Calculate line vector and extend slightly beyond cell centers for visual impact
    final dx = endCenter.dx - startCenter.dx;
    final dy = endCenter.dy - startCenter.dy;
    final totalDist = math.sqrt(dx * dx + dy * dy);

    if (totalDist == 0) return;

    final unitX = dx / totalDist;
    final unitY = dy / totalDist;
    final extension = cellSize * 0.32;

    final fullStart = Offset(
      startCenter.dx - unitX * extension,
      startCenter.dy - unitY * extension,
    );
    final fullEnd = Offset(
      endCenter.dx + unitX * extension,
      endCenter.dy + unitY * extension,
    );

    // Current animated end point based on progress (0.0 to 1.0)
    final currentEnd = Offset(
      fullStart.dx + (fullEnd.dx - fullStart.dx) * progress,
      fullStart.dy + (fullEnd.dy - fullStart.dy) * progress,
    );

    // 1. Wide atmospheric blur glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = strokeWidth * 2.8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawLine(fullStart, currentEnd, glowPaint);

    // 2. Focused vibrant laser beam
    final beamPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(fullStart, currentEnd, beamPaint);

    // 3. Intense pure white laser core
    final corePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth * 0.36
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(fullStart, currentEnd, corePaint);

    // 4. Glowing energy node at each winning position
    for (final pos in line.positions) {
      final posCenter = Offset(
        (pos.col + 0.5) * cellSize,
        (pos.row + 0.5) * cellSize,
      );
      final nodePaint = Paint()
        ..color = color.withValues(alpha: 0.6 * progress)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(posCenter, strokeWidth * 0.9, nodePaint);

      final nodeCore = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * progress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(posCenter, strokeWidth * 0.4, nodeCore);
    }
  }

  @override
  bool shouldRepaint(covariant _WinningLinePainter oldDelegate) =>
      oldDelegate.winningLine != winningLine ||
      oldDelegate.allWinningLines != allWinningLines ||
      oldDelegate.winner != winner ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.progress != progress;
}
