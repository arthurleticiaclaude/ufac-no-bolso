import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'avisos_classroom.dart';
import 'banco.dart';

/// Só leitura. Nenhum escopo além destes dois.
const escopoTurmas = 'https://www.googleapis.com/auth/classroom.courses.readonly';
const escopoAtividades = 'https://www.googleapis.com/auth/classroom.coursework.me.readonly';

/// Nome antigo e equivalente de [escopoAtividades]; usado só se o novo for recusado.
const escopoAtividadesAntigo = 'https://www.googleapis.com/auth/classroom.student-submissions.me.readonly';

class Turma {
  const Turma({required this.id, required this.nome, this.secao, this.link});
  final String id, nome;
  final String? secao, link;
}

enum SituacaoEntrega { entregue, pendente, atrasada }

class Atividade {
  const Atividade({
    required this.id,
    required this.titulo,
    this.turma,
    this.prazo,
    this.link,
    required this.situacao,
  });
  final String id, titulo;
  final String? turma, link;
  final DateTime? prazo;
  final SituacaoEntrega situacao;

  Atividade comTurma(String nome) =>
      Atividade(id: id, titulo: titulo, turma: nome, prazo: prazo, link: link, situacao: situacao);

  Map<String, dynamic> paraJson() => {
        'id': id,
        'titulo': titulo,
        'turma': turma,
        'prazo': prazo?.toIso8601String(),
        'link': link,
        'situacao': situacao.name,
      };

  static Atividade? deJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['titulo'] is! String) return null;
    return Atividade(
      id: j['id'],
      titulo: j['titulo'],
      turma: j['turma'] as String?,
      prazo: DateTime.tryParse(j['prazo'] as String? ?? ''),
      link: _linkSeguro(j['link']),
      situacao: SituacaoEntrega.values.asNameMap()[j['situacao']] ?? SituacaoEntrega.pendente,
    );
  }
}

/// O que entra no cartão da Início: o que falta entregar com prazo nos próximos 7 dias,
/// mais o que atrasou nos últimos 7 dias.
List<Atividade> atividadesDaSemana(List<Atividade> todas, DateTime agora) => ordenarPorPrazo([
      for (final a in todas)
        if (a.situacao != SituacaoEntrega.entregue &&
            a.prazo != null &&
            a.prazo!.isAfter(agora.subtract(const Duration(days: 7))) &&
            a.prazo!.isBefore(agora.add(const Duration(days: 7))))
          a,
    ]);

/// Erro já com a frase que a pessoa vai ler.
class ErroClassroom implements Exception {
  const ErroClassroom(this.mensagem, {this.pedirLogin = false});
  final String mensagem;
  final bool pedirLogin;
  @override
  String toString() => mensagem;
}

// ---------- Leitura das respostas (testável sem internet) ----------

Turma? lerTurma(Map<String, dynamic> j) {
  final id = j['id'], nome = j['name'];
  if (id is! String || nome is! String) return null;
  return Turma(id: id, nome: nome, secao: j['section'] as String?, link: _linkSeguro(j['alternateLink']));
}

/// O Classroom manda o prazo em UTC, separado em data e hora.
DateTime? lerPrazo(Map<String, dynamic> j) {
  final d = j['dueDate'];
  if (d is! Map || d['year'] is! int || d['month'] is! int || d['day'] is! int) return null;
  final h = j['dueTime'] is Map ? j['dueTime'] as Map : const {};
  return DateTime.utc(d['year'], d['month'], d['day'], (h['hours'] as int?) ?? 0, (h['minutes'] as int?) ?? 0)
      .toLocal();
}

SituacaoEntrega lerSituacao(Map<String, dynamic>? entrega, DateTime? prazo, DateTime agora) {
  final estado = entrega?['state'];
  if (estado == 'TURNED_IN' || estado == 'RETURNED') return SituacaoEntrega.entregue;
  if (entrega?['late'] == true || (prazo != null && agora.isAfter(prazo))) return SituacaoEntrega.atrasada;
  return SituacaoEntrega.pendente;
}

Atividade? lerAtividade(Map<String, dynamic> j, Map<String, dynamic>? entrega, DateTime agora) {
  final id = j['id'], titulo = j['title'];
  if (id is! String || titulo is! String) return null;
  final prazo = lerPrazo(j);
  return Atividade(
    id: id,
    titulo: titulo,
    prazo: prazo,
    link: _linkSeguro(j['alternateLink']),
    situacao: lerSituacao(entrega, prazo, agora),
  );
}

