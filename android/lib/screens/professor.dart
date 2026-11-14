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
import 'inicio.dart' show cabecalhoComFaixas, linhaProximaRefeicao;
import 'menu.dart';
import 'ru.dart' show CartaoSaldo;
import 'site_oficial.dart';

// Telas do perfil do professor. Só leitura: a chamada e as notas são lançadas na página
// oficial, aberta dentro do app. Toda ação tem um botão com o nome do que ele faz.

void _abrirNoPortal(BuildContext context, String titulo, String endereco) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => TelaSiteOficial(titulo: titulo, endereco: endereco),
  ),
);

String _iniciais(String nome) {
  final partes = nome.split(' ').where((p) => p.length > 2).toList();
  if (partes.isEmpty) return '?';
  return (partes.first[0] + (partes.length > 1 ? partes.last[0] : '')).toUpperCase();
}

const _diasCurtos = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _diasLongos = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

String _dataCurta(DateTime d) => '${_diasCurtos[d.weekday - 1]}, ${d.day}/${d.month}';
String _faixaHorario(int inicio, int fim) => '${formatarHoraMin(inicio)} às ${formatarHoraMin(fim)}';

// ---------------- Peças comuns ----------------

/// Botão com o nome da ação. Pequeno, ao lado de uma linha, ou [grande], na largura toda.
/// A ação principal (chamada) é sempre âmbar, a mesma cor em todas as telas.
class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({
    required this.texto,
    required this.icone,
    required this.aoTocar,
    this.contorno = false,
    this.grande = false,
  });

  final String texto;
  final IconData icone;
  final VoidCallback aoTocar;
  final bool contorno, grande;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppMedidas.raioBotao));
    final tamanho = grande ? const Size.fromHeight(48) : const Size(0, AppMedidas.toqueMinimo);
    const espaco = EdgeInsets.symmetric(horizontal: 14);
    final texto_ = grande ? AppTexto.corpoForte : AppTexto.rotulo;
    final icone_ = Icon(icone, size: grande ? 20 : 18);
    if (contorno) {
      return OutlinedButton.icon(
        onPressed: aoTocar,
        icon: icone_,
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.navAtivo,
          side: BorderSide(color: grande ? c.navAtivo : c.borda),
          minimumSize: tamanho,
          padding: espaco,
          textStyle: texto_,
          shape: forma,
        ),
      );
    }
    return FilledButton.icon(
      onPressed: aoTocar,
      icon: icone_,
      label: Text(texto),
      style: FilledButton.styleFrom(
        backgroundColor: c.primaria,
        foregroundColor: c.sobrePrimaria,
        minimumSize: tamanho,
        padding: espaco,
        textStyle: texto_,
        shape: forma,
      ),
    );
  }
}

/// Um número com rótulo, no mesmo bloco do cartão de identificação do aluno.
class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);

  final String rotulo, valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: c.fundo, borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: AppTexto.rotulo.copyWith(color: c.secundario),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: AppTexto.corpoForte),
          ),
        ],
      ),
    );
  }
}

Widget _linhaDeNumeros(List<_Numero> numeros) => Row(
  children: [
    for (var i = 0; i < numeros.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: numeros[i])],
  ],
);

/// Título de cartão com ícone e uma linha de apoio.
class _TituloCartao extends StatelessWidget {
  const _TituloCartao({required this.icone, required this.titulo, this.apoio, this.cor, this.fundo});

