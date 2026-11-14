import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/session/regras_sessao.dart';
import 'package:ufac_no_bolso/session/sessao.dart';

// "Pular" no login: a pessoa conecta só o Portal ou só o eTICKET.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Sessao.instancia.carregarPulados();
  });

  test('sistema pulado fica desconectado e é lembrado ao abrir de novo', () async {
    final s = Sessao.instancia;
    expect(s.conectado(Sistema.eticket), isTrue);
    await s.pular(Sistema.eticket);
    expect(s.conectado(Sistema.eticket), isFalse);
    expect(s.conectado(Sistema.portal), isTrue);
    // Simula fechar e abrir o app: lê de novo do cofre.
    await s.carregarPulados();
    expect(s.conectado(Sistema.eticket), isFalse);
  });

  test('entrar depois conecta de novo', () async {
    final s = Sessao.instancia;
    await s.pular(Sistema.portal);
    await s.conectar(Sistema.portal);
    await s.carregarPulados();
    expect(s.conectado(Sistema.portal), isTrue);
  });

  test('com o eTICKET pulado, abrir o app não lê nada da Ufac', () async {
    final s = Sessao.instancia;
    var leituras = 0;
    s.leitor = (_, _) async {
      leituras++;
      return const PaginaLida(ResultadoVerificacao.ativa, '<html></html>');
    };
    await s.pular(Sistema.eticket);
    final r = await s.verificar();
    expect(r.resultado, ResultadoVerificacao.semResposta);
    expect(leituras, 0);
    expect(s.expirados, isNot(contains(Sistema.eticket)), reason: 'sem aviso de "sessão terminou"');
    await s.conectar(Sistema.eticket);
    await s.verificar();
    expect(leituras, 1);
  });
}
