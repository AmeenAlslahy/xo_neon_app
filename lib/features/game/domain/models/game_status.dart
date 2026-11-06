import 'player.dart';
import 'winning_line.dart';

/// Represents the exhaustive state/outcome of a game.
sealed class GameStatus {
  const GameStatus();

  bool get isTerminal => this is GameWon || this is GameDraw || this is GameTimeout;
}

/// The game is currently active and awaiting a move from [currentPlayer].
final class GameInProgress extends GameStatus {
  final Player currentPlayer;

  const GameInProgress(this.currentPlayer);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameInProgress && other.currentPlayer == currentPlayer;

  @override
  int get hashCode => currentPlayer.hashCode;

  @override
  String toString() => 'GameInProgress(turn: ${currentPlayer.symbol})';
}

/// The game has ended in victory for [winner] along [winningLine].
/// If multiple winning lines occurred simultaneously, all are stored in [allWinningLines].
final class GameWon extends GameStatus {
  final Player winner;
  final WinningLine winningLine;
  final List<WinningLine> allWinningLines;

  GameWon({
    required this.winner,
    required this.winningLine,
    List<WinningLine>? allWinningLines,
  }) : allWinningLines = List.unmodifiable(
          allWinningLines != null
              ? List<WinningLine>.from(allWinningLines)
              : [winningLine],
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameWon &&
          other.winner == winner &&
          other.winningLine == winningLine &&
          _listEquals(allWinningLines, other.allWinningLines);

  @override
  int get hashCode => Object.hash(
        winner,
        winningLine,
        Object.hashAll(allWinningLines),
      );

  @override
  String toString() =>
      'GameWon(winner: ${winner.symbol}, count: ${winningLine.length}, direction: ${winningLine.direction})';

  static bool _listEquals(List<WinningLine> a, List<WinningLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The game has ended in a draw (board is full without any player satisfying the win streak).
final class GameDraw extends GameStatus {
  const GameDraw();

  @override
  bool operator ==(Object other) => other is GameDraw;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'GameDraw()';
}

/// The game has ended due to [timedOutPlayer] running out of chess-clock time.
/// The round is awarded to the opponent ([winner]).
final class GameTimeout extends GameStatus {
  final Player timedOutPlayer;
  final Player winner;

  const GameTimeout({
    required this.timedOutPlayer,
    required this.winner,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameTimeout &&
          other.timedOutPlayer == timedOutPlayer &&
          other.winner == winner;

  @override
  int get hashCode => Object.hash(timedOutPlayer, winner);

  @override
  String toString() =>
      'GameTimeout(timedOut: ${timedOutPlayer.symbol}, winner: ${winner.symbol})';
}
