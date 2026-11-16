-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- SGA_completo.sql: GERADO por montar_sga_completo.sh. Não edite aqui;
-- edite os arquivos de origem e rode o script de novo.
-- Ordem: 01_ddl.sql 02a_functions_views_triggers.sql 02b_procedures.sql 02c_procedures_cadastro.sql 03_dados.sql 04_testes.sql
-- ============================================================

-- >>>>>>>>>> 01_ddl.sql
-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 01_ddl.sql: criação do banco, tabelas, índices e constraints
-- Responsável: Guilherme
-- ============================================================
-- Ordem de execução (ver README):
--   01_ddl -> 02a_functions_views_triggers -> 02b_procedures
--   -> 02c_procedures_cadastro -> 03_dados -> 04_testes
--
-- ATENÇÃO: este script APAGA e recria o banco sga_fbi do zero.
--
-- Combinados do grupo usados aqui:
--   * Textos exatos. O CHECK compara com COLLATE utf8mb4_bin, então
--     'Em exame' ou 'Secretário' são recusados:
--       usuario.perfil      'Secretario' | 'Coordenador'
--       curso.turno         'Matutino' | 'Vespertino' | 'Noturno'
--       aluno.status        'Ativo' | 'Trancado' | 'Formado'
--       turma.status        'Aberta' | 'Encerrada'
--       matricula.situacao  'Cursando' | 'Aprovado' | 'Em Exame'
--                           | 'Reprovado por Nota' | 'Reprovado por Falta'
--   * Senha: SHA-256 em hexadecimal minúsculo, CHAR(64)
--     (no INSERT: SHA2('senha', 256)).
--   * Notas: DECIMAL(4,2) entre 0 e 10 (RN07).
--   * CPF: só os 11 dígitos, sem ponto nem traço.
--   * Semestre: 'AAAA.S', por exemplo '2026.1' e '2026.2'.
-- ============================================================

DROP DATABASE IF EXISTS sga_fbi;
CREATE DATABASE sga_fbi
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE sga_fbi;

-- ------------------------------------------------------------
-- usuario: quem usa o sistema (Secretário ou Coordenador)
-- ------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario  INT          NOT NULL AUTO_INCREMENT,
    nome        VARCHAR(100) NOT NULL,
    cpf         CHAR(11)     NOT NULL,
    email       VARCHAR(100) NOT NULL,
    login       VARCHAR(30)  NOT NULL,
    senha_hash  CHAR(64)     NOT NULL,
    perfil      VARCHAR(11)  NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_cpf   UNIQUE (cpf),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT uq_usuario_login UNIQUE (login),
    CONSTRAINT ck_usuario_cpf CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT ck_usuario_senha_hash CHECK (REGEXP_LIKE(senha_hash, '^[0-9a-f]{64}$', 'c')),
    CONSTRAINT ck_usuario_perfil CHECK (perfil COLLATE utf8mb4_bin IN ('Secretario', 'Coordenador'))
);

-- ------------------------------------------------------------
-- curso
-- valor_mensalidade: além do mínimo, para o faturamento por curso
-- ------------------------------------------------------------
CREATE TABLE curso (
    id_curso             INT           NOT NULL AUTO_INCREMENT,
    nome                 VARCHAR(100)  NOT NULL,
    carga_horaria_total  INT           NOT NULL,
    turno                VARCHAR(10)   NOT NULL,
    valor_mensalidade    DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_curso PRIMARY KEY (id_curso),
    CONSTRAINT uq_curso_nome_turno UNIQUE (nome, turno),
    CONSTRAINT ck_curso_carga_horaria CHECK (carga_horaria_total > 0),
    CONSTRAINT ck_curso_turno CHECK (turno COLLATE utf8mb4_bin IN ('Matutino', 'Vespertino', 'Noturno')),
    CONSTRAINT ck_curso_mensalidade CHECK (valor_mensalidade >= 0)
);

-- ------------------------------------------------------------
-- disciplina: periodo = semestre da grade em que ela é oferecida
-- ------------------------------------------------------------
CREATE TABLE disciplina (
    id_disciplina  INT          NOT NULL AUTO_INCREMENT,
    id_curso       INT          NOT NULL,
    nome           VARCHAR(100) NOT NULL,
    carga_horaria  INT          NOT NULL,
    periodo        TINYINT      NOT NULL,
    CONSTRAINT pk_disciplina PRIMARY KEY (id_disciplina),
    CONSTRAINT uq_disciplina_curso_nome UNIQUE (id_curso, nome),
    CONSTRAINT fk_disciplina_curso FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso),
    CONSTRAINT ck_disciplina_carga_horaria CHECK (carga_horaria > 0),
    CONSTRAINT ck_disciplina_periodo CHECK (periodo BETWEEN 1 AND 12)
);

