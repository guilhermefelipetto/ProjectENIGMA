#!/usr/bin/env python3
"""Desenha os ícones dos produtos do mod no estilo do jogo (isométrico, plano, sem contorno).

Gera um SVG por produto e exporta para PNG de 500px com o Inkscape:

    python3 tools/gerar_icones.py            # a partir da pasta do mod

Os PNG vão para assets/products/, que é o que shops_items.json aponta.
"""
import math
import os
import subprocess
import sys

MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(MOD_DIR, "assets", "products")
BUILD_DIR = os.path.join(MOD_DIR, "tools", "build")

# Paleta dos ícones do jogo
MINT, TEAL, TEAL_D = "#c8e9d5", "#48b5b0", "#2f8f8b"
WINE, WINE_D = "#8f1a3a", "#6b1029"
NAVY, NAVY_L = "#1c2f4a", "#2c4466"
CREAM, PAPER, PAPER_D = "#f3ead8", "#fbf7ee", "#e6dcc6"
BROWN, BROWN_M, BROWN_D = "#c05a32", "#8c2a14", "#5c1a14"
YEL, YEL_D, YEL_L = "#f2c84b", "#d9a21f", "#f8dc85"
GRAY, GRAY_D, GRAY_L = "#d8dde3", "#a9b3bf", "#eef1f4"
GREEN, GREEN_D, GREEN_L = "#6aa84f", "#3f7a34", "#9fd08a"
PINK, PINK_D = "#e58a8a", "#c25e66"
CARD, CARD_D, CARD_L = "#c9a06a", "#a57c47", "#e0c08e"
FONT = "DejaVu Sans"

OX, OY = 250, 300


def iso(x, y, z):
    return (OX + (x - y) * 0.866, OY + (x + y) * 0.5 - z)


def poly(points, fill, extra=""):
    pts = " ".join("%.1f,%.1f" % p for p in points)
    return '<polygon points="%s" fill="%s" %s/>' % (pts, fill, extra)


def path(d, fill, extra=""):
    return '<path d="%s" fill="%s" %s/>' % (d, fill, extra)


def box(x, y, z, w, d, h, top, left, right):
    """Caixa: topo, face da esquerda (+y) e face da direita (+x)"""
    return "".join([
        poly([iso(x, y + d, z), iso(x + w, y + d, z), iso(x + w, y + d, z + h),
              iso(x, y + d, z + h)], left),
        poly([iso(x + w, y, z), iso(x + w, y + d, z), iso(x + w, y + d, z + h),
              iso(x + w, y, z + h)], right),
        poly([iso(x, y, z + h), iso(x + w, y, z + h), iso(x + w, y + d, z + h),
              iso(x, y + d, z + h)], top),
    ])


def cylinder(cx, cy, z, r, h, top, side, side_dark=None):
    """Cilindro em pé, de raio r (no chão) e altura h"""
    bx, by = iso(cx, cy, z)
    tx, ty = iso(cx, cy, z + h)
    rx, ry = r * 1.2247, r * 0.7071
    out = [
        '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (bx, by, rx, ry, side),
        '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>'
        % (bx - rx, ty, 2 * rx, by - ty, side),
    ]
    if side_dark:
        out.append(
            '<path d="M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 0 1 %.1f %.1f Z" fill="%s"/>'
            % (bx, ty, bx, by + ry, rx, ry, bx + rx, by, side_dark)
        )
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>'
                   % (bx, ty, rx, by - ty, side_dark))
    out.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>'
               % (tx, ty, rx, ry, top))
    return "".join(out)


def text(x, y, content, size, fill, anchor="middle", weight="bold", extra=""):
    return ('<text x="%.1f" y="%.1f" font-family="%s" font-weight="%s" font-size="%d" '
            'fill="%s" text-anchor="%s" %s>%s</text>'
            % (x, y, FONT, weight, size, fill, anchor, extra, content))


def iso_text(x, y, z, content, size, fill, face="left"):
    """Texto pintado numa face vertical da caixa"""
    px, py = iso(x, y, z)
    skew = 30 if face == "left" else -30
    return ('<g transform="translate(%.1f %.1f) skewY(%d)">%s</g>'
            % (px, py, skew, text(0, 0, content, size, fill)))


