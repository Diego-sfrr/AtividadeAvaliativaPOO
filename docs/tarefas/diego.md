# Tarefas — Diego

Branch: `diego` · Regras de negócio dentro do banco (ver `docs/DIVISAO_TRABALHO.md`).

Arquivos: `database/02a_functions_views_triggers.sql`, `database/SGA_completo.sql`, `apresentacao/`.

## S1 · Functions (até 01/11)
- [x] `fn_calcular_media(n1, n2, exame)` (RN01, RN03)
- [x] `fn_frequencia(id_matricula)`
- [x] `fn_situacao(id_matricula)` (RN02, RN03, RN04) + auxiliares `fn_frequencia_valores` e `fn_situacao_valores`

## S2 · Views e triggers (até 08/11)
- [x] `vw_boletim` (+ `id_matricula` e `id_turma`)
- [x] `vw_turmas_lotacao`
- [x] `vw_desempenho_turma`
- [x] `trg_valida_vagas` (RN05)
- [x] `trg_auditoria_nota` (RN08)
- [x] `trg_atualiza_situacao`
- [x] Extra: `trg_calcula_situacao_insert` (situação já na inserção da massa de dados)

## S3 · Extras e script final (até 15/11)
- [x] `vw_faturamento_curso`
- [x] `fn_cr_aluno` (opcional)
- [x] `SGA_completo.sql` (`bash database/montar_sga_completo.sh`; regerar após cada merge)
- [ ] Rodar o `SGA_completo.sql` do zero no Workbench, com a integração de todos

## S4 · Slides e relatório (até 20/11)
- [x] Meus slides: `apresentacao/diego_functions_views_triggers.pptx`
- [ ] Juntar os slides de todos
- [ ] Explicação de functions, views e triggers no relatório
- [ ] Meu parágrafo em "Dificuldades e Soluções"
