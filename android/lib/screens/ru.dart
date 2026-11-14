import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/refeicoes.dart';
import '../data/repositorio_ru.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/formatos.dart';
import 'historico.dart';
import 'login.dart';
import 'menu.dart';
import 'qr.dart';
import 'recarga.dart';

class TelaRu extends StatefulWidget {
  const TelaRu({super.key});

  @override
  State<TelaRu> createState() => _TelaRuState();
}

class _TelaRuState extends State<TelaRu> {
  late Refeicao _refeicao = proximaRefeicao(DateTime.now());

  Future<void> _abrirInstagram() async {
    final abriu = await launchUrl(Uri.parse(instagramRu), mode: LaunchMode.externalApplication);
    if (!abriu && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Não consegui abrir o Instagram neste celular.')));
    }
  }

  // Skeleton lendo; erro humano se falhou; senão, avisa que o cardápio ainda não saiu.
  Widget _semCardapio(BuildContext context, RepositorioRu ru) {
    final c = context.cores;
    if (ru.carregando && ru.cardapioDeHoje == null) {
      return const Column(
        children: [
          Skeleton(altura: 36, raio: AppMedidas.raioIcone),
          SizedBox(height: 10),
          Skeleton(altura: 36, raio: AppMedidas.raioIcone),
          SizedBox(height: 10),
          Skeleton(altura: 36, raio: AppMedidas.raioIcone),
        ],
      );
    }
    if (!Sessao.instancia.conectado(Sistema.eticket)) {
      return EstadoVazio(
        icone: Icons.restaurant_menu_rounded,
        titulo: 'O cardápio vem do eTICKET',
        texto: 'Conecte o eTICKET no cartão acima, ou veja no Instagram do RU.',
        acao: BotaoContorno(
          texto: 'Ver no Instagram do RU',
          icone: Icons.open_in_new_rounded,
          cor: c.navAtivo,
          aoTocar: _abrirInstagram,
        ),
      );
    }
    final semLeitura = ru.cardapioDeHoje == null;
    return EstadoVazio(
      icone: semLeitura ? Icons.wifi_off_rounded : Icons.schedule_rounded,
      titulo: semLeitura
          ? 'Não consegui ler o cardápio agora'
          : 'O cardápio do ${_refeicao.nomeMinusculo} ainda não saiu',
      texto: semLeitura ? 'Confira sua internet ou entre de novo no eTICKET.' : 'Costuma aparecer perto do horário.',
      acao: BotaoContorno(
        texto: 'Ver no Instagram do RU',
        icone: Icons.open_in_new_rounded,
        cor: c.navAtivo,
        aoTocar: _abrirInstagram,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([RepositorioRu.instancia, Sessao.instancia]),
      builder: (context, _) => _construir(context, RepositorioRu.instancia),
    );
  }

  Widget _construir(BuildContext context, RepositorioRu ru) {
    final c = context.cores;
    final itens = ru.cardapioDeHoje?.itens(_refeicao) ?? const <String>[];
    final h = _refeicao.horario;
    return ListaDaTela(
      aoAtualizar: ru.atualizar,
      children: [
        CabecalhoTela(
          titulo: 'RU',
          subtitulo: 'Restaurante Universitário · Ufac',
          acoes: [BotaoRedondo(icone: Icons.menu_rounded, descricao: 'Menu', aoTocar: () => abrirMenu(context))],
        ),
        const CartaoSaldo(tituloSaldo: 'Saldo'),
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cardápio de hoje', style: AppTexto.tituloCartao),
              Text(formatarData(DateTime.now()), style: AppTexto.apoio.copyWith(color: c.secundario)),
              const SizedBox(height: 12),
              SeletorAbas(
                rotulos: [for (final r in Refeicao.values) r.nome],
                atual: _refeicao.index,
                aoEscolher: (i) => setState(() => _refeicao = Refeicao.values[i]),
              ),
              const SizedBox(height: 10),
              Text(
                '${formatarHoraMin(h.inicioMin)} às ${formatarHoraMin(h.fimMin)}',
                style: AppTexto.rotulo.copyWith(color: c.secundario),
              ),
              const SizedBox(height: 8),
              if (itens.isEmpty)
                _semCardapio(context, ru)
              else
                for (final item in itens)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        IconeQuadrado(
                          icone: Icons.restaurant_menu_rounded,
                          cor: c.verde,
                          fundo: c.verdeFundo,
                          lado: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(item, style: AppTexto.corpo)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        if (Sessao.instancia.conectado(Sistema.eticket))
          ItemLista(
            icone: Icons.history_rounded,
            corIcone: c.navAtivo,
            fundoIcone: c.navAtivoFundo,
            titulo: 'Histórico de uso',
            subtitulo: 'Refeições e recargas',
            aoTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaHistorico())),
          ),
      ],
    );
  }
}