def tag(x, y, label, rotation=-12):
    """Etiqueta de preço pendurada"""
    return (
        '<g transform="translate(%d %d) rotate(%d)">' % (x, y, rotation)
        + path("M 0 0 L 26 -22 L 120 -22 L 120 22 L 26 22 Z", YEL)
        + '<circle cx="18" cy="0" r="6" fill="%s"/>' % YEL_D
        + text(72, 8, label, 22, NAVY)
        + "</g>"
    )


# ---------------------------------------------------------------- produtos

def casca_banana():
    return (
        path("M 250 330 C 200 300 150 330 105 400 C 160 385 205 370 245 360 Z", YEL_D)
        + path("M 255 330 C 300 290 360 300 410 370 C 350 370 300 365 262 360 Z", YEL)
        + path("M 250 335 C 230 270 250 200 300 150 C 300 220 285 290 268 345 Z", YEL_L)
        + path("M 236 340 C 215 300 205 270 180 245 C 215 260 240 300 258 345 Z", YEL)
        + '<ellipse cx="255" cy="350" rx="38" ry="22" fill="%s"/>' % CREAM
        + path("M 296 150 C 300 135 312 128 322 132 L 314 152 Z", BROWN_D)
        + '<circle cx="150" cy="378" r="6" fill="%s"/>' % BROWN_D
        + '<circle cx="372" cy="355" r="5" fill="%s"/>' % BROWN_D
        + '<circle cx="290" cy="225" r="5" fill="%s"/>' % BROWN_D
    )


def fuzil():
    body = (
        path("M 40 270 L 120 250 L 140 300 L 60 330 Z", BROWN)
        + path("M 60 330 L 140 300 L 146 314 L 66 344 Z", BROWN_M)
        + path("M 120 250 L 330 200 L 340 236 L 140 300 Z", NAVY_L)
        + path("M 140 300 L 340 236 L 344 250 L 146 314 Z", NAVY)
        + path("M 330 200 L 470 170 L 474 188 L 340 220 Z", NAVY)
        + path("M 250 240 L 300 226 L 330 330 L 296 340 Z", NAVY)
        + path("M 296 340 L 330 330 L 334 342 L 300 352 Z", NAVY_L)
        + path("M 190 268 L 228 258 L 240 330 L 206 340 Z", BROWN)
        + path("M 340 210 L 400 196 L 404 214 L 344 228 Z", BROWN)
        + '<rect x="440" y="160" width="10" height="16" fill="%s"/>' % NAVY
    )
    return body + tag(150, 150, "PROMO", -14)


def granada():
    return (
        '<ellipse cx="240" cy="300" rx="110" ry="135" fill="%s"/>' % GREEN_D
        + path("M 240 165 A 110 135 0 0 0 130 300 A 110 135 0 0 0 240 435 Z", GREEN)
        + "".join('<rect x="135" y="%d" width="210" height="10" fill="%s" opacity=".45"/>'
                  % (y, GREEN_D) for y in (240, 290, 340))
        + box(-55, -55, 140, 50, 50, 40, GRAY_L, GRAY, GRAY_D)
        + path("M 270 120 L 380 80 L 390 100 L 290 150 Z", GRAY_D)
        + '<circle cx="410" cy="150" r="34" fill="none" stroke="%s" stroke-width="10"/>' % GRAY_D
        + path("M 425 200 l 18 30 l -36 0 Z", YEL_D)
    )


def ar_engarrafado():
    return (
        path("M 190 200 C 190 160 215 150 215 120 L 285 120 C 285 150 310 160 310 200 "
             "L 310 420 C 310 440 290 450 250 450 C 210 450 190 440 190 420 Z",
             "#dff3f1", 'opacity=".9"')
        + path("M 250 120 L 285 120 C 285 150 310 160 310 200 L 310 420 C 310 440 290 450 "
               "250 450 Z", "#c3e7e3", 'opacity=".9"')
        + '<rect x="222" y="86" width="56" height="40" rx="6" fill="%s"/>' % BROWN
        + '<rect x="190" y="270" width="120" height="80" fill="%s"/>' % WINE
        + text(250, 322, "AR", 44, CREAM)
        + path("M 200 230 C 215 225 215 250 230 245", "none",
               'stroke="#ffffff" stroke-width="8" stroke-linecap="round"')
        + text(250, 395, "premium", 20, TEAL_D)
    )


