import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme/app_cores.dart';
import '../theme/app_medidas.dart';
import '../theme/app_texto.dart';
import '../ui/componentes.dart';
import '../ui/tela_atual.dart';

/// Só versão, aparelho e tela. Nunca CPF, matrícula, QR, notas, cookies ou prints.
String montarRelato({
  required String versao,
  required String modelo,
  required String android,
  required String tela,
}) =>
    'Olá! Encontrei um problema no UFAC+.\n\n'
    'O que aconteceu?\n\n\n'
    '---\n'
    'Versão do app: $versao\n'
    'Celular: $modelo\n'
    'Android: $android\n'
    'Tela: $tela';

Future<String> _relatoDesteCelular() async {
  final pacote = await PackageInfo.fromPlatform();
  var modelo = 'não informado';
  var android = Platform.operatingSystemVersion;
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    modelo = '${info.manufacturer} ${info.model}';
    android = info.version.release;
  }
  return montarRelato(versao: pacote.version, modelo: modelo, android: android, tela: telaAtual);
}

Future<void> _abrir(BuildContext context, Uri destino) async {
  final mensageiro = ScaffoldMessenger.of(context);
  final abriu = await launchUrl(destino, mode: LaunchMode.externalApplication);
  if (!abriu) {
    mensageiro.showSnackBar(const SnackBar(content: Text('Não consegui abrir esse app neste celular.')));
  }
}

/// A pessoa revisa a mensagem no WhatsApp ou no e-mail e envia ela mesma.
Future<void> abrirRelatar(BuildContext context) async {
  final c = context.cores;
  final relato = await _relatoDesteCelular();
  if (!context.mounted) return;
  final telefone = contatoWhatsapp.replaceAll(RegExp(r'\D'), '');
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.superficie,
    builder: (folha) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppMedidas.margem),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Relatar um problema', style: AppTexto.tituloCartao),
            const SizedBox(height: 4),
            Text(
              'A mensagem abre pronta com a versão do app e o modelo do celular. Você revisa e envia.',
              style: AppTexto.apoio.copyWith(color: c.secundario),
            ),
            const SizedBox(height: 14),
            if (telefone.isEmpty && contatoEmail.isEmpty)
              Text(
                'O contato ainda não foi configurado nesta versão do app.',
                style: AppTexto.corpo.copyWith(color: c.secundario),
              ),
            if (telefone.isNotEmpty)
              BotaoContorno(
                texto: 'WhatsApp',
                icone: Icons.chat_rounded,
                cor: c.navAtivo,
                aoTocar: () {
                  Navigator.of(folha).pop();
                  _abrir(context, Uri.https('wa.me', '/$telefone', {'text': relato}));
                },
              ),
            if (telefone.isNotEmpty && contatoEmail.isNotEmpty) const SizedBox(height: 10),
            if (contatoEmail.isNotEmpty)
              BotaoContorno(
                texto: 'E-mail',
                icone: Icons.mail_rounded,
                cor: c.navAtivo,
                aoTocar: () {
                  Navigator.of(folha).pop();
                  final assunto = Uri.encodeComponent('Problema no UFAC+');
                  _abrir(context, Uri.parse('mailto:$contatoEmail?subject=$assunto&body=${Uri.encodeComponent(relato)}'));
                },
              ),
          ],
        ),
      ),
    ),
  );
}
