-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02a_functions_views_triggers.sql: functions, views e triggers
-- Responsável: Diego
-- ============================================================
-- Nessa ordem: as views e os triggers usam as functions.
-- Roda depois do 01_ddl.sql. Pode ser executado várias vezes
-- (cada objeto é recriado com DROP ... IF EXISTS).
--
-- Decisões (valem para functions, views e triggers):
--   * Média parcial = ROUND((n1 + n2) / 2, 2). Toda comparação usa o
--     valor já arredondado, para a situação bater com o que a tela mostra.
--   * O exame só entra na média quando a média parcial está entre 4,0 e
--     6,99 (RN02/RN03). Fora dessa faixa o exame é ignorado.
--   * Frequência < 75% é comparada em inteiros, sem arredondar.
--   * BEFORE UPDATE não consegue chamar fn_situacao(id), porque ela lê a
--     linha antiga. Por isso existem funções auxiliares *_valores, que
--     recebem os valores e são chamadas pelo trigger com NEW.*.
--   * Extra: trg_calcula_situacao_insert (BEFORE INSERT) calcula media_final
--     e situacao ao inserir uma matrícula já com notas (massa de dados).
-- ============================================================

USE sga_fbi;

DELIMITER $$

-- ------------------------------------------------------------
-- FUNCTIONS
-- ------------------------------------------------------------

-- fn_calcular_media (RN01 e RN03)
--   sem exame (ou fora da faixa de exame): média parcial
--   com exame: (média parcial + exame) / 2
--   n1 ou n2 nulos: NULL
DROP FUNCTION IF EXISTS fn_calcular_media$$
CREATE FUNCTION fn_calcular_media(
    p_n1     DECIMAL(4,2),
    p_n2     DECIMAL(4,2),
    p_exame  DECIMAL(4,2)
)
RETURNS DECIMAL(4,2)
DETERMINISTIC
BEGIN
    DECLARE v_parcial DECIMAL(4,2);

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN NULL;
    END IF;

    SET v_parcial = ROUND((p_n1 + p_n2) / 2, 2);

    IF p_exame IS NOT NULL AND v_parcial >= 4 AND v_parcial < 7 THEN
        RETURN ROUND((v_parcial + p_exame) / 2, 2);
    END IF;

    RETURN v_parcial;
END$$