def rim():
    return (
        path("M 250 140 C 360 120 420 200 400 300 C 385 380 300 420 230 390 "
             "C 190 372 215 330 190 300 C 165 270 120 270 125 220 C 130 170 190 150 250 140 Z",
             PINK)
        + path("M 400 300 C 385 380 300 420 230 390 C 190 372 215 330 190 300 "
               "C 260 330 340 320 400 300 Z", PINK_D)
        + path("M 190 300 C 210 280 230 285 250 300", "none",
               'stroke="%s" stroke-width="14" stroke-linecap="round"' % WINE)
        + '<circle cx="320" cy="210" r="16" fill="#ffffff" opacity=".45"/>'
        + tag(60, 420, "TROCA", -8)
    )


def pedra_areia():
    return (
        path("M 60 400 C 120 300 200 250 250 250 C 300 250 380 300 440 400 Z", YEL_L)
        + path("M 250 250 C 300 250 380 300 440 400 L 250 400 Z", YEL)
        + "".join('<circle cx="%d" cy="%d" r="4" fill="%s"/>' % (x, y, YEL_D)
                  for x, y in ((150, 360), (200, 330), (300, 340), (350, 370), (260, 300)))
        + path("M 215 255 L 240 222 L 280 220 L 300 250 L 270 268 L 228 268 Z", GRAY_D)
        + path("M 240 222 L 280 220 L 300 250 L 258 246 Z", GRAY)
        + '<circle cx="330" cy="190" r="26" fill="%s"/>' % MINT
        + path("M 318 190 l 9 10 l 18 -22", "none",
               'stroke="%s" stroke-width="7" fill="none"' % TEAL_D)
    )


def capivara():
    return (
        box(-150, -40, 0, 210, 110, 120, CARD_L, CARD_D, CARD)
        + box(60, -20, 50, 90, 80, 90, CARD_L, CARD_D, CARD)
        + box(140, -5, 60, 40, 50, 45, CARD_L, CARD_D, CARD)
        + box(-130, 60, -40, 30, 30, 40, CARD, CARD_D, CARD_D)
        + box(20, 60, -40, 30, 30, 40, CARD, CARD_D, CARD_D)
        + box(80, 10, 140, 20, 15, 20, CARD_D, BROWN_M, BROWN_M)
        + '<circle cx="%.1f" cy="%.1f" r="7" fill="%s"/>' % (*iso(135, 60, 120), NAVY)
        + '<circle cx="%.1f" cy="%.1f" r="6" fill="%s"/>' % (*iso(180, 40, 90), NAVY)
        + text(250, 470, "47 m", 34, WINE)
    )


def lanca_chamas():
    nozzle_x, nozzle_y = iso(200, -5, 135)
    return (
        cylinder(-60, 40, 0, 60, 230, GRAY_L, GRAY, GRAY_D)
        + path("M %.1f %.1f C 150 360 210 380 %.1f %.1f" % (*iso(-20, 40, 60), *iso(60, 0, 80)),
               "none", 'stroke="%s" stroke-width="14" stroke-linecap="round"' % NAVY)
        + box(0, -20, 120, 200, 30, 30, NAVY_L, NAVY, NAVY)
        + box(60, -10, 60, 30, 20, 60, NAVY_L, NAVY, NAVY)
        + '<g transform="translate(%.1f %.1f) rotate(30)">' % (nozzle_x, nozzle_y)
        + path("M 0 0 C 30 -40 80 -30 110 0 C 80 30 30 40 0 0 Z", "#f28c28")
        + path("M 0 0 C 20 -20 50 -16 70 0 C 50 16 20 20 0 0 Z", YEL)
        + "</g>"
        + '<circle cx="%.1f" cy="%.1f" r="14" fill="%s"/>' % (*iso(-60, 40, 160), WINE)
    )


def sapato():
    return (
        box(-150, -40, 0, 300, 120, 30, NAVY_L, NAVY, NAVY)
        + box(-150, -40, 30, 180, 120, 90, WINE, WINE_D, WINE_D)
        + box(30, -40, 30, 120, 120, 30, WINE, WINE_D, WINE_D)
        + box(-140, -30, 120, 90, 100, 8, NAVY, NAVY, NAVY)
        + "".join(poly([iso(x, 80, 60), iso(x + 20, 80, 60), iso(x + 20, 80, 66),
                        iso(x, 80, 66)], CREAM) for x in (-100, -60, -20))
        + '<circle cx="390" cy="130" r="46" fill="%s"/>' % YEL
        + text(390, 147, "E", 48, NAVY)
    )


