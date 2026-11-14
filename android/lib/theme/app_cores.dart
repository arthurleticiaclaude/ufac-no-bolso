import 'package:flutter/material.dart';

/// Tokens de cor da seção 6 do CLAUDE.md. Nada de cor solta fora daqui.
@immutable
class AppCores extends ThemeExtension<AppCores> {
  const AppCores({
    required this.fundo,
    required this.superficie,
    required this.texto,
    required this.secundario,
    required this.borda,
    required this.chrome,
    required this.primaria,
    required this.sobrePrimaria,
    required this.sobrePrimariaSuave,
    required this.destaque,
    required this.sobreDestaque,
    required this.chipFundo,
    required this.chipTexto,
    required this.navAtivo,
    required this.navAtivoFundo,
    required this.verde,
    required this.verdeFundo,
    required this.perigo,
    required this.perigoFundo,
  });

  final Color fundo, superficie, texto, secundario, borda, chrome;
  final Color primaria, sobrePrimaria, sobrePrimariaSuave;
  final Color destaque, sobreDestaque;
  final Color chipFundo, chipTexto;
  final Color navAtivo, navAtivoFundo;
  final Color verde, verdeFundo;
  final Color perigo, perigoFundo;

  // Sempre branco e preto, inclusive no modo escuro, para o leitor conseguir ler.
  Color get qrFundo => const Color(0xFFFFFFFF);
  Color get qrTinta => const Color(0xFF000000);

  static const claro = AppCores(
    fundo: Color(0xFFF3F5F9),
    superficie: Color(0xFFFFFFFF),
    texto: Color(0xFF0E1726),
    secundario: Color(0xFF536074),
    borda: Color(0xFFE3E8F0),
    chrome: Color(0xFFE6EBF2),
    primaria: Color(0xFF0B4FA8),
    sobrePrimaria: Color(0xFFFFFFFF),
    sobrePrimariaSuave: Color(0xFFD3E1F7),
    destaque: Color(0xFFF2A516),
    sobreDestaque: Color(0xFF1A1300),
    chipFundo: Color(0xFFFFF1D6),
    chipTexto: Color(0xFF7A4A00),
    navAtivo: Color(0xFF0B4FA8),
    navAtivoFundo: Color(0xFFE2ECFB),
    verde: Color(0xFF1F7A44),
    verdeFundo: Color(0xFFE1F4E8),
    perigo: Color(0xFFB42318),
    perigoFundo: Color(0xFFFDE8E6),
  );

  static const escuro = AppCores(
    fundo: Color(0xFF0A0F1A),
    superficie: Color(0xFF141B2A),
    texto: Color(0xFFE9EEF6),
    secundario: Color(0xFF9AA6BA),
    borda: Color(0xFF232D40),
    chrome: Color(0xFF1A2233),
    primaria: Color(0xFF16438C),
    sobrePrimaria: Color(0xFFFFFFFF),
    sobrePrimariaSuave: Color(0xFFC6D7F4),
    destaque: Color(0xFFF5B23A),
    sobreDestaque: Color(0xFF1A1300),
    chipFundo: Color(0xFF3A2A0A),
    chipTexto: Color(0xFFF8C76A),
    navAtivo: Color(0xFF8DB4FF),
    navAtivoFundo: Color(0xFF1B2A47),
    verde: Color(0xFF7BD69E),
    verdeFundo: Color(0xFF163323),
    perigo: Color(0xFFF97066),
    perigoFundo: Color(0xFF3A1512),
  );

  // Professores: o azul vira o âmbar da Ufac (o mesmo do botão Mostrar QR do aluno).
  // O âmbar é claro, então o texto sobre ele é escuro, e o botão de destaque, que no aluno é
  // âmbar, vira escuro para não sumir no cartão. Perigo continua o vermelho de sempre.
  // Contraste AA conferido em test/contraste_test.dart.
  static final professorClaro = _comPrimaria(
    claro,
    primaria: const Color(0xFFF2A516),
    sobrePrimaria: const Color(0xFF1A1300),
    sobrePrimariaSuave: const Color(0xFF4D3300),
    destaque: const Color(0xFF1A1300),
    sobreDestaque: const Color(0xFFFFFFFF),
    navAtivo: const Color(0xFF8A5300),
    navAtivoFundo: const Color(0xFFFFF1D6),
  );

  static final professorEscuro = _comPrimaria(
    escuro,
    primaria: const Color(0xFFF5B23A),
    sobrePrimaria: const Color(0xFF1A1300),
    sobrePrimariaSuave: const Color(0xFF4D3300),
    destaque: const Color(0xFF1A1300),
    sobreDestaque: const Color(0xFFFFFFFF),
    navAtivo: const Color(0xFFF8C76A),
    navAtivoFundo: const Color(0xFF3A2A0A),
  );

  static AppCores _comPrimaria(
    AppCores base, {
    required Color primaria,
    required Color sobrePrimaria,
    required Color sobrePrimariaSuave,
    required Color destaque,
    required Color sobreDestaque,
    required Color navAtivo,
    required Color navAtivoFundo,
  }) =>
      AppCores(
        fundo: base.fundo,
        superficie: base.superficie,
        texto: base.texto,
        secundario: base.secundario,
        borda: base.borda,
        chrome: base.chrome,
        primaria: primaria,
        sobrePrimaria: sobrePrimaria,
        sobrePrimariaSuave: sobrePrimariaSuave,
        destaque: destaque,
        sobreDestaque: sobreDestaque,
        chipFundo: base.chipFundo,
        chipTexto: base.chipTexto,
        navAtivo: navAtivo,
        navAtivoFundo: navAtivoFundo,
        verde: base.verde,
        verdeFundo: base.verdeFundo,
        perigo: base.perigo,
        perigoFundo: base.perigoFundo,
      );

  @override
  AppCores copyWith() => this;

  @override
  AppCores lerp(ThemeExtension<AppCores>? other, double t) => t < 0.5 || other is! AppCores ? this : other;
}

extension CoresDoContexto on BuildContext {
  AppCores get cores => Theme.of(this).extension<AppCores>()!;
}
