import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import '../data/atualizacoes.dart';
import '../data/avisos_classroom.dart';
import '../data/classroom.dart';
import '../data/foto_perfil.dart';
import '../data/perfil.dart';
import '../data/preferencias.dart';
import '../data/repositorio_portal.dart';
import '../data/repositorio_biblioteca.dart';
import '../data/repositorio_professor.dart';
import '../data/repositorio_ru.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../session/credenciais.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import '../ui/componentes.dart';
import 'acoes_portal.dart';
import 'acoes_professor.dart';
import 'menu.dart';
import 'relatar.dart';
import 'ru.dart' show conectarEticket;

/// Quais sistemas da Ufac estão conectados. Quem pulou um no login conecta por aqui.
class _CartaoContas extends StatelessWidget {
  const _CartaoContas();

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final professor = Perfil.instancia.ehProfessor;
    final portal = professor ? Sistema.professor : Sistema.portal;
    final linhas = [
      (portal, professor ? 'Turmas, horários e relatórios' : 'Dados, horários, notas e biblioteca'),
      (Sistema.eticket, 'Saldo, QR de entrada e cardápio'),
    ];
    return ListenableBuilder(
      listenable: Sessao.instancia,
      builder: (context, _) => Cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contas da Ufac', style: AppTexto.tituloCartao),
            for (final (sistema, apoio) in linhas) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sistema.nome, style: AppTexto.corpoForte),
                        Text(
                          Sessao.instancia.conectado(sistema) ? 'Conectado · $apoio' : 'Não conectado · $apoio',
                          style: AppTexto.apoio.copyWith(color: c.secundario),
                        ),
                      ],
                    ),
                  ),
                  if (!Sessao.instancia.conectado(sistema))
                    TextButton(
                      onPressed: () => switch (sistema) {
                        Sistema.eticket => conectarEticket(context),
                        Sistema.professor => entrarNoPortalProfessor(context),
                        _ => entrarNoPortal(context),
                      },
                      child: const Text('Conectar'),
                    )
                  else
                    Icon(Icons.check_circle_rounded, color: c.verde),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TelaConfiguracoes extends StatelessWidget {
  const TelaConfiguracoes({super.key});

  static const _temas = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  Future<void> _verificarAtualizacoes(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    final pacote = await PackageInfo.fromPlatform();
    final resultado = await Atualizacoes.instancia.verificar();
    final texto = switch (resultado) {
      ResultadoAtualizacao.atualizado => 'Você está na versão mais recente (${pacote.version}).',
      ResultadoAtualizacao.haNova => 'Nova versão disponível: ${Atualizacoes.instancia.nova!.versao}. Veja a tela Início.',
      ResultadoAtualizacao.semConfiguracao => 'Versão instalada: ${pacote.version}. A busca por versões ainda não foi configurada.',
      ResultadoAtualizacao.semResposta => 'Versão instalada: ${pacote.version}. Não consegui verificar agora.',
    };
    mensageiro
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _mudarAvisosClassroom(bool ligar) async {
    await Preferencias.instancia.definirAvisarClassroom(ligar);
    if (ligar) await AvisosClassroom.instancia.pedirPermissao();
    await AvisosClassroom.instancia.reagendar(AtividadesDaSemana.instancia.lista ?? const []);
  }

  Future<void> _limparDados(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    final limpar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Limpar dados salvos?'),
        content: const Text(
          'Apaga horários, notas, cardápio e histórico guardados. Você continua logado e o QR continua funcionando. '
          'Os dados do Portal voltam depois de entrar nele de novo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Limpar')),
        ],
      ),
    );
    if (limpar != true) return;
    await RepositorioRu.instancia.limparCache();
    RepositorioPortal.instancia.limparCache();
    RepositorioProfessor.instancia.limparCache();
    RepositorioBiblioteca.instancia.limparCache();
    await RepositorioRu.instancia.aoAbrirApp();
    if (Perfil.instancia.ehProfessor) {
      await RepositorioProfessor.instancia.aoAbrirApp();
    } else {
      await RepositorioPortal.instancia.aoAbrirApp();
    }
    mensageiro.showSnackBar(const SnackBar(content: Text('Dados salvos apagados.')));
  }

  Future<void> _sobre(BuildContext context) async {
    final pacote = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Sobre o UFAC+'),
        content: Text(
          'Versão ${pacote.version}\n\n'
          'App independente, feito por um aluno. Não é um aplicativo oficial da Ufac.\n\n'
          'O que fica guardado neste celular: sessão do Portal e do eTICKET, matrícula e número do QR '
          '(em armazenamento seguro), dados lidos da Ufac, foto de perfil e suas preferências. '
          'Se "Entrar sozinho" estiver ligado, também o CPF e a senha do ID Ufac, cifrados no cofre do '
          'Android, usados só para entrar no site da Ufac. Nada é enviado a servidores do app.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Fechar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([Preferencias.instancia, FotoPerfil.instancia]),
        builder: (context, _) {
          final prefs = Preferencias.instancia;
          final foto = FotoPerfil.instancia;
          return ListaDaTela(
            children: [
              Row(
                children: [
                  BotaoRedondo(
                    icone: Icons.arrow_back_rounded,
                    descricao: 'Voltar',
                    aoTocar: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Configurações', style: AppTexto.tituloTela)),
                ],
              ),
              Cartao(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppMedidas.raioIcone),
                      child: foto.bytes == null
                          ? IconeQuadrado(icone: Icons.person_rounded, cor: c.navAtivo, fundo: c.navAtivoFundo, lado: 56)
                          : Image.memory(foto.bytes!, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Foto de perfil', style: AppTexto.corpoForte),
                          Text('Fica só neste celular', style: AppTexto.apoio.copyWith(color: c.secundario)),
                          if (foto.bytes != null)
                            TextButton(
                              onPressed: foto.remover,
                              style: TextButton.styleFrom(foregroundColor: c.perigo, padding: EdgeInsets.zero),
                              child: const Text('Remover foto'),
                            ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => foto.escolher(context), child: const Text('Trocar')),
                  ],
                ),
              ),
              Cartao(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aparência', style: AppTexto.tituloCartao),
                    const SizedBox(height: 10),
                    SeletorAbas(
                      rotulos: const ['Sistema', 'Claro', 'Escuro'],
                      atual: _temas.indexOf(prefs.tema),
                      aoEscolher: (i) => prefs.definirTema(_temas[i]),
                    ),
                  ],
                ),
              ),
              Cartao(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avisar sobre feriados', style: AppTexto.corpoForte),
                          Text('Na véspera, na tela Início', style: AppTexto.apoio.copyWith(color: c.secundario)),
                        ],
                      ),
                    ),
                    Switch(value: prefs.avisarFeriados, onChanged: prefs.definirAvisarFeriados),
                  ],
                ),
              ),
              Cartao(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avisar sobre atividades', style: AppTexto.corpoForte),
                          Text(
                            'Às ${horaAvisoClassroom}h, o que falta entregar no Classroom até o dia seguinte',
                            style: AppTexto.apoio.copyWith(color: c.secundario),
                          ),
                        ],
                      ),
                    ),
                    Switch(value: prefs.avisarClassroom, onChanged: _mudarAvisosClassroom),
                  ],
                ),
              ),
              const _CartaoContas(),
              const _CartaoLoginAutomatico(),
              ItemLista(
                icone: Icons.system_update_rounded,
                corIcone: c.navAtivo,
                fundoIcone: c.navAtivoFundo,
                titulo: 'Verificar atualizações',
                aoTocar: () => _verificarAtualizacoes(context),
              ),
              ItemLista(
                icone: Icons.bug_report_rounded,
                corIcone: c.navAtivo,
                fundoIcone: c.navAtivoFundo,
                titulo: 'Relatar um problema',
                aoTocar: () => abrirRelatar(context),
              ),
              ItemLista(
                icone: Icons.cleaning_services_rounded,
                corIcone: c.navAtivo,
                fundoIcone: c.navAtivoFundo,
                titulo: 'Limpar dados salvos',
                aoTocar: () => _limparDados(context),
              ),
              ItemLista(
                icone: Icons.info_rounded,
                corIcone: c.navAtivo,
                fundoIcone: c.navAtivoFundo,
                titulo: 'Sobre o UFAC+',
                aoTocar: () => _sobre(context),
              ),
              BotaoContorno(
                texto: 'Sair da conta',
                icone: Icons.logout_rounded,
                cor: c.perigo,
                aoTocar: () => confirmarSaida(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "Entrar sozinho quando a sessão cair": liga, desliga e esquece a senha guardada.
class _CartaoLoginAutomatico extends StatefulWidget {
  const _CartaoLoginAutomatico();

  @override
  State<_CartaoLoginAutomatico> createState() => _CartaoLoginAutomaticoState();
}

class _CartaoLoginAutomaticoState extends State<_CartaoLoginAutomatico> {
  bool _ligado = true, _temSalvas = false;

  @override
  void initState() {
    super.initState();
    _ler();
  }

  Future<void> _ler() async {
    final ligado = await Credenciais.instancia.ligado();
    final salvas = await Credenciais.instancia.temSalvas();
    if (!mounted) return;
    setState(() {
      _ligado = ligado;
      _temSalvas = salvas;
    });
  }

  Future<void> _esquecer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Esquecer a senha salva?'),
        content: const Text(
          'O CPF e a senha saem deste celular. Quando a sessão da Ufac cair, o app vai pedir para você entrar de novo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Esquecer')),
        ],
      ),
    );
    if (ok != true) return;
    await Credenciais.instancia.esquecer(manterChave: true);
    await _ler();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrar sozinho quando a sessão cair', style: AppTexto.corpoForte),
                    Text(
                      !_ligado
                          ? 'Desligado: o app pede login quando a sessão da Ufac cai'
                          : _temSalvas
                              ? 'CPF e senha guardados cifrados neste celular'
                              : 'Ligado, mas ainda sem senha: entre uma vez com a chave ligada',
                      style: AppTexto.apoio.copyWith(color: c.secundario),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _ligado,
                onChanged: (v) async {
                  await Credenciais.instancia.definirLigado(v);
                  await _ler();
                },
              ),
            ],
          ),
          if (_temSalvas)
            TextButton(
              onPressed: _esquecer,
              style: TextButton.styleFrom(foregroundColor: c.perigo, padding: EdgeInsets.zero),
              child: const Text('Esquecer senha salva'),
            ),
        ],
      ),
    );
  }
}
