# ============================================================
# SGA - Faculdade do Bug Infinito (FBI)
# gerar_SGA_completo.ps1: monta o database/SGA_completo.sql
# Responsavel: Diego
# ============================================================
# Junta os scripts do grupo, na ordem de execucao combinada, em um
# arquivo so para a entrega. O SGA_completo.sql e GERADO: ninguem
# edita ele na mao. Mudou algum script? Rode de novo:
#
#   powershell -ExecutionPolicy Bypass -File database\gerar_SGA_completo.ps1
#
# Funciona de qualquer pasta (usa o caminho do proprio script).
# (Este arquivo nao tem acentos de proposito: o PowerShell 5.1 le
# scripts sem BOM como ANSI e estragaria os textos acentuados.)
# ============================================================

$ErrorActionPreference = 'Stop'

$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path

# Ordem de execucao (pagina 3 do plano de ataque / README)
$arquivos = @(
    '01_ddl.sql',
    '02a_functions_views_triggers.sql',
    '02b_procedures.sql',
    '02c_procedures_cadastro.sql',
    '03_dados.sql',
    '04_testes.sql'
)

$nl = "`n"
$linha = '-- ' + ('=' * 60)

$partes = New-Object System.Collections.Generic.List[string]
$partes.Add($linha)
$partes.Add('-- SGA - Faculdade do Bug Infinito (FBI)')
$partes.Add('-- SGA_completo.sql: todos os scripts do banco, na ordem de execucao')
$partes.Add('--')
$partes.Add('-- ARQUIVO GERADO por database/gerar_SGA_completo.ps1. NAO EDITE AQUI:')
$partes.Add('-- altere o script de origem e gere de novo.')
$partes.Add('--')
$partes.Add('-- ATENCAO: apaga e recria o banco sga_fbi do zero.')
$partes.Add('-- No Workbench: abra este arquivo e execute tudo.')
$partes.Add('-- Os testes do final que devem falhar param o script: desligue a')
$partes.Add('-- opcao de parar no erro ou rode o bloco de testes um por vez.')
$partes.Add('--')
$partes.Add('-- Conteudo, na ordem:')
foreach ($a in $arquivos) { $partes.Add("--   $a") }
$partes.Add($linha)

foreach ($a in $arquivos) {
    $caminho = Join-Path $pasta $a
    if (-not (Test-Path $caminho)) {
        throw "Arquivo nao encontrado: $a (esperado em $pasta)"
    }

    $texto = [System.IO.File]::ReadAllText($caminho, [System.Text.Encoding]::UTF8)
    # Normaliza o fim de linha e tira espacos sobrando no fim do arquivo
    $texto = $texto.Replace("`r`n", "`n").TrimEnd()

    $partes.Add('')
    $partes.Add('')
    $partes.Add($linha)
    $partes.Add("-- >>> INICIO DE $a")
    $partes.Add($linha)
    $partes.Add('')
    $partes.Add($texto)
    $partes.Add('')
    # Garante que um arquivo que esqueceu de voltar o delimitador nao
    # quebre o proximo.
    $partes.Add('DELIMITER ;')
    $partes.Add("-- <<< FIM DE $a")
}

$saida = Join-Path $pasta 'SGA_completo.sql'
$conteudo = ($partes -join $nl) + $nl

# UTF-8 sem BOM, igual aos outros scripts
[System.IO.File]::WriteAllText($saida, $conteudo, (New-Object System.Text.UTF8Encoding($false)))

$linhas = ($conteudo -split $nl).Count
Write-Host "Gerado: $saida ($linhas linhas, $($arquivos.Count) scripts)"
