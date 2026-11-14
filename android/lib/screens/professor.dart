import 'package:flutter/material.dart';

import '../config.dart';
import '../data/academico.dart';
import '../data/foto_perfil.dart';
import '../data/professor.dart';
import '../data/refeicoes.dart';
import '../data/repositorio_professor.dart';
import '../data/repositorio_ru.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'acoes_professor.dart';
import 'inicio.dart' show faixasDaInicio, linhaProximaRefeicao;
import 'menu.dart';
import 'ru.dart' show CartaoSaldo;
import 'site_oficial.dart';

// Telas do perfil do professor. Só leitura: lançar chamada e notas acontece na página
// oficial, aberta dentro do app, até a tela nativa de lançamento existir.

void _abrirNoPortal(BuildContext context, String titulo, String endereco) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TelaSiteOficial(titulo: titulo, endereco: endereco)),
    );

String _iniciais(String nome) {
  final partes = nome.split(' ').where((p) => p.length > 2).toList();
  if (partes.isEmpty) return '?';
  return (partes.first[0] + (partes.length > 1 ? partes.last[0] : '')).toUpperCase();
}

// ---------------- Início ----------------

class TelaInicioProfessor extends StatelessWidget {
  const TelaInicioProfessor({super.key, required this.abrirRu});

  final VoidCallback abrirRu;

  Future<void> _atualizar(BuildContext context) async {
    await Future.wait([RepositorioRu.instancia.atualizar(), atualizarProfessor(context)]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RepositorioProfessor.instancia,
      builder: (context, _) {
        final c = context.cores;
        final prof = RepositorioProfessor.instancia;
        final agora = DateTime.now();
        final turmas = prof.turmas;
        final aula = proximaAula(prof.aulas ?? const [], agora);
        return ListaDaTela(
          aoAtualizar: () => _atualizar(context),
          children: [
            CabecalhoTela(
              titulo: prof.nome == null ? 'Olá' : 'Olá, ${prof.primeiroNome}',
              sobretitulo: formatarData(agora),
              acoes: [
                BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
              ],
            ),
            ...faixasDaInicio(context, agora),
            if (prof.nome != null)
              _CartaoProfessor(nome: prof.nome!, turmas: turmas?.length, semestre: prof.semestre)
            else if (prof.carregando)
              const Cartao(child: Skeleton(altura: 72, raio: AppMedidas.raioBotao))
            else
              Cartao(
                child: EstadoVazio(
                  icone: Icons.badge_rounded,
                  titulo: 'Ainda não li seus dados do Portal',
                  texto: 'Entre no Portal do Professor para ver turmas e horários.',
                  acao: BotaoContorno(
                    texto: 'Entrar no Portal',
                    cor: c.navAtivo,
                    aoTocar: () => entrarNoPortalProfessor(context),
                  ),
                ),
              ),
            if (turmas != null)
              Cartao(
                child: aula == null
                    ? const EstadoVazio(icone: Icons.event_available_rounded, titulo: 'Sem aula nos próximos dias')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Selo(texto: aula.rotulo, cor: c.chipTexto, fundo: c.chipFundo),
                          const SizedBox(height: 10),
                          Text(aula.aula.disciplina, style: AppTexto.tituloCartao),
                          const SizedBox(height: 2),
                          Text(
                            'Próxima aula · ${formatarHoraMin(aula.aula.inicioMin)} às ${formatarHoraMin(aula.aula.fimMin)}',
                            style: AppTexto.apoio.copyWith(color: c.secundario),
                          ),
                        ],
                      ),
              ),
            if (turmas != null) _CartaoPendencias(turmas: turmas, agora: agora),
            const CartaoSaldo(tituloSaldo: 'Saldo no RU', compacto: true),
            linhaProximaRefeicao(proximaRefeicao(agora), abrirRu),
          ],
        );
      },
    );
  }
}

class _CartaoProfessor extends StatelessWidget {
  const _CartaoProfessor({required this.nome, this.turmas, this.semestre});

