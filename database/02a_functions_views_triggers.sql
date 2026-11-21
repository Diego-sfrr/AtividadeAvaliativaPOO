-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02a_functions_views_triggers.sql: functions, views e triggers
-- Responsável: Diego
-- ============================================================
-- Ordem de execução (ver README):
--   01_ddl -> 02a_functions_views_triggers -> 02b_procedures
--   -> 02c_procedures_cadastro -> 03_dados -> 04_testes
--
-- Dentro deste arquivo a ordem é functions -> views -> triggers,
-- porque as views e os triggers usam as functions.
--
-- Pode rodar de novo quantas vezes quiser: cada objeto tem o seu
-- DROP ... IF EXISTS antes do CREATE.
--
-- O que tem aqui:
--   Functions  fn_calcular_media      RN01, RN03
--              fn_frequencia_calc     auxiliar (recebe os valores)
--              fn_frequencia          fórmula de presença do enunciado
--              fn_situacao_calc       auxiliar (recebe os valores)
--              fn_situacao            RN02, RN03, RN04
--              fn_cr_aluno            opcional (ponto extra)
--   Views      vw_boletim             boletim + ids para a tela de notas
--              vw_turmas_lotacao      vagas, matriculados, % de ocupação
--              vw_desempenho_turma    média, maior/menor nota, % aprov./reprov.
--              vw_faturamento_curso   alunos ativos x mensalidade
--   Triggers   trg_valida_vagas       BEFORE INSERT  RN05
--              trg_situacao_inicial   BEFORE INSERT  (além do mínimo)
--              trg_atualiza_situacao  BEFORE UPDATE  RN01 a RN04
--              trg_auditoria_nota     AFTER UPDATE   RN08
--
-- Combinados do grupo usados aqui:
--   * Situações com a grafia exata: 'Cursando', 'Aprovado', 'Em Exame',
--     'Reprovado por Nota', 'Reprovado por Falta'.
--   * Regra quebrada vira SIGNAL SQLSTATE '45000' com MESSAGE_TEXT legível.
--   * Prefixos fn_ vw_ trg_; parâmetros p_, variáveis v_.
--
-- Decisões que valem para o sistema todo (detalhes em
-- relatorio/functions_views_triggers.md):
--   1. As médias são arredondadas para 2 casas ANTES de comparar com
--      7,0 / 4,0 / 5,0. Assim a situação sempre bate com a média que
--      aparece no boletim (6,995 vira 7,00 e é 'Aprovado').
--   2. A frequência é truncada (não arredondada) em 2 casas, para
--      74,999% nunca aparecer como 75,00%.
--   3. O exame só entra na média de quem está na faixa de exame
--      (média parcial de 4,00 a 6,99).
--   4. 'Reprovado por Falta' ganha de tudo (RN04), inclusive antes de
--      as notas serem lançadas.
-- ============================================================

USE sga_fbi;

-- Limpeza, na ordem inversa da dependência
DROP TRIGGER IF EXISTS trg_auditoria_nota;
DROP TRIGGER IF EXISTS trg_atualiza_situacao;
DROP TRIGGER IF EXISTS trg_situacao_inicial;
DROP TRIGGER IF EXISTS trg_valida_vagas;

DROP VIEW IF EXISTS vw_faturamento_curso;
DROP VIEW IF EXISTS vw_desempenho_turma;
DROP VIEW IF EXISTS vw_turmas_lotacao;
DROP VIEW IF EXISTS vw_boletim;

DROP FUNCTION IF EXISTS fn_cr_aluno;
DROP FUNCTION IF EXISTS fn_situacao;
DROP FUNCTION IF EXISTS fn_situacao_calc;
DROP FUNCTION IF EXISTS fn_frequencia;
DROP FUNCTION IF EXISTS fn_frequencia_calc;
DROP FUNCTION IF EXISTS fn_calcular_media;


-- ============================================================
-- FUNCTIONS
-- ============================================================
DELIMITER $$

