import 'package:flutter/material.dart';

import '../config.dart';
import '../data/classroom.dart';
import '../data/foto_perfil.dart';
import '../data/perfil.dart';
import '../data/preferencias.dart';
import '../data/repositorio_professor.dart';
import '../data/repositorio_portal.dart';
import '../data/repositorio_ru.dart';
import '../session/sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import 'boas_vindas.dart';
import 'classroom.dart';
import 'configuracoes.dart';
import 'site_oficial.dart';

void abrirMenu(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaMenu()));
}

Future<void> confirmarSaida(BuildContext context) async {
  final navegador = Navigator.of(context);
  final sair = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Sair da conta?'),
      content: const Text(
        'Sua sessão, os dados salvos, o número do QR e a foto serão apagados deste celular. '
        'Depois é só entrar de novo com seu ID Ufac.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Sair')),
      ],
    ),
  );
  if (sair != true) return;
  await Sessao.instancia.sair();
  await Classroom.instancia.desconectar();
  await AtividadesDaSemana.instancia.limpar();
  await RepositorioRu.instancia.limpar();
  RepositorioPortal.instancia.limpar();
  RepositorioProfessor.instancia.limpar();
  await FotoPerfil.instancia.remover();
  Preferencias.instancia.limpar();
  Perfil.instancia.limpar();
  navegador.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TelaBoasVindas()), (_) => false);
}

class TelaMenu extends StatelessWidget {
  const TelaMenu({super.key});

  Future<void> _abrirSite(BuildContext context, String titulo, String Function(String id)? comId, {String? js}) async {
    final navegador = Navigator.of(context);
    // Sem o número interno, a página inicial do portal pede o login e a pessoa segue por lá.
    final id = comId == null ? null : await RepositorioPortal.instancia.garantirIdInterno();
    final endereco = comId == null || id == null ? urlPortal : comId(id);
    navegador.push(
      MaterialPageRoute(builder: (_) => TelaSiteOficial(titulo: titulo, endereco: endereco, jsAoCarregar: js)),
    );
  }

  Future<void> _abrirComunicacoes(BuildContext context) async {
    final navegador = Navigator.of(context);
    final endereco = await RepositorioPortal.instancia.lerEnderecoComunicacoesDoPortal();
    navegador.push(
      MaterialPageRoute(builder: (_) => TelaSiteOficial(titulo: 'Comunicações', endereco: endereco ?? urlPortal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final professor = Perfil.instancia.ehProfessor;
    final atalhos = professor ? _atalhosProfessor(context) : [
      _Atalho(Icons.how_to_reg_rounded, 'Matrícula', () => _abrirSite(context, 'Matrícula', urlMatricula)),
      _Atalho(Icons.local_library_rounded, 'Biblioteca', () => _abrirSite(context, 'Biblioteca', urlBiblioteca)),
      _Atalho(Icons.campaign_rounded, 'Comunicações', () => _abrirComunicacoes(context)),
      _Atalho(
        Icons.link_rounded,
        'Links externos',
        () => _abrirSite(context, 'Links externos', null, js: 'if (window.modalLinksExternos) modalLinksExternos();'),
      ),
      _Atalho(Icons.language_rounded, 'Abrir site completo', () => _abrirSite(context, 'Portal do Aluno', null)),
      _Atalho(
        Icons.school_rounded,
        'Classroom',
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaClassroom())),
      ),
    ];
    return Scaffold(
      body: ListaDaTela(
        children: [
          CabecalhoTela(
            titulo: 'Menu',
            acoes: [
              BotaoRedondo(
                icone: Icons.close_rounded,
                descricao: 'Fechar',
                aoTocar: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(professor ? 'Portal do Professor' : 'Portal do Aluno', style: AppTexto.tituloCartao),
          for (var i = 0; i < atalhos.length; i += 2)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CartaoAtalho(atalho: atalhos[i])),
                  const SizedBox(width: AppMedidas.entreCartoes),
                  Expanded(child: i + 1 < atalhos.length ? _CartaoAtalho(atalho: atalhos[i + 1]) : const SizedBox()),
                ],
              ),
            ),
          const SizedBox(height: 4),
          BotaoContorno(
            texto: 'Configurações',
            icone: Icons.settings_rounded,
            cor: c.navAtivo,
            aoTocar: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TelaConfiguracoes()),
            ),
          ),
          BotaoContorno(
            texto: 'Sair',
            icone: Icons.logout_rounded,
            cor: c.perigo,
            aoTocar: () => confirmarSaida(context),
          ),
        ],
      ),
    );
  }
}

List<_Atalho> _atalhosProfessor(BuildContext context) {
  void abrir(String titulo, String endereco) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TelaSiteOficial(titulo: titulo, endereco: endereco)),
      );
  return [
    _Atalho(Icons.local_library_rounded, 'Biblioteca', () => abrir('Biblioteca', 'https://portal.ufac.br/biblioteca/pesquisa/pesquisar.action')),
    _Atalho(Icons.link_rounded, 'Links', () => abrir('Links', 'https://portal.ufac.br/professor/professor/links/links.action')),
    _Atalho(Icons.campaign_rounded, 'Comunicações', () => abrir('Comunicações', 'https://portal.ufac.br/comunicacoes/index.action')),
    _Atalho(Icons.language_rounded, 'Abrir site completo', () => abrir('Portal do Professor', urlProfessorInicio)),
  ];
}

class _Atalho {
  const _Atalho(this.icone, this.titulo, this.aoTocar);
  final IconData icone;
  final String titulo;
  final VoidCallback aoTocar;
}

class _CartaoAtalho extends StatelessWidget {
  const _CartaoAtalho({required this.atalho});

  final _Atalho atalho;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      aoTocar: atalho.aoTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconeQuadrado(icone: atalho.icone, cor: c.navAtivo, fundo: c.navAtivoFundo),
          const SizedBox(height: 10),
          Text(atalho.titulo, style: AppTexto.corpoForte),
        ],
      ),
    );
  }
}