/// Prazo mais próximo primeiro; sem prazo vai para o fim.
List<Atividade> ordenarPorPrazo(List<Atividade> lista) => [...lista]
  ..sort((a, b) {
    if (a.prazo == null && b.prazo == null) return a.titulo.compareTo(b.titulo);
    if (a.prazo == null) return 1;
    if (b.prazo == null) return -1;
    return a.prazo!.compareTo(b.prazo!);
  });

String? _linkSeguro(Object? v) => v is String && v.startsWith('https://classroom.google.com/') ? v : null;

/// Traduz a falha do login do Google para uma frase humana.
ErroClassroom traduzirErroLogin(GoogleSignInException e) {
  final texto = '${e.description ?? ''} ${e.details ?? ''}'.toLowerCase();
  if (texto.contains('admin_policy') || texto.contains('org_internal') || texto.contains('disallowed_useragent')) {
    return const ErroClassroom(
      'A Ufac bloqueou o acesso de apps externos nesta conta. É uma regra da instituição, não um defeito do app. '
      'Tente com uma conta Google pessoal.',
    );
  }
  if (texto.contains('access_denied') || texto.contains('not verified') || texto.contains('não verificado')) {
    return const ErroClassroom(
      'O Google não liberou o acesso. Se apareceu "O Google não verificou este app", toque em Avançado e depois '
      'em Acessar UFAC+. É um app feito por um aluno, ainda sem a revisão do Google.',
    );
  }
  if (texto.contains('invalid_scope') || texto.contains('scope')) {
    return const ErroClassroom('O Google recusou a permissão pedida. Avise o Arthur.');
  }
  if (texto.contains('developer_error') || RegExp(r'\b10\b').hasMatch(texto)) {
    return const ErroClassroom(
      'O Google não reconheceu este app. Se a configuração foi feita agora há pouco, ela pode levar de minutos a '
      'algumas horas para valer.',
    );
  }
  if (texto.contains('network') || RegExp(r'\b7\b').hasMatch(texto)) {
    return const ErroClassroom('Sem internet agora. Tente de novo quando a conexão voltar.');
  }
  switch (e.code) {
    case GoogleSignInExceptionCode.canceled:
      return const ErroClassroom(
        'O login não foi concluído. Se o Google mostrou "não verificado", toque em Avançado e depois em Acessar '
        'UFAC+. Se mostrou "Acesso bloqueado", a instituição não permite apps externos nesta conta.',
      );
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return const ErroClassroom(
        'O Google não reconheceu este app. Se a configuração foi feita agora há pouco, ela pode levar de minutos a '
        'algumas horas para valer.',
      );
    default:
      return const ErroClassroom('Não consegui entrar com o Google agora. Tente de novo em instantes.');
  }
}

/// Traduz a resposta de erro da API do Classroom.
ErroClassroom traduzirErroApi(int status, String corpo) {
  final texto = corpo.toLowerCase();
  if (status == 401) {
    return const ErroClassroom('Seu acesso ao Google expirou. Entre de novo.', pedirLogin: true);
  }
  if (texto.contains('classroomapidisabled') || texto.contains('domain') || texto.contains('administrator')) {
    return const ErroClassroom(
      'A Ufac não permite que esta conta use o Classroom fora dos apps dela. É uma regra da instituição, não um '
      'defeito do app.',
    );
  }
  if (texto.contains('service_disabled') || texto.contains('has not been used')) {
    return const ErroClassroom(
      'O Google ainda está ativando o acesso ao Classroom para este app. Isso pode levar de minutos a algumas horas.',
    );
  }
  if (status == 403) {
    return const ErroClassroom('O Google não deu permissão para ler o Classroom desta conta.', pedirLogin: true);
  }
  return const ErroClassroom('Não consegui falar com o Classroom agora. Tente de novo em instantes.');
}

// ---------- Acesso ----------

class Classroom {
  Classroom._();
  static final instancia = Classroom._();

  bool _iniciado = false;
  String? _token; // só na memória; quem guarda a autorização é o Google Play Services
  List<String> _escopos = const [escopoTurmas, escopoAtividades];

  GoogleSignInAuthorizationClient get _cliente => GoogleSignIn.instance.authorizationClient;

  Future<void> _iniciar() async {
    if (_iniciado) return;
    // Sem clientId nem serverClientId: no Android o app é reconhecido por pacote + SHA-1.
    await GoogleSignIn.instance.initialize();
    _iniciado = true;
  }

  /// Tenta sem mostrar nada. Devolve false se a pessoa precisa tocar em "Entrar".
  Future<bool> conectarEmSilencio() async {
    await _iniciar();
    try {
      final a = await _cliente.authorizationForScopes(_escopos);
      _token = a?.accessToken;
    } on GoogleSignInException catch (e) {
      _registrar('silencioso', e);
      _token = null;
    }
    return _token != null;
  }