  final IconData icone;
  final String titulo;
  final String? apoio;
  final Color? cor, fundo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Row(
      children: [
        IconeQuadrado(icone: icone, cor: cor ?? c.navAtivo, fundo: fundo ?? c.navAtivoFundo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTexto.tituloCartao),
              if (apoio != null) Text(apoio!, style: AppTexto.apoio.copyWith(color: c.secundario)),
            ],
          ),
        ),
      ],
    );
  }
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
            cabecalhoComFaixas(
              context,
              agora,
              CabecalhoTela(
                titulo: prof.nome == null ? 'Olá' : 'Olá, ${prof.primeiroNome}',
                sobretitulo: formatarData(agora),
                acoes: [BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context))],
              ),
            ),
            if (prof.nome != null)
              _CartaoProfessor(nome: prof.nome!, turmas: turmas, semestre: prof.semestre)
            else if (prof.carregando)
              const Cartao(child: Skeleton(altura: 120, raio: AppMedidas.raioBotao))
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
            if (turmas != null) _CartaoProximaAula(aula: aula),
            if (turmas != null) _CartaoParaFazer(turmas: turmas, agora: agora),
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
  final List<TurmaCompleta>? turmas;
  final String? semestre;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final lista = turmas;
    final alunos = lista == null
        ? null
        : lista.every((t) => t.detalhe?.matriculas == null)
        ? null
        : lista.fold<int>(0, (s, t) => s + (t.detalhe?.matriculas ?? 0));
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                            ? Image.memory(foto, width: 60, height: 60, fit: BoxFit.cover)
                            : Container(
                                width: 60,
                                height: 60,
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
                    Text('Docente · Ufac', style: AppTexto.apoio.copyWith(color: c.secundario)),
                  ],
                ),
              ),
            ],
          ),
          if (lista != null) ...[
            const SizedBox(height: 14),
            _linhaDeNumeros([
              _Numero('Turmas', '${lista.length}'),
              if (alunos != null) _Numero('Alunos', '$alunos'),
              if (semestre != null) _Numero('Semestre', semestreCurto(semestre!)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _CartaoProximaAula extends StatelessWidget {
  const _CartaoProximaAula({required this.aula});

  final ProximaAula? aula;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final a = aula;
    if (a == null) {
      return const Cartao(
        child: EstadoVazio(icone: Icons.event_available_rounded, titulo: 'Sem aula nos próximos dias'),
      );
    }
    // "Disciplina · Turma A": separa para mostrar a turma menor, embaixo.
    final partes = a.aula.disciplina.split(' · ');
    final disciplina = partes.first;
    final turma = partes.length > 1 ? partes.sublist(1).join(' · ') : null;
    return Cartao(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconeQuadrado(icone: Icons.schedule_rounded, cor: c.chipTexto, fundo: c.chipFundo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Próxima aula', style: AppTexto.rotulo.copyWith(color: c.secundario)),
                const SizedBox(height: 2),
                Text(disciplina, style: AppTexto.tituloCartao, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [?turma, _faixaHorario(a.aula.inicioMin, a.aula.fimMin)].join(' · '),
                  style: AppTexto.apoio.copyWith(color: c.secundario),
                ),
                const SizedBox(height: 10),
                Selo(texto: a.rotulo, cor: c.chipTexto, fundo: c.chipFundo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Para fazer": aulas que já aconteceram sem chamada e turmas com notas abertas.
class _CartaoParaFazer extends StatelessWidget {
  const _CartaoParaFazer({required this.turmas, required this.agora});

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
    final total = pendentes.length + notas.length;
    if (total == 0) {
      return Cartao(
        child: _TituloCartao(
          icone: Icons.task_alt_rounded,
          titulo: 'Tudo em dia',
          apoio: 'Todas as aulas do mês têm chamada.',
          cor: c.verde,
          fundo: c.verdeFundo,
        ),
      );
    }
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TituloCartao(
            icone: Icons.checklist_rounded,
            titulo: 'Para fazer',
            apoio: total == 1 ? '1 pendência' : '$total pendências',
            cor: c.chipTexto,
            fundo: c.chipFundo,
          ),
          for (final (t, a) in pendentes.take(4)) ...[
            const SizedBox(height: 10),
            _LinhaPendencia(
              titulo: t.turma.disciplina,
              apoio: 'Chamada · ${_dataCurta(a.data)} · ${formatarHoraMin(a.inicioMin)}',
              botao: _BotaoAcao(
                texto: 'Fazer chamada',
                icone: Icons.how_to_reg_rounded,
                aoTocar: () => abrirChamada(context, t.turma, a),
              ),
            ),
          ],
          if (pendentes.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                pendentes.length == 5
                    ? 'e mais 1 chamada na aba Turmas'
                    : 'e mais ${pendentes.length - 4} chamadas na aba Turmas',
                style: AppTexto.rotulo.copyWith(color: c.secundario),
              ),
            ),
          for (final t in notas) ...[
            const SizedBox(height: 10),
            _LinhaPendencia(
              titulo: t.turma.disciplina,
              apoio: 'Notas · lançamento aberto',
              botao: _BotaoAcao(
                texto: 'Lançar notas',
                icone: Icons.grading_rounded,
                contorno: true,
                aoTocar: () => abrirNotas(context, t.turma),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma pendência: nome em cima, data e o botão da ação embaixo, sem espremer o texto.
class _LinhaPendencia extends StatelessWidget {
  const _LinhaPendencia({required this.titulo, required this.apoio, required this.botao});

  final String titulo, apoio;
  final Widget botao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(color: c.fundo, borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: AppTexto.corpoForte, maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            children: [
              Expanded(
                child: Text(apoio, style: AppTexto.apoio.copyWith(color: c.secundario)),
              ),
              const SizedBox(width: 8),
              botao,
            ],
          ),
        ],
      ),
    );
  }
}

/// A chamada é feita na página oficial da aula, dentro do app. Ao voltar, as pendências são relidas.
Future<void> abrirChamada(BuildContext context, TurmaProfessor turma, AulaAgenda aula) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaSiteOficial(
        titulo: 'Chamada · ${_dataCurta(aula.data)}',
        endereco: urlProfessorChamada(aula.idAgenda!),
        dica:
            'Toque no quadradinho de cada aluno para marcar presença (verde) ou falta (vermelho). '
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
              subtitulo: prof.semestre == null ? null : semestreCurto(prof.semestre!),
              acoes: [BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context))],
            ),
            if (turmas == null)
              prof.carregando
                  ? const Skeleton(altura: 120, raio: AppMedidas.raioCartao)
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
              const Cartao(
                child: EstadoVazio(icone: Icons.groups_rounded, titulo: 'Nenhuma turma neste semestre'),
              )
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.disciplina, style: AppTexto.tituloCartao),
                    const SizedBox(height: 2),
                    Text(
                      [t.nome, if (t.curso != null) t.curso!].join(' · '),
                      style: AppTexto.apoio.copyWith(color: c.secundario),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.secundario),
            ],
          ),
          if (d != null && d.horarios.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: c.secundario),
                const SizedBox(width: 6),
                Expanded(child: Text(_resumoHorarios(d.horarios), style: AppTexto.apoio)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (d?.matriculas != null) Selo(texto: '${d!.matriculas} alunos', cor: c.secundario, fundo: c.chrome),
              if (d?.cargaHorariaRealizada != null)
                Selo(texto: '${d!.cargaHorariaRealizada} h dadas', cor: c.secundario, fundo: c.chrome),
              if (sem > 0)
                Selo(texto: sem == 1 ? '1 sem chamada' : '$sem sem chamada', cor: c.perigo, fundo: c.perigoFundo)
              else if (turma.aulasDoMes != null)
                Selo(texto: 'Chamadas em dia', cor: c.verde, fundo: c.verdeFundo),
              if (t.lancamentoNotasAberto) Selo(texto: 'Notas abertas', cor: c.verde, fundo: c.verdeFundo),
            ],
          ),
        ],
      ),
    );
  }
}

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
    final sem = turma.semChamada(agora).length;
    final horarios = [...?d?.horarios]..sort((a, b) => a.diaSemana.compareTo(b.diaSemana));
    return Scaffold(
      body: ListaDaTela(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BotaoRedondo(
                icone: Icons.arrow_back_rounded,
                descricao: 'Voltar',
                aoTocar: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.disciplina, style: AppTexto.tituloTela),
                    Text(
                      [t.nome, if (t.codigo != null) t.codigo!].join(' · '),
                      style: AppTexto.apoio.copyWith(color: c.secundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _linhaDeNumeros([
                  if (d?.matriculas != null)
                    _Numero('Alunos', d!.vagas == null ? '${d.matriculas}' : '${d.matriculas} / ${d.vagas}'),
                  if (d?.cargaHorariaRealizada != null) _Numero('Carga dada', '${d!.cargaHorariaRealizada} h'),
                  _Numero('Sem chamada', '$sem'),
                ]),
                const SizedBox(height: 14),
                _BotaoAcao(
                  texto: 'Fazer chamada',
                  icone: Icons.how_to_reg_rounded,
                  grande: true,
                  aoTocar: () => _escolherAula(context, turma, agora),
                ),
                const SizedBox(height: 10),
                _BotaoAcao(
                  texto: t.lancamentoNotasAberto ? 'Lançar notas · aberto' : 'Lançar notas',
                  icone: Icons.grading_rounded,
                  grande: true,
                  contorno: true,
                  aoTocar: () => abrirNotas(context, t),
                ),
              ],
            ),
          ),
          if (aulas.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TituloCartao(
                    icone: Icons.event_note_rounded,
                    titulo: 'Aulas deste mês',
                    apoio: sem == 0 ? 'Todas as aulas dadas têm chamada' : 'As sem chamada têm o botão ao lado',
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < aulas.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: c.borda),
                    _LinhaAula(turma: t, aula: aulas[i], agora: agora),
                  ],
                ],
              ),
            ),
          if (horarios.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TituloCartao(icone: Icons.schedule_rounded, titulo: 'Horários'),
                  const SizedBox(height: 10),
                  for (final h in horarios)
                    _Dado(
                      _diasLongos[h.diaSemana - 1],
                      '${_faixaHorario(h.inicioMin, h.fimMin)}${h.tipo == null ? '' : ' · ${h.tipo}'}',
                    ),
                ],
              ),
            ),
          if (d != null && d.modeloNotas.isNotEmpty)
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TituloCartao(icone: Icons.grading_rounded, titulo: 'Avaliações'),
                  const SizedBox(height: 10),
                  for (final g in d.modeloNotas) ...[
                    Text('${g.rotulo} · peso ${g.peso}', style: AppTexto.corpoForte),
                    for (final a in g.avaliacoes)
                      Text('${a.nome} (${a.codigo}) · ${a.peso}', style: AppTexto.apoio.copyWith(color: c.secundario)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TituloCartao(icone: Icons.info_outline_rounded, titulo: 'Sobre a turma'),
                const SizedBox(height: 10),
                if ((d?.curso ?? t.curso) != null) _Dado('Curso', (d?.curso ?? t.curso)!),
                if (t.periodo != null) _Dado('Período', t.periodo!),
                if (d?.tipo != null) _Dado('Tipo', d!.tipo!),
                if (t.situacaoFrequencia != null) _Dado('Frequência', t.situacaoFrequencia!),
                if (t.situacaoNotas != null) _Dado('Notas', t.situacaoNotas!),
                for (final x in d?.docentes ?? const <(String, String)>[]) _Dado(x.$2, x.$1),
              ],
            ),
          ),
          ItemLista(
            icone: Icons.calendar_month_rounded,
            corIcone: c.navAtivo,
            fundoIcone: c.navAtivoFundo,
            titulo: 'Agenda da turma no portal',
            subtitulo: 'Página oficial',
            aoTocar: () => _abrirNoPortal(context, 'Agenda da turma', urlProfessorAgenda(t.id)),
          ),
        ],
      ),
    );
  }
}

