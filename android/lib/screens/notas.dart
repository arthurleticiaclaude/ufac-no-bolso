import 'package:flutter/material.dart';

import '../data/academico.dart';
import '../data/repositorio_portal.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'acoes_portal.dart';
import 'aviso_faltas.dart';
import 'menu.dart';

class TelaNotas extends StatelessWidget {
  const TelaNotas({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RepositorioPortal.instancia,
      builder: (context, _) => _construir(context, RepositorioPortal.instancia),
    );
  }

  Widget _construir(BuildContext context, RepositorioPortal portal) {
    final c = context.cores;
    final notas = portal.notas;
    final lidas = portal.notasLidasEm;
    return ListaDaTela(
      aoAtualizar: () => atualizarPortal(context),
      children: [
        CabecalhoTela(
          titulo: 'Notas',
          subtitulo: portal.semestreDasNotas,
          acoes: [
            BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
          ],
        ),
        if (lidas != null)
          Text(
            'Lidas em ${formatarDiaHora(lidas)}. Puxe para atualizar.',
            style: AppTexto.rotulo.copyWith(color: c.secundario),
          ),
        if (notas == null)
          portal.carregando
              ? const Skeleton(altura: 110, raio: AppMedidas.raioCartao)
              : Cartao(
                  child: EstadoVazio(
                    icone: Icons.grading_rounded,
                    titulo: 'Ainda não li suas notas',
                    texto: 'Entre no Portal do Aluno para ver as notas deste semestre.',
                    acao: BotaoContorno(
                      texto: 'Entrar no Portal',
                      cor: c.navAtivo,
                      aoTocar: () => entrarNoPortal(context),
                    ),
                  ),
                )
        else if (notas.isEmpty)
          const Cartao(child: EstadoVazio(icone: Icons.grading_rounded, titulo: 'Sem disciplinas neste semestre'))
        else
          for (final n in notas) _CartaoNota(nota: n),
      ],
    );
  }
}

class _CartaoNota extends StatelessWidget {
  const _CartaoNota({required this.nota});

  final NotasDisciplina nota;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final aprovado = nota.situacao.toLowerCase().contains('aprovado') && !nota.situacao.toLowerCase().contains('reprovado');
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(nota.disciplina, style: AppTexto.corpoForte)),
              const SizedBox(width: 8),
              Selo(
                texto: nota.situacaoApresentavel,
                cor: aprovado ? c.verde : c.navAtivo,
                fundo: aprovado ? c.verdeFundo : c.navAtivoFundo,
              ),
            ],
          ),
          // O mesmo quadro que o portal mostra ao abrir as notas da disciplina.
          for (final a in nota.notas) ...[
            const SizedBox(height: 12),
            Text(
              a.peso.isEmpty ? a.rotulo : '${a.rotulo} · peso ${_pesoCurto(a.peso)}',
              style: AppTexto.rotulo.copyWith(color: c.secundario),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [for (final i in a.itens) _Valor(rotulo: i.rotulo, detalhe: _pesoCurto(i.peso), valor: i.valor)],
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: c.borda),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              if (nota.resumo.isEmpty) _Valor(rotulo: 'Média Final', valor: nota.media),
              for (final i in nota.resumo) _Valor(rotulo: i.rotulo, valor: i.valor),
              _Valor(rotulo: 'Faltas', valor: nota.faltas),
            ],
          ),
          const SizedBox(height: 10),
          AvisoFaltas(nota: nota),
        ],
      ),
    );
  }
}

/// "100.00%" vira "100%"; "33.33%" fica igual.
String _pesoCurto(String peso) => peso.replaceFirst(RegExp(r'[.,]00%$'), '%');

class _Valor extends StatelessWidget {
  const _Valor({required this.rotulo, required this.valor, this.detalhe = ''});

  final String rotulo, valor, detalhe;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: AppTexto.rotulo.copyWith(color: c.secundario)),
        if (detalhe.isNotEmpty) Text(detalhe, style: AppTexto.rotulo.copyWith(color: c.secundario)),
        const SizedBox(height: 2),
        Text(valor.isEmpty ? '–' : valor, style: AppTexto.tituloCartao),
      ],
    );
  }
}
