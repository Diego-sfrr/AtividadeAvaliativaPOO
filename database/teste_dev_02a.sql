-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- teste_dev_02a.sql: teste rápido das functions, views e triggers
-- Responsável: Diego
-- ============================================================
-- NÃO é o roteiro oficial (esse é o 04_testes.sql, do Mykael) e NÃO
-- entra no SGA_completo.sql. Serve para quem for revisar o PR do 02a
-- conseguir testar sem depender da massa de dados.
--
-- Como usar:
--   1. Rode 01_ddl.sql e 02a_functions_views_triggers.sql.
--   2. Rode este arquivo. No Workbench, desligue a opção de parar no
--      erro (ou rode bloco a bloco): o teste 4 FALHA de propósito.
--   3. Compare a coluna "obtido" com a coluna "esperado".
--
-- Tudo roda dentro de uma transação que termina em ROLLBACK, então
-- nenhum dado de teste fica no banco. Só os contadores de
-- AUTO_INCREMENT avançam: antes de carregar o 03_dados.sql, rode o
-- 01_ddl.sql de novo para os IDs dos cenários começarem do 1.
-- ============================================================

USE sga_fbi;

-- ------------------------------------------------------------
-- 1. fn_calcular_media (não precisa de dados)
-- ------------------------------------------------------------
SELECT 'media: sem N2'             AS teste, NULL AS esperado, fn_calcular_media(8, NULL, NULL) AS obtido
UNION ALL SELECT 'media: parcial',           8.50, fn_calcular_media(8, 9, NULL)
UNION ALL SELECT 'media: exame pendente',    5.50, fn_calcular_media(5, 6, NULL)
UNION ALL SELECT 'media: com exame',         6.25, fn_calcular_media(5, 6, 7)
UNION ALL SELECT 'media: exame ignorado',    8.50, fn_calcular_media(8, 9, 2)
UNION ALL SELECT 'media: arredonda 6.995',   7.00, fn_calcular_media(6.99, 7.00, NULL);

-- ------------------------------------------------------------
-- 2. fn_frequencia_calc e fn_situacao_calc (não precisam de dados)
-- ------------------------------------------------------------
SELECT 'freq: 20 faltas em 80'     AS teste, 75.00 AS esperado, fn_frequencia_calc(20, 80) AS obtido
UNION ALL SELECT 'freq: 21 faltas em 80',    73.75, fn_frequencia_calc(21, 80)
UNION ALL SELECT 'freq: trunca 2/3',         66.66, fn_frequencia_calc(1, 3)
UNION ALL SELECT 'freq: mais faltas q aulas', 0.00, fn_frequencia_calc(90, 80);

SELECT 'sit: sem notas'            AS teste, 'Cursando'            AS esperado, fn_situacao_calc(NULL, NULL, NULL, 0, 80) AS obtido
UNION ALL SELECT 'sit: 7.0 exato',           'Aprovado',            fn_situacao_calc(7, 7, NULL, 0, 80)
UNION ALL SELECT 'sit: 6.99',                'Em Exame',            fn_situacao_calc(6.99, 6.99, NULL, 0, 80)
UNION ALL SELECT 'sit: 4.0 exato',           'Em Exame',            fn_situacao_calc(4, 4, NULL, 0, 80)
UNION ALL SELECT 'sit: 3.99',                'Reprovado por Nota',  fn_situacao_calc(3.99, 3.99, NULL, 0, 80)
UNION ALL SELECT 'sit: exame aprova (5.0)',  'Aprovado',            fn_situacao_calc(5, 5, 5, 0, 80)
UNION ALL SELECT 'sit: exame reprova',       'Reprovado por Nota',  fn_situacao_calc(5, 5, 4.9, 0, 80)
UNION ALL SELECT 'sit: 75% de frequencia',   'Aprovado',            fn_situacao_calc(9, 9, NULL, 20, 80)
UNION ALL SELECT 'sit: media 9 e 73.75%',    'Reprovado por Falta', fn_situacao_calc(9, 9, NULL, 21, 80)
UNION ALL SELECT 'sit: falta sem nota',      'Reprovado por Falta', fn_situacao_calc(NULL, NULL, NULL, 21, 80);