/// Uma aula do mês: data, conteúdo e, à direita, o que dá para fazer com ela.
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
    final pode = aula.idAgenda != null && !futura;
    final Widget direita;
    if (aula.chamadaLancada) {
      direita = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Selo(texto: 'Feita', cor: c.verde, fundo: c.verdeFundo),
          if (pode)
            IconButton(
              onPressed: () => abrirChamada(context, turma, aula),
              tooltip: 'Corrigir chamada',
              icon: Icon(Icons.edit_rounded, size: 20, color: c.secundario),
            ),
        ],
      );
    } else if (pode) {
      direita = _BotaoAcao(
        texto: 'Fazer chamada',
        icone: Icons.how_to_reg_rounded,
        aoTocar: () => abrirChamada(context, turma, aula),
      );
    } else {
      direita = Selo(texto: futura ? 'Ainda não' : 'Sem chamada', cor: c.secundario, fundo: c.chrome);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(_diasCurtos[aula.data.weekday - 1], style: AppTexto.rotulo.copyWith(color: c.secundario)),
                Text('${aula.data.day}/${aula.data.month}', style: AppTexto.corpoForte),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_faixaHorario(aula.inicioMin, aula.fimMin), style: AppTexto.corpo),
                if (aula.conteudo != null)
                  Text(
                    aula.conteudo!,
                    style: AppTexto.rotulo.copyWith(color: c.secundario),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          direita,
        ],
      ),
    );
  }
}

