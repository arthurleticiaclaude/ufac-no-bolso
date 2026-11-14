import 'package:flutter/material.dart';

import '../config.dart';
import '../data/academico.dart';
import '../data/repositorio_portal.dart';
import '../pdf/servico_pdf.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import 'acoes_portal.dart';
import 'menu.dart';
import 'site_oficial.dart';
import 'pdf.dart';

class TelaRelatorios extends StatelessWidget {
  const TelaRelatorios({super.key, this.comVoltar = false});

  /// Aberta pelo Menu (o aluno tem Biblioteca na barra): ganha tela própria e botão de fechar.
  final bool comVoltar;

  @override
  Widget build(BuildContext context) {
    final tela = ListenableBuilder(
      listenable: RepositorioPortal.instancia,
      builder: (context, _) => _construir(context),
    );
    return comVoltar ? Scaffold(body: tela) : tela;
  }

  Widget _construir(BuildContext context) {
    final c = context.cores;
    final id = RepositorioPortal.instancia.identificacao;
    return ListaDaTela(
      children: [
        CabecalhoTela(
          titulo: 'Relatórios',
          subtitulo: id == null ? null : '${id.curso} · ${id.periodo}º período · ${semestreCurto(id.semestre)}',
          acoes: [
            comVoltar
                ? BotaoRedondo(
                    icone: Icons.close_rounded,
                    descricao: 'Fechar',
                    aoTocar: () => Navigator.of(context).maybePop(),
                  )
                : BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context)),
          ],
        ),
        Cartao(
          preenchimento: const EdgeInsets.symmetric(horizontal: AppMedidas.interno, vertical: 4),
          child: Column(
            children: [
              for (final r in RelatorioPortal.values) ...[
                if (r != RelatorioPortal.values.first) Divider(height: 1, color: c.borda),
                _LinhaRelatorio(relatorio: r),
              ],
            ],
          ),
        ),
        ItemLista(
          icone: Icons.folder_open_rounded,
          corIcone: c.navAtivo,
          fundoIcone: c.navAtivoFundo,
          titulo: 'Mais relatórios',
          aoTocar: () => _abrirMaisRelatorios(context),
        ),
        Text(
          'Os PDFs são gerados pelo Portal do Aluno na hora do pedido',
          style: AppTexto.rotulo.copyWith(color: c.secundario),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

void _avisar(BuildContext context, String texto, {SnackBarAction? acao}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), action: acao));
}

Future<void> _abrirMaisRelatorios(BuildContext context) async {
  final navegador = Navigator.of(context);
  final endereco = await RepositorioPortal.instancia.lerEnderecoMaisRelatorios();
  if (!context.mounted) return;
  if (endereco == null) {
    _avisar(
      context,
      'Para ver mais relatórios, entre no Portal.',
      acao: SnackBarAction(
        label: 'Entrar',
        onPressed: () => entrarNoPortal(context, aoEntrar: () => _abrirMaisRelatorios(context)),
      ),
    );
    return;
  }
  navegador.push(MaterialPageRoute(builder: (_) => TelaSiteOficial(titulo: 'Mais relatórios', endereco: endereco)));
}

class _LinhaRelatorio extends StatefulWidget {
  const _LinhaRelatorio({required this.relatorio});

  final RelatorioPortal relatorio;

  @override
  State<_LinhaRelatorio> createState() => _LinhaRelatorioState();
}

class _LinhaRelatorioState extends State<_LinhaRelatorio> {
  bool _ocupado = false;

  Future<void> _abrir({required bool visualizar}) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final navegador = Navigator.of(context);
    final resultado = await ServicoPdf.deRelatorio(widget.relatorio);
    if (!mounted) return;
    setState(() => _ocupado = false);
    final arquivo = resultado.arquivo;
    switch (resultado.status) {
      case StatusPdf.sessaoExpirada:
        _avisar(
          context,
          'Para abrir os PDFs, entre no Portal.',
          acao: SnackBarAction(
            label: 'Entrar',
            onPressed: () => entrarNoPortal(context, aoEntrar: () => _abrir(visualizar: visualizar)),
          ),
        );
      case StatusPdf.semConexao:
        _avisar(context, 'Não consegui falar com o Portal agora. Confira sua internet.');
      case StatusPdf.pronto:
        if (visualizar) {
          navegador.push(
            MaterialPageRoute(builder: (_) => TelaPdf(arquivo: arquivo!, titulo: widget.relatorio.nome)),
          );
          return;
        }
        final salvou = await salvarPdf(arquivo!);
        arquivo.delete().ignore();
        if (salvou && mounted) _avisar(context, 'PDF salvo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final nome = widget.relatorio.nome;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.perigoFundo, borderRadius: BorderRadius.circular(AppMedidas.raioIcone)),
            child: Text('PDF', style: AppTexto.rotulo.copyWith(color: c.perigo)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(nome, style: AppTexto.corpo)),
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Skeleton(largura: 76, altura: 40, raio: AppMedidas.raioBotao),
            )
          else ...[
            IconButton(
              onPressed: () => _abrir(visualizar: true),
              tooltip: 'Visualizar',
              icon: const Icon(Icons.visibility_rounded, size: 20),
              style: IconButton.styleFrom(backgroundColor: c.navAtivoFundo, foregroundColor: c.navAtivo),
            ),
            IconButton(
              onPressed: () => _abrir(visualizar: false),
              tooltip: 'Baixar',
              icon: const Icon(Icons.download_rounded, size: 20),
              style: IconButton.styleFrom(backgroundColor: c.primaria, foregroundColor: c.sobrePrimaria),
            ),
          ],
        ],
      ),
    );
  }
}