  /// Abre a escolha de conta e a tela de consentimento do Google.
  Future<void> entrar() async {
    await _iniciar();
    try {
      _token = (await _cliente.authorizeScopes(_escopos)).accessToken;
    } on GoogleSignInException catch (e) {
      _registrar('entrar', e);
      final texto = '${e.description ?? ''} ${e.details ?? ''}'.toLowerCase();
      if (texto.contains('scope') && !_escopos.contains(escopoAtividadesAntigo)) {
        debugPrint('Classroom: escopo coursework.me.readonly recusado; tentando student-submissions.me.readonly');
        _escopos = const [escopoTurmas, escopoAtividadesAntigo];
        try {
          _token = (await _cliente.authorizeScopes(_escopos)).accessToken;
          return;
        } on GoogleSignInException catch (e2) {
          _registrar('entrar (escopo antigo)', e2);
          throw traduzirErroLogin(e2);
        }
      }
      throw traduzirErroLogin(e);
    }
  }

  /// Revoga o acesso no Google (não só "sai").
  Future<void> desconectar() async {
    final token = _token;
    _token = null;
    if (token != null) {
      final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final pedido = await cliente.postUrl(Uri.https('oauth2.googleapis.com', '/revoke'));
        pedido.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
        pedido.write('token=${Uri.encodeQueryComponent(token)}'); // no corpo, nunca no endereço
        final r = await pedido.close();
        await r.drain<void>();
        debugPrint('Classroom: revogação respondeu ${r.statusCode}');
      } catch (e) {
        debugPrint('Classroom: não consegui revogar (${e.runtimeType})');
      } finally {
        cliente.close();
      }
      try {
        await _cliente.clearAuthorizationToken(accessToken: token);
      } catch (_) {}
    }
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
  }

  Future<List<Turma>> turmas() async {
    final itens = await _todasAsPaginas('/v1/courses', {'studentId': 'me', 'courseStates': 'ACTIVE'}, 'courses');
    return [for (final j in itens) ?lerTurma(j)];
  }

  Future<List<Atividade>> atividades(String turmaId) async {
    final base = '/v1/courses/${Uri.encodeComponent(turmaId)}';
    final trabalhos = await _todasAsPaginas('$base/courseWork', const {}, 'courseWork');
    // "-" pede as entregas de todas as atividades da turma numa leitura só.
    final entregas = await _todasAsPaginas('$base/courseWork/-/studentSubmissions', {'userId': 'me'}, 'studentSubmissions');
    final porAtividade = {for (final e in entregas) e['courseWorkId']: e};
    final agora = DateTime.now();
    return ordenarPorPrazo([for (final j in trabalhos) ?lerAtividade(j, porAtividade[j['id']], agora)]);
  }

  Future<List<Map<String, dynamic>>> _todasAsPaginas(String caminho, Map<String, String> filtros, String campo) async {
    final todos = <Map<String, dynamic>>[];
    String? pagina;
    var voltas = 0;
    do {
      final j = await _pedir(caminho, {...filtros, 'pageSize': '100', 'pageToken': ?pagina});
      final lista = j[campo];
      if (lista is List) todos.addAll(lista.whereType<Map<String, dynamic>>());
      pagina = j['nextPageToken'] as String?;
    } while (pagina != null && pagina.isNotEmpty && ++voltas < 20);
    return todos;
  }

  Future<Map<String, dynamic>> _pedir(String caminho, Map<String, String> filtros, {bool renovou = false}) async {
    if (_token == null && !await conectarEmSilencio()) {
      throw const ErroClassroom('Entre com sua conta Google para ver o Classroom.', pedirLogin: true);
    }
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final pedido = await cliente.getUrl(Uri.https('classroom.googleapis.com', caminho, filtros));
      pedido.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      final r = await pedido.close().timeout(const Duration(seconds: 20));
      final corpo = await r.transform(utf8.decoder).join();
      if (r.statusCode == 401 && !renovou) {
        // Token vencido: limpa e pede outro em silêncio, uma vez.
        final velho = _token!;
        _token = null;
        try {
          await _cliente.clearAuthorizationToken(accessToken: velho);
        } catch (_) {}
        return await _pedir(caminho, filtros, renovou: true);
      }
      if (r.statusCode != 200) {
        debugPrint('Classroom: $caminho respondeu ${r.statusCode}: ${_resumo(corpo)}');
        throw traduzirErroApi(r.statusCode, corpo);
      }
      return jsonDecode(corpo) as Map<String, dynamic>;
    } on SocketException {
      throw const ErroClassroom('Sem internet agora. Tente de novo quando a conexão voltar.');
    } on TimeoutException {
      throw const ErroClassroom('O Classroom demorou para responder. Tente de novo em instantes.');
    } finally {
      cliente.close();
    }
  }

  /// Só o status e a mensagem do Google, para o log. Nada da pessoa.
  String _resumo(String corpo) {
    try {
      final e = (jsonDecode(corpo) as Map)['error'] as Map;
      return '${e['status']} ${e['message']}';
    } catch (_) {
      return '(sem detalhe)';
    }
  }

  void _registrar(String etapa, GoogleSignInException e) {
    final texto = (e.description ?? '').toLowerCase();
    if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
        e.code == GoogleSignInExceptionCode.providerConfigurationError ||
        texto.contains('developer_error') ||
        RegExp(r'\b10\b').hasMatch(texto)) {
      debugPrint('Classroom ($etapa): DEVELOPER_ERROR provável. Confira pacote e SHA-1 no Google Cloud.');
    }
    debugPrint('Classroom ($etapa): ${e.code.name} ${e.description ?? ''}');
  }
}