-- ------------------------------------------------------------
-- pre_requisito: autorrelacionamento N:N de disciplina
-- (id_disciplina exige aprovação em id_disciplina_requisito)
-- ------------------------------------------------------------
CREATE TABLE pre_requisito (
    id_disciplina            INT NOT NULL,
    id_disciplina_requisito  INT NOT NULL,
    CONSTRAINT pk_pre_requisito PRIMARY KEY (id_disciplina, id_disciplina_requisito),
    CONSTRAINT fk_pre_requisito_disciplina FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),
    CONSTRAINT fk_pre_requisito_requisito FOREIGN KEY (id_disciplina_requisito)
        REFERENCES disciplina (id_disciplina),
    CONSTRAINT ck_pre_requisito_diferente CHECK (id_disciplina <> id_disciplina_requisito)
);

-- ------------------------------------------------------------
-- professor
-- ------------------------------------------------------------
CREATE TABLE professor (
    id_professor   INT          NOT NULL AUTO_INCREMENT,
    nome           VARCHAR(100) NOT NULL,
    cpf            CHAR(11)     NOT NULL,
    email          VARCHAR(100) NOT NULL,
    titulacao      VARCHAR(12)  NOT NULL,
    data_admissao  DATE         NOT NULL,
    CONSTRAINT pk_professor PRIMARY KEY (id_professor),
    CONSTRAINT uq_professor_cpf   UNIQUE (cpf),
    CONSTRAINT uq_professor_email UNIQUE (email),
    CONSTRAINT ck_professor_cpf CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT ck_professor_titulacao CHECK (titulacao COLLATE utf8mb4_bin IN ('Graduado', 'Especialista', 'Mestre', 'Doutor'))
);

-- ------------------------------------------------------------
-- aluno
-- ------------------------------------------------------------
CREATE TABLE aluno (
    id_aluno         INT          NOT NULL AUTO_INCREMENT,
    ra               VARCHAR(20)  NOT NULL,
    nome             VARCHAR(100) NOT NULL,
    cpf              CHAR(11)     NOT NULL,
    email            VARCHAR(100) NOT NULL,
    data_nascimento  DATE         NOT NULL,
    id_curso         INT          NOT NULL,
    status           VARCHAR(8)   NOT NULL DEFAULT 'Ativo',
    CONSTRAINT pk_aluno PRIMARY KEY (id_aluno),
    CONSTRAINT uq_aluno_ra    UNIQUE (ra),
    CONSTRAINT uq_aluno_cpf   UNIQUE (cpf),
    CONSTRAINT uq_aluno_email UNIQUE (email),
    CONSTRAINT fk_aluno_curso FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso),
    CONSTRAINT ck_aluno_cpf CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT ck_aluno_status CHECK (status COLLATE utf8mb4_bin IN ('Ativo', 'Trancado', 'Formado'))
);

-- ------------------------------------------------------------
-- turma
-- status: além do mínimo, a sp_fechar_semestre marca 'Encerrada'
-- ------------------------------------------------------------
CREATE TABLE turma (
    id_turma       INT        NOT NULL AUTO_INCREMENT,
    id_disciplina  INT        NOT NULL,
    id_professor   INT        NOT NULL,
    semestre       CHAR(6)    NOT NULL,
    vagas          INT        NOT NULL,
    total_aulas    INT        NOT NULL,
    status         VARCHAR(9) NOT NULL DEFAULT 'Aberta',
    CONSTRAINT pk_turma PRIMARY KEY (id_turma),
    CONSTRAINT fk_turma_disciplina FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),
    CONSTRAINT fk_turma_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor),
    CONSTRAINT ck_turma_semestre CHECK (REGEXP_LIKE(semestre, '^[0-9]{4}[.][12]$')),
    CONSTRAINT ck_turma_vagas CHECK (vagas > 0),
    CONSTRAINT ck_turma_total_aulas CHECK (total_aulas > 0),
    CONSTRAINT ck_turma_status CHECK (status COLLATE utf8mb4_bin IN ('Aberta', 'Encerrada'))
);

