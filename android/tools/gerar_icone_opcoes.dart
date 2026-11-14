// Gera três opções de ícone mais neutras, com as mesmas cores do atual, para escolha.
// Rodar: dart run tools/gerar_icone_opcoes.dart
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const lado = 512;
const azul = [0x0B, 0x4F, 0xA8];
const ambar = [0xF2, 0xA5, 0x16];
const branco = [0xFF, 0xFF, 0xFF];

double _segmento(double x, double y, double ax, double ay, double bx, double by) {
  final px = x - ax, py = y - ay, ex = bx - ax, ey = by - ay;
  final t = ((px * ex + py * ey) / (ex * ex + ey * ey)).clamp(0.0, 1.0);
  final dx = px - ex * t, dy = py - ey * t;
  return sqrt(dx * dx + dy * dy);
}

double _caixa(double x, double y, double x0, double y0, double x1, double y1, double r) {
  final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  final qx = (x - cx).abs() - ((x1 - x0) / 2 - r), qy = (y - cy).abs() - ((y1 - y0) / 2 - r);
  final fora = sqrt(pow(max(qx, 0.0), 2) + pow(max(qy, 0.0), 2));
  return fora + min(max(qx, qy), 0.0) - r;
}

double _poligono(double x, double y, List<Point<double>> p) {
  var d = double.infinity;
  var sinal = 1.0;
  for (var i = 0, j = p.length - 1; i < p.length; j = i++) {
    d = min(d, _segmento(x, y, p[j].x, p[j].y, p[i].x, p[i].y));
    final c1 = y >= p[i].y, c2 = y < p[j].y;
    final c3 = (p[j].x - p[i].x) * (y - p[i].y) > (p[j].y - p[i].y) * (x - p[i].x);
    if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) sinal = -sinal;
  }
  return sinal * d;
}

double _cob(double d) => (0.5 - d).clamp(0.0, 1.0);

void _pinta(img.Image im, int x, int y, List<int> cor, double a) {
  if (a <= 0) return;
  final p = im.getPixel(x, y);
  im.setPixelRgba(
    x,
    y,
    p.r * (1 - a) + cor[0] * a,
    p.g * (1 - a) + cor[1] * a,
    p.b * (1 - a) + cor[2] * a,
    255,
  );
}

img.Image _desenha(void Function(img.Image im, int x, int y, double fx, double fy) camadas) {
  final im = img.Image(width: lado, height: lado, numChannels: 4);
  for (var y = 0; y < lado; y++) {
    for (var x = 0; x < lado; x++) {
      // Fundo: quadrado arredondado azul, como o ícone aparece na tela do celular.
      final fundo = _cob(_caixa(x + 0.5, y + 0.5, 0, 0, lado.toDouble(), lado.toDouble(), 112));
      im.setPixelRgba(x, y, azul[0], azul[1], azul[2], (fundo * 255).round());
      if (fundo > 0) camadas(im, x, y, x + 0.5, y + 0.5);
    }
  }
  return im;
}

// A: o bolso atual, sem a costura e com formas mais simples.
void _opcaoA(img.Image im, int x, int y, double fx, double fy) {
  _pinta(im, x, y, ambar, _cob(_caixa(fx, fy, 196, 136, 316, 236, 18)));
  const bolso = [Point(166.0, 214.0), Point(346.0, 214.0), Point(346.0, 322.0), Point(256.0, 376.0), Point(166.0, 322.0)];
  _pinta(im, x, y, branco, _cob(_poligono(fx, fy, bolso) - 16));
}

// B: monograma "U+": U branco e + âmbar.
void _opcaoB(img.Image im, int x, int y, double fx, double fy) {
  const esp = 26.0;
  final dEsq = _segmento(fx, fy, 170, 160, 170, 276);
  final dDir = _segmento(fx, fy, 286, 160, 286, 276);
  final dx = fx - 228, dy = fy - 276;
  final dArco = dy >= 0 ? (sqrt(dx * dx + dy * dy) - 58).abs() : double.infinity;
  _pinta(im, x, y, branco, _cob(min(min(dEsq, dDir), dArco) - esp));
  final dMais = min(_segmento(fx, fy, 366, 196, 366, 280), _segmento(fx, fy, 324, 238, 408, 238));
  _pinta(im, x, y, ambar, _cob(dMais - 18));
}