/// Cartão "Atividades da semana" da Início, com cache para abrir instantâneo e offline.
class AtividadesDaSemana extends ChangeNotifier {
  AtividadesDaSemana._();
  static final instancia = AtividadesDaSemana._();

  static const _chave = 'classroom_semana';
  static const _intervalo = Duration(minutes: 15);

  bool conectado = false;
  bool carregando = false;
  String? erro;
  List<Atividade>? lista;
  DateTime? atualizadoEm;
  DateTime? _ultimaLeitura;

  Future<void> aoAbrirApp() async {
    await _lerCache();
    await atualizar();
  }

  /// Ao voltar para o app, no máximo a cada 15 minutos.
  Future<void> aoVoltarParaOApp() async {
    final ultima = _ultimaLeitura;
    if (ultima != null && DateTime.now().difference(ultima) < _intervalo) return;
    await atualizar();
  }

  Future<void> atualizar() async {
    if (carregando) return;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      conectado = await Classroom.instancia.conectarEmSilencio();
      debugPrint('Classroom: autorização silenciosa ${conectado ? 'ok' : 'precisa entrar'}');
      if (!conectado) return;
      notifyListeners(); // o cartão já aparece, carregando
      final turmas = await Classroom.instancia.turmas();
      final todas = <Atividade>[];
      // De 4 em 4 turmas ao mesmo tempo: rápido sem disparar dezenas de pedidos juntos.
      for (var i = 0; i < turmas.length; i += 4) {
        final grupo = turmas.skip(i).take(4);
        final partes = await Future.wait([
          for (final t in grupo)
            Classroom.instancia.atividades(t.id).then((l) => [for (final a in l) a.comTurma(t.nome)]),
        ]);
        for (final p in partes) {
          todas.addAll(p);
        }
      }
      lista = atividadesDaSemana(todas, DateTime.now());
      debugPrint('Classroom: ${turmas.length} turmas, ${todas.length} atividades, ${lista!.length} na semana');
      atualizadoEm = DateTime.now();
      _ultimaLeitura = atualizadoEm;
      await Banco.gravar(
        _chave,
        jsonEncode({'em': atualizadoEm!.toIso8601String(), 'lista': [for (final a in lista!) a.paraJson()]}),
      );
      await AvisosClassroom.instancia.reagendar(lista!);
    } on ErroClassroom catch (e) {
      erro = e.mensagem;
      if (e.pedirLogin) conectado = false;
    } catch (e) {
      // Falha inesperada (ex.: Google Play Services indisponível): o cartão vira o atalho.
      debugPrint('Classroom: falha ao atualizar (${e.runtimeType})');
      erro = 'Não consegui falar com o Classroom agora.';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  Future<void> _lerCache() async {
    try {
      final texto = await Banco.ler(_chave);
      if (texto == null) return;
      final j = jsonDecode(texto) as Map<String, dynamic>;
      if (j['em'] == null) return; // desconectado
      atualizadoEm = DateTime.tryParse(j['em'] as String? ?? '');
      lista = [for (final a in (j['lista'] as List? ?? const [])) ?Atividade.deJson(a)];
      conectado = true;
      notifyListeners();
    } catch (_) {}
  }

  /// Ao desconectar o Google ou sair da conta.
  Future<void> limpar() async {
    await AvisosClassroom.instancia.cancelar();
    conectado = false;
    lista = null;
    erro = null;
    atualizadoEm = null;
    _ultimaLeitura = null;
    await Banco.gravar(_chave, '{}');
    notifyListeners();
  }
}