  final String nome;
  final int? turmas;
  final String? semestre;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      child: Row(
        children: [
          ListenableBuilder(
            listenable: FotoPerfil.instancia,
            builder: (context, _) {
              final foto = FotoPerfil.instancia.bytes;
              return Semantics(
                button: true,
                label: 'Escolher foto de perfil',
                child: GestureDetector(
                  onTap: () => FotoPerfil.instancia.escolher(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppMedidas.raioIcone + 2),
                    child: foto != null
                        ? Image.memory(foto, width: 64, height: 64, fit: BoxFit.cover)
                        : Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            color: c.navAtivoFundo,
                            child: Text(_iniciais(nome), style: AppTexto.tituloCartao.copyWith(color: c.navAtivo)),
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: AppTexto.tituloCartao),
                const SizedBox(height: 2),
                Text(
                  [
                    'Docente · Ufac',
                    if (turmas != null) turmas == 1 ? '1 turma' : '$turmas turmas',
                    if (semestre != null) semestreCurto(semestre!),
                  ].join(' · '),
                  style: AppTexto.apoio.copyWith(color: c.secundario),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoPendencias extends StatelessWidget {
  const _CartaoPendencias({required this.turmas, required this.agora});

  final List<TurmaCompleta> turmas;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    // Mais recente primeiro: é a aula que o professor acabou de dar.
    final pendentes = [
      for (final t in turmas)
        for (final a in t.semChamada(agora))
          if (a.idAgenda != null) (t, a),
    ]..sort((x, y) => y.$2.data.compareTo(x.$2.data));
    final notas = turmas.where((t) => t.turma.lancamentoNotasAberto).toList();
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconeQuadrado(icone: Icons.fact_check_rounded, cor: c.chipTexto, fundo: c.chipFundo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chamadas pendentes', style: AppTexto.tituloCartao),
                    Text(
                      pendentes.isEmpty
                          ? 'Todas as aulas do mês têm chamada.'
                          : pendentes.length == 1
                              ? '1 aula já aconteceu e está sem chamada'
                              : '${pendentes.length} aulas já aconteceram e estão sem chamada',
                      style: AppTexto.apoio.copyWith(color: c.secundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final (t, a) in pendentes.take(4)) ...[
            const SizedBox(height: 10),
            _AulaComBotao(turma: t.turma, aula: a, rotuloBotao: 'Fazer chamada'),
          ],
          if (pendentes.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'e mais ${pendentes.length - 4} na aba Turmas',
                style: AppTexto.rotulo.copyWith(color: c.secundario),
              ),
            ),
          for (final t in notas) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.grading_rounded, size: 20, color: c.verde),
                const SizedBox(width: 10),
                Expanded(child: Text('${t.turma.disciplina}: lançamento de notas aberto', style: AppTexto.corpo)),
                TextButton(
                  onPressed: () => abrirNotas(context, t.turma),
                  child: const Text('Abrir'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma aula com um botão claro para a chamada. Usada na Início e na Turma.
class _AulaComBotao extends StatelessWidget {
  const _AulaComBotao({required this.turma, required this.aula, required this.rotuloBotao});

  final TurmaProfessor turma;
  final AulaAgenda aula;
  final String rotuloBotao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final d = aula.data;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(color: c.fundo, borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(turma.disciplina, style: AppTexto.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${_diasCurtos[d.weekday - 1]}, ${d.day}/${d.month} · ${formatarHoraMin(aula.inicioMin)} às ${formatarHoraMin(aula.fimMin)}',
                  style: AppTexto.apoio.copyWith(color: c.secundario),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => abrirChamada(context, turma, aula),
            icon: const Icon(Icons.how_to_reg_rounded, size: 18),
            label: Text(rotuloBotao),
            style: FilledButton.styleFrom(
              backgroundColor: c.primaria,
              foregroundColor: c.sobrePrimaria,
              minimumSize: const Size(0, AppMedidas.toqueMinimo),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chamada é feita na página oficial da aula, dentro do app. Ao voltar, as pendências são relidas.
Future<void> abrirChamada(BuildContext context, TurmaProfessor turma, AulaAgenda aula) async {
  final d = aula.data;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaSiteOficial(
        titulo: 'Chamada · ${_diasCurtos[d.weekday - 1]}, ${d.day}/${d.month}',
        endereco: urlProfessorChamada(aula.idAgenda!),
        dica: 'Toque no quadradinho de cada aluno para marcar presença (verde) ou falta (vermelho). '
            'Depois toque em Salvar, no fim da página.',
      ),
    ),
  );
  RepositorioProfessor.instancia.atualizar();
}

// ---------------- Turmas ----------------

class TelaTurmasProfessor extends StatelessWidget {
  const TelaTurmasProfessor({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RepositorioProfessor.instancia,
      builder: (context, _) {
        final c = context.cores;
        final prof = RepositorioProfessor.instancia;
        final turmas = prof.turmas;
        final agora = DateTime.now();
        return ListaDaTela(
          aoAtualizar: () => atualizarProfessor(context),
          children: [
            CabecalhoTela(
              titulo: 'Turmas',
              subtitulo: prof.semestre,
              acoes: [
                BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
              ],
            ),
            if (turmas == null)
              prof.carregando
                  ? const Skeleton(altura: 96, raio: AppMedidas.raioCartao)
                  : Cartao(
                      child: EstadoVazio(
                        icone: Icons.groups_rounded,
                        titulo: 'Ainda não li suas turmas',
                        acao: BotaoContorno(
                          texto: 'Entrar no Portal',
                          cor: c.navAtivo,
                          aoTocar: () => entrarNoPortalProfessor(context),
                        ),
                      ),
                    )
            else if (turmas.isEmpty)
              const Cartao(child: EstadoVazio(icone: Icons.groups_rounded, titulo: 'Nenhuma turma neste semestre'))
            else
              for (final t in turmas) _CartaoTurma(turma: t, agora: agora),
            if (prof.lidoEm != null)
              Text(
                'Atualizado em ${formatarDiaHora(prof.lidoEm!)}',
                style: AppTexto.rotulo.copyWith(color: c.secundario),
                textAlign: TextAlign.center,
              ),
          ],
        );
      },
    );
  }
}

class _CartaoTurma extends StatelessWidget {
  const _CartaoTurma({required this.turma, required this.agora});

  final TurmaCompleta turma;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = turma.turma, d = turma.detalhe;
    final sem = turma.semChamada(agora).length;
    return Cartao(
      aoTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TelaTurma(turma: turma))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.disciplina, style: AppTexto.tituloCartao)),
              Icon(Icons.chevron_right_rounded, color: c.secundario),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [t.nome, if (t.curso != null) t.curso!].join(' · '),
            style: AppTexto.apoio.copyWith(color: c.secundario),
          ),
          if (d != null && d.horarios.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_resumoHorarios(d.horarios), style: AppTexto.apoio),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (d?.matriculas != null)
                Selo(texto: '${d!.matriculas} alunos', cor: c.navAtivo, fundo: c.navAtivoFundo),
              if (d?.cargaHorariaRealizada != null)
                Selo(texto: '${d!.cargaHorariaRealizada} h dadas', cor: c.navAtivo, fundo: c.navAtivoFundo),
              if (sem > 0)
                Selo(texto: sem == 1 ? '1 aula sem chamada' : '$sem aulas sem chamada', cor: c.chipTexto, fundo: c.chipFundo),
              if (t.lancamentoNotasAberto) Selo(texto: 'Notas: lançamento aberto', cor: c.verde, fundo: c.verdeFundo),
            ],
          ),
        ],
      ),
    );
  }
}

const _diasCurtos = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String _resumoHorarios(List<HorarioTurma> h) => [
      for (final x in [...h]..sort((a, b) => a.diaSemana.compareTo(b.diaSemana)))
        '${_diasCurtos[x.diaSemana - 1]} ${formatarHoraMin(x.inicioMin)}–${formatarHoraMin(x.fimMin)}',
    ].join(' · ');

class _TelaTurma extends StatelessWidget {
  const _TelaTurma({required this.turma});

  final TurmaCompleta turma;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = turma.turma, d = turma.detalhe;
    final aulas = turma.aulasDoMes ?? const <AulaAgenda>[];
    final agora = DateTime.now();
    return Scaffold(
      body: ListaDaTela(
        children: [
          Row(
            children: [
              BotaoRedondo(
                icone: Icons.arrow_back_rounded,
                descricao: 'Voltar',
                aoTocar: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(t.disciplina, style: AppTexto.tituloTela)),
            ],
          ),
          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Dado('Turma', t.nome),
                if (t.codigo != null) _Dado('Código', t.codigo!),
                if ((d?.curso ?? t.curso) != null) _Dado('Curso', (d?.curso ?? t.curso)!),
                if (t.periodo != null) _Dado('Período', t.periodo!),
                if (d?.tipo != null) _Dado('Tipo', d!.tipo!),
                if (d?.matriculas != null)
                  _Dado('Alunos', d!.vagas == null ? '${d.matriculas}' : '${d.matriculas} de ${d.vagas} vagas'),
                if (d?.cargaHorariaRealizada != null) _Dado('Carga horária realizada', '${d!.cargaHorariaRealizada} h'),
                if (t.situacaoFrequencia != null) _Dado('Frequência', t.situacaoFrequencia!),
                if (t.situacaoNotas != null) _Dado('Notas', t.situacaoNotas!),
              ],
            ),
          ),
          BotaoDestaque(
            texto: 'Fazer chamada',
            icone: Icons.how_to_reg_rounded,
            aoTocar: () => _escolherAula(context, turma, agora),
          ),
          BotaoContorno(
            texto: 'Lançar notas no portal',
            icone: Icons.grading_rounded,
            cor: c.navAtivo,
            aoTocar: () => abrirNotas(context, t),
          ),
          TextButton(
            onPressed: () => _abrirNoPortal(context, 'Agenda da turma', urlProfessorAgenda(t.id)),
            child: const Text('Abrir a agenda da turma no portal'),
          ),
          if (d != null && d.horarios.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Horários', style: AppTexto.tituloCartao),
                  const SizedBox(height: 8),
                  for (final h in d.horarios)
                    _Dado(
                      _diasCurtos[h.diaSemana - 1],
                      '${formatarHoraMin(h.inicioMin)} às ${formatarHoraMin(h.fimMin)}${h.tipo == null ? '' : ' · ${h.tipo}'}',
                    ),
                ],
              ),
            ),
          if (aulas.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aulas deste mês', style: AppTexto.tituloCartao),
                  const SizedBox(height: 8),
                  for (final a in aulas) _LinhaAula(turma: t, aula: a, agora: agora),
                ],
              ),
            ),
          if (d != null && d.modeloNotas.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Avaliações', style: AppTexto.tituloCartao),
                  const SizedBox(height: 8),
                  for (final g in d.modeloNotas) ...[
                    Text('${g.rotulo} · peso ${g.peso}', style: AppTexto.corpoForte),
                    for (final a in g.avaliacoes)
                      Text('${a.nome} (${a.codigo}) · ${a.peso}', style: AppTexto.apoio.copyWith(color: c.secundario)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          if (d != null && d.docentes.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Docentes', style: AppTexto.tituloCartao),
                  const SizedBox(height: 8),
                  for (final x in d.docentes) _Dado(x.$2, x.$1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaAula extends StatelessWidget {
  const _LinhaAula({required this.turma, required this.aula, required this.agora});

  final TurmaProfessor turma;

  final AulaAgenda aula;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final futura = aula.data.isAfter(hoje);
    final (texto, cor, fundo) = aula.chamadaLancada
        ? ('Chamada feita', c.verde, c.verdeFundo)
        : futura
            ? ('Ainda não', c.secundario, c.chrome)
            : ('Sem chamada', c.chipTexto, c.chipFundo);
    final podeFazer = aula.idAgenda != null && !futura;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                '${_diasCurtos[aula.data.weekday - 1]}, ${aula.data.day}/${aula.data.month}',
                style: AppTexto.corpoForte,
              ),
            ),
            Expanded(
              child: Text(
                aula.conteudo ?? '${formatarHoraMin(aula.inicioMin)} às ${formatarHoraMin(aula.fimMin)}',
                style: AppTexto.apoio.copyWith(color: c.secundario),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Selo(texto: texto, cor: cor, fundo: fundo),
          ],
        ),
          ),
          if (podeFazer)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => abrirChamada(context, turma, aula),
                icon: Icon(aula.chamadaLancada ? Icons.edit_rounded : Icons.how_to_reg_rounded, size: 18),
                label: Text(aula.chamadaLancada ? 'Corrigir chamada' : 'Fazer chamada'),
              ),
            ),
          Divider(height: 8, color: c.borda),
        ],
      ),
    );
  }
}