/// Login só do eTICKET (para quem pulou no começo, ou pelas Configurações). Ao concluir, lê saldo e cardápio.
void conectarEticket(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaLogin(
        etapas: const [Sistema.eticket],
        aoConcluir: (rota) {
          Navigator.of(rota).pop();
          RepositorioRu.instancia.atualizar();
        },
      ),
    ),
  );
}

/// Cartão azul com o saldo. Usado na Início (botões lado a lado) e na aba RU (empilhados).
class CartaoSaldo extends StatelessWidget {
  const CartaoSaldo({super.key, required this.tituloSaldo, this.compacto = false});

  final String tituloSaldo;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sessao.instancia,
      builder: (context, _) => Sessao.instancia.conectado(Sistema.eticket) ? _comSaldo(context) : _semEticket(context),
    );
  }

  /// Quem pulou o eTICKET no login: o cartão explica e oferece conectar.
  Widget _semEticket(BuildContext context) {
    final c = context.cores;
    return Cartao(
      cor: c.primaria,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('eTICKET não conectado', style: AppTexto.tituloCartao.copyWith(color: c.sobrePrimaria)),
          const SizedBox(height: 4),
          Text(
            'Conecte para ver o saldo, o QR de entrada e o cardápio do RU.',
            style: AppTexto.apoio.copyWith(color: c.sobrePrimariaSuave),
          ),
          const SizedBox(height: 14),
          BotaoDestaque(texto: 'Conectar eTICKET', icone: Icons.login_rounded, aoTocar: () => conectarEticket(context)),
        ],
      ),
    );
  }

  Widget _comSaldo(BuildContext context) {
    final c = context.cores;
    final mostrarQr = BotaoDestaque(
      texto: compacto ? 'Mostrar QR' : 'Mostrar QR de entrada',
      icone: Icons.qr_code_2_rounded,
      aoTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaQr())),
    );
    final recarregar = BotaoContorno(
      texto: compacto ? 'Recarregar' : 'Recarregar créditos',
      aoTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaRecarga())),
    );
    return Cartao(
      cor: c.primaria,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tituloSaldo, style: AppTexto.apoio.copyWith(color: c.sobrePrimariaSuave)),
          const SizedBox(height: 2),
          ListenableBuilder(
            listenable: RepositorioRu.instancia,
            builder: (context, _) {
              final ru = RepositorioRu.instancia;
              final hora = ru.atualizadoEm;
              if (ru.saldo == null) {
                return Text('Saldo ainda não lido', style: AppTexto.tituloCartao.copyWith(color: c.sobrePrimaria));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatarMoeda(ru.saldo!), style: AppTexto.saldo.copyWith(color: c.sobrePrimaria)),
                  const SizedBox(height: 2),
                  if (hora != null)
                    Text(
                      'Atualizado às ${formatarHora(hora.hour, hora.minute)}',
                      style: AppTexto.rotulo.copyWith(color: c.sobrePrimariaSuave),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (compacto)
            Row(
              children: [
                Expanded(child: mostrarQr),
                const SizedBox(width: 10),
                Expanded(child: recarregar),
              ],
            )
          else ...[
            mostrarQr,
            const SizedBox(height: 10),
            recarregar,
          ],
        ],
      ),
    );
  }
}
