"""Gera os guias de estudo (PDF) de cada integrante a partir dos .md desta pasta.

Uso:
    python docs/guias/gerar_guias.py            # gera todos os guias que existirem
    python docs/guias/gerar_guias.py diego      # gera só o do Diego

Para cada guia_<nome>.md cria Guia_<Nome>.pdf ao lado. Reaproveita o conversor de
Markdown e o Chrome/Edge do relatório (relatorio/gerar_relatorio.py).
"""
import html
import importlib.util
import os
import subprocess
import sys

PASTA = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(PASTA))

spec = importlib.util.spec_from_file_location('rel', os.path.join(RAIZ, 'relatorio', 'gerar_relatorio.py'))
rel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rel)

GUIAS = {
    'diego': ('Diego', 'Functions, views e triggers'),
    'mykael': ('Mykael', 'Procedures e testes'),
    'leo': ('Leo', 'Interface, login e controle de acesso'),
    'guilherme': ('Guilherme', 'Banco, dados e telas do Coordenador'),
    'roteiro': ('Grupo', 'Roteiro da apresentação e da demonstração'),
}

CSS_EXTRA = r'''
h1 { page-break-before: always; font-size: 19pt; }
section.primeira h1:first-of-type { page-break-before: avoid; }
pre.code { font-size: 8.6pt; page-break-inside: auto; margin: 2mm 0 2mm; border-left: 3px solid #2563eb; }
table { font-size: 9.2pt; }
td:first-child { width: 34%; white-space: normal; overflow-wrap: anywhere; font-family: Consolas, monospace; font-size: 8.6pt; color: #1e3a8a; }
blockquote { background: #fffbeb; border-left-color: #f59e0b; }
.capa .marca { font-size: 54pt; }
'''


def capa(nome, assunto):
    return f'''<div class="capa">
<div class="marca">{html.escape(nome)}</div>
<div class="sub">Guia de estudo: {html.escape(assunto)}</div>
<div class="linha"></div>
<p><strong>SGA, Sistema de Gestão Acadêmica</strong></p>
<p>Trabalho de Laboratório de Banco de Dados, apresentação em 23/11/2026</p>
<p>Este guia explica a sua parte do projeto, trecho por trecho e linha por linha,
com o que falar na apresentação e as perguntas que o professor pode fazer.</p>
</div>'''


def gerar(chave):
    nome, assunto = GUIAS[chave]
    origem = os.path.join(PASTA, f'guia_{chave}.md')
    if not os.path.exists(origem):
        print('sem arquivo:', origem)
        return
    with open(origem, encoding='utf-8') as f:
        corpo = rel.md(f.read())
    doc = (f'<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Guia {nome}</title>'
           f'<style>{rel.CSS}{CSS_EXTRA}</style></head><body>{capa(nome, assunto)}'
           f'<section class="primeira">{corpo}</section></body></html>')
    saida_html = os.path.join(PASTA, f'Guia_{nome}.html')
    saida_pdf = os.path.join(PASTA, f'Guia_{nome}.pdf')
    with open(saida_html, 'w', encoding='utf-8') as f:
        f.write(doc)
    nav = next((n for n in rel.NAVEGADORES if os.path.exists(n)), None)
    if not nav:
        sys.exit('Chrome/Edge não encontrado')
    subprocess.run([nav, '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
                    f'--print-to-pdf={saida_pdf}', 'file:///' + saida_html.replace('\\', '/')],
                   check=True, capture_output=True)
    os.remove(saida_html)
    print('ok:', saida_pdf)


if __name__ == '__main__':
    alvo = sys.argv[1:] or list(GUIAS)
    for c in alvo:
        gerar(c)