def saco_vento():
    return (
        path("M 160 220 C 120 300 130 420 250 430 C 370 420 380 300 340 220 Z", CARD_L)
        + path("M 250 430 C 370 420 380 300 340 220 L 260 220 C 290 300 290 380 250 430 Z", CARD)
        + path("M 190 225 C 210 180 290 180 310 225 Z", CARD_D)
        + '<rect x="200" y="200" width="100" height="16" rx="8" fill="%s"/>' % BROWN_M
        + "".join(path(d, "none", 'stroke="%s" stroke-width="10" stroke-linecap="round"' % TEAL)
                  for d in ("M 60 150 C 110 120 150 170 110 185",
                            "M 380 120 C 430 90 470 140 430 160",
                            "M 400 330 C 450 300 480 350 440 365"))
        + text(250, 340, "VENTO", 30, BROWN_M)
    )


def dignidade():
    return (
        box(-110, -70, 0, 220, 140, 200, "#e9f6f2", MINT, "#b3dcc4")
        + box(-110, -70, 200, 220, 140, 10, PAPER, PAPER_D, PAPER_D)
        + iso_text(0, 70, 120, "DIGNIDADE", 26, WINE)
        + iso_text(0, 70, 85, "1 unidade", 20, NAVY)
        + iso_text(110, 0, 100, "(vazio)", 20, TEAL_D, face="right")
    )


def iphone_47():
    return (
        box(-40, -60, 0, 80, 14, 420, NAVY_L, NAVY, NAVY)
        + poly([iso(-32, -46, 20), iso(32, -46, 20), iso(32, -46, 400), iso(-32, -46, 400)],
               "#3d6fa3")
        + "".join('<circle cx="%.1f" cy="%.1f" r="9" fill="%s"/>'
                  % (*iso(x, -60, z), GRAY_D)
                  for x, z in ((25, 380), (25, 350), (25, 320), (8, 380), (8, 350),
                               (8, 320), (25, 290)))
        + text(400, 330, "47", 80, WINE)
        + text(400, 370, "PRO MAX", 22, NAVY)
        + text(400, 395, "PLUS ULTRA", 18, NAVY)
    )


def plutonio():
    trefoil = "".join(
        path("M 0 0 L %.1f %.1f A 60 60 0 0 1 %.1f %.1f Z" % (
            60 * math.cos(math.radians(a)), 60 * math.sin(math.radians(a)),
            60 * math.cos(math.radians(a + 60)), 60 * math.sin(math.radians(a + 60))), NAVY)
        for a in (-120, 0, 120)
    ) + '<circle r="14" fill="%s"/><circle r="9" fill="%s"/>' % (YEL, NAVY)
    return (
        cylinder(0, 0, 0, 120, 260, YEL_L, YEL, YEL_D)
        + "".join('<rect x="103" y="%d" width="294" height="12" fill="%s"/>' % (y, YEL_D)
                  for y in (200, 330))
        + '<g transform="translate(250 270) scale(1 0.85)">%s</g>' % trefoil
        + path("M 330 115 C 360 90 390 120 420 95", "none",
               'stroke="%s" stroke-width="12" stroke-linecap="round"' % GREEN_L)
    )


def alma():
    return (
        cylinder(0, 0, 0, 110, 300, "#e6f4f2", "#d4ecea", "#c3e3e0")
        + path("M 200 360 C 180 300 200 210 250 190 C 300 210 320 300 300 360 "
               "C 285 345 275 370 260 352 C 245 372 235 345 220 365 Z", WINE, 'opacity=".9"')
        + path("M 222 255 l 22 10 M 278 255 l -22 10", "none",
               'stroke="%s" stroke-width="8" stroke-linecap="round"' % CREAM)
        + '<circle cx="232" cy="280" r="8" fill="%s"/><circle cx="268" cy="280" r="8" fill="%s"/>'
        % (CREAM, CREAM)
        + path("M 232 315 C 245 305 255 305 268 315", "none",
               'stroke="%s" stroke-width="6" stroke-linecap="round"' % CREAM)
        + box(-80, -80, 300, 160, 160, 26, BROWN, BROWN_M, BROWN_D)
    )


