import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ufac_no_bolso/data/avisos_classroom.dart';
import 'package:ufac_no_bolso/data/classroom.dart';
import 'package:ufac_no_bolso/ui/formatos.dart';

void main() {
  testesDaSemana();
  testesDosAvisos();

  test('pede só os dois escopos de leitura', () {
    expect(escopoTurmas, endsWith('classroom.courses.readonly'));
    expect(escopoAtividades, endsWith('classroom.coursework.me.readonly'));
  });

  test('lê turma e ignora link fora do Classroom', () {
    final t = lerTurma({'id': '1', 'name': 'Direito Civil', 'section': 'T1', 'alternateLink': 'https://x.com/a'})!;
    expect(t.nome, 'Direito Civil');
    expect(t.link, isNull);
    expect(lerTurma({'name': 'sem id'}), isNull);
  });

  test('prazo vem em UTC e vira hora local', () {
    final p = lerPrazo({
      'dueDate': {'year': 2026, 'month': 11, 'day': 12},
      'dueTime': {'hours': 3, 'minutes': 59},
    })!;
    expect(p, DateTime.utc(2026, 11, 12, 3, 59).toLocal());
    expect(lerPrazo({}), isNull);
  });

  test('situação da entrega', () {
    final agora = DateTime(2026, 11, 10);
    final passado = DateTime(2026, 11, 1), futuro = DateTime(2026, 11, 20);
    expect(lerSituacao({'state': 'TURNED_IN'}, passado, agora), SituacaoEntrega.entregue);
    expect(lerSituacao({'state': 'RETURNED'}, null, agora), SituacaoEntrega.entregue);
    expect(lerSituacao({'state': 'CREATED'}, passado, agora), SituacaoEntrega.atrasada);
    expect(lerSituacao({'state': 'CREATED', 'late': true}, null, agora), SituacaoEntrega.atrasada);
    expect(lerSituacao(null, futuro, agora), SituacaoEntrega.pendente);
  });

  test('ordena pelo prazo mais próximo, sem prazo no fim', () {
    Atividade a(String t, DateTime? p) => Atividade(id: t, titulo: t, prazo: p, situacao: SituacaoEntrega.pendente);
    final l = ordenarPorPrazo([a('sem', null), a('depois', DateTime(2026, 12)), a('antes', DateTime(2026, 11))]);
    expect(l.map((x) => x.titulo), ['antes', 'depois', 'sem']);
  });

  test('mensagens de erro em português', () {
    expect(traduzirErroApi(401, '').pedirLogin, isTrue);
    expect(traduzirErroApi(403, '{"error":{"details":[{"reason":"ClassroomApiDisabled"}]}}').mensagem,
        contains('regra da instituição'));
    expect(traduzirErroApi(403, '{"error":{"status":"PERMISSION_DENIED","message":"SERVICE_DISABLED"}}').mensagem,
        contains('minutos a algumas horas'));
    expect(
      traduzirErroLogin(const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Error 400: admin_policy_enforced',
      )).mensagem,
      contains('regra da instituição'),
    );
    expect(
      traduzirErroLogin(const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'SDK reported an exception: 10: DEVELOPER_ERROR',
      )).mensagem,
      contains('não reconheceu este app'),
    );
    expect(
      traduzirErroLogin(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled)).mensagem,
      contains('Avançado'),
    );
  });
}

void testesDaSemana() {
  final agora = DateTime(2026, 11, 10, 12);
  Atividade a(String t, DateTime? p, SituacaoEntrega s) => Atividade(id: t, titulo: t, prazo: p, situacao: s);

  test('semana: falta entregar, prazo de 7 dias atrás a 7 dias à frente', () {
    final l = atividadesDaSemana([
      a('amanha', DateTime(2026, 11, 11), SituacaoEntrega.pendente),
      a('entregue', DateTime(2026, 11, 11), SituacaoEntrega.entregue),
      a('longe', DateTime(2026, 11, 30), SituacaoEntrega.pendente),
      a('atrasou ontem', DateTime(2026, 11, 9), SituacaoEntrega.atrasada),
      a('atrasou faz tempo', DateTime(2026, 10, 1), SituacaoEntrega.atrasada),
      a('sem prazo', null, SituacaoEntrega.pendente),
    ], agora);
    expect(l.map((x) => x.titulo), ['atrasou ontem', 'amanha']);
  });

  test('cache: ida e volta pelo JSON', () {
    final original = Atividade(
      id: '1',
      titulo: 'Fichamento',
      turma: 'Direito Penal',
      prazo: DateTime(2026, 11, 12, 23, 59),
      link: 'https://classroom.google.com/c/1',
      situacao: SituacaoEntrega.atrasada,
    );
    final volta = Atividade.deJson(original.paraJson())!;
    expect(volta.titulo, 'Fichamento');
    expect(volta.turma, 'Direito Penal');
    expect(volta.prazo, original.prazo);
    expect(volta.link, original.link);
    expect(volta.situacao, SituacaoEntrega.atrasada);
    expect(Atividade.deJson({'titulo': 'sem id'}), isNull);
  });

  test('prazo curto', () {
    expect(formatarPrazoCurto(DateTime(2026, 11, 10, 23, 59), agora), 'hoje 23h59');
    expect(formatarPrazoCurto(DateTime(2026, 11, 11, 10), agora), 'amanhã 10h');
    expect(formatarPrazoCurto(DateTime(2026, 11, 13, 18), agora), 'sex 18h');
  });
}

void testesDosAvisos() {
  Atividade a(String t, DateTime p, [SituacaoEntrega s = SituacaoEntrega.pendente]) =>
      Atividade(id: t, titulo: t, turma: 'Penal', prazo: p, situacao: s);

  test('aviso às 19h com o que vence até o fim do dia seguinte', () {
    final agora = DateTime(2026, 11, 10, 12); // terça, meio-dia
    final avisos = planejarAvisos([
      a('amanha cedo', DateTime(2026, 11, 11, 10)),
      a('hoje a noite', DateTime(2026, 11, 10, 23, 59)),
      a('ja entregue', DateTime(2026, 11, 11, 10), SituacaoEntrega.entregue),
      a('sexta', DateTime(2026, 11, 13, 18)),
    ], agora);
    expect(avisos.map((x) => x.quando), [
      DateTime(2026, 11, 10, 19),
      DateTime(2026, 11, 12, 19),
    ]);
    expect(avisos.first.titulo, '2 atividades para entregar');
    expect(avisos.first.texto, 'hoje a noite · hoje 23h59 · Penal\namanha cedo · amanhã 10h · Penal');
    expect(avisos[1].texto, 'sexta · amanhã 18h · Penal');
  });

  test('depois das 19h, o aviso de hoje já passou', () {
    final avisos = planejarAvisos([a('x', DateTime(2026, 11, 11, 10))], DateTime(2026, 11, 10, 20));
    expect(avisos, isEmpty);
  });

  test('sem nada a entregar, nenhum aviso', () {
    expect(planejarAvisos(const [], DateTime(2026, 11, 10, 8)), isEmpty);
  });
}
