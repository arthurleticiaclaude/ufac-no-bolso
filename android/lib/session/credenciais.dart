import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// CPF e senha do ID Ufac, guardados cifrados no cofre do Android (Keystore), só neste celular.
/// Servem para o app refazer o login sozinho, na página oficial, quando a sessão da Ufac cai.
/// Nunca vão para log, cache, servidor do app ou qualquer lugar que não seja o site da Ufac.
class Credenciais {
  Credenciais._();
  static final instancia = Credenciais._();

  static const _cofre = FlutterSecureStorage();
  static const _chaveCpf = 'login_cpf';
  static const _chaveSenha = 'login_senha';
  static const _chaveLigado = 'login_automatico';

  String? _cpf, _senha;
  bool _carregou = false;

  /// Depois de uma senha recusada, para de tentar até a pessoa entrar de novo à mão.
  bool falhou = false;

  Future<void> _carregar() async {
    if (_carregou) return;
    _cpf = await _cofre.read(key: _chaveCpf);
    _senha = await _cofre.read(key: _chaveSenha);
    _carregou = true;
  }

  /// A chave "Entrar sozinho" da tela de login. Ligada por padrão.
  Future<bool> ligado() async => await _cofre.read(key: _chaveLigado) != 'nao';

  Future<void> definirLigado(bool valor) async {
    await _cofre.write(key: _chaveLigado, value: valor ? 'sim' : 'nao');
    if (!valor) await esquecer(manterChave: true);
  }

  Future<bool> temSalvas() async {
    await _carregar();
    return _cpf != null && _senha != null;
  }

  /// (cpf, senha) para o login automático. Null se não houver, se a chave estiver desligada
  /// ou se a última tentativa foi recusada.
  Future<(String, String)?> paraLoginAutomatico() async {
    if (falhou || !await ligado()) return null;
    await _carregar();
    final cpf = _cpf, senha = _senha;
    return cpf == null || senha == null ? null : (cpf, senha);
  }

  Future<void> guardar(String cpf, String senha) async {
    final soDigitos = cpf.replaceAll(RegExp(r'\D'), '');
    if (soDigitos.length != 11 || senha.isEmpty) return;
    await _cofre.write(key: _chaveCpf, value: soDigitos);
    await _cofre.write(key: _chaveSenha, value: senha);
    _cpf = soDigitos;
    _senha = senha;
    _carregou = true;
    falhou = false;
  }

  Future<void> esquecer({bool manterChave = false}) async {
    await _cofre.delete(key: _chaveCpf);
    await _cofre.delete(key: _chaveSenha);
    if (!manterChave) await _cofre.delete(key: _chaveLigado);
    _cpf = null;
    _senha = null;
    _carregou = true;
  }

  /// Depois de "Sair": o cofre inteiro já foi apagado; aqui só a memória.
  void limparMemoria() {
    _cpf = null;
    _senha = null;
    _carregou = false;
    falhou = false;
  }
}

/// CPF com pontos e traço, como o eTICKET espera ver no campo.
String cpfFormatado(String digitos) => digitos.length != 11
    ? digitos
    : '${digitos.substring(0, 3)}.${digitos.substring(3, 6)}.${digitos.substring(6, 9)}-${digitos.substring(9)}';

/// Script que preenche o formulário oficial de login e aperta Entrar.
/// Os valores entram como texto JSON, então nada do CPF ou da senha vira código.
/// Não preenche nada se a página tiver CAPTCHA (regra 1: CAPTCHA é sempre da pessoa).
String scriptLoginAutomatico({required bool eticket, required String cpf, required String senha}) {
  final c = jsonEncode(eticket ? cpfFormatado(cpf) : cpf);
  final s = jsonEncode(senha);
  final campoCpf = eticket ? 'input[name="cpf"]' : 'input[name="j_username"]';
  final campoSenha = eticket ? 'input[name="password"]' : 'input[name="j_password"]';
  return '''
(function () {
  if (document.querySelector('.g-recaptcha, iframe[src*="recaptcha"], iframe[src*="hcaptcha"], [name*="captcha" i]')) return 'captcha';
  var u = document.querySelector('$campoCpf'), p = document.querySelector('$campoSenha');
  if (!u || !p) return 'sem-formulario';
  u.value = $c;
  p.value = $s;
  u.dispatchEvent(new Event('input', { bubbles: true }));
  p.dispatchEvent(new Event('input', { bubbles: true }));
  var f = p.form || u.form;
  if (!f) return 'sem-formulario';
  var b = f.querySelector('[type="submit"]');
  if (b) { b.click(); } else { f.submit(); }
  return 'enviado';
})();
''';
}

/// Script que, na tela de login visível, avisa o app quando a pessoa aperta Entrar,
/// para guardar o CPF e a senha que ela mesma digitou (só se a chave estiver ligada).
String scriptCapturarLogin({required bool eticket}) {
  final campoCpf = eticket ? 'input[name="cpf"]' : 'input[name="j_username"]';
  final campoSenha = eticket ? 'input[name="password"]' : 'input[name="j_password"]';
  return '''
(function () {
  var p = document.querySelector('$campoSenha');
  if (!p || !p.form || p.form.__ufacmais) return;
  p.form.__ufacmais = true;
  p.form.addEventListener('submit', function () {
    var u = document.querySelector('$campoCpf');
    if (u && window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('loginDigitado', u.value, p.value);
    }
  }, true);
})();
''';
}