/// "Fazer chamada" na tela da turma: abre direto se só uma aula espera; senão, deixa escolher.
Future<void> _escolherAula(BuildContext context, TurmaCompleta turma, DateTime agora) async {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final passadas = [
    for (final a in turma.aulasDoMes ?? const <AulaAgenda>[])
      if (a.idAgenda != null && !a.data.isAfter(hoje)) a,
  ]..sort((x, y) {
      // Sem chamada primeiro; dentro de cada grupo, a mais recente primeiro.
      if (x.chamadaLancada != y.chamadaLancada) return x.chamadaLancada ? 1 : -1;
      return y.data.compareTo(x.data);
    });
  final pendentes = passadas.where((a) => !a.chamadaLancada).toList();
  if (pendentes.length == 1) return abrirChamada(context, turma.turma, pendentes.first);
  if (passadas.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nenhuma aula deste mês já aconteceu. A chamada abre depois da aula.')),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (folha) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(folha).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppMedidas.margem, 0, AppMedidas.margem, AppMedidas.margem),
          children: [
            Text('De qual aula?', style: AppTexto.tituloCartao),
            const SizedBox(height: 4),
            Text(
              pendentes.isEmpty ? 'Todas já têm chamada. Escolha uma para corrigir.' : 'As aulas sem chamada aparecem primeiro.',
              style: AppTexto.apoio.copyWith(color: folha.cores.secundario),
            ),
            for (final a in passadas) ...[
              const SizedBox(height: 10),
              _AulaComBotao(
                turma: turma.turma,
                aula: a,
                rotuloBotao: a.chamadaLancada ? 'Corrigir' : 'Fazer chamada',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Dado extends StatelessWidget {
  const _Dado(this.rotulo, this.valor);

  final String rotulo, valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(rotulo, style: AppTexto.apoio.copyWith(color: c.secundario))),
          Expanded(child: Text(valor, style: AppTexto.corpo)),
        ],
      ),
    );
  }
}

