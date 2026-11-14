// Desenha o ícone do app (capelo branco com borla âmbar sobre azul), sem logo da Ufac.
// Rodar: dart run tools/gerar_icone.dart
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const lado = 1024;
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

// Cobertura da borda em pixels do desenho final ([escala] converte de unidades do desenho).
double _cob(double d, double escala) => (0.5 - d * escala).clamp(0.0, 1.0);

void _pinta(img.Image im, int x, int y, List<int> cor, double a) {
  if (a <= 0) return;
  final p = im.getPixel(x, y);
  final fundoA = p.a / 255;
  final saidaA = a + fundoA * (1 - a);
  double mix(num f, int c) => (c * a + f * fundoA * (1 - a)) / saidaA;
  im.setPixelRgba(x, y, mix(p.r, cor[0]), mix(p.g, cor[1]), mix(p.b, cor[2]), saidaA * 255);
}

/// O desenho é feito num quadro de 512; [tamanho] encolhe o capelo (o ícone adaptável
/// do Android recorta as bordas, então a frente precisa ficar menor).
img.Image desenha({required bool comFundo, required double tamanho}) {
  final im = img.Image(width: lado, height: lado, numChannels: 4);
  final escala = lado / 512 * tamanho;
  const topo = [Point(256.0, 150.0), Point(420.0, 222.0), Point(256.0, 294.0), Point(92.0, 222.0)];
  const base = [Point(168.0, 262.0), Point(344.0, 262.0), Point(344.0, 330.0), Point(256.0, 366.0), Point(168.0, 330.0)];
  for (var y = 0; y < lado; y++) {
    for (var x = 0; x < lado; x++) {
      // Centro do capelo um pouco abaixo do meio, para compensar a borla.
      final fx = 256 + (x + 0.5 - lado / 2) / escala;
      final fy = 258 + (y + 0.5 - lado / 2) / escala;
      if (comFundo) _pinta(im, x, y, azul, 1);
      _pinta(im, x, y, branco, _cob(_poligono(fx, fy, base) - 6, escala));
      _pinta(im, x, y, azul, _cob(_poligono(fx, fy, topo) - 14, escala));
      _pinta(im, x, y, branco, _cob(_poligono(fx, fy, topo) - 6, escala));
      _pinta(im, x, y, ambar, _cob(_segmento(fx, fy, 256, 222, 376, 246) - 6, escala));
      _pinta(im, x, y, ambar, _cob(_segmento(fx, fy, 376, 246, 376, 318) - 6, escala));
      _pinta(im, x, y, ambar, _cob(_caixa(fx, fy, 362, 310, 390, 352, 8), escala));
    }
  }
  return im;
}

void main() {
  File('assets/icon/icone.png').writeAsBytesSync(img.encodePng(desenha(comFundo: true, tamanho: 1)));
  File('assets/icon/icone_frente.png').writeAsBytesSync(img.encodePng(desenha(comFundo: false, tamanho: 0.78)));
}