-- ------------------------------------------------------------
-- 3. Dados temporários para os triggers e as views
-- ------------------------------------------------------------
START TRANSACTION;

INSERT INTO usuario (nome, cpf, email, login, senha_hash, perfil)
VALUES ('Teste Coordenador', '99999999901', 'teste.coord@fbi.test', 'teste_coord',
        SHA2('Senha@123', 256), 'Coordenador');
SET @u = LAST_INSERT_ID();

INSERT INTO curso (nome, carga_horaria_total, turno, valor_mensalidade)
VALUES ('Curso de Teste', 3000, 'Noturno', 500.00);
SET @c = LAST_INSERT_ID();

INSERT INTO disciplina (id_curso, nome, carga_horaria, periodo)
VALUES (@c, 'Disciplina de Teste', 80, 1);
SET @d = LAST_INSERT_ID();

INSERT INTO professor (nome, cpf, email, titulacao, data_admissao)
VALUES ('Professor de Teste', '99999999902', 'teste.prof@fbi.test', 'Mestre', '2020-02-01');
SET @p = LAST_INSERT_ID();

INSERT INTO aluno (ra, nome, cpf, email, data_nascimento, id_curso, status)
VALUES ('TESTE001', 'Aluno Teste 1', '99999999911', 'teste.a1@fbi.test', '2004-01-01', @c, 'Ativo');
SET @a1 = LAST_INSERT_ID();
INSERT INTO aluno (ra, nome, cpf, email, data_nascimento, id_curso, status)
VALUES ('TESTE002', 'Aluno Teste 2', '99999999912', 'teste.a2@fbi.test', '2004-01-02', @c, 'Ativo');
SET @a2 = LAST_INSERT_ID();
INSERT INTO aluno (ra, nome, cpf, email, data_nascimento, id_curso, status)
VALUES ('TESTE003', 'Aluno Teste 3', '99999999913', 'teste.a3@fbi.test', '2004-01-03', @c, 'Trancado');
SET @a3 = LAST_INSERT_ID();

-- Turma com 2 vagas e 80 aulas
INSERT INTO turma (id_disciplina, id_professor, semestre, vagas, total_aulas)
VALUES (@d, @p, '2026.2', 2, 80);
SET @t = LAST_INSERT_ID();

-- trg_situacao_inicial: matrícula sem notas nasce 'Cursando'; com
-- notas, já nasce com média e situação calculadas.
INSERT INTO matricula (id_aluno, id_turma, id_usuario) VALUES (@a1, @t, @u);
SET @m1 = LAST_INSERT_ID();
INSERT INTO matricula (id_aluno, id_turma, n1, n2, faltas, id_usuario) VALUES (@a2, @t, 9, 9, 21, @u);
SET @m2 = LAST_INSERT_ID();

SELECT 'insert sem notas' AS teste, 'Cursando / NULL' AS esperado,
       CONCAT(situacao, ' / ', COALESCE(media_final, 'NULL')) AS obtido
  FROM matricula WHERE id_matricula = @m1
UNION ALL
SELECT 'insert media 9 e 21 faltas', 'Reprovado por Falta / 9.00',
       CONCAT(situacao, ' / ', COALESCE(media_final, 'NULL'))
  FROM matricula WHERE id_matricula = @m2;

-- ------------------------------------------------------------
-- 4. trg_valida_vagas (RN05): a turma tem 2 vagas e 2 matriculados.
--    ESPERADO: Error Code 1644 (SQLSTATE 45000) "Turma lotada: ..."
-- ------------------------------------------------------------
INSERT INTO matricula (id_aluno, id_turma, id_usuario) VALUES (@a3, @t, @u);