def conta_luz():
    return (
        '<g transform="rotate(-8 250 270)">'
        + '<rect x="130" y="80" width="240" height="330" fill="%s"/>' % PAPER
        + '<rect x="130" y="80" width="240" height="60" fill="%s"/>' % TEAL
        + path("M 262 92 L 236 120 L 252 120 L 240 140 L 270 110 L 254 110 Z", YEL)
        + "".join('<rect x="155" y="%d" width="%d" height="10" fill="%s"/>'
                  % (y, w, PAPER_D) for y, w in ((165, 190), (190, 150), (215, 170), (240, 120)))
        + text(250, 300, "R$ 847,50", 30, NAVY)
        + "</g>"
        + '<g transform="rotate(-24 260 360)">'
        + '<rect x="150" y="320" width="230" height="64" rx="8" fill="none" stroke="%s" '
          'stroke-width="7"/>' % WINE
        + text(265, 366, "ATRASADA", 34, WINE)
        + "</g>"
    )


def voto():
    return (
        box(-100, -80, 0, 200, 160, 170, GRAY_L, GRAY, GRAY_D)
        + poly([iso(-60, -10, 170), iso(60, -10, 170), iso(60, 10, 170), iso(-60, 10, 170)],
               NAVY)
        + '<g transform="rotate(-10 250 120)">'
        + '<rect x="190" y="40" width="130" height="160" fill="%s"/>' % PAPER
        + '<rect x="210" y="70" width="28" height="28" fill="none" stroke="%s" stroke-width="5"/>'
        % NAVY
        + path("M 212 82 l 10 12 l 22 -26", "none",
               'stroke="%s" stroke-width="7" fill="none"' % WINE)
        + "".join('<rect x="250" y="%d" width="50" height="8" fill="%s"/>' % (y, PAPER_D)
                  for y in (78, 120, 150))
        + path("M 190 175 C 230 160 260 200 320 180 L 320 200 L 190 200 Z", PAPER_D)
        + "</g>"
        + iso_text(0, 80, 90, "VOTO", 34, NAVY)
    )


def wifi_vizinho():
    arcs = "".join(
        path("M %d %d A %d %d 0 0 1 %d %d" % (250 - r, 250, r, r, 250 + r, 250), "none",
             'stroke="%s" stroke-width="30" stroke-linecap="round"' % color)
        for r, color in ((150, TEAL_D), (100, TEAL), (50, MINT))
    )
    return (
        '<g transform="translate(0 40)">%s<circle cx="250" cy="260" r="22" fill="%s"/></g>'
        % (arcs, NAVY)
        + '<g transform="rotate(8 360 380)">'
        + '<rect x="290" y="320" width="150" height="130" fill="%s"/>' % YEL
        + text(365, 370, "senha:", 22, NAVY)
        + text(365, 410, "vizinho123", 20, WINE)
        + "</g>"
    )


def post_it_chefe():
    return (
        '<g transform="rotate(-6 250 260)">'
        + '<rect x="110" y="110" width="280" height="280" fill="%s"/>' % YEL
        + path("M 330 390 L 390 330 L 390 390 Z", YEL_D)
        + text(250, 185, "SENHA DO", 28, NAVY)
        + text(250, 222, "CHEFE:", 28, NAVY)
        + text(250, 300, "chefe123", 46, WINE)
        + text(250, 345, "(não contar!)", 20, NAVY_L, weight="normal")
        + "</g>"
        + '<rect x="200" y="88" width="100" height="36" fill="%s" opacity=".75" '
          'transform="rotate(-6 250 106)"/>' % GRAY
    )


def antivirus_zap():
    return (
        path("M 250 70 L 400 120 C 400 300 340 390 250 440 C 160 390 100 300 100 120 Z", TEAL)
        + path("M 250 70 L 400 120 C 400 300 340 390 250 440 Z", TEAL_D)
        + '<ellipse cx="250" cy="270" rx="52" ry="66" fill="%s"/>' % WINE
        + '<circle cx="250" cy="195" r="30" fill="%s"/>' % WINE_D
        + "".join(path("M %d %d l %d %d" % (x, y, dx, dy), "none",
                       'stroke="%s" stroke-width="9" stroke-linecap="round"' % WINE_D)
                  for x, y, dx, dy in ((200, 250, -40, -16), (200, 285, -44, 6),
                                       (300, 250, 40, -16), (300, 285, 44, 6),
                                       (235, 170, -16, -26), (265, 170, 16, -26)))
        + '<circle cx="390" cy="390" r="56" fill="%s"/>' % GREEN
        + path("M 352 430 L 345 455 L 372 440 Z", GREEN)
        + text(390, 404, "zap", 30, "#ffffff")
    )