// C: bolso só em contorno branco, com o cartão âmbar dentro.
void _opcaoC(img.Image im, int x, int y, double fx, double fy) {
  _pinta(im, x, y, ambar, _cob(_caixa(fx, fy, 206, 150, 306, 262, 14)));
  const bolso = [Point(170.0, 222.0), Point(342.0, 222.0), Point(342.0, 320.0), Point(256.0, 370.0), Point(170.0, 320.0)];
  final d = _poligono(fx, fy, bolso) - 14;
  _pinta(im, x, y, azul, _cob(d));
  _pinta(im, x, y, branco, _cob(d.abs() - 12));
}

// D: cartão de estudante: cartão branco com chip âmbar e duas linhas.
void _opcaoD(img.Image im, int x, int y, double fx, double fy) {
  _pinta(im, x, y, branco, _cob(_caixa(fx, fy, 120, 170, 392, 342, 28)));
  _pinta(im, x, y, ambar, _cob(_caixa(fx, fy, 152, 214, 222, 270, 10)));
  _pinta(im, x, y, azul, _cob(_segmento(fx, fy, 252, 228, 356, 228) - 9));
  _pinta(im, x, y, azul, _cob(_segmento(fx, fy, 252, 262, 324, 262) - 9));
  _pinta(im, x, y, azul, _cob(_segmento(fx, fy, 152, 304, 356, 304) - 9));
}

// E: capelo de formatura branco com borla âmbar.
void _opcaoE(img.Image im, int x, int y, double fx, double fy) {
  const topo = [Point(256.0, 150.0), Point(420.0, 222.0), Point(256.0, 294.0), Point(92.0, 222.0)];
  const base = [Point(168.0, 262.0), Point(344.0, 262.0), Point(344.0, 330.0), Point(256.0, 366.0), Point(168.0, 330.0)];
  _pinta(im, x, y, branco, _cob(_poligono(fx, fy, base) - 6));
  _pinta(im, x, y, azul, _cob(_poligono(fx, fy, topo) - 14));
  _pinta(im, x, y, branco, _cob(_poligono(fx, fy, topo) - 6));
  _pinta(im, x, y, ambar, _cob(_segmento(fx, fy, 256, 222, 376, 246) - 6));
  _pinta(im, x, y, ambar, _cob(_segmento(fx, fy, 376, 246, 376, 318) - 6));
  _pinta(im, x, y, ambar, _cob(_caixa(fx, fy, 362, 310, 390, 352, 8)));
}

// F: selo redondo branco com U azul e + âmbar no canto.
void _opcaoF(img.Image im, int x, int y, double fx, double fy) {
  final cx = fx - 256, cy = fy - 256;
  _pinta(im, x, y, branco, _cob(sqrt(cx * cx + cy * cy) - 150));
  final dEsq = _segmento(fx, fy, 202, 196, 202, 270);
  final dDir = _segmento(fx, fy, 310, 196, 310, 270);
  final ax = fx - 256, ay = fy - 270;
  final dArco = ay >= 0 ? (sqrt(ax * ax + ay * ay) - 54).abs() : double.infinity;
  _pinta(im, x, y, azul, _cob(min(min(dEsq, dDir), dArco) - 22));
  final px = fx - 362, py = fy - 150;
  _pinta(im, x, y, azul, _cob(sqrt(px * px + py * py) - 52));
  _pinta(im, x, y, ambar, _cob(sqrt(px * px + py * py) - 44));
  final dMais = min(_segmento(fx, fy, 362, 128, 362, 172), _segmento(fx, fy, 340, 150, 384, 150));
  _pinta(im, x, y, branco, _cob(dMais - 9));
}

// G: sinal de + grande branco, com o centro âmbar.
void _opcaoG(img.Image im, int x, int y, double fx, double fy) {
  final dMais = min(_segmento(fx, fy, 256, 140, 256, 372), _segmento(fx, fy, 140, 256, 372, 256));
  _pinta(im, x, y, branco, _cob(dMais - 46));
  _pinta(im, x, y, ambar, _cob(_caixa(fx, fy, 222, 222, 290, 290, 16)));
}

void main() {
  final pasta = Directory('docs/prints/icone')..createSync(recursive: true);
  final opcoes = {
    'opcao_a': _opcaoA,
    'opcao_b': _opcaoB,
    'opcao_c': _opcaoC,
    'opcao_d': _opcaoD,
    'opcao_e': _opcaoE,
    'opcao_f': _opcaoF,
    'opcao_g': _opcaoG,
  };
  for (final o in opcoes.entries) {
    File('${pasta.path}/${o.key}.png').writeAsBytesSync(img.encodePng(_desenha(o.value)));
  }
}