-- fn_frequencia_valores (auxiliar)
--   (total_aulas - faltas) / total_aulas * 100, entre 0 e 100.
DROP FUNCTION IF EXISTS fn_frequencia_valores$$
CREATE FUNCTION fn_frequencia_valores(
    p_total_aulas  INT,
    p_faltas       INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    IF p_total_aulas IS NULL OR p_total_aulas <= 0 THEN
        RETURN NULL;
    END IF;

    RETURN GREATEST(0, LEAST(100,
        ROUND((p_total_aulas - IFNULL(p_faltas, 0)) / p_total_aulas * 100, 2)));
END$$

-- fn_frequencia: porcentagem de presença de uma matrícula
DROP FUNCTION IF EXISTS fn_frequencia$$
CREATE FUNCTION fn_frequencia(p_id_matricula INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_total_aulas INT;
    DECLARE v_faltas      INT;

    SELECT t.total_aulas, m.faltas
      INTO v_total_aulas, v_faltas
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    RETURN fn_frequencia_valores(v_total_aulas, v_faltas);
END$$

-- fn_situacao_valores (auxiliar; usada pelo trigger e pela fn_situacao)
--   RN04 -> frequência < 75%            : 'Reprovado por Falta'
--   n1 ou n2 nulos                      : 'Cursando'
--   RN02 -> parcial >= 7                : 'Aprovado'
--           parcial < 4                 : 'Reprovado por Nota'
--           sem exame lançado           : 'Em Exame'
--   RN03 -> (parcial + exame) / 2 >= 5  : 'Aprovado'
--           senão                       : 'Reprovado por Nota'
DROP FUNCTION IF EXISTS fn_situacao_valores$$
CREATE FUNCTION fn_situacao_valores(
    p_n1           DECIMAL(4,2),
    p_n2           DECIMAL(4,2),
    p_exame        DECIMAL(4,2),
    p_faltas       INT,
    p_total_aulas  INT
)
RETURNS VARCHAR(19)
DETERMINISTIC
BEGIN
    DECLARE v_parcial DECIMAL(4,2);
    DECLARE v_final   DECIMAL(4,2);

    -- RN04: (total - faltas) / total < 0,75, em inteiros
    IF p_total_aulas IS NOT NULL AND p_total_aulas > 0
       AND (p_total_aulas - IFNULL(p_faltas, 0)) * 100 < 75 * p_total_aulas THEN
        RETURN 'Reprovado por Falta';
    END IF;

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN 'Cursando';
    END IF;

    SET v_parcial = fn_calcular_media(p_n1, p_n2, NULL);

    IF v_parcial >= 7 THEN
        RETURN 'Aprovado';
    END IF;

    IF v_parcial < 4 THEN
        RETURN 'Reprovado por Nota';
    END IF;

    IF p_exame IS NULL THEN
        RETURN 'Em Exame';
    END IF;

    SET v_final = fn_calcular_media(p_n1, p_n2, p_exame);

    IF v_final >= 5 THEN
        RETURN 'Aprovado';
    END IF;

    RETURN 'Reprovado por Nota';
END$$

-- fn_situacao: situação de uma matrícula (RN02, RN03 e RN04)
DROP FUNCTION IF EXISTS fn_situacao$$
CREATE FUNCTION fn_situacao(p_id_matricula INT)
RETURNS VARCHAR(19)
READS SQL DATA
BEGIN
    DECLARE v_n1           DECIMAL(4,2);
    DECLARE v_n2           DECIMAL(4,2);
    DECLARE v_exame        DECIMAL(4,2);
    DECLARE v_faltas       INT;
    DECLARE v_total_aulas  INT;

    SELECT m.n1, m.n2, m.exame, m.faltas, t.total_aulas
      INTO v_n1, v_n2, v_exame, v_faltas, v_total_aulas
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    IF v_total_aulas IS NULL THEN
        RETURN NULL;   -- matrícula não existe
    END IF;

    RETURN fn_situacao_valores(v_n1, v_n2, v_exame, v_faltas, v_total_aulas);
END$$

-- fn_cr_aluno (opcional): coeficiente de rendimento
--   média das disciplinas já concluídas (Aprovado, Reprovado por Nota ou
--   Reprovado por Falta), ponderada pela carga horária. Reprovado por Falta
--   entra com nota 0. Sem disciplina concluída: NULL.
DROP FUNCTION IF EXISTS fn_cr_aluno$$
CREATE FUNCTION fn_cr_aluno(p_id_aluno INT)
RETURNS DECIMAL(4,2)
READS SQL DATA
BEGIN
    DECLARE v_cr DECIMAL(4,2);

    SELECT ROUND(
               SUM(CASE WHEN m.situacao = 'Reprovado por Falta' THEN 0
                        ELSE IFNULL(m.media_final, 0) END * d.carga_horaria)
               / SUM(d.carga_horaria), 2)
      INTO v_cr
      FROM matricula m
      JOIN turma t      ON t.id_turma = m.id_turma
      JOIN disciplina d ON d.id_disciplina = t.id_disciplina
     WHERE m.id_aluno = p_id_aluno
       AND m.situacao IN ('Aprovado', 'Reprovado por Nota', 'Reprovado por Falta');

    RETURN v_cr;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- VIEWS
-- ------------------------------------------------------------

-- vw_boletim: id_matricula e id_turma servem à tela de lançar notas.
-- frequencia vem da fn_frequencia_valores.
CREATE OR REPLACE VIEW vw_boletim AS
SELECT m.id_matricula,
       t.id_turma,
       a.id_aluno,
       a.ra,
       a.nome         AS aluno,
       d.nome         AS disciplina,
       t.semestre,
       m.n1,
       m.n2,
       m.exame,
       m.media_final,
       m.faltas,
       fn_frequencia_valores(t.total_aulas, m.faltas) AS frequencia,
       m.situacao
  FROM matricula m
  JOIN aluno a      ON a.id_aluno = m.id_aluno
  JOIN turma t      ON t.id_turma = m.id_turma
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina;

-- vw_turmas_lotacao: vagas, matriculados, restantes e % de ocupação
CREATE OR REPLACE VIEW vw_turmas_lotacao AS
SELECT t.id_turma,
       d.nome       AS disciplina,
       p.nome       AS professor,
       t.semestre,
       t.status,
       t.vagas      AS vagas_totais,
       COUNT(m.id_matricula)               AS matriculados,
       t.vagas - COUNT(m.id_matricula)     AS vagas_restantes,
       ROUND(COUNT(m.id_matricula) / t.vagas * 100, 2) AS percentual_ocupacao
  FROM turma t
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina
  JOIN professor p  ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre, t.status, t.vagas;

-- vw_desempenho_turma: média global, maior/menor nota (media_final) e
-- percentuais sobre todas as matrículas da turma (inclui 'Cursando').
CREATE OR REPLACE VIEW vw_desempenho_turma AS
SELECT t.id_turma,
       d.nome       AS disciplina,
       t.semestre,
       COUNT(m.id_matricula)        AS matriculados,
       ROUND(AVG(m.media_final), 2) AS media_global,
       MAX(m.media_final)           AS maior_nota,
       MIN(m.media_final)           AS menor_nota,
       ROUND(SUM(m.situacao = 'Aprovado')
             / NULLIF(COUNT(m.id_matricula), 0) * 100, 2) AS percentual_aprovados,
       ROUND(SUM(m.situacao IN ('Reprovado por Nota', 'Reprovado por Falta'))
             / NULLIF(COUNT(m.id_matricula), 0) * 100, 2) AS percentual_reprovados
  FROM turma t
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, t.semestre;

-- vw_faturamento_curso: alunos ativos x mensalidade (só Coordenador)
CREATE OR REPLACE VIEW vw_faturamento_curso AS
SELECT c.id_curso,
       c.nome   AS curso,
       c.turno,
       c.valor_mensalidade,
       COUNT(a.id_aluno) AS alunos_ativos,
       COUNT(a.id_aluno) * c.valor_mensalidade AS faturamento_mensal
  FROM curso c
  LEFT JOIN aluno a ON a.id_curso = c.id_curso AND a.status = 'Ativo'
 GROUP BY c.id_curso, c.nome, c.turno, c.valor_mensalidade;

-- ------------------------------------------------------------
-- TRIGGERS
-- ------------------------------------------------------------

DELIMITER $$

-- trg_valida_vagas (RN05): bloqueia matrícula em turma lotada
DROP TRIGGER IF EXISTS trg_valida_vagas$$
CREATE TRIGGER trg_valida_vagas
BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_vagas       INT;
    DECLARE v_matriculados INT;

    SELECT vagas INTO v_vagas
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SELECT COUNT(*) INTO v_matriculados
      FROM matricula
     WHERE id_turma = NEW.id_turma;

    IF v_vagas IS NOT NULL AND v_matriculados >= v_vagas THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Turma lotada: não há vagas disponíveis.';
    END IF;
END$$

-- trg_calcula_situacao_insert (extra): media_final e situacao já na inserção
DROP TRIGGER IF EXISTS trg_calcula_situacao_insert$$
CREATE TRIGGER trg_calcula_situacao_insert
BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_total_aulas INT;

    SELECT total_aulas INTO v_total_aulas
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
    SET NEW.situacao    = fn_situacao_valores(NEW.n1, NEW.n2, NEW.exame,
                                              NEW.faltas, v_total_aulas);
END$$

-- trg_atualiza_situacao: recalcula media_final e situacao a cada UPDATE
DROP TRIGGER IF EXISTS trg_atualiza_situacao$$
CREATE TRIGGER trg_atualiza_situacao
BEFORE UPDATE ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_total_aulas INT;

    SELECT total_aulas INTO v_total_aulas
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
    SET NEW.situacao    = fn_situacao_valores(NEW.n1, NEW.n2, NEW.exame,
                                              NEW.faltas, v_total_aulas);
END$$

-- trg_auditoria_nota (RN08): uma linha em log_nota por campo alterado.
-- <=> trata NULL. O usuário vem de NEW.id_usuario.
DROP TRIGGER IF EXISTS trg_auditoria_nota$$
CREATE TRIGGER trg_auditoria_nota
AFTER UPDATE ON matricula
FOR EACH ROW
BEGIN
    IF NOT (OLD.n1 <=> NEW.n1) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'n1', OLD.n1, NEW.n1, NEW.id_usuario);
    END IF;

    IF NOT (OLD.n2 <=> NEW.n2) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'n2', OLD.n2, NEW.n2, NEW.id_usuario);
    END IF;

    IF NOT (OLD.exame <=> NEW.exame) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'exame', OLD.exame, NEW.exame, NEW.id_usuario);
    END IF;

    IF NOT (OLD.faltas <=> NEW.faltas) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'faltas', OLD.faltas, NEW.faltas, NEW.id_usuario);
    END IF;
END$$

DELIMITER ;