def nitrogenio_evaporado():
    return (
        cylinder(0, 0, 0, 90, 250, GRAY_L, GRAY, GRAY_D)
        + '<ellipse cx="%.1f" cy="%.1f" rx="70" ry="40" fill="%s"/>' % (*iso(0, 0, 250), NAVY)
        + box(-40, -40, 250, 80, 80, 30, TEAL, TEAL_D, TEAL_D)
        + "".join(path(d, "none", 'stroke="%s" stroke-width="12" stroke-linecap="round" '
                                  'opacity=".7"' % GRAY_D)
                  for d in ("M 230 20 C 210 45 250 60 230 85",
                            "M 270 10 C 250 35 290 50 270 75"))
        + '<rect x="165" y="230" width="170" height="70" fill="%s"/>' % WINE
        + text(250, 278, "0 L", 40, CREAM)
    )


def martelo_isopor():
    return (
        box(-20, -20, 0, 40, 40, 260, "#ffffff", GRAY_L, GRAY)
        + box(-110, -40, 240, 220, 80, 80, "#ffffff", GRAY_L, GRAY)
        + "".join('<circle cx="%d" cy="%d" r="5" fill="%s"/>' % (x, y, GRAY_D)
                  for x, y in ((180, 130), (210, 150), (290, 120), (320, 160), (250, 300),
                               (238, 360), (265, 250)))
        + tag(300, 330, "3 g", -10)
    )


def furadeira_vazia():
    return (
        box(-130, -90, 0, 260, 180, 150, CARD, CARD_D, CARD_D)
        + poly([iso(-130, 90, 150), iso(-130, 160, 220), iso(130, 160, 220), iso(130, 90, 150)],
               CARD_L)
        + poly([iso(130, -90, 150), iso(200, -90, 220), iso(200, 90, 220), iso(130, 90, 150)],
               CARD)
        + poly([iso(-125, -85, 150), iso(125, -85, 150), iso(125, 85, 150), iso(-125, 85, 150)],
               BROWN_M)
        + iso_text(0, 90, 80, "FURADEIRA", 28, NAVY)
        + iso_text(130, 0, 90, "vazia", 24, NAVY, face="right")
    )


def monitor_papelao():
    return (
        poly([iso(-150, 0, 140), iso(150, 0, 140), iso(150, 0, 340), iso(-150, 0, 340)], CARD)
        + poly([iso(-130, 0, 160), iso(130, 0, 160), iso(130, 0, 320), iso(-130, 0, 320)],
               CARD_D)
        + box(-20, -10, 40, 40, 14, 100, CARD_L, CARD, CARD_D)
        + box(-80, -50, 30, 160, 100, 10, CARD_L, CARD, CARD_D)
        + iso_text(0, 0, 225, "4K", 64, CARD_L)
        + "".join(path("M %.1f %.1f l 10 -6 l 10 6 l 10 -6 l 10 6" % iso(x, 0, 140), "none",
                       'stroke="%s" stroke-width="4"' % CARD_D) for x in (-140, -40, 60))
    )


def bolo_pote_vazio():
    return (
        cylinder(0, 0, 0, 100, 210, "#e6f4f2", "#d4ecea", "#c3e3e0")
        + '<ellipse cx="%.1f" cy="%.1f" rx="110" ry="62" fill="%s"/>'
        % (*iso(0, 0, 210), "#b3dcc4")
        + '<g transform="translate(110 -150) rotate(18 250 400)">'
        + cylinder(0, 0, 0, 100, 30, WINE, WINE_D)
        + "</g>"
        + "".join('<circle cx="%d" cy="%d" r="5" fill="%s"/>' % (x, y, BROWN_D)
                  for x, y in ((220, 400), (270, 410)))
    )