SELECT 'turma lotada bloqueou' AS teste, 2 AS esperado, COUNT(*) AS obtido
  FROM matricula WHERE id_turma = @t;

-- ------------------------------------------------------------
-- 5. trg_atualiza_situacao + trg_auditoria_nota
-- ------------------------------------------------------------
-- 5a. Lança N1 e N2 que caem em exame: 2 linhas no log (n1 e n2)
UPDATE matricula SET n1 = 5, n2 = 6, id_usuario = @u WHERE id_matricula = @m1;

SELECT 'update cai em exame' AS teste, 'Em Exame / 5.50' AS esperado,
       CONCAT(situacao, ' / ', media_final) AS obtido
  FROM matricula WHERE id_matricula = @m1
UNION ALL
SELECT 'fn_situacao(id) bate com a coluna', 'Em Exame', fn_situacao(@m1)
UNION ALL
SELECT 'fn_frequencia(id)', '100.00', fn_frequencia(@m1)
UNION ALL
SELECT 'log apos N1 e N2', '2', COUNT(*) FROM log_nota WHERE id_matricula = @m1;

-- 5b. Lança o exame: média final (5.50 + 7) / 2 = 6.25, 1 linha no log
UPDATE matricula SET exame = 7, id_usuario = @u WHERE id_matricula = @m1;

SELECT 'update com exame' AS teste, 'Aprovado / 6.25' AS esperado,
       CONCAT(situacao, ' / ', media_final) AS obtido
  FROM matricula WHERE id_matricula = @m1
UNION ALL
SELECT 'log apos exame', '3', COUNT(*) FROM log_nota WHERE id_matricula = @m1;

-- 5c. UPDATE que não muda valor nenhum não gera log
UPDATE matricula SET n1 = 5, id_usuario = @u WHERE id_matricula = @m1;

SELECT 'update sem mudanca nao loga' AS teste, 3 AS esperado, COUNT(*) AS obtido
  FROM log_nota WHERE id_matricula = @m1;

-- O que ficou registrado (campo, valor antigo -> novo, quem, quando)
SELECT campo, valor_antigo, valor_novo, usuario, data_hora
  FROM log_nota WHERE id_matricula = @m1 ORDER BY id_log;

-- ------------------------------------------------------------
-- 6. Views
-- ------------------------------------------------------------
-- Esperado: 2 linhas; Aluno Teste 1 Aprovado 6.25 / freq 100.00;
--           Aluno Teste 2 Reprovado por Falta 9.00 / freq 73.75
SELECT * FROM vw_boletim WHERE id_turma = @t ORDER BY aluno;

-- Esperado: vagas 2, matriculados 2, vagas_restantes 0, perc_ocupacao 100.00
SELECT * FROM vw_turmas_lotacao WHERE id_turma = @t;

-- Esperado: matriculados 2, media_turma 7.63, maior 9.00, menor 6.25,
--           perc_aprovados 50.00, perc_reprovados 50.00, em_andamento 0.00
SELECT * FROM vw_desempenho_turma WHERE id_turma = @t;

-- Esperado: alunos_ativos 2 (o Trancado não conta), faturamento_mensal 1000.00
SELECT * FROM vw_faturamento_curso WHERE id_curso = @c;

-- ------------------------------------------------------------
-- 7. fn_cr_aluno: só disciplinas concluídas, peso = carga horária
-- ------------------------------------------------------------
SELECT 'CR aluno 1 (aprovado 6.25)' AS teste, 6.25 AS esperado, fn_cr_aluno(@a1) AS obtido
UNION ALL SELECT 'CR aluno 2 (rep. falta 9.00)', 9.00, fn_cr_aluno(@a2)
UNION ALL SELECT 'CR aluno 3 (sem disciplina)',  NULL, fn_cr_aluno(@a3);

-- Desfaz todos os dados de teste
ROLLBACK;