// ---------------- Relatórios ----------------

class TelaRelatoriosProfessor extends StatelessWidget {
  const TelaRelatoriosProfessor({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ListaDaTela(
      children: [
        CabecalhoTela(
          titulo: 'Relatórios',
          subtitulo: 'Portal do Professor',
          acoes: [
            BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
          ],
        ),
        for (final r in RelatorioProfessor.values)
          ItemLista(
            icone: Icons.picture_as_pdf_rounded,
            corIcone: c.perigo,
            fundoIcone: c.perigoFundo,
            titulo: r.nome,
            aoTocar: () => _abrirNoPortal(context, r.nome, r.url),
          ),
        ItemLista(
          icone: Icons.more_horiz_rounded,
          corIcone: c.navAtivo,
          fundoIcone: c.navAtivoFundo,
          titulo: 'Mais relatórios',
          aoTocar: () => _abrirNoPortal(context, 'Mais relatórios', 'https://portal.ufac.br/relatorios/relatorios.action'),
        ),
        Text(
          'Os relatórios abrem na página oficial do Portal do Professor, dentro do app.',
          style: AppTexto.rotulo.copyWith(color: c.secundario),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// O lançamento de notas também é feito na página oficial. Ao voltar, a situação é relida.
Future<void> abrirNotas(BuildContext context, TurmaProfessor turma) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaSiteOficial(
        titulo: 'Notas · ${turma.disciplina}',
        endereco: urlProfessorQuadroNotas(turma.id),
        dica: 'Digite a nota de cada avaliação e toque em Salvar. Não use "Encerrar" se ainda for mudar alguma nota.',
      ),
    ),
  );
  RepositorioProfessor.instancia.atualizar();
}