def brigadeiro_brocolis():
    florets = "".join('<circle cx="%d" cy="%d" r="%d" fill="%s"/>' % c for c in (
        (200, 210, 50, GREEN_D), (300, 210, 50, GREEN_D), (250, 180, 60, GREEN),
        (205, 245, 45, GREEN), (295, 245, 45, GREEN), (250, 240, 55, GREEN_L)))
    return (
        path("M 150 300 L 350 300 L 320 420 L 180 420 Z", BROWN)
        + "".join(path("M %d 300 L %d 420" % (x, x + (250 - x) // 5), "none",
                       'stroke="%s" stroke-width="6"' % BROWN_M) for x in (180, 220, 280, 320))
        + '<rect x="225" y="250" width="50" height="70" fill="%s"/>' % GREEN_D
        + florets
        + "".join('<circle cx="%d" cy="%d" r="4" fill="%s"/>' % (x, y, GREEN_D)
                  for x, y in ((230, 170), (270, 200), (215, 230), (285, 235)))
    )


def tiramisu_vazio():
    return (
        '<ellipse cx="250" cy="320" rx="200" ry="110" fill="%s"/>' % GRAY_D
        + '<ellipse cx="250" cy="306" rx="200" ry="110" fill="%s"/>' % GRAY_L
        + '<ellipse cx="250" cy="306" rx="130" ry="70" fill="#ffffff"/>'
        + "".join('<circle cx="%d" cy="%d" r="%d" fill="%s"/>' % c for c in (
            (200, 300, 6, BROWN), (230, 320, 4, BROWN_D), (290, 290, 5, BROWN),
            (310, 325, 3, BROWN_D), (260, 280, 3, BROWN)))
        + path("M 380 200 L 470 120 L 480 130 L 392 212 Z", GRAY_D)
        + '<ellipse cx="370" cy="215" rx="30" ry="18" fill="%s" transform="rotate(-40 370 215)"/>'
        % GRAY_D
    )


PRODUCTS = {
    "casca_banana": casca_banana, "fuzil_promocao": fuzil, "granada": granada,
    "ar_engarrafado": ar_engarrafado, "rim": rim, "pedra_areia": pedra_areia,
    "capivara": capivara, "lanca_chamas": lanca_chamas, "sapato_esquerdo": sapato,
    "saco_vento": saco_vento, "dignidade": dignidade, "iphone_47": iphone_47,
    "plutonio": plutonio, "alma": alma, "conta_luz": conta_luz, "voto": voto,
    "wifi_vizinho": wifi_vizinho, "senha_chefe": post_it_chefe,
    "antivirus_zap": antivirus_zap, "nitrogenio_evaporado": nitrogenio_evaporado,
    "martelo_isopor": martelo_isopor, "furadeira_vazia": furadeira_vazia,
    "monitor_papelao": monitor_papelao, "bolo_pote_vazio": bolo_pote_vazio,
    "brigadeiro_brocolis": brigadeiro_brocolis, "tiramisu_vazio": tiramisu_vazio,
}


## nome -> (escala, deslocamento para a direita, para baixo), para os que passam da borda
FIT = {
    "alma": (0.8, 0, 45), "bolo_pote_vazio": (0.78, 0, 50), "plutonio": (0.85, 0, 40),
    "monitor_papelao": (0.8, 0, 60), "martelo_isopor": (0.82, 0, 50),
    "lanca_chamas": (0.82, -40, 20), "nitrogenio_evaporado": (0.85, 0, 40),
}


def fit(name, drawing):
    if name not in FIT:
        return drawing
    scale, right, down = FIT[name]
    return ('<g transform="translate(250 250) scale(%s) translate(%d %d)">%s</g>'
            % (scale, -250 + right, -250 + down, drawing))


def trim(png_path):
    """Corta a margem transparente e amplia de volta a 500px, como os ícones do jogo"""
    from PIL import Image
    image = Image.open(png_path)
    image = image.crop(image.getbbox())
    scale = 500 / max(image.size)
    image = image.resize((round(image.width * scale), round(image.height * scale)),
                         Image.LANCZOS)
    image.save(png_path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(BUILD_DIR, exist_ok=True)
    only = set(sys.argv[1:])
    actions = []
    for name, draw in PRODUCTS.items():
        if only and name not in only:
            continue
        svg_path = os.path.join(BUILD_DIR, name + ".svg")
        with open(svg_path, "w", encoding="utf8") as svg:
            svg.write('<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" '
                      'viewBox="0 0 500 500">%s</svg>' % fit(name, draw()))
        actions.append("file-open:%s;export-filename:%s;export-width:500;export-do;file-close"
                       % (svg_path, os.path.join(OUT_DIR, name + ".png")))
    subprocess.run(["inkscape", "--actions=" + ";".join(actions)], check=True,
                   stderr=subprocess.DEVNULL)
    for name in PRODUCTS:
        if not only or name in only:
            trim(os.path.join(OUT_DIR, name + ".png"))
    print("%d ícones em %s" % (len(actions), OUT_DIR))


if __name__ == "__main__":
    main()
