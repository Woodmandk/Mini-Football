# Draws the Banebold logo options and the final logo files (SVG) from the game font. Needs fonttools.
# Run: python3 logo/make_logo.py /tmp/options logo
import math, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
F = '/home/user/mini-football/godot3d/fonts/ChakraPetch-Bold.ttf'
font = TTFont(F); gs = font.getGlyphSet(); cmap = font.getBestCmap(); upm = font['head'].unitsPerEm
def text(s, x, y, size, track=0, skew=0, anchor='start'):
    sc = size/upm
    # width
    w = 0
    for ch in s: w += gs[cmap[ord(ch)]].width*sc + track
    w -= track
    if anchor=='middle': x -= w/2
    pen = SVGPathPen(gs); cx = x
    for ch in s:
        g = gs[cmap[ord(ch)]]
        # y up in font -> flip; skew: x += tan*fy
        t = (sc, 0, math.tan(math.radians(skew))*sc, -sc, cx, y)
        g.draw(TransformPen(pen, t)); cx += g.width*sc + track
    return pen.getCommands(), w
def ball(cx, cy, r, fill='#f3f1e7', ink='#0f1d16', sw=None):
    sw = sw or r*0.07
    # center pentagon
    pr = r*0.36
    pts = [(cx+pr*math.sin(math.radians(a)), cy-pr*math.cos(math.radians(a))) for a in range(0,360,72)]
    out = [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>']
    cid = f'bc{int(cx)}{int(cy)}{int(r)}'
    out.append(f'<clipPath id="{cid}"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath><g clip-path="url(#{cid})">')
    out.append('<polygon points="%s" fill="%s"/>' % (' '.join(f'{a:.2f},{b:.2f}' for a,b in pts), ink))
    for i,a in enumerate(range(0,360,72)):
        # seam from pentagon vertex outward
        px,py = pts[i]; ang=math.radians(a)
        ex,ey = cx+r*0.72*math.sin(ang), cy-r*0.72*math.cos(ang)
        out.append(f'<line x1="{px:.2f}" y1="{py:.2f}" x2="{ex:.2f}" y2="{ey:.2f}" stroke="{ink}" stroke-width="{sw:.2f}"/>')
        # outer patch centred between
        oa = math.radians(a+36); orr=r*1.02; prr=r*0.30
        ox,oy = cx+orr*math.sin(oa), cy-orr*math.cos(oa)
        opts = [(ox+prr*math.sin(oa+math.radians(k)), oy-prr*math.cos(oa+math.radians(k))) for k in range(0,360,72)]
        out.append('<polygon points="%s" fill="%s"/>' % (' '.join(f'{a2:.2f},{b2:.2f}' for a2,b2 in opts), ink))
    out.append('</g>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{r-sw/2}" fill="none" stroke="{ink}" stroke-width="{sw:.2f}"/>')
    return ''.join(out)
BG='#0f1d16'; S2='#1e3529'; CH='#f3f1e7'; G='#33c95f'; GL='#1c6a3a'; GO='#ffc83d'
def svg(w,h,body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{body}</svg>'
logos = {}
# ---------- 1: KRIDT (chalk wordmark, O = centre circle) ----------
def l1(icon=False):
    if icon:
        b = f'<rect width="512" height="512" rx="112" fill="{G}"/>'
        b += f'<rect y="0" width="512" height="512" rx="112" fill="url(#st)"/>'
        b += f'<line x1="256" y1="40" x2="256" y2="472" stroke="{CH}" stroke-width="22"/>'
        b += f'<circle cx="256" cy="256" r="150" fill="none" stroke="{CH}" stroke-width="22"/>'
        b += ball(256,256,78)
        defs = f'<defs><pattern id="st" width="128" height="512" patternUnits="userSpaceOnUse"><rect width="64" height="512" fill="#000" opacity=".10"/></pattern></defs>'
        return svg(512,512,defs+b)
    W,H=1200,360
    b = ''
    p1,w1 = text('BANEB', 0, 0, 170, 6, 0)
    p2,w2 = text('LD', 0, 0, 170, 6, 0)
    gap=150; tot=w1+gap+w2; x0=(W-tot)/2; y=235
    p1,_ = text('BANEB', x0, y, 170, 6, 9)
    p2,_ = text('LD', x0+w1+gap, y, 170, 6, 9)
    ocx = x0+w1+gap/2+6; ocy=y-62
    b += f'<path d="{p1}" fill="{CH}"/><path d="{p2}" fill="{CH}"/>'
    b += f'<circle cx="{ocx}" cy="{ocy}" r="66" fill="none" stroke="{G}" stroke-width="14"/>'
    b += f'<line x1="{ocx}" y1="{ocy-96}" x2="{ocx}" y2="{ocy+96}" stroke="{G}" stroke-width="14"/>'
    b += ball(ocx,ocy,34)
    # chalk underline
    b += f'<path d="M{x0+20} 285 L{x0+tot-20} 285" stroke="{G}" stroke-width="10" stroke-linecap="round"/>'
    return svg(W,H,b)
# ---------- 2: SKJOLD (crest) ----------
def shield(cx, top, w, h):
    l=cx-w/2; r=cx+w/2
    return f'M{l} {top+h*0.06} Q{cx} {top-h*0.04} {r} {top+h*0.06} L{r} {top+h*0.52} Q{r} {top+h*0.84} {cx} {top+h} Q{l} {top+h*0.84} {l} {top+h*0.52} Z'
def crest(cx, top, w, h, idp):
    d = shield(cx,top,w,h)
    b = f'<clipPath id="{idp}"><path d="{d}"/></clipPath>'
    b += f'<path d="{d}" fill="{GL}"/>'
    b += f'<g clip-path="url(#{idp})">'
    n=6; sw=w/n
    for i in range(n):
        if i%2==0: b+=f'<rect x="{cx-w/2+i*sw}" y="{top-h*0.1}" width="{sw}" height="{h*1.2}" fill="{G}" opacity=".55"/>'
    b += f'<line x1="{cx-w}" y1="{top+h*0.47}" x2="{cx+w}" y2="{top+h*0.47}" stroke="{CH}" stroke-width="{w*0.035}"/>'
    b += f'<circle cx="{cx}" cy="{top+h*0.47}" r="{w*0.27}" fill="none" stroke="{CH}" stroke-width="{w*0.035}"/>'
    b += '</g>'
    b += ball(cx, top+h*0.47, w*0.15)
    b += f'<path d="{d}" fill="none" stroke="{CH}" stroke-width="{w*0.045}"/>'
    b += f'<path d="{shield(cx,top+w*0.06,w*0.86,h-w*0.11)}" fill="none" stroke="{GO}" stroke-width="{w*0.012}" opacity=".9"/>'
    return b
def l2(icon=False):
    if icon:
        b = f'<rect width="512" height="512" rx="112" fill="{BG}"/>' + crest(256, 52, 330, 410, 'c2i')
        return svg(512,512,b)
    W,H=1200,360
    b = crest(170, 30, 230, 300, 'c2')
    p,w = text('BANEBOLD', 330, 205, 150, 4, 7)
    b += f'<path d="{p}" fill="{CH}"/>'
    p,w2 = text('PLAY THE MATCH', 336, 262, 40, 10, 0)
    b += f'<path d="{p}" fill="{GO}"/>'
    return svg(W,H,b)
# ---------- 3: STAK (stacked block wordmark, ball in flight) ----------
def l3(icon=False):
    if icon:
        b = f'<rect width="512" height="512" rx="112" fill="{BG}"/>'
        p,w = text('BB', 0,0, 300, -6, 10)
        p,w = text('BB', 256-w/2-10, 360, 300, -6, 10)
        b += f'<path d="{p}" fill="{CH}"/>'
        b += f'<rect x="0" y="392" width="512" height="120" fill="{G}" clip-path="url(#ic3)"/>'
        b += f'<clipPath id="ic3"><rect width="512" height="512" rx="112"/></clipPath>'
        for i,(x,y,l) in enumerate([(300,438,120),(270,466,80)]):
            pass
        b += ball(400,438,46,CH,BG)
        b += f'<path d="M60 430 L320 430 M110 452 L330 452" stroke="{BG}" stroke-width="10" stroke-linecap="round" opacity=".55"/>'
        return svg(512,512,b)
    W,H=1200,360
    b=''
    p,w = text('BANE', 0,0, 150, 4, 10)
    x0 = (W-w)/2+60
    p,_ = text('BANE', x0, 160, 150, 4, 10)
    b += f'<path d="{p}" fill="{CH}"/>'
    b += f'<path d="M{x0-40} 184 L{x0+w+50} 184 L{x0+w+28} 330 L{x0-62} 330 Z" fill="{G}"/>'
    p,_ = text('BOLD', x0-36, 310, 150, 4, 10)
    b += f'<path d="{p}" fill="{BG}"/>'
    bx = x0-150
    b += f'<path d="M{bx-230} 60 L{bx-90} 60 M{bx-180} 100 L{bx-80} 100 M{bx-250} 140 L{bx-100} 140" stroke="{G}" stroke-width="12" stroke-linecap="round"/>'
    b += ball(bx,100,62)
    return svg(W,H,b)
import pathlib
out = pathlib.Path(sys.argv[1]); out.mkdir(exist_ok=True)
for k,f in [('1-kridt',l1),('2-skjold',l2),('3-stak',l3)]:
    (out/f'{k}.svg').write_text(f()); (out/f'{k}-ikon.svg').write_text(f(True))

# ---------- final assets for the chosen logo (3 Stak, Daniel's pick 2026-11-14) ----------
def stack(x0, top, size):
    """BANE over a green slab with BOLD, ball flying in from the left. x0 = left of BANE, top = top of BANE."""
    k = size/150
    p,w = text('BANE', 0,0, size, 4*k, 10)
    b = ''
    p,_ = text('BANE', x0, top+110*k, size, 4*k, 10)
    b += f'<path d="{p}" fill="{CH}"/>'
    y1 = top+134*k; y2 = top+280*k
    b += f'<path d="M{x0-40*k} {y1} L{x0+w+50*k} {y1} L{x0+w+28*k} {y2} L{x0-62*k} {y2} Z" fill="{G}"/>'
    p,_ = text('BOLD', x0-36*k, top+260*k, size, 4*k, 10)
    b += f'<path d="{p}" fill="{BG}"/>'
    bx = x0-150*k; by = top+50*k
    b += f'<path d="M{bx-230*k} {by-40*k} L{bx-90*k} {by-40*k} M{bx-180*k} {by} L{bx-80*k} {by} M{bx-250*k} {by+40*k} L{bx-100*k} {by+40*k}" stroke="{G}" stroke-width="{12*k}" stroke-linecap="round"/>'
    b += ball(bx, by, 62*k)
    return b, w
def inline(x, cy, size):
    """One line: ball, BANE, BOLD on a green slab. Returns markup and right edge."""
    k = size/150
    b = ball(x+62*k, cy, 62*k)
    x1 = x+150*k
    p,w1 = text('BANE', x1, cy+52*k, size, 4*k, 10)
    b += f'<path d="{p}" fill="{CH}"/>'
    _,w2 = text('BOLD', 0, 0, size, 4*k, 10)
    x2 = x1+w1+42*k
    b += f'<path d="M{x2-14*k} {cy-72*k} L{x2+w2+44*k} {cy-72*k} L{x2+w2+24*k} {cy+74*k} L{x2-34*k} {cy+74*k} Z" fill="{G}"/>'
    p,_ = text('BOLD', x2+4*k, cy+52*k, size, 4*k, 10)
    b += f'<path d="{p}" fill="{BG}"/>'
    return b, x2+w2+50*k
def bb(cx, base, size, col=CH):
    _,w = text('BB', 0,0, size, -0.02*size, 10)
    p,_ = text('BB', cx-w/2-0.03*size, base, size, -0.02*size, 10)
    return f'<path d="{p}" fill="{col}"/>'
def icon_body(s=1.0):
    # BB in chalk, green slab with the ball rolling along it
    c = 256
    b = bb(c, c+(360-256)*s, 300*s)
    top = c+(392-256)*s
    b += f'<rect x="0" y="{top}" width="512" height="{512-top}" fill="{G}"/>'
    b += f'<path d="M{c-196*s} {top+38*s} L{c+60*s} {top+38*s} M{c-146*s} {top+66*s} L{c+70*s} {top+66*s}" stroke="{BG}" stroke-width="{10*s}" stroke-linecap="round" opacity=".55"/>'
    b += ball(c+144*s, top+46*s, 46*s, CH, BG)
    return b
def final(dst):
    d = pathlib.Path(dst); d.mkdir(exist_ok=True, parents=True)
    for f in d.glob('*.svg'): f.unlink()
    (d/'logo.svg').write_text(l3())
    m, r = inline(8, 80, 112)
    (d/'logo-compact.svg').write_text(svg(int(r+8), 160, m))
    cl = '<clipPath id="ri"><rect width="512" height="512" rx="112"/></clipPath>'
    (d/'icon.svg').write_text(svg(512,512, cl+f'<g clip-path="url(#ri)"><rect width="512" height="512" fill="{BG}"/>'+icon_body()+'</g>'))
    (d/'icon-small.svg').write_text(svg(512,512, cl+f'<g clip-path="url(#ri)"><rect width="512" height="512" fill="{S2}"/>'+icon_body()+'</g>'))
    # maskable: full bleed, content inside the safe circle
    (d/'icon-maskable.svg').write_text(svg(512,512, f'<rect width="512" height="512" fill="{BG}"/>'+bb(256, 300, 230)+f'<rect x="0" y="330" width="512" height="182" fill="{G}"/>'+ball(330, 368, 36, CH, BG)+f'<path d="M110 360 L270 360 M150 384 L280 384" stroke="{BG}" stroke-width="8" stroke-linecap="round" opacity=".55"/>'))
    sz = 118; k = sz/150
    _, w = stack(0, 0, sz)
    left, right = -400*k, w + 50*k  # speed lines .. end of the slab
    b, w = stack((800 - (right-left))/2 - left, 300 - 134*k, sz)
    (d/'splash.svg').write_text(svg(800,600, '<rect width="800" height="600" fill="#0d1a14"/>'+b))
if len(sys.argv) > 2: final(sys.argv[2])
