import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';
import '../extractors/eticket_cardapio.dart';
import '../extractors/eticket_historico.dart';
import '../extractors/eticket_inicio.dart';
import '../session/regras_sessao.dart';
import '../session/sessao.dart';
import 'banco.dart';
import 'cardapio.dart';
import 'historico.dart';

enum ResultadoHistorico { atualizado, sessaoExpirada, falhou }

/// Saldo, QR e cardápio. O número do QR equivale a dinheiro: só no armazenamento seguro, nunca em log.
class RepositorioRu extends ChangeNotifier {
  RepositorioRu._();
  static final instancia = RepositorioRu._();

  static const _cofre = FlutterSecureStorage();
  static const _chaveQr = 'numero_qr';
  static const _chaveSaldo = 'saldo';
  static const _chaveHora = 'saldo_atualizado_em';
  static const _chaveCardapio = 'cardapio';
  static const _chaveHistorico = 'historico_ru';
  static const _intervaloAoVoltar = Duration(minutes: 15);

  String? numeroQr;
  double? saldo;
  DateTime? atualizadoEm;
  CardapioDoDia? _cardapio;
  HistoricoRu? historico;
  bool carregando = false;
  bool falhou = false;
  bool falhouCardapio = false;
  DateTime? _ultimaLeitura;

  /// Só devolve o cardápio se ele foi lido hoje.
  CardapioDoDia? get cardapioDeHoje => _cardapio != null && _cardapio!.valeEm(DateTime.now()) ? _cardapio : null;

  Future<void> carregarSalvos() async {
    numeroQr = await _cofre.read(key: _chaveQr);
    saldo = double.tryParse(await _cofre.read(key: _chaveSaldo) ?? '');
    atualizadoEm = DateTime.tryParse(await _cofre.read(key: _chaveHora) ?? '');
    final salvo = await Banco.ler(_chaveCardapio);
    if (salvo != null) _cardapio = CardapioDoDia.deMapa(jsonDecode(salvo) as Map<String, dynamic>);
    final salvoHistorico = await Banco.ler(_chaveHistorico);
    if (salvoHistorico != null) historico = HistoricoRu.deMapa(jsonDecode(salvoHistorico) as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> aplicarPagina(PaginaLida pagina) async {
    final conteudo = pagina.html;
    if (pagina.resultado != ResultadoVerificacao.ativa || conteudo == null) {
      falhou = pagina.resultado == ResultadoVerificacao.semResposta;
      notifyListeners();
      return;
    }
    final dados = lerEticketInicio(conteudo);
    falhou = dados == null;
    if (dados != null) {
      numeroQr = dados.numeroQr;
      saldo = dados.saldo;
      atualizadoEm = DateTime.now();
      await _cofre.write(key: _chaveQr, value: dados.numeroQr);
      await _cofre.write(key: _chaveSaldo, value: dados.saldo.toString());
      await _cofre.write(key: _chaveHora, value: atualizadoEm!.toIso8601String());
    }
    notifyListeners();
  }

  Future<void> _lerCardapio() async {
    final pagina = await Sessao.instancia.lerEMarcar(Sistema.eticket, url: urlCardapio);
    final conteudo = pagina.html;
    final textos = conteudo == null ? null : lerEticketCardapio(conteudo);
    falhouCardapio = textos == null;
    if (textos != null) {
      _cardapio = CardapioDoDia(DateTime.now(), textos);
      await Banco.gravar(_chaveCardapio, jsonEncode(_cardapio!.paraMapa()));
    }
  }

  /// Saldo e QR vêm da página aberta na verificação, para não pedir duas vezes à Ufac.
  /// O cardápio só é lido se ainda faltar alguma refeição de hoje.
  Future<void> _atualizarTudo(Future<PaginaLida> Function() lerInicio, {bool forcarCardapio = false}) async {
    if (carregando) return;
    carregando = true;
    notifyListeners();
    final pagina = await lerInicio();
    await aplicarPagina(pagina);
    if (pagina.resultado == ResultadoVerificacao.ativa &&
        (forcarCardapio || cardapioPendente(_cardapio, DateTime.now()))) {
      await _lerCardapio();
    }
    _ultimaLeitura = DateTime.now();
    carregando = false;
    notifyListeners();
  }

  Future<void> aoAbrirApp() => _atualizarTudo(Sessao.instancia.verificar);

  /// Ao voltar para o app, no máximo a cada 15 minutos (regra 5).
  Future<void> aoVoltarParaOApp() async {
    final ultima = _ultimaLeitura;
    if (ultima != null && DateTime.now().difference(ultima) < _intervaloAoVoltar) return;
    await aoAbrirApp();
  }

  /// Lê os dois históricos, só quando a pessoa abre essa tela (regra 5).
  Future<ResultadoHistorico> atualizarHistorico() async {
    final sessao = Sessao.instancia;
    final recargasPag = await sessao.lerEMarcar(Sistema.eticket, url: urlHistorico);
    if (recargasPag.resultado == ResultadoVerificacao.expirada) return ResultadoHistorico.sessaoExpirada;
    final refeicoesPag = await sessao.lerEMarcar(Sistema.eticket, url: urlHistoricoRefeicoes);
    final recargas = recargasPag.html == null ? null : lerHistoricoRecargas(recargasPag.html!);
    final refeicoes = refeicoesPag.html == null ? null : lerHistoricoRefeicoes(refeicoesPag.html!);
    if (recargas == null || refeicoes == null) return ResultadoHistorico.falhou;
    historico = HistoricoRu(lidoEm: DateTime.now(), refeicoes: refeicoes, recargas: recargas);
    await Banco.gravar(_chaveHistorico, jsonEncode(historico!.paraMapa()));
    notifyListeners();
    return ResultadoHistorico.atualizado;
  }

  Future<void> atualizar() => _atualizarTudo(Sessao.instancia.verificar, forcarCardapio: true);

  /// "Limpar dados salvos": apaga o cache, mas o QR e o saldo continuam.
  Future<void> limparCache() async {
    _cardapio = null;
    historico = null;
    await Banco.apagarTudo();
    notifyListeners();
  }

  Future<void> limpar() async {
    numeroQr = null;
    saldo = null;
    atualizadoEm = null;
    _cardapio = null;
    historico = null;
    falhou = false;
    falhouCardapio = false;
    await Banco.apagarTudo();
    notifyListeners();
  }
}
