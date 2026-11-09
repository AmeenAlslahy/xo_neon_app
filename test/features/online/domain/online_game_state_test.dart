import 'package:flutter_test/flutter_test.dart';
import 'package:xo_neon_app/features/game/domain/models/cell_position.dart';
import 'package:xo_neon_app/features/game/domain/models/player.dart';
import 'package:xo_neon_app/features/online/domain/models/online_game_state.dart';

void main() {
  group('OnlineMove Domain Model', () {
    test('serialization round-trip to/from Map', () {
      const move = OnlineMove(
        row: 2,
        col: 3,
        player: Player.x,
        timestampMs: 1234567,
      );

      final map = move.toMap();
      final reloaded = OnlineMove.fromMap(map);

      expect(reloaded, equals(move));
      expect(reloaded.position, equals(const Position(2, 3)));
    });
  });

  group('OnlineGameState Domain Model', () {
    test('lifecycle state getters', () {
      const playing = OnlineGameState(
        currentRound: 1,
        currentTurn: Player.x,
        hostScore: 0,
        guestScore: 0,
        moves: [],
        status: OnlineGameStatus.playing,
        lastUpdatedMs: 1000,
      );

      expect(playing.isPlaying, isTrue);
      expect(playing.isRoundOver, isFalse);
      expect(playing.isMatchOver, isFalse);

      final roundWon = playing.copyWith(
        status: OnlineGameStatus.roundWon,
        roundWinner: Player.x,
      );
      expect(roundWon.isPlaying, isFalse);
      expect(roundWon.isRoundOver, isTrue);
      expect(roundWon.isMatchOver, isFalse);

      final matchOver = playing.copyWith(
        status: OnlineGameStatus.matchOver,
        roundWinner: Player.x,
      );
      expect(matchOver.isMatchOver, isTrue);
      expect(matchOver.isRoundOver, isFalse);
    });

    test('serialization round-trip to/from Map', () {
      final state = OnlineGameState(
        currentRound: 2,
        currentTurn: Player.o,
        hostScore: 1,
        guestScore: 0,
        moves: const [
          OnlineMove(row: 0, col: 0, player: Player.x, timestampMs: 100),
          OnlineMove(row: 1, col: 1, player: Player.o, timestampMs: 200),
        ],
        status: OnlineGameStatus.playing,
        roundWinner: null,
        winningPositions: const [Position(0, 0), Position(0, 1), Position(0, 2)],
        lastUpdatedMs: 300,
      );

      final map = state.toMap();
      final reloaded = OnlineGameState.fromMap(map);

      expect(reloaded.currentRound, 2);
      expect(reloaded.currentTurn, Player.o);
      expect(reloaded.hostScore, 1);
      expect(reloaded.guestScore, 0);
      expect(reloaded.moves.length, 2);
      expect(reloaded.moves[0].player, Player.x);
      expect(reloaded.moves[1].player, Player.o);
      expect(reloaded.winningPositions?.length, 3);
    });
  });
}