-- ------------------------------------------------------------
-- fn_calcular_media(p_n1, p_n2, p_exame)  ->  DECIMAL(4,2)
-- RN01: média parcial = (N1 + N2) / 2
-- RN03: média final   = (média parcial + exame) / 2
--
--   falta N1 ou N2                  -> NULL (ainda não tem média)
--   parcial fora da faixa de exame  -> a própria parcial
--   parcial na faixa, sem exame     -> a parcial (por enquanto)
--   parcial na faixa, com exame     -> (parcial + exame) / 2
--
-- Exemplos: (8, 9, NULL) = 8.50 | (5, 6, NULL) = 5.50
--           (5, 6, 7) = 6.25    | (8, 9, 2) = 8.50 (exame ignorado)
-- ------------------------------------------------------------
CREATE FUNCTION fn_calcular_media(
    p_n1    DECIMAL(4,2),
    p_n2    DECIMAL(4,2),
    p_exame DECIMAL(4,2)
)
RETURNS DECIMAL(4,2)
DETERMINISTIC
NO SQL
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

-- ------------------------------------------------------------
-- fn_frequencia_calc(p_faltas, p_total_aulas)  ->  DECIMAL(5,2)
-- Auxiliar: mesma fórmula da fn_frequencia, mas recebendo os valores.
-- Existe para o trigger BEFORE UPDATE poder calcular com NEW.* (a
-- fn_frequencia(id) leria a linha antiga da tabela) e para as views
-- não fazerem um SELECT a mais por linha.
--
--   (total_aulas - faltas) / total_aulas * 100, truncado em 2 casas
--   total_aulas NULL ou 0 -> NULL | mais faltas que aulas -> 0.00
-- ------------------------------------------------------------
CREATE FUNCTION fn_frequencia_calc(
    p_faltas      INT,
    p_total_aulas INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total_aulas IS NULL OR p_total_aulas <= 0 THEN
        RETURN NULL;
    END IF;

    RETURN TRUNCATE(
        GREATEST(p_total_aulas - COALESCE(p_faltas, 0), 0) * 100 / p_total_aulas,
        2);
END$$

-- ------------------------------------------------------------
-- fn_frequencia(p_id_matricula)  ->  DECIMAL(5,2)
-- Porcentagem de presença da matrícula:
--   (total_aulas - faltas) / total_aulas * 100
-- total_aulas vem da turma; faltas, da matrícula.
-- Matrícula inexistente -> NULL.
-- ------------------------------------------------------------
CREATE FUNCTION fn_frequencia(p_id_matricula INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_faltas      INT;
    DECLARE v_total_aulas INT;

    SELECT m.faltas, t.total_aulas
      INTO v_faltas, v_total_aulas
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    RETURN fn_frequencia_calc(v_faltas, v_total_aulas);
END$$

-- ------------------------------------------------------------
-- fn_situacao_calc(p_n1, p_n2, p_exame, p_faltas, p_total_aulas)
--   ->  VARCHAR(19)
-- Auxiliar com TODA a regra de situação (RN02, RN03 e RN04) em um
-- lugar só. É chamada pela fn_situacao e pelos triggers.
--
--   frequência < 75%           -> 'Reprovado por Falta'   (RN04)
--   falta N1 ou N2             -> 'Cursando'
--   parcial >= 7,00            -> 'Aprovado'              (RN02)
--   parcial <  4,00            -> 'Reprovado por Nota'    (RN02)
--   4,00 a 6,99, sem exame     -> 'Em Exame'              (RN02)
--   (parcial + exame)/2 >= 5   -> 'Aprovado'              (RN03)
--   senão                      -> 'Reprovado por Nota'    (RN03)
-- ------------------------------------------------------------
CREATE FUNCTION fn_situacao_calc(
    p_n1          DECIMAL(4,2),
    p_n2          DECIMAL(4,2),
    p_exame       DECIMAL(4,2),
    p_faltas      INT,
    p_total_aulas INT
)
RETURNS VARCHAR(19)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_frequencia DECIMAL(5,2);
    DECLARE v_parcial    DECIMAL(4,2);

    -- RN04: reprovação por falta independe das notas
    SET v_frequencia = fn_frequencia_calc(p_faltas, p_total_aulas);
    IF v_frequencia IS NOT NULL AND v_frequencia < 75 THEN
        RETURN 'Reprovado por Falta';
    END IF;

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN 'Cursando';
    END IF;

    -- RN01 / RN02
    SET v_parcial = ROUND((p_n1 + p_n2) / 2, 2);

    IF v_parcial >= 7 THEN
        RETURN 'Aprovado';
    END IF;

    IF v_parcial < 4 THEN
        RETURN 'Reprovado por Nota';
    END IF;

    IF p_exame IS NULL THEN
        RETURN 'Em Exame';
    END IF;

    -- RN03: a média final já sai certa da fn_calcular_media
    IF fn_calcular_media(p_n1, p_n2, p_exame) >= 5 THEN
        RETURN 'Aprovado';
    END IF;

    RETURN 'Reprovado por Nota';
END$$

-- ------------------------------------------------------------
-- fn_situacao(p_id_matricula)  ->  VARCHAR(19)
-- Situação da matrícula combinando RN02, RN03 e RN04.
-- Só busca a linha e chama a fn_situacao_calc.
-- Matrícula inexistente -> NULL.
-- ------------------------------------------------------------
CREATE FUNCTION fn_situacao(p_id_matricula INT)
RETURNS VARCHAR(19)
READS SQL DATA
BEGIN
    DECLARE v_n1          DECIMAL(4,2);
    DECLARE v_n2          DECIMAL(4,2);
    DECLARE v_exame       DECIMAL(4,2);
    DECLARE v_faltas      INT;
    DECLARE v_total_aulas INT;
    DECLARE v_achou       INT DEFAULT 0;

    SELECT m.n1, m.n2, m.exame, m.faltas, t.total_aulas, 1
      INTO v_n1, v_n2, v_exame, v_faltas, v_total_aulas, v_achou
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    IF v_achou = 0 THEN
        RETURN NULL;
    END IF;

    RETURN fn_situacao_calc(v_n1, v_n2, v_exame, v_faltas, v_total_aulas);
END$$

-- ------------------------------------------------------------
-- fn_cr_aluno(p_id_aluno)  ->  DECIMAL(4,2)        (opcional)
-- Coeficiente de Rendimento ponderado pela carga horária:
--   CR = SOMA(média final x carga horária) / SOMA(carga horária)
--
-- Entram só as disciplinas já concluídas ('Aprovado', 'Reprovado por
-- Nota' e 'Reprovado por Falta'). 'Cursando' e 'Em Exame' ficam de
-- fora porque ainda não têm resultado. Reprovação por falta sem nota
-- lançada conta como média 0.
-- Aluno sem disciplina concluída -> NULL.
-- ------------------------------------------------------------
CREATE FUNCTION fn_cr_aluno(p_id_aluno INT)
RETURNS DECIMAL(4,2)
READS SQL DATA
BEGIN
    DECLARE v_cr DECIMAL(4,2);

    SELECT ROUND(SUM(COALESCE(m.media_final, 0) * d.carga_horaria)
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


-- ============================================================
-- VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- vw_boletim
-- Uma linha por matrícula. Colunas do enunciado: aluno, ra,
-- disciplina, semestre, n1, n2, exame, media_final, faltas, situacao.
-- Além do mínimo (combinado do grupo): id_matricula e id_turma, para
-- a tela de lançar notas saber qual matrícula está editando; e
-- id_aluno, total_aulas e frequencia, para filtrar e exibir.
--
-- Uso:  SELECT * FROM vw_boletim WHERE id_aluno = ? ORDER BY semestre;
--       SELECT * FROM vw_boletim WHERE id_turma = ? ORDER BY aluno;
-- ------------------------------------------------------------
CREATE VIEW vw_boletim AS
SELECT m.id_matricula,
       m.id_turma,
       a.id_aluno,
       a.nome        AS aluno,
       a.ra,
       d.nome        AS disciplina,
       t.semestre,
       m.n1,
       m.n2,
       m.exame,
       m.media_final,
       m.faltas,
       t.total_aulas,
       fn_frequencia_calc(m.faltas, t.total_aulas) AS frequencia,
       m.situacao
  FROM matricula m
  JOIN aluno a      ON a.id_aluno = m.id_aluno
  JOIN turma t      ON t.id_turma = m.id_turma
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina;

-- ------------------------------------------------------------
-- vw_turmas_lotacao
-- Uma linha por turma (inclusive as que não têm ninguém matriculado):
-- vagas totais, matriculados, vagas restantes e % de ocupação.
-- Além do mínimo: semestre e status, para a tela de matrícula listar
-- só as turmas 'Aberta' do semestre.
--
-- Uso:  SELECT * FROM vw_turmas_lotacao WHERE status = 'Aberta';
-- ------------------------------------------------------------
CREATE VIEW vw_turmas_lotacao AS
SELECT t.id_turma,
       d.nome                           AS disciplina,
       p.nome                           AS professor,
       t.semestre,
       t.status,
       t.vagas,
       COUNT(m.id_matricula)            AS matriculados,
       t.vagas - COUNT(m.id_matricula)  AS vagas_restantes,
       ROUND(COUNT(m.id_matricula) * 100 / t.vagas, 2) AS perc_ocupacao
  FROM turma t
  JOIN disciplina d     ON d.id_disciplina = t.id_disciplina
  JOIN professor p      ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre, t.status, t.vagas;

-- ------------------------------------------------------------
-- vw_desempenho_turma
-- Uma linha por turma: média global, maior e menor nota (sobre a
-- media_final dos alunos que já têm média), % de aprovados e % de
-- reprovados (por nota + por falta).
-- Os percentuais são sobre o total de matriculados da turma, então
-- aprovados + reprovados só fecha 100% quando ninguém mais está
-- 'Cursando' ou 'Em Exame' (por isso a coluna perc_em_andamento).
-- Turma sem matrícula: contagens 0 e o resto NULL.
-- ------------------------------------------------------------
CREATE VIEW vw_desempenho_turma AS
SELECT t.id_turma,
       d.nome                        AS disciplina,
       p.nome                        AS professor,
       t.semestre,
       COUNT(m.id_matricula)         AS matriculados,
       ROUND(AVG(m.media_final), 2)  AS media_turma,
       MAX(m.media_final)            AS maior_nota,
       MIN(m.media_final)            AS menor_nota,
       ROUND(COALESCE(SUM(m.situacao = 'Aprovado'), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_aprovados,
       ROUND(COALESCE(SUM(m.situacao IN ('Reprovado por Nota', 'Reprovado por Falta')), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_reprovados,
       ROUND(COALESCE(SUM(m.situacao IN ('Cursando', 'Em Exame')), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_em_andamento
  FROM turma t
  JOIN disciplina d     ON d.id_disciplina = t.id_disciplina
  JOIN professor p      ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre;

-- ------------------------------------------------------------
-- vw_faturamento_curso                       (além do mínimo)
-- Faturamento mensal previsto por curso, para o relatório financeiro
-- do Coordenador: alunos com status 'Ativo' x valor_mensalidade.
-- Trancados e formados não pagam mensalidade, então não entram.
-- Curso sem aluno ativo aparece com 0.
-- ------------------------------------------------------------
CREATE VIEW vw_faturamento_curso AS
SELECT c.id_curso,
       c.nome                                  AS curso,
       c.turno,
       c.valor_mensalidade,
       COUNT(a.id_aluno)                       AS alunos_ativos,
       COUNT(a.id_aluno) * c.valor_mensalidade AS faturamento_mensal
  FROM curso c
  LEFT JOIN aluno a ON a.id_curso = c.id_curso
                   AND a.status = 'Ativo'
 GROUP BY c.id_curso, c.nome, c.turno, c.valor_mensalidade;


-- ============================================================
-- TRIGGERS (todos na tabela matricula)
-- ============================================================
DELIMITER $$

-- ------------------------------------------------------------
-- trg_valida_vagas  (BEFORE INSERT)                       RN05
-- Bloqueia a matrícula quando a turma já está com todas as vagas
-- ocupadas. Vale para qualquer INSERT, inclusive os da massa de
-- dados e os feitos fora da sp_matricular_aluno.
--
-- O SELECT ... FOR UPDATE trava a linha da turma até o fim da
-- transação: duas matrículas simultâneas na última vaga entram em
-- fila, e a segunda já enxerga a turma lotada.
-- ------------------------------------------------------------
CREATE TRIGGER trg_valida_vagas
BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_vagas        INT;
    DECLARE v_matriculados INT;
    DECLARE v_msg          VARCHAR(128);

    SELECT vagas
      INTO v_vagas
      FROM turma
     WHERE id_turma = NEW.id_turma
       FOR UPDATE;

    -- Turma inexistente: v_vagas fica NULL e quem recusa é a FK.
    IF v_vagas IS NOT NULL THEN
        SELECT COUNT(*)
          INTO v_matriculados
          FROM matricula
         WHERE id_turma = NEW.id_turma;

        IF v_matriculados >= v_vagas THEN
            SET v_msg = CONCAT('Turma lotada: a turma ', NEW.id_turma,
                               ' já tem ', v_matriculados, ' de ', v_vagas,
                               ' vagas ocupadas.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------
-- trg_situacao_inicial  (BEFORE INSERT)          (além do mínimo)
-- Calcula media_final e situacao também na inserção. Sem ele, uma
-- matrícula inserida já com notas (a massa de dados do semestre
-- encerrado, por exemplo) ficaria 'Cursando' e sem média até o
-- primeiro UPDATE. O que vier em media_final/situacao no INSERT é
-- substituído pelo valor calculado.
-- FOLLOWS: roda depois do trg_valida_vagas.
-- ------------------------------------------------------------
CREATE TRIGGER trg_situacao_inicial
BEFORE INSERT ON matricula
FOR EACH ROW
FOLLOWS trg_valida_vagas
BEGIN
    DECLARE v_total_aulas INT;

    SELECT total_aulas
      INTO v_total_aulas
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
    SET NEW.situacao    = fn_situacao_calc(NEW.n1, NEW.n2, NEW.exame,
                                           NEW.faltas, v_total_aulas);
END$$

-- ------------------------------------------------------------
-- trg_atualiza_situacao  (BEFORE UPDATE)              RN01 a RN04
-- Recalcula media_final e situacao sempre que n1, n2, exame, faltas
-- ou a turma mudam. Quem lança nota só precisa dar UPDATE nas notas:
-- a média e a situação saem daqui.
--
-- Usa NEW.* com as functions auxiliares, porque dentro de um BEFORE
-- UPDATE a fn_situacao(id) ainda leria os valores antigos da tabela.
--
-- Se o UPDATE não mexe em nota, falta nem turma, o trigger não
-- recalcula. Isso deixa a sp_fechar_semestre gravar uma situação de
-- fechamento (ex.: 'Em Exame' sem exame -> 'Reprovado por Nota').
-- ------------------------------------------------------------
CREATE TRIGGER trg_atualiza_situacao
BEFORE UPDATE ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_total_aulas INT;

    IF NOT (OLD.n1 <=> NEW.n1)
       OR NOT (OLD.n2 <=> NEW.n2)
       OR NOT (OLD.exame <=> NEW.exame)
       OR NOT (OLD.faltas <=> NEW.faltas)
       OR NOT (OLD.id_turma <=> NEW.id_turma) THEN

        SELECT total_aulas
          INTO v_total_aulas
          FROM turma
         WHERE id_turma = NEW.id_turma;

        SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
        SET NEW.situacao    = fn_situacao_calc(NEW.n1, NEW.n2, NEW.exame,
                                               NEW.faltas, v_total_aulas);
    END IF;
END$$

-- ------------------------------------------------------------
-- trg_auditoria_nota  (AFTER UPDATE)                      RN08
-- Grava em log_nota uma linha por campo alterado: n1, n2, exame e
-- faltas (as faltas entram porque também mudam a situação).
-- O usuário vem de NEW.id_usuario: quem altera nota precisa gravar o
-- próprio id na matrícula, no mesmo UPDATE.
-- O <=> compara tratando NULL: de NULL para 7.5 conta como alteração,
-- e de NULL para NULL não.
-- ------------------------------------------------------------
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
