import 'package:flutter/material.dart';

import '../data/historico.dart';
import '../data/repositorio_ru.dart';
import '../session/regras_sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'login.dart';

/// Refeições e recargas do eTICKET. Abre com o que está salvo e lê de novo em seguida.
class TelaHistorico extends StatefulWidget {
  const TelaHistorico({super.key});

  @override
  State<TelaHistorico> createState() => _TelaHistoricoState();
}

class _TelaHistoricoState extends State<TelaHistorico> {
  int _aba = 0;
  bool _lendo = true;
  ResultadoHistorico? _resultado;

  @override
  void initState() {
    super.initState();
    _atualizar();
  }

  Future<void> _atualizar() async {
    setState(() => _lendo = true);
    final resultado = await RepositorioRu.instancia.atualizarHistorico();
    if (mounted) {
      setState(() {
        _lendo = false;
        _resultado = resultado;
      });
    }
  }

  void _entrar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaLogin(
          etapas: const [Sistema.eticket],
          aoConcluir: (rota) {
            Navigator.of(rota).pop();
            _atualizar();
          },
        ),
      ),
    );
  }

  Widget? _aviso(HistoricoRu? historico) {
    final desde = historico == null ? '' : ' Mostrando dados de ${formatarDiaHora(historico.lidoEm)}.';
    return switch (_resultado) {
      ResultadoHistorico.sessaoExpirada => FaixaAviso(
          icone: Icons.history_toggle_off_rounded,
          texto: 'Sua sessão do eTICKET terminou.$desde',
          acao: 'Entrar',
          aoTocar: _entrar,
        ),
      ResultadoHistorico.falhou => FaixaAviso(
          icone: Icons.wifi_off_rounded,
          texto: 'Não consegui ler o histórico agora.$desde',
        ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: RepositorioRu.instancia,
        builder: (context, _) {
          final historico = RepositorioRu.instancia.historico;
          final aviso = _aviso(historico);
          return ListaDaTela(
            aoAtualizar: _atualizar,
            children: [
              Row(
                children: [
                  BotaoRedondo(
                    icone: Icons.arrow_back_rounded,
                    descricao: 'Voltar',
                    aoTocar: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Histórico de uso', style: AppTexto.tituloTela)),
                ],
              ),
              ?aviso,
              SeletorAbas(
                rotulos: const ['Refeições', 'Recargas'],
                atual: _aba,
                aoEscolher: (i) => setState(() => _aba = i),
              ),
              if (historico == null)
                _lendo
                    ? const Skeleton(altura: 76, raio: AppMedidas.raioCartao)
                    : const Cartao(
                        child: EstadoVazio(icone: Icons.history_rounded, titulo: 'Ainda não li seu histórico'),
                      )
              else if (_aba == 0) ...[
                if (historico.refeicoes.isEmpty)
                  const Cartao(child: EstadoVazio(icone: Icons.restaurant_rounded, titulo: 'Nenhuma refeição ainda')),
                for (final r in historico.refeicoes) _LinhaRefeicao(registro: r),
              ] else ...[
                if (historico.recargas.isEmpty)
                  const Cartao(child: EstadoVazio(icone: Icons.payments_rounded, titulo: 'Nenhuma recarga ainda')),
                for (final r in historico.recargas) _LinhaRecarga(registro: r),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _quando(String data, String hora) {
  final h = hora.replaceFirst(':', 'h');
  return [data, h].where((t) => t.isNotEmpty).join(' · ');
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.titulo,
    required this.detalhe,
    required this.valor,
    required this.situacao,
  });

  final IconData icone;
  final Color cor, fundo;
  final String titulo, detalhe, situacao;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconeQuadrado(icone: icone, cor: cor, fundo: fundo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTexto.corpoForte),
                Text(detalhe, style: AppTexto.apoio.copyWith(color: c.secundario)),
                if (situacao.isNotEmpty) Text(situacao, style: AppTexto.rotulo.copyWith(color: c.secundario)),
              ],
            ),
          ),
          if (valor != null) ...[
            const SizedBox(width: 8),
            Text(formatarMoeda(valor!), style: AppTexto.corpoForte),
          ],
        ],
      ),
    );
  }
}

class _LinhaRefeicao extends StatelessWidget {
  const _LinhaRefeicao({required this.registro});

  final RegistroRefeicao registro;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final partes = [_quando(registro.data, registro.hora), registro.prato].where((t) => t.isNotEmpty);
    return _Linha(
      icone: Icons.restaurant_rounded,
      cor: c.verde,
      fundo: c.verdeFundo,
      titulo: registro.refeicao.isEmpty ? 'Refeição' : registro.refeicao,
      detalhe: partes.join('\n'),
      valor: registro.valor,
      situacao: registro.status,
    );
  }
}

class _LinhaRecarga extends StatelessWidget {
  const _LinhaRecarga({required this.registro});

  final RegistroRecarga registro;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return _Linha(
      icone: Icons.payments_rounded,
      cor: c.navAtivo,
      fundo: c.navAtivoFundo,
      titulo: registro.forma.isEmpty ? 'Recarga' : 'Recarga · ${registro.forma}',
      detalhe: _quando(registro.data, registro.hora),
      valor: registro.valor,
      situacao: registro.situacao,
    );
  }
}
