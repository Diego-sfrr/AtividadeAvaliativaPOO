# Tarefas — Mykael

Branch: `mykael` · Proposta inicial, sujeita a ajuste pelo grupo (ver `docs/DIVISAO_TRABALHO.md`).

## Responsabilidade principal
Stored procedures e roteiro de testes.

## Checklist
- [x] `sp_LoginUsuario`
- [x] `sp_matricular_aluno` (RN05, RN06, RN09; `SIGNAL SQLSTATE '45000'`)
- [x] `sp_lancar_notas`
- [x] `sp_lancar_exame` (somente se "Em Exame")
- [x] `sp_historico_aluno`
- [x] `sp_fechar_semestre` (cursor + transação; somente Coordenador)
- [x] `04_testes.sql`: os 9 testes obrigatórios
- [x] Casos de teste e resultados para o relatório
- [x] Aplicação desktop Java Swing/JDBC integrada em `app/` (login, menus por perfil, consultas e operações acadêmicas)

## Resultado da execução local

As procedures foram executadas no MySQL Workbench em uma base local com massa de desenvolvimento. Resultados observados:

- Login inválido retornou 0 usuários; login válido retornou perfil Coordenador.
- Turma lotada, ausência de pré-requisito e aluno Trancado foram recusados com SQLSTATE `45000` (erro MySQL 1644); a contagem da turma lotada permaneceu em 7.
- Nota 11 foi recusada pelo `CHECK ck_matricula_n1` (erro MySQL 3819).
- N1=5, N2=6, exame=7 produziu média final 6,25 e situação `Aprovado`.
- Média 9,00 com frequência 70% produziu `Reprovado por Falta`.
- `log_nota` registrou N2 de 5,00 para 6,00 e exame de NULL para 7,00.
- As três views acadêmicas retornaram dados; o histórico do aluno 1 retornou três matrículas.
- Matrícula válida foi aceita. Secretário não pôde fechar semestre; Coordenador encerrou duas turmas de `2026.1`.

O `04_testes.sql` usa os IDs da massa local `dev_03_dados_mykael.sql`, que está na cópia isolada de desenvolvimento. Ao integrar com a massa oficial de Guilherme, ajustar os IDs dos cenários conforme necessário. Execute cada bloco separadamente no Workbench, pois os testes negativos interrompem o restante do script.

## Também contribuo com
- [ ] Minha parte do relatório técnico (`relatorio/`)
- [ ] Meus slides da apresentação (`apresentacao/`)
- [ ] Dificuldades e soluções que enfrentei (para a seção obrigatória do relatório)
