-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 04_testes.sql: roteiro de testes (Mykael)
-- ============================================================
-- Preparacao da base limpa (executar uma vez, nesta ordem):
--   01_ddl.sql
--   02a_functions_views_triggers.sql
--   02b_procedures.sql
--   dev_03_dados_mykael.sql  (massa local da pasta isolada)
--
-- ATENCAO: nao execute este arquivo inteiro de uma vez.
-- Os casos marcados ESPERA ERRO passam quando o MySQL os rejeita;
-- um erro esperado interrompe a execucao de scripts seguintes.
-- Selecione e execute cada bloco individualmente no Workbench.
-- Os IDs abaixo correspondem a massa de desenvolvimento deste projeto.
-- O arquivo dev_03_dados_mykael.sql e para desenvolvimento local;
-- substitua pelos IDs da massa oficial quando o grupo a fornecer.
-- ============================================================

USE sga_fbi;

-- TESTE 1 - Login inexistente (espera resultado vazio, sem erro).
CALL sp_LoginUsuario('login_inexistente', SHA2('Senha@123', 256));

-- TESTE 1B - Login valido (espera 1 linha, sem coluna de senha).
CALL sp_LoginUsuario('coord1', SHA2('Senha@123', 256));

-- TESTE 2 - Turma 1 lotada (ESPERA ERRO SQLSTATE 45000).
CALL sp_matricular_aluno(8, 1, 3);
-- Conferencia, executar depois do erro: deve continuar retornando 7.
SELECT COUNT(*) AS matriculas_turma_1
  FROM matricula
 WHERE id_turma = 1;

-- TESTE 3 - Aluno sem pre-requisito (ESPERA ERRO SQLSTATE 45000).
CALL sp_matricular_aluno(8, 2, 3);

-- TESTE 4 - Aluno Trancado (ESPERA ERRO SQLSTATE 45000).
CALL sp_matricular_aluno(20, 2, 3);

-- TESTE 5 - CHECK de nota: executar isoladamente; espera erro 3819
-- indicando violacao de ck_matricula_n1; a nota deve permanecer 5.00.
UPDATE matricula
   SET n1 = 11
 WHERE id_matricula = 8;
-- Conferencia, executar depois do erro:
SELECT id_matricula, n1
  FROM matricula
 WHERE id_matricula = 8;

-- TESTE 6A - Lancar notas na faixa de exame. Espera situacao Em Exame.
CALL sp_lancar_notas(8, 5, 6, 0, 1);
SELECT id_matricula, n1, n2, media_final, situacao
  FROM matricula
 WHERE id_matricula = 8;

-- TESTE 6B - Exame 7.00: media final esperada 6.25 e Aprovado.
CALL sp_lancar_exame(8, 7, 1);
SELECT id_matricula, n1, n2, exame, media_final, situacao
  FROM matricula
 WHERE id_matricula = 8;

-- TESTE 6C - Exame em situacao diferente de Em Exame (ESP. ERRO).
CALL sp_lancar_exame(8, 7, 1);

-- TESTE 7 - Media alta com frequencia abaixo de 75%:
-- id_matricula 15 deve mostrar media 9.00, frequencia 70.00,
-- situacao Reprovado por Falta.
SELECT id_matricula, n1, n2, media_final, faltas, frequencia, situacao
  FROM vw_boletim
 WHERE id_matricula = 15;

-- TESTE 8 - Alterar notas e conferir a auditoria em log_nota.
CALL sp_lancar_notas(8, 7, 8, 0, 1);
SELECT id_matricula, campo, valor_antigo, valor_novo, usuario, data_hora
  FROM log_nota
 WHERE id_matricula = 8
 ORDER BY id_log;

-- TESTE 9 - Consultar as tres views obrigatorias (um SELECT por bloco).
SELECT * FROM vw_boletim ORDER BY semestre, aluno LIMIT 10;
SELECT * FROM vw_turmas_lotacao ORDER BY id_turma;
SELECT * FROM vw_desempenho_turma ORDER BY id_turma;

-- TESTE EXTRA - Historico do aluno 1 (espera 3 matriculas ordenadas).
CALL sp_historico_aluno(1);

-- TESTE EXTRA A - Matricula valida: turma 3 deve aceitar o aluno 15.
CALL sp_matricular_aluno(15, 3, 3);
SELECT id_aluno, id_turma, situacao
  FROM matricula
 WHERE id_aluno = 15 AND id_turma = 3;

-- TESTE EXTRA B - Secretario nao pode lancar notas (ESP. ERRO).
CALL sp_lancar_notas(8, 7, 8, 0, 3);

-- TESTE EXTRA C - Somente Coordenador pode fechar semestre.
-- Primeiro execute como Secretario: ESPERA ERRO SQLSTATE 45000.
CALL sp_fechar_semestre('2026.1', 3);
-- Depois execute como Coordenador: espera 2 turmas encerradas.
CALL sp_fechar_semestre('2026.1', 1);
SELECT id_turma, semestre, status
  FROM turma
 WHERE semestre = '2026.1'
 ORDER BY id_turma;
