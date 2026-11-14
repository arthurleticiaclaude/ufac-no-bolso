import 'package:flutter/material.dart';

import '../config.dart';
import '../data/academico.dart';
import '../data/atualizacoes.dart';
import '../data/classroom.dart';
import '../data/feriados.dart';
import '../data/foto_perfil.dart';
import '../data/preferencias.dart';
import '../data/refeicoes.dart';
import '../data/repositorio_portal.dart';
import '../data/repositorio_ru.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'acoes_portal.dart';
import 'aviso_faltas.dart';
import 'classroom.dart';
import 'login.dart';
import 'menu.dart';
import 'ru.dart';
import 'site_oficial.dart';

class TelaInicio extends StatelessWidget {
  const TelaInicio({super.key, required this.abrirRu});

  final VoidCallback abrirRu;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ListenableBuilder(
      listenable: RepositorioPortal.instancia,
      builder: (context, _) => _construir(context, c, RepositorioPortal.instancia),
    );
  }

  Future<void> _atualizar(BuildContext context) async {
    await Future.wait([
      RepositorioRu.instancia.atualizar(),
      atualizarPortal(context),
      AtividadesDaSemana.instancia.atualizar(),
    ]);
  }

  Widget _construir(BuildContext context, AppCores c, RepositorioPortal portal) {
    final agora = DateTime.now();
    final identificacao = portal.identificacao;
    final refeicao = proximaRefeicao(agora);
    final aula = proximaAula(portal.aulas ?? const [], agora);
    return ListaDaTela(
      aoAtualizar: () => _atualizar(context),
      children: [
        CabecalhoTela(
          titulo: identificacao == null ? 'Olá' : 'Olá, ${identificacao.primeiroNome}',
          sobretitulo: formatarData(agora),
          acoes: [
            BotaoRedondo(
              icone: Icons.notifications_rounded,
              descricao: 'Notificações',
              aoTocar: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TelaSiteOficial(titulo: 'Avisos do RU', endereco: urlAvisosRu),
                ),
              ),
            ),
            BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
          ],
        ),
        ...faixasDaInicio(context, agora),
        if (identificacao != null)
          _CartaoIdentificacao(identificacao: identificacao, matricula: portal.matricula)
        else if (portal.carregando)
          const Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(largura: 200, altura: 20),
                SizedBox(height: 12),
                Skeleton(altura: 56, raio: AppMedidas.raioBotao),
              ],
            ),
          )
        else
          Cartao(
            child: EstadoVazio(
              icone: Icons.badge_rounded,
              titulo: 'Ainda não li seus dados do Portal',
              texto: 'Entre no Portal do Aluno para ver nome, curso e horários.',
              acao: BotaoContorno(
                texto: 'Entrar no Portal',
                cor: c.navAtivo,
                aoTocar: () => entrarNoPortal(context),
              ),
            ),
          ),
        const CartaoSaldo(tituloSaldo: 'Saldo no RU', compacto: true),
        if (portal.aulas != null)
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
                      if (notasDaDisciplina(portal.notas, aula.aula.disciplina) case final n?) ...[
                        const SizedBox(height: 10),
                        AvisoFaltas(nota: n),
                      ],
                    ],
                  ),
          ),
        const _CartaoAtividades(),
        linhaProximaRefeicao(refeicao, abrirRu),
      ],
    );
  }
}


class _CartaoIdentificacao extends StatelessWidget {
  const _CartaoIdentificacao({required this.identificacao, required this.matricula});

