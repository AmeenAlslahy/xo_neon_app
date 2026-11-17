import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../domain/xo_engine.dart';
import 'animated_cell_mark.dart';

/// Interactive cell representing a single grid square.
/// Includes accessible semantics, small-cell glow suppression (<40dp), and clean hover state.
class CellWidget extends StatefulWidget {
  final Position position;
  final Player? player;
  final bool isWinningCell;
  final VoidCallback? onTap;

  const CellWidget({
    super.key,
    required this.position,
    this.player,
    this.isWinningCell = false,
    this.onTap,
  });

  @override
  State<CellWidget> createState() => _CellWidgetState();
}

class _CellWidgetState extends State<CellWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    Color borderColor = NeonColors.borderSubtle;
    if (widget.isWinningCell) {
      borderColor = NeonColors.amberGold;
    } else if (widget.player == Player.x) {
      borderColor = NeonColors.cyanX.withValues(alpha: 0.5);
    } else if (widget.player == Player.o) {
      borderColor = NeonColors.magentaO.withValues(alpha: 0.5);
    } else if (_isHovered) {
      borderColor = NeonColors.cyanX.withValues(alpha: 0.8);
    }

    final r1 = widget.position.row + 1;
    final c1 = widget.position.col + 1;
    final semanticsLabel = isArabic
        ? 'الخانة: الصف $r1، العمود $c1'
        : 'Cell row $r1 column $c1';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final markSize = cellSize * 0.65;
        // Suppress glow on small cells (< 40dp) to prevent clutter on 9x9 and 11x11 boards
        final hasGlow = cellSize >= 40 || widget.isWinningCell;

        return Semantics(
          label: semanticsLabel,
          value: widget.player?.symbol ?? (isArabic ? 'فارغة' : 'Empty'),
          button: widget.player == null,
          child: GestureDetector(
            onTapDown: (_) {
              if (!reduceMotion && widget.player == null) {
                setState(() => _isHovered = true);
              }
            },
            onTapUp: (_) {
              if (!reduceMotion && mounted) {
                setState(() => _isHovered = false);
              }
            },
            onTapCancel: () {
              if (!reduceMotion && mounted) {
                setState(() => _isHovered = false);
              }
            },
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: Duration(milliseconds: reduceMotion ? 0 : 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: widget.isWinningCell
                    ? NeonColors.amberGold.withValues(alpha: 0.12)
                    : NeonColors.surfaceGlass,
                borderRadius: BorderRadius.circular(cellSize > 60 ? 14 : 8),
                border: Border.all(
                  color: borderColor,
                  width: widget.isWinningCell ? 2.0 : 1.2,
                ),
                boxShadow: widget.isWinningCell
                    ? NeonColors.glow(color: NeonColors.amberGold, blur: 12)
                    : _isHovered
                        ? NeonColors.glow(color: NeonColors.cyanX, blur: 8)
                        : null,
              ),
              child: Center(
                child: widget.player == null
                    ? const SizedBox.shrink()
                    : AnimatedCellMark(
                        key: ValueKey('mark-${widget.position.row}-${widget.position.col}-${widget.player!.symbol}'),
                        player: widget.player!,
                        size: markSize,
                        isWinning: widget.isWinningCell,
                        hasGlow: hasGlow,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
