import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Escolhas da pessoa. Ficam fora do cache, para "Limpar dados salvos" não apagá-las.
class Preferencias extends ChangeNotifier {
  Preferencias._();
  static final instancia = Preferencias._();

  static const _cofre = FlutterSecureStorage();
  static const _chaveTema = 'pref_tema';
  static const _chaveFeriados = 'pref_avisar_feriados';
  static const _chaveClassroom = 'pref_avisar_classroom';

  ThemeMode tema = ThemeMode.system;
  bool avisarFeriados = true;
  bool avisarClassroom = true;

  Future<void> carregar() async {
    tema = ThemeMode.values.asNameMap()[await _cofre.read(key: _chaveTema)] ?? ThemeMode.system;
    avisarFeriados = await _cofre.read(key: _chaveFeriados) != 'nao';
    avisarClassroom = await _cofre.read(key: _chaveClassroom) != 'nao';
    notifyListeners();
  }

  Future<void> definirTema(ThemeMode novo) async {
    tema = novo;
    notifyListeners();
    await _cofre.write(key: _chaveTema, value: novo.name);
  }

  Future<void> definirAvisarFeriados(bool novo) async {
    avisarFeriados = novo;
    notifyListeners();
    await _cofre.write(key: _chaveFeriados, value: novo ? 'sim' : 'nao');
  }

  Future<void> definirAvisarClassroom(bool novo) async {
    avisarClassroom = novo;
    notifyListeners();
    await _cofre.write(key: _chaveClassroom, value: novo ? 'sim' : 'nao');
  }

  void limpar() {
    tema = ThemeMode.system;
    avisarFeriados = true;
    avisarClassroom = true;
    notifyListeners();
  }
}
