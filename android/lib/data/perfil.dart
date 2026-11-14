import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PerfilUsuario { aluno, professor }

/// Quem usa este celular. Define o portal, as abas e as cores (azul para alunos, âmbar para professores).
class Perfil extends ChangeNotifier {
  Perfil._();
  static final instancia = Perfil._();

  static const _cofre = FlutterSecureStorage();
  static const _chave = 'perfil';

  /// Quem já usava o app antes desta escolha existir é aluno.
  PerfilUsuario atual = PerfilUsuario.aluno;

  bool get ehProfessor => atual == PerfilUsuario.professor;

  Future<void> carregar() async {
    atual = PerfilUsuario.values.asNameMap()[await _cofre.read(key: _chave)] ?? PerfilUsuario.aluno;
    notifyListeners();
  }

  Future<void> definir(PerfilUsuario novo) async {
    atual = novo;
    notifyListeners();
    await _cofre.write(key: _chave, value: novo.name);
  }

  void limpar() {
    atual = PerfilUsuario.aluno;
    notifyListeners();
  }
}
