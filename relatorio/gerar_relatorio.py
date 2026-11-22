"""Monta o relatório técnico (PDF) a partir dos arquivos .md desta pasta.

Uso (na raiz do repositório ou em qualquer pasta):
    python relatorio/gerar_relatorio.py

Gera relatorio/Relatorio_SGA.html e relatorio/Relatorio_SGA.pdf.
Requisitos: Python 3 e Google Chrome (ou Edge) instalado, usado só para imprimir o PDF.
"""
import html
import os
import re
import subprocess
import sys

PASTA = os.path.dirname(os.path.abspath(__file__))
SAIDA_HTML = os.path.join(PASTA, 'Relatorio_SGA.html')
SAIDA_PDF = os.path.join(PASTA, 'Relatorio_SGA.pdf')

NAVEGADORES = [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    '/usr/bin/google-chrome', '/usr/bin/chromium', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
]


# --------------------------------------------------------------------------
# Conversor mínimo de Markdown -> HTML (o que os nossos .md usam)
# --------------------------------------------------------------------------
def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'&lt;u&gt;(.*?)&lt;/u&gt;', r'<u>\1</u>', t)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])', r'<em>\1</em>', t)
    t = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', t)  # links viram só o texto
    return t


def figura(alt, src):
    return (f'<figure><img src="{html.escape(src)}" alt="{html.escape(alt)}">'
            f'<figcaption>{inline(alt)}</figcaption></figure>')


def md(texto, nivel_base=0):
    linhas = texto.replace('\r\n', '\n').split('\n')
    out, i = [], 0
    while i < len(linhas):
        l = linhas[i]
        if l.strip().startswith('```'):
            lang = l.strip()[3:].strip()
            i += 1
            bloco = []
            while i < len(linhas) and not linhas[i].strip().startswith('```'):
                bloco.append(linhas[i])
                i += 1
            i += 1
            if lang == 'mermaid':
                continue
            out.append(f'<pre class="code"><code>{html.escape(chr(10).join(bloco))}</code></pre>')
            continue
        m = re.match(r'^(#{1,4})\s+(.*)$', l)
        if m:
            n = min(len(m.group(1)) + nivel_base, 5)
            out.append(f'<h{n}>{inline(m.group(2))}</h{n}>')
            i += 1
            continue
        if l.startswith('|') and i + 1 < len(linhas) and re.match(r'^\|[\s:|-]+\|?\s*$', linhas[i + 1]):
            cab = [c.strip() for c in l.strip().strip('|').split('|')]
            i += 2
            corpo = []
            while i < len(linhas) and linhas[i].startswith('|'):
                corpo.append([c.strip() for c in linhas[i].strip().strip('|').split('|')])
                i += 1
            h = '<table><thead><tr>' + ''.join(f'<th>{inline(c)}</th>' for c in cab) + '</tr></thead><tbody>'
            for r in corpo:
                tds = ''
                for c in r:
                    cls = ' class="c"' if c in ('sim', 'não', 'OK') else ''
                    tds += f'<td{cls}>{inline(c)}</td>'
                h += f'<tr>{tds}</tr>'
            out.append(h + '</tbody></table>')
            continue
        if re.match(r'^\s*[-*]\s+', l) or re.match(r'^\s*\d+\.\s+', l):
            ordenada = bool(re.match(r'^\s*\d+\.\s+', l))
            itens = []
            while i < len(linhas) and (re.match(r'^\s*[-*]\s+', linhas[i]) or re.match(r'^\s*\d+\.\s+', linhas[i])
                                       or (linhas[i].startswith('  ') and linhas[i].strip() and itens)):
                if re.match(r'^\s*([-*]|\d+\.)\s+', linhas[i]):
                    itens.append(re.sub(r'^\s*([-*]|\d+\.)\s+', '', linhas[i]))
                else:
                    itens[-1] += ' ' + linhas[i].strip()
                i += 1
            tag = 'ol' if ordenada else 'ul'
            out.append(f'<{tag}>' + ''.join(f'<li>{inline(x)}</li>' for x in itens) + f'</{tag}>')
            continue
        if l.strip().startswith('>'):
            q = []
            while i < len(linhas) and linhas[i].strip().startswith('>'):
                q.append(linhas[i].strip().lstrip('>').strip())
                i += 1
            out.append(f'<blockquote>{inline(" ".join(q))}</blockquote>')
            continue
        imgs = re.findall(r'!\[([^\]]*)\]\(([^)]+)\)', l)
        if imgs and re.sub(r'!\[[^\]]*\]\([^)]+\)', '', l).strip() == '':
            figs = ''.join(figura(a, s) for a, s in imgs)
            out.append(figs if len(imgs) == 1 else f'<div class="gal">{figs}</div>')
            i += 1
            continue
        if not l.strip():
            i += 1
            continue
        par = [l]
        i += 1
        while i < len(linhas) and linhas[i].strip() and not re.match(r'^(#{1,4}\s|\||```|\s*[-*]\s|\s*\d+\.\s|>|!\[)', linhas[i]):
            par.append(linhas[i])
            i += 1
        out.append(f'<p>{inline(" ".join(par))}</p>')
    return '\n'.join(out)


