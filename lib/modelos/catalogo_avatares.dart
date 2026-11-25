class CatalogoAvatares {
  CatalogoAvatares._();

  static const int avatarPredeterminado = 0;

  static const List<int> avataresDisponibles = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  static bool esValido(int avatarId) {
    return avataresDisponibles.contains(avatarId);
  }

  static String? obtenerRuta(int avatarId) {
    if (!esValido(avatarId) || avatarId == avatarPredeterminado) {
      return null;
    }

    final numero = avatarId.toString().padLeft(2, '0');

    return 'assets/avatares/avatar_$numero.png';
  }

  static String obtenerNombre(int avatarId) {
    if (!esValido(avatarId) || avatarId == avatarPredeterminado) {
      return 'Predeterminado';
    }

    return 'Avatar $avatarId';
  }
}
