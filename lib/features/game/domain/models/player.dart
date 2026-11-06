enum Player {
  x,
  o;

  /// Returns the opponent player.
  Player get other => this == Player.x ? Player.o : Player.x;

  /// Returns the display symbol for the player ('X' or 'O').
  String get symbol => this == Player.x ? 'X' : 'O';
}