def le(nome):
    with open(os.path.join(PASTA, nome), encoding='utf-8') as f:
        return f.read()


def cortar(texto, de, ate=None):
    """Remove o trecho que começa em `de` e vai até `ate` (ou até o fim)."""
    a = texto.find(de)
    if a < 0:
        return texto
    b = texto.find(ate, a + len(de)) if ate else -1
    return texto[:a] + (texto[b:] if b >= 0 else '')


# --------------------------------------------------------------------------
# Conteúdo
# --------------------------------------------------------------------------
def secao(numero, titulo, corpo_html, quebra=True):
    cls = ' class="nova"' if quebra else ''
    return f'<section{cls}><h1><span class="n">{numero}</span>{html.escape(titulo)}</h1>{corpo_html}</section>'


def montar():
    # modelo de dados: tira o mermaid (vira o EER em imagem) e as instruções do Workbench
    modelo = le('modelo_dados.md')
    modelo = modelo.split('\n', 2)[2] if modelo.startswith('# ') else modelo
    modelo = cortar(modelo, '## Diagrama EER do Workbench (para o PDF)')
    modelo = modelo.replace('## Modelo lógico relacional\n',
                            '## Modelo lógico relacional\n\nO diagrama abaixo mostra as nove tabelas, suas chaves e os relacionamentos '
                            '(1 = lado um, N = lado muitos). A notação textual segue logo depois.\n\n'
                            '![Diagrama EER do banco sga_fbi](img/eer_sga_fbi.png)\n')
    modelo = re.sub(r'^Responsável:.*\n', '', modelo, flags=re.M)
    modelo = re.sub(r'^Notação textual.*\n', 'Notação textual (chave primária sublinhada, chave estrangeira com seta):\n', modelo, flags=re.M)

    fvt = le('functions_views_triggers.md')
    fvt = fvt.split('\n', 2)[2]
    fvt = cortar(fvt, '## Dificuldades e soluções (parte do Diego)')
    fvt = re.sub(r'^Responsável:.*\n', '', fvt, flags=re.M)
    fvt = cortar(fvt, '## O que as outras partes precisam saber', '## Como testar')
    fvt = cortar(fvt, '## Como testar')
    fvt = fvt.replace('A razão de existirem está em "Dificuldades", abaixo.', 'A razão de existirem está na seção "Principais dificuldades".')

    pt = le('procedures_e_testes.md')
    pt = pt.split('\n', 2)[2]
    pt = re.sub(r'^Parte do Mykael\..*\n', '', pt, flags=re.M)
    proc = cortar(pt, '## 3. Roteiro de testes')
    proc = proc.replace('## 1. Procedures', '## Procedures').replace('## 2. Criptografia e perfis', '## Criptografia e perfis')
    testes_bd = pt[pt.index('## 3. Roteiro de testes'):]
    testes_bd = cortar(testes_bd, '## 4. Principais dificuldades e soluções')
    testes_bd = testes_bd.replace('## 3. Roteiro de testes (`04_testes.sql`)', '## Testes das regras no banco (`04_testes.sql`)')

    partes = [
        secao(1, 'Introdução', md(le('introducao.md'), 0).replace('<h1>Introdução</h1>', '')),
        secao(2, 'Modelo de dados (MER e modelo lógico)', md(modelo, 0)),
        secao(3, 'Normalização até a 3FN', md(le('normalizacao_3fn.md').split('\n', 2)[2], 0)),
        secao(4, 'Functions, views e triggers', md(fvt, 0)),
        secao(5, 'Procedures, criptografia e perfis', md(proc, 0)),
        secao(6, 'Interface e controle de acesso', md(le('interface_e_acesso.md').split('\n', 2)[2], 0)),
        secao(7, 'Casos de teste', md(testes_bd, 0) + md(le('testes_interface.md').split('\n', 2)[2].replace('## ', '## '), 0)),
        secao(8, 'Principais dificuldades encontradas e soluções', md(le('dificuldades.md').split('\n', 2)[2], 0)),
    ]
    return partes


