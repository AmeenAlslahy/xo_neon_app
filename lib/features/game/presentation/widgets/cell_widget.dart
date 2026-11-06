import 'package:flutter/material.dart';
import '../../../../app/theme/neon_colors.dart';
import '../../domain/xo_engine.dart';
import 'neon_o_widget.dart';
import 'neon_x_widget.dart';

/// Interactive cell representing a single grid square.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth;
        final markSize = cellSize * 0.65;

        return Semantics(
          label: 'Cell row ${widget.position.row} column ${widget.position.col}',
          value: widget.player?.symbol ?? 'Empty',
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
                    : widget.player == Player.x
                        ? NeonXWidget(
                            size: markSize,
                            isWinning: widget.isWinningCell,
                          )
                        : NeonOWidget(
                            size: markSize,
                            isWinning: widget.isWinningCell,
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}