  final Identificacao identificacao;
  final String? matricula;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      child: Column(
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
                            ? Image.memory(foto, width: 64, height: 64, fit: BoxFit.cover)
                            : Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                color: c.navAtivoFundo,
                                child: Text(
                                  identificacao.iniciais,
                                  style: AppTexto.tituloCartao.copyWith(color: c.navAtivo),
                                ),
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
                    Text(identificacao.nome, style: AppTexto.tituloCartao),
                    const SizedBox(height: 2),
                    Text('${identificacao.curso} · Ufac', style: AppTexto.apoio.copyWith(color: c.secundario)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(flex: 5, child: _BlocoDado(rotulo: 'Matrícula', valor: matricula ?? '–')),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _BlocoDado(rotulo: 'Período', valor: '${identificacao.periodo}º')),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _BlocoDado(rotulo: 'Semestre', valor: semestreCurto(identificacao.semestre)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlocoDado extends StatelessWidget {
  const _BlocoDado({required this.rotulo, required this.valor});

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
          Text(rotulo, style: AppTexto.rotulo.copyWith(color: c.secundario)),
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

/// Atividades do Classroom com prazo nesta semana. Sem Google conectado, vira um atalho discreto.
class _CartaoAtividades extends StatelessWidget {
  const _CartaoAtividades();

  void _abrir(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaClassroom()));

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return ListenableBuilder(
      listenable: AtividadesDaSemana.instancia,
      builder: (context, _) {
        final repo = AtividadesDaSemana.instancia;
        final lista = repo.lista;
        if (!repo.conectado && lista == null) {
          if (repo.carregando) return const SizedBox.shrink();
          return ItemLista(
            icone: Icons.school_rounded,
            corIcone: c.navAtivo,
            fundoIcone: c.navAtivoFundo,
            subtitulo: 'Classroom',
            titulo: 'Ver suas atividades da semana',
            aoTocar: () => _abrir(context),
          );
        }
        final em = repo.atualizadoEm;
        final rodape = repo.erro != null && em != null
            ? 'Não consegui falar com o Classroom agora — mostrando dados das ${formatarHora(em.hour, em.minute)}'
            : em == null
                ? null
                : 'Atualizado às ${formatarHora(em.hour, em.minute)}';
        return Cartao(
          aoTocar: () => _abrir(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Atividades da semana', style: AppTexto.tituloCartao)),
                  Icon(Icons.chevron_right_rounded, color: c.secundario),
                ],
              ),
              const SizedBox(height: 10),
              if (lista == null)
                const Skeleton(altura: 44, raio: AppMedidas.raioBotao)
              else if (lista.isEmpty)
                Text('Nada para entregar nos próximos 7 dias.', style: AppTexto.apoio.copyWith(color: c.secundario))
              else
                for (final a in lista.take(3)) _LinhaAtividade(atividade: a),
              if (lista != null && lista.length > 3)
                Text('e mais ${lista.length - 3}', style: AppTexto.rotulo.copyWith(color: c.secundario)),
              if (rodape != null) ...[
                const SizedBox(height: 6),
                Text(rodape, style: AppTexto.rotulo.copyWith(color: c.secundario)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LinhaAtividade extends StatelessWidget {
  const _LinhaAtividade({required this.atividade});
  final Atividade atividade;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final atrasada = atividade.situacao == SituacaoEntrega.atrasada;
    final prazo = atividade.prazo!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Selo(
            texto: atrasada ? 'Atrasada' : formatarPrazoCurto(prazo, DateTime.now()),
            cor: atrasada ? c.perigo : c.chipTexto,
            fundo: atrasada ? c.perigoFundo : c.chipFundo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(atividade.titulo, style: AppTexto.corpoForte, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (atividade.turma != null)
                  Text(
                    atividade.turma!,
                    style: AppTexto.rotulo.copyWith(color: c.secundario),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixas de aviso do topo da Início (sessão do eTICKET, versão nova, feriado). Também na Início do professor.
List<Widget> faixasDaInicio(BuildContext context, DateTime agora) => [
    ListenableBuilder(
      listenable: Sessao.instancia,
      builder: (context, _) {
        // O portal cai em menos de 1 hora; só o eTICKET merece aviso.
        if (!Sessao.instancia.expirados.contains(Sistema.eticket)) return const SizedBox.shrink();
        return FaixaAviso(
          icone: Icons.history_toggle_off_rounded,
          texto: 'Sua sessão terminou. Mostrando os dados salvos.',
          acao: 'Entrar de novo',
          aoTocar: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TelaLogin(
                etapas: const [Sistema.eticket],
                aoConcluir: (rota) {
                  Navigator.of(rota).pop();
                  RepositorioRu.instancia.atualizar();
                },
              ),
            ),
          ),
        );
      },
    ),
    ListenableBuilder(
      listenable: Atualizacoes.instancia,
      builder: (context, _) {
        final atualizacoes = Atualizacoes.instancia;
        if (atualizacoes.nova == null) return const SizedBox.shrink();
        return FaixaAviso(
          icone: Icons.system_update_rounded,
          texto: atualizacoes.baixando ? 'Baixando a nova versão…' : 'Nova versão disponível',
          acao: atualizacoes.baixando ? null : 'Atualizar',
          aoTocar: atualizacoes.baixando
              ? null
              : () async {
                  final mensageiro = ScaffoldMessenger.of(context);
                  if (!await atualizacoes.baixarEInstalar()) {
                    mensageiro.showSnackBar(
                      const SnackBar(content: Text('Não consegui baixar a nova versão agora.')),
                    );
                  }
                },
        );
      },
    ),
    ListenableBuilder(
      listenable: Preferencias.instancia,
      builder: (context, _) {
        final aviso = Preferencias.instancia.avisarFeriados ? avisoFeriado(agora) : null;
        if (aviso == null) return const SizedBox.shrink();
        return FaixaAviso(icone: Icons.event_rounded, texto: '${aviso.titulo}\n${aviso.texto}');
      },
    ),
    ];

/// "Próxima refeição", que abre a aba RU.
Widget linhaProximaRefeicao(Refeicao refeicao, VoidCallback abrirRu) => ListenableBuilder(
      listenable: RepositorioRu.instancia,
      builder: (context, _) {
        final c = context.cores;
        final itens = RepositorioRu.instancia.cardapioDeHoje?.itens(refeicao) ?? const <String>[];
        return ItemLista(
          icone: Icons.restaurant_rounded,
          corIcone: c.verde,
          fundoIcone: c.verdeFundo,
          subtitulo:
              'Próxima refeição · ${refeicao.nome} · ${formatarHoraMin(refeicao.horario.inicioMin)} às ${formatarHoraMin(refeicao.horario.fimMin)}',
          titulo: itens.isEmpty ? 'O cardápio ainda não saiu' : itens.first,
          aoTocar: abrirRu,
        );
      },
    );
