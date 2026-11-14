import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/avisos_classroom.dart';
import '../data/classroom.dart';
import '../data/preferencias.dart';
import '../theme/app_cores.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';

/// Turmas do Classroom (só leitura).
class TelaClassroom extends StatefulWidget {
  const TelaClassroom({super.key});

  @override
  State<TelaClassroom> createState() => _TelaClassroomState();
}

class _TelaClassroomState extends State<TelaClassroom> {
  bool _carregando = true;
  bool _precisaEntrar = false;
  String? _erro;
  List<Turma> _turmas = const [];

  @override
  void initState() {
    super.initState();
    _carregar(silencioso: true);
  }

  Future<void> _carregar({bool silencioso = false, bool entrar = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (entrar) {
        await Classroom.instancia.entrar();
      } else if (silencioso && !await Classroom.instancia.conectarEmSilencio()) {
        setState(() {
          _carregando = false;
          _precisaEntrar = true;
        });
        return;
      }
      final turmas = await Classroom.instancia.turmas();
      if (entrar) AtividadesDaSemana.instancia.atualizar();
      // Quem usa o Classroom recebe o pedido do Android para avisos (ele só pergunta uma vez).
      if (Preferencias.instancia.avisarClassroom) {
        AvisosClassroom.instancia.pedirPermissao().then((ok) {
          final lista = AtividadesDaSemana.instancia.lista;
          if (ok && lista != null) AvisosClassroom.instancia.reagendar(lista);
        });
      }
      if (!mounted) return;
      setState(() {
        _turmas = turmas;
        _precisaEntrar = false;
        _carregando = false;
      });
    } on ErroClassroom catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _precisaEntrar = e.pedirLogin;
        _carregando = false;
      });
    }
  }

  Future<void> _desconectar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Desconectar o Google?'),
        content: const Text('O app perde o acesso ao seu Classroom. Para ver de novo, é só entrar outra vez.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Desconectar')),
        ],
      ),
    );
    if (ok != true) return;
    await Classroom.instancia.desconectar();
    await AtividadesDaSemana.instancia.limpar();
    if (!mounted) return;
    setState(() {
      _turmas = const [];
      _precisaEntrar = true;
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      body: ListaDaTela(
        aoAtualizar: _precisaEntrar ? null : () => _carregar(),
        children: [
          CabecalhoTela(
            titulo: 'Classroom',
            subtitulo: 'Suas turmas · só leitura',
            acoes: [
              BotaoRedondo(
                icone: Icons.close_rounded,
                descricao: 'Fechar',
                aoTocar: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (_carregando)
            for (var i = 0; i < 3; i++)
              const Cartao(child: Skeleton(altura: 44))
          else ...[
            if (_erro != null)
              Cartao(
                child: EstadoVazio(
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Não deu certo',
                  texto: _erro,
                  acao: _precisaEntrar
                      ? null
                      : BotaoContorno(texto: 'Tentar de novo', cor: c.navAtivo, aoTocar: () => _carregar()),
                ),
              ),
            if (_precisaEntrar)
              Cartao(
                child: Column(
                  children: [
                    EstadoVazio(
                      icone: Icons.school_rounded,
                      titulo: 'Entre com sua conta Google',
                      texto: 'O app só lê suas turmas e atividades. Nada é enviado para outro lugar.',
                    ),
                    BotaoDestaque(
                      texto: 'Entrar com Google',
                      icone: Icons.login_rounded,
                      aoTocar: () => _carregar(entrar: true),
                    ),
                  ],
                ),
              )
            else if (_erro == null) ...[
              if (_turmas.isEmpty)
                const Cartao(
                  child: EstadoVazio(icone: Icons.inbox_rounded, titulo: 'Nenhuma turma ativa nesta conta'),
                ),
              for (final t in _turmas)
                ItemLista(
                  icone: Icons.class_rounded,
                  corIcone: c.verde,
                  fundoIcone: c.verdeFundo,
                  titulo: t.nome,
                  subtitulo: t.secao,
                  aoTocar: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _TelaAtividades(turma: t)),
                  ),
                ),
              BotaoContorno(
                texto: 'Desconectar Google',
                icone: Icons.link_off_rounded,
                cor: c.perigo,
                aoTocar: _desconectar,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TelaAtividades extends StatefulWidget {
  const _TelaAtividades({required this.turma});
  final Turma turma;

  @override
  State<_TelaAtividades> createState() => _TelaAtividadesState();
}

class _TelaAtividadesState extends State<_TelaAtividades> {
  List<Atividade>? _lista;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final l = await Classroom.instancia.atividades(widget.turma.id);
      if (mounted) setState(() => _lista = l);
    } on ErroClassroom catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final lista = _lista;
    return Scaffold(
      body: ListaDaTela(
        aoAtualizar: _carregar,
        children: [
          CabecalhoTela(
            titulo: widget.turma.nome,
            subtitulo: 'Atividades · prazo mais próximo primeiro',
            acoes: [
              BotaoRedondo(
                icone: Icons.arrow_back_rounded,
                descricao: 'Voltar',
                aoTocar: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (_erro != null)
            Cartao(
              child: EstadoVazio(
                icone: Icons.cloud_off_rounded,
                titulo: 'Não deu certo',
                texto: _erro,
                acao: BotaoContorno(texto: 'Tentar de novo', cor: c.navAtivo, aoTocar: _carregar),
              ),
            )
          else if (lista == null)
            for (var i = 0; i < 3; i++)
              const Cartao(child: Skeleton(altura: 44))
          else if (lista.isEmpty)
            const Cartao(child: EstadoVazio(icone: Icons.task_alt_rounded, titulo: 'Nenhuma atividade nesta turma'))
          else
            for (final a in lista) _CartaoAtividade(atividade: a),
        ],
      ),
    );
  }
}

class _CartaoAtividade extends StatelessWidget {
  const _CartaoAtividade({required this.atividade});
  final Atividade atividade;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final (texto, cor, fundo) = switch (atividade.situacao) {
      SituacaoEntrega.entregue => ('Entregue', c.verde, c.verdeFundo),
      SituacaoEntrega.atrasada => ('Atrasada', c.perigo, c.perigoFundo),
      SituacaoEntrega.pendente => ('Pendente', c.chipTexto, c.chipFundo),
    };
    final prazo = atividade.prazo;
    final link = atividade.link;
    return Cartao(
      aoTocar: link == null
          ? null
          : () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Selo(texto: texto, cor: cor, fundo: fundo),
          const SizedBox(height: 8),
          Text(atividade.titulo, style: AppTexto.corpoForte),
          const SizedBox(height: 2),
          Text(
            prazo == null ? 'Sem prazo' : 'Prazo: ${formatarDiaHora(prazo)}',
            style: AppTexto.apoio.copyWith(color: c.secundario),
          ),
        ],
      ),
    );
  }
}
