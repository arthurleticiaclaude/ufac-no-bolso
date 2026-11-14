import 'package:flutter/material.dart';

import '../session/regras_sessao.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../data/perfil.dart';
import 'casca.dart';
import 'login.dart';

class TelaBoasVindas extends StatelessWidget {
  const TelaBoasVindas({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, limites) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppMedidas.margem),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: limites.maxHeight - AppMedidas.margem * 2),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppMedidas.raioCartao),
                      child: Image.asset('assets/icon/icone.png', width: 84, height: 84),
                    ),
                    const SizedBox(height: 20),
                    Text('UFAC+', style: AppTexto.tituloTela),
                    const SizedBox(height: 6),
                    Text(
                      'Portal do Aluno e RU num lugar só: horários, notas, relatórios, saldo e QR de entrada.',
                      style: AppTexto.corpo.copyWith(color: c.secundario),
                    ),
                    const SizedBox(height: 24),
                    Cartao(
                      child: Column(
                        children: const [
                          _Garantia(
                            icone: Icons.lock_rounded,
                            titulo: 'Sua senha fica com a Ufac',
                            texto: 'Você entra na página oficial. O app nunca vê nem guarda sua senha.',
                          ),
                          SizedBox(height: 14),
                          _Garantia(
                            icone: Icons.smartphone_rounded,
                            titulo: 'Seus dados ficam no seu celular',
                            texto: 'Sem servidor, sem propaganda, sem enviar nada a terceiros.',
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    Text('Os dois entram com o ID Ufac.', style: AppTexto.apoio.copyWith(color: c.secundario)),
                    const SizedBox(height: 10),
                    BotaoDestaque(
                      texto: 'Sou aluno',
                      icone: Icons.school_rounded,
                      aoTocar: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TelaLogin(
                            etapas: const [Sistema.portal, Sistema.eticket],
                            aoConcluir: (rota) async {
                              final navegador = Navigator.of(rota);
                              await Perfil.instancia.definir(PerfilUsuario.aluno);
                              navegador.pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const Casca()),
                                (_) => false,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    BotaoContorno(
                      texto: 'Sou professor',
                      icone: Icons.co_present_rounded,
                      cor: c.navAtivo,
                      aoTocar: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TelaLogin(
                            etapas: const [Sistema.professor, Sistema.eticket],
                            aoConcluir: (rota) async {
                              final navegador = Navigator.of(rota);
                              await Perfil.instancia.definir(PerfilUsuario.professor);
                              navegador.pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const Casca()),
                                (_) => false,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'App independente, feito por um aluno. Não é um aplicativo oficial da Ufac.',
                      style: AppTexto.rotulo.copyWith(color: c.secundario),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Garantia extends StatelessWidget {
  const _Garantia({required this.icone, required this.titulo, required this.texto});

  final IconData icone;
  final String titulo, texto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconeQuadrado(icone: icone, cor: c.verde, fundo: c.verdeFundo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTexto.corpoForte),
              Text(texto, style: AppTexto.apoio.copyWith(color: c.secundario)),
            ],
          ),
        ),
      ],
    );
  }
}