CSS = r'''
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
@page eer { size: A4 landscape; margin: 12mm; }
* { box-sizing: border-box; }
body { font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #0f172a; }
.capa { height: 255mm; display: flex; flex-direction: column; justify-content: center; padding: 0 6mm; page-break-after: always; }
.capa .marca { font-size: 64pt; font-weight: 800; letter-spacing: -1px; color: #0f172a; line-height: 1; }
.capa .sub { font-size: 20pt; color: #2563eb; font-weight: 600; margin: 6mm 0 14mm; }
.capa .linha { height: 4px; width: 60mm; background: #2563eb; margin-bottom: 12mm; }
.capa p { margin: 1.5mm 0; font-size: 12pt; color: #334155; }
.capa .rodape { margin-top: 28mm; font-size: 10.5pt; color: #64748b; }
h1 { font-size: 21pt; margin: 0 0 6mm; padding-bottom: 3mm; border-bottom: 2px solid #0f172a; page-break-after: avoid; }
h1 .n { display: inline-block; background: #2563eb; color: #fff; border-radius: 6px; padding: 0 9px; margin-right: 10px; font-size: 17pt; }
h2 { font-size: 14.5pt; margin: 8mm 0 2.5mm; color: #1e3a8a; page-break-after: avoid; }
h3 { font-size: 12pt; margin: 6mm 0 2mm; page-break-after: avoid; }
h4 { font-size: 10.5pt; margin: 4mm 0 1mm; }
p { margin: 0 0 2.6mm; text-align: justify; hyphens: auto; }
section.nova { page-break-before: always; }
ul, ol { margin: 0 0 3mm 5mm; padding-left: 5mm; }
li { margin-bottom: 1mm; }
code { font-family: Consolas, "Courier New", monospace; font-size: 9.2pt; background: #f1f5f9; padding: 0 3px; border-radius: 3px; }
pre.code { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 3mm 4mm; font-size: 8.4pt; line-height: 1.35; overflow: hidden; white-space: pre-wrap; page-break-inside: avoid; }
pre.code code { background: none; padding: 0; font-size: inherit; }
table { border-collapse: collapse; width: 100%; margin: 2mm 0 4mm; font-size: 9pt; page-break-inside: auto; }
thead { display: table-header-group; }
tr { page-break-inside: avoid; }
th { background: #0f172a; color: #fff; text-align: left; padding: 1.6mm 2.2mm; font-weight: 600; }
td { border-bottom: 1px solid #e2e8f0; padding: 1.5mm 2.2mm; vertical-align: top; }
tbody tr:nth-child(even) td { background: #f8fafc; }
td.c { text-align: center; }
blockquote { border-left: 3px solid #2563eb; margin: 2mm 0 3mm; padding: 1mm 4mm; color: #334155; background: #eff6ff; }
figure { margin: 3mm 0 4mm; text-align: center; page-break-inside: avoid; }
figure img { max-width: 100%; height: auto; border: 1px solid #e2e8f0; border-radius: 6px; box-shadow: 0 1px 4px rgba(15,23,42,.12); }
figcaption { font-size: 8.8pt; color: #64748b; margin-top: 1.5mm; }
.gal { display: flex; flex-wrap: wrap; gap: 4mm; justify-content: center; align-items: flex-end; margin: 2mm 0 4mm; page-break-inside: avoid; }
.gal figure { margin: 0; }
.gal img { max-width: 62mm; }
section.eer { page: eer; page-break-before: always; page-break-after: always; }
section.eer h2 { margin-top: 0; }
section.eer img { max-width: 100%; max-height: 150mm; border: none; box-shadow: none; }
a { color: inherit; text-decoration: none; }
'''


def capa():
    return '''<div class="capa">
<div class="marca">SGA</div>
<div class="sub">Sistema de Gestão Acadêmica</div>
<div class="linha"></div>
<p><strong>Relatório técnico</strong></p>
<p>Trabalho Prático Integrado de Laboratório de Banco de Dados</p>
<p>Banco de dados relacional (MySQL) e interface desktop (Java Swing)</p>
<div class="rodape">
<p>Equipe: Guilherme, Diego, Mykael e Leo</p>
<p>Entrega e apresentação: 23/11/2026</p>
</div></div>'''


def indice(partes):
    itens = re.findall(r'<h1><span class="n">(\d+)</span>([^<]+)</h1>', ''.join(partes))
    li = ''.join(f'<li><strong>{n}.</strong> {t}</li>' for n, t in itens)
    return f'<section class="nova"><h1>Sumário</h1><ul style="list-style:none;margin-left:0;padding-left:0;font-size:12pt;line-height:2">{li}</ul></section>'


def main():
    partes = montar()
    # a figura do EER vai em página paisagem própria, dentro da seção 2
    partes[1] = re.sub(
        r'(<h2>Modelo lógico relacional</h2>\s*<p>.*?</p>\s*)<figure><img src="img/eer_sga_fbi.png"',
        r'</section><section class="eer">\1<figure><img src="img/eer_sga_fbi.png"', partes[1], count=1, flags=re.S)
    partes[1] = re.sub(r'(<figcaption>Diagrama EER do banco sga_fbi</figcaption></figure>)',
                       r'\1</section><section>', partes[1], count=1)
    doc = f'''<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Relatório técnico do SGA</title>
<style>{CSS}</style></head><body>{capa()}{indice(partes)}{''.join(partes)}</body></html>'''
    with open(SAIDA_HTML, 'w', encoding='utf-8') as f:
        f.write(doc)

    nav = next((n for n in NAVEGADORES if os.path.exists(n)), None)
    if not nav:
        sys.exit('Chrome/Edge não encontrado: abra Relatorio_SGA.html no navegador e imprima em PDF.')
    uri = 'file:///' + SAIDA_HTML.replace('\\', '/')
    subprocess.run([nav, '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
                    f'--print-to-pdf={SAIDA_PDF}', uri], check=True, capture_output=True)
    print('ok:', SAIDA_PDF)


if __name__ == '__main__':
    main()