/// "Fazer chamada" na tela da turma: abre direto se só uma aula espera; senão, deixa escolher.
Future<void> _escolherAula(BuildContext context, TurmaCompleta turma, DateTime agora) async {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final passadas =
      [
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
              pendentes.isEmpty
                  ? 'Todas já têm chamada. Escolha uma para corrigir.'
                  : 'As aulas sem chamada aparecem primeiro.',
              style: AppTexto.apoio.copyWith(color: folha.cores.secundario),
            ),
            for (final a in passadas) ...[
              const SizedBox(height: 10),
              _LinhaPendencia(
                titulo: '${_dataCurta(a.data)} · ${_faixaHorario(a.inicioMin, a.fimMin)}',
                apoio: a.chamadaLancada ? 'Chamada feita' : 'Sem chamada',
                botao: _BotaoAcao(
                  texto: a.chamadaLancada ? 'Corrigir' : 'Fazer chamada',
                  icone: a.chamadaLancada ? Icons.edit_rounded : Icons.how_to_reg_rounded,
                  contorno: a.chamadaLancada,
                  aoTocar: () {
                    Navigator.of(folha).pop();
                    abrirChamada(context, turma.turma, a);
                  },
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(rotulo, style: AppTexto.apoio.copyWith(color: c.secundario)),
          ),
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
          acoes: [BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context))],
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
          aoTocar: () =>
              _abrirNoPortal(context, 'Mais relatórios', 'https://portal.ufac.br/relatorios/relatorios.action'),
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
