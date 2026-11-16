#!/usr/bin/env bash
# Junta os scripts na ordem de execução e gera database/SGA_completo.sql.
# Uso (na raiz do repo, no Git Bash): bash database/montar_sga_completo.sh
set -euo pipefail
cd "$(dirname "$0")"

ARQUIVOS=(
  01_ddl.sql
  02a_functions_views_triggers.sql
  02b_procedures.sql
  02c_procedures_cadastro.sql
  03_dados.sql
  04_testes.sql
)

{
  echo "-- ============================================================"
  echo "-- SGA - Faculdade do Bug Infinito (FBI)"
  echo "-- SGA_completo.sql: GERADO por montar_sga_completo.sh. Não edite aqui;"
  echo "-- edite os arquivos de origem e rode o script de novo."
  echo "-- Ordem: ${ARQUIVOS[*]}"
  echo "-- ============================================================"
  for f in "${ARQUIVOS[@]}"; do
    echo
    echo "-- >>>>>>>>>> $f"
    tr -d '\r' < "$f"
    echo
  done
} > SGA_completo.sql

echo "Gerado database/SGA_completo.sql"
