import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/session/credenciais.dart';

void main() {
  test('CPF com pontos e traço para o eTICKET', () {
    expect(cpfFormatado('12345678901'), '123.456.789-01');
    expect(cpfFormatado('123'), '123');
  });

  test('portal: preenche j_username e j_password', () {
    final s = scriptLoginAutomatico(eticket: false, cpf: '12345678901', senha: 'abc');
    expect(s, contains('input[name="j_username"]'));
    expect(s, contains('input[name="j_password"]'));
    expect(s, contains('"12345678901"'));
  });

  test('eTICKET: preenche cpf formatado e password', () {
    final s = scriptLoginAutomatico(eticket: true, cpf: '12345678901', senha: 'abc');
    expect(s, contains('input[name="cpf"]'));
    expect(s, contains('"123.456.789-01"'));
  });

  test('senha com aspas e barras não vira código', () {
    const perigosa = r'''a"); alert(1); ("\'</script>''';
    final s = scriptLoginAutomatico(eticket: false, cpf: '12345678901', senha: perigosa);
    // A senha só aparece dentro de uma string JSON, com as aspas escapadas.
    expect(s, contains(r'p.value = "a\"); alert(1); (\"\\'));
    expect(s, isNot(contains('p.value = "a"); alert(1)')));
  });

  test('não preenche se houver CAPTCHA (regra 1)', () {
    final s = scriptLoginAutomatico(eticket: true, cpf: '12345678901', senha: 'x');
    final captcha = s.indexOf("return 'captcha'");
    final preenche = s.indexOf('u.value =');
    expect(captcha, greaterThan(0));
    expect(captcha, lessThan(preenche), reason: 'confere o CAPTCHA antes de tocar nos campos');
  });

  test('captura só avisa o app no Entrar, sem ler antes', () {
    final s = scriptCapturarLogin(eticket: false);
    expect(s, contains("addEventListener('submit'"));
    expect(s, contains("callHandler('loginDigitado'"));
  });
}
