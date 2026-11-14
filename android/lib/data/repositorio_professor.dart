import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../extractors/professor.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import 'academico.dart';
import 'banco.dart';
import 'professor.dart';
import 'repositorio_portal.dart' show ResultadoPortal;

/// Dados do Portal do Professor. Como no app do aluno, as telas vivem do que está salvo e
/// só leem de novo depois do login ou quando a pessoa puxa para atualizar.
/// Nada aqui tem nome ou nota de aluno: só turmas, horários, totais e situação dos lançamentos.
class RepositorioProfessor extends ChangeNotifier {
  RepositorioProfessor._();
  static final instancia = RepositorioProfessor._();

  static const _chave = 'professor_v1';

  String? nome;
  List<TurmaCompleta>? turmas;
  DateTime? lidoEm;
  bool carregando = false;

  List<Aula>? get aulas => turmas == null ? null : aulasDoProfessor(turmas!);

  /// "2° Semestre / 2026", da primeira turma.
  String? get semestre => turmas?.map((t) => t.turma.periodo).nonNulls.firstOrNull;

  String get primeiroNome => (nome ?? '').split(' ').first;

  Future<void> carregarSalvos() async {
    final texto = await Banco.ler(_chave);
    if (texto == null) return;
    try {
      final m = jsonDecode(texto) as Map<String, dynamic>;
      if (m['lidoEm'] == null) return;
      nome = m['nome'] as String?;
      lidoEm = DateTime.parse(m['lidoEm'] as String);
      turmas = [for (final t in m['turmas'] as List) TurmaCompleta.deMapa(t as Map<String, dynamic>)];
      notifyListeners();
    } catch (_) {
      // Formato antigo ou corrompido: lê de novo da Ufac.
    }
  }

  Future<void> aoAbrirApp() async {
    if (turmas == null && Sessao.instancia.conectado(Sistema.professor)) await atualizar();
  }

  Future<ResultadoPortal> atualizar() async {
    if (carregando) return ResultadoPortal.falhou;
    carregando = true;
    notifyListeners();
    final resultado = await _ler();
    carregando = false;
    notifyListeners();
    return resultado;
  }

  Future<ResultadoPortal> _ler() async {
    final sessao = Sessao.instancia;
    final freq = await sessao.lerEMarcar(Sistema.professor, url: urlProfessorTurmasFrequencia);
    if (freq.resultado == ResultadoVerificacao.expirada) return ResultadoPortal.sessaoExpirada;
    final lista = freq.html == null ? null : lerTurmasProfessor(freq.html!);
    if (lista == null) return ResultadoPortal.falhou;
    nome = lerNomeProfessor(freq.html!) ?? nome;

    // Situação do lançamento de notas: se falhar, as turmas aparecem sem ela.
    final notas = await sessao.lerEMarcar(Sistema.professor, url: urlProfessorTurmasNotas);
    final situacoes = {
      for (final t in (notas.html == null ? null : lerTurmasProfessor(notas.html!)) ?? const <TurmaProfessor>[])
        t.id: t.situacaoFrequencia,
    };

    final antigas = {for (final t in turmas ?? const <TurmaCompleta>[]) t.turma.id: t};
    final agora = DateTime.now();
    final lidas = <TurmaCompleta>[];
    for (final t in lista) {
      final turma = t.comNotas(situacoes[t.id]);
      final pagina = await sessao.lerEMarcar(Sistema.professor, url: urlProfessorTurma(t.id));
      if (pagina.resultado == ResultadoVerificacao.expirada) return ResultadoPortal.sessaoExpirada;
      final detalhe = (pagina.html == null ? null : lerDetalheTurma(pagina.html!)) ?? antigas[t.id]?.detalhe;
      final aulasMes = await _lerAulasDoMes(t.id, agora) ?? antigas[t.id]?.aulasDoMes;
      lidas.add(TurmaCompleta(turma, detalhe: detalhe, aulasDoMes: aulasMes));
      // Mostra cada turma assim que chega.
      turmas = [...lidas, ...lista.skip(lidas.length).map((x) => antigas[x.id] ?? TurmaCompleta(x))];
      notifyListeners();
    }
    turmas = lidas;
    lidoEm = DateTime.now();
    await Banco.gravar(
      _chave,
      jsonEncode({
        'nome': nome,
        'lidoEm': lidoEm!.toIso8601String(),
        'turmas': [for (final t in lidas) t.paraMapa()],
      }),
    );
    return ResultadoPortal.atualizado;
  }

  /// O portal monta cada mês da Agenda à parte; aqui só o mês corrente.
  Future<List<AulaAgenda>?> _lerAulasDoMes(String idTurma, DateTime agora) async {
    final sessao = Sessao.instancia;
    final agenda = await sessao.lerEMarcar(Sistema.professor, url: urlProfessorAgenda(idTurma));
    if (agenda.html == null) return null;
    final mes = lerMesesAgenda(agenda.html!).where((m) => m.ano == agora.year && m.mes == agora.month).firstOrNull;
    if (mes == null) return const [];
    final pagina = await sessao.lerEMarcar(
      Sistema.professor,
      url: urlProfessorAulasDoMes(idTurma, mes.anoMes, mes.indice),
    );
    return pagina.html == null ? null : lerAulasDoMes(pagina.html!, ano: mes.ano, mes: mes.mes);
  }

  /// "Limpar dados salvos": o banco é apagado pelo repositório do RU; aqui só a memória.
  void limparCache() {
    turmas = null;
    lidoEm = null;
    notifyListeners();
  }

  void limpar() {
    nome = null;
    limparCache();
  }
}