-- ------------------------------------------------------------
-- matricula: aluno x turma, com notas, faltas e situação
-- media_final e situacao são preenchidas pelo trg_atualiza_situacao.
-- id_usuario: quem fez a última operação (matrícula ou notas).
-- ------------------------------------------------------------
CREATE TABLE matricula (
    id_matricula    INT          NOT NULL AUTO_INCREMENT,
    id_aluno        INT          NOT NULL,
    id_turma        INT          NOT NULL,
    data_matricula  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    n1              DECIMAL(4,2) NULL,
    n2              DECIMAL(4,2) NULL,
    exame           DECIMAL(4,2) NULL,
    faltas          INT          NOT NULL DEFAULT 0,
    media_final     DECIMAL(4,2) NULL,
    situacao        VARCHAR(19)  NOT NULL DEFAULT 'Cursando',
    id_usuario      INT          NOT NULL,
    CONSTRAINT pk_matricula PRIMARY KEY (id_matricula),
    CONSTRAINT uq_matricula_aluno_turma UNIQUE (id_aluno, id_turma),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (id_aluno)
        REFERENCES aluno (id_aluno),
    CONSTRAINT fk_matricula_turma FOREIGN KEY (id_turma)
        REFERENCES turma (id_turma),
    CONSTRAINT fk_matricula_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario),
    CONSTRAINT ck_matricula_n1 CHECK (n1 BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_n2 CHECK (n2 BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_exame CHECK (exame BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_media_final CHECK (media_final BETWEEN 0 AND 10),
    CONSTRAINT ck_matricula_faltas CHECK (faltas >= 0),
    CONSTRAINT ck_matricula_situacao CHECK (situacao COLLATE utf8mb4_bin IN (
        'Cursando', 'Aprovado', 'Em Exame', 'Reprovado por Nota', 'Reprovado por Falta'))
);

-- ------------------------------------------------------------
-- log_nota: auditoria das alterações de nota (RN08)
-- Alimentada pelo trg_auditoria_nota, uma linha por campo alterado.
-- usuario: id do usuário do SGA que alterou (vem de matricula.id_usuario).
-- valor_*: DECIMAL(6,2) para caber também faltas, se o trigger registrar.
-- ------------------------------------------------------------
CREATE TABLE log_nota (
    id_log        INT          NOT NULL AUTO_INCREMENT,
    id_matricula  INT          NOT NULL,
    campo         VARCHAR(20)  NOT NULL,
    valor_antigo  DECIMAL(6,2) NULL,
    valor_novo    DECIMAL(6,2) NULL,
    usuario       INT          NOT NULL,
    data_hora     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_nota PRIMARY KEY (id_log),
    CONSTRAINT fk_log_nota_matricula FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula),
    CONSTRAINT fk_log_nota_usuario FOREIGN KEY (usuario)
        REFERENCES usuario (id_usuario)
);

-- ------------------------------------------------------------
-- Índices
-- ra, cpf, email e login já têm índice pelos UNIQUE acima, e algumas
-- FKs já são cobertas por PK/UNIQUE compostos (disciplina.id_curso,
-- pre_requisito.id_disciplina, matricula.id_aluno).
-- Abaixo: as demais FKs e as colunas usadas em busca e ordenação.
-- ------------------------------------------------------------
CREATE INDEX idx_pre_requisito_requisito ON pre_requisito (id_disciplina_requisito);
CREATE INDEX idx_aluno_curso             ON aluno (id_curso);
CREATE INDEX idx_aluno_nome              ON aluno (nome);
CREATE INDEX idx_turma_disciplina        ON turma (id_disciplina);
CREATE INDEX idx_turma_professor         ON turma (id_professor);
CREATE INDEX idx_turma_semestre          ON turma (semestre);
CREATE INDEX idx_matricula_turma         ON matricula (id_turma);
CREATE INDEX idx_matricula_usuario       ON matricula (id_usuario);
CREATE INDEX idx_log_nota_matricula      ON log_nota (id_matricula);
CREATE INDEX idx_log_nota_usuario        ON log_nota (usuario);


-- >>>>>>>>>> 02a_functions_views_triggers.sql
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


-- >>>>>>>>>> 02b_procedures.sql
-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02b_procedures.sql: stored procedures do enunciado
-- Responsável: Mykael
-- ============================================================

-- sp_LoginUsuario, sp_matricular_aluno, sp_lancar_notas,
-- sp_lancar_exame, sp_historico_aluno, sp_fechar_semestre


-- >>>>>>>>>> 02c_procedures_cadastro.sql
-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02c_procedures_cadastro.sql: cadastro de aluno pela interface
-- Responsável: Guilherme
-- ============================================================

-- sp_cadastrar_aluno, sp_editar_aluno, sp_excluir_aluno
-- vw_alunos (listagem)


-- >>>>>>>>>> 03_dados.sql
-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 03_dados.sql: massa de dados de exemplo
-- Responsável: Guilherme
-- ============================================================
-- Roda DEPOIS da programação (02a, 02b, 02c), com os triggers
-- ativos: se o trg_valida_vagas reclamar, a massa está errada.

-- Mínimo exigido:
--   5 usuários (2 Coordenadores + 3 Secretários, senhas em hash)
--   3 cursos | 6 disciplinas | 5 professores
--   20 alunos | 5 turmas | 35 matrículas


-- >>>>>>>>>> 04_testes.sql
-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 04_testes.sql: roteiro de testes obrigatórios
-- Responsável: Mykael
-- ============================================================

-- 1. Login com senha incorreta / usuário inexistente -> falha ou vazio
-- 2. Matrícula em turma lotada -> falha (SQLSTATE 45000)
-- 3. Matrícula sem pré-requisito -> falha
-- 4. Matrícula de aluno Trancado -> falha
-- 5. Nota fora do intervalo (ex.: 11.0) -> falha (CHECK)
-- 6. Lançar notas (Em Exame) e depois nota de exame -> situação final
-- 7. Média 9.0 com frequência < 75% -> "Reprovado por Falta"
-- 8. Alteração de notas -> registros em log_nota
-- 9. Consulta das 3 views (vw_boletim, vw_turmas_lotacao, vw_desempenho_turma)

