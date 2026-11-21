-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- SGA_completo.sql: todos os scripts do banco, na ordem de execucao
--
-- ARQUIVO GERADO por database/gerar_SGA_completo.ps1. NAO EDITE AQUI:
-- altere o script de origem e gere de novo.
--
-- ATENCAO: apaga e recria o banco sga_fbi do zero.
-- No Workbench: abra este arquivo e execute tudo.
-- Os testes do final que devem falhar param o script: desligue a
-- opcao de parar no erro ou rode o bloco de testes um por vez.
--
-- Conteudo, na ordem:
--   01_ddl.sql
--   02a_functions_views_triggers.sql
--   02b_procedures.sql
--   02c_procedures_cadastro.sql
--   03_dados.sql
--   04_testes.sql
-- ============================================================


-- ============================================================
-- >>> INICIO DE 01_ddl.sql
-- ============================================================

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

DELIMITER ;
-- <<< FIM DE 01_ddl.sql


-- ============================================================
-- >>> INICIO DE 02a_functions_views_triggers.sql
-- ============================================================

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

DELIMITER ;
-- <<< FIM DE 02a_functions_views_triggers.sql


-- ============================================================
-- >>> INICIO DE 02b_procedures.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02b_procedures.sql: procedures do enunciado (Mykael)
-- Executar depois de 01_ddl.sql e 02a_functions_views_triggers.sql.
-- ============================================================

USE sga_fbi;

DROP PROCEDURE IF EXISTS sp_LoginUsuario;
DROP PROCEDURE IF EXISTS sp_matricular_aluno;
DROP PROCEDURE IF EXISTS sp_lancar_notas;
DROP PROCEDURE IF EXISTS sp_lancar_exame;
DROP PROCEDURE IF EXISTS sp_historico_aluno;
DROP PROCEDURE IF EXISTS sp_fechar_semestre;

DELIMITER $$

-- Valida o login pelo hash SHA-256 enviado pelo aplicativo.
-- A senha nunca faz parte do resultado.
CREATE PROCEDURE sp_LoginUsuario(
    IN p_login      VARCHAR(30),
    IN p_senha_hash CHAR(64)
)
READS SQL DATA
BEGIN
    SELECT id_usuario, nome, email, perfil
      FROM usuario
     WHERE login = p_login
       AND senha_hash = p_senha_hash
     LIMIT 1;
END$$

-- Matricula somente aluno Ativo, em turma Aberta e após aprovar todos
-- os pré-requisitos. O trigger trg_valida_vagas protege a capacidade,
-- inclusive em tentativas concorrentes.
CREATE PROCEDURE sp_matricular_aluno(
    IN p_id_aluno   INT,
    IN p_id_turma   INT,
    IN p_id_usuario INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_status_aluno VARCHAR(8);
    DECLARE v_status_turma VARCHAR(9);
    DECLARE v_id_disciplina INT;
    DECLARE v_vagas INT;
    DECLARE v_contagem INT DEFAULT 0;
    DECLARE v_pendencias INT DEFAULT 0;

    SELECT COUNT(*) INTO v_contagem
      FROM usuario
     WHERE id_usuario = p_id_usuario
       AND perfil IN ('Secretario', 'Coordenador');
    IF v_contagem = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuario inexistente ou sem perfil autorizado.';
    END IF;

    SELECT COUNT(*) INTO v_contagem
      FROM aluno
     WHERE id_aluno = p_id_aluno;
    IF v_contagem = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Aluno nao encontrado.';
    END IF;
    SELECT status INTO v_status_aluno
      FROM aluno
     WHERE id_aluno = p_id_aluno;
    IF v_status_aluno <> 'Ativo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Aluno Trancado ou Formado nao pode receber matricula.';
    END IF;

    SELECT COUNT(*) INTO v_contagem
      FROM turma
     WHERE id_turma = p_id_turma;
    IF v_contagem = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Turma nao encontrada.';
    END IF;
    SELECT id_disciplina, vagas, status
      INTO v_id_disciplina, v_vagas, v_status_turma
      FROM turma
     WHERE id_turma = p_id_turma;
    IF v_status_turma <> 'Aberta' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A turma esta encerrada e nao aceita matriculas.';
    END IF;

    SELECT COUNT(*) INTO v_contagem
      FROM matricula
     WHERE id_aluno = p_id_aluno
       AND id_turma = p_id_turma;
    IF v_contagem > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Aluno ja esta matriculado nesta turma.';
    END IF;

    SELECT COUNT(*) INTO v_contagem
      FROM matricula
     WHERE id_turma = p_id_turma;
    IF v_contagem >= v_vagas THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Turma lotada: nao ha vagas disponiveis.';
    END IF;

    SELECT COUNT(*) INTO v_pendencias
      FROM pre_requisito pr
     WHERE pr.id_disciplina = v_id_disciplina
       AND NOT EXISTS (
            SELECT 1
              FROM matricula m
              JOIN turma t ON t.id_turma = m.id_turma
             WHERE m.id_aluno = p_id_aluno
               AND t.id_disciplina = pr.id_disciplina_requisito
               AND m.situacao = 'Aprovado'
       );
    IF v_pendencias > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Aluno ainda nao foi aprovado em todos os pre-requisitos.';
    END IF;

    INSERT INTO matricula (id_aluno, id_turma, id_usuario)
    VALUES (p_id_aluno, p_id_turma, p_id_usuario);
END$$

-- Somente Coordenador pode lancar notas. O trigger de matricula
-- recalcula media/situacao e registra alteracoes no log_nota.
CREATE PROCEDURE sp_lancar_notas(
    IN p_id_matricula INT,
    IN p_n1           DECIMAL(4,2),
    IN p_n2           DECIMAL(4,2),
    IN p_faltas       INT,
    IN p_id_usuario   INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_autorizado INT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO v_autorizado
      FROM usuario
     WHERE id_usuario = p_id_usuario
       AND perfil = 'Coordenador';
    IF v_autorizado = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Somente Coordenador pode lancar ou alterar notas.';
    END IF;

    IF p_n1 IS NULL OR p_n1 < 0 OR p_n1 > 10
       OR p_n2 IS NULL OR p_n2 < 0 OR p_n2 > 10 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'N1 e N2 devem estar entre 0 e 10.';
    END IF;
    IF p_faltas IS NULL OR p_faltas < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Faltas deve ser um numero inteiro maior ou igual a zero.';
    END IF;

    SELECT COUNT(*) INTO v_existe
      FROM matricula
     WHERE id_matricula = p_id_matricula;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Matricula nao encontrada.';
    END IF;

    UPDATE matricula
       SET n1 = p_n1,
           n2 = p_n2,
           faltas = p_faltas,
           id_usuario = p_id_usuario
     WHERE id_matricula = p_id_matricula;
END$$

-- Somente Coordenador pode lancar exame, e apenas quando a situacao
-- atual da matricula for exatamente Em Exame.
CREATE PROCEDURE sp_lancar_exame(
    IN p_id_matricula INT,
    IN p_exame        DECIMAL(4,2),
    IN p_id_usuario   INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_autorizado INT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_situacao VARCHAR(19);

    SELECT COUNT(*) INTO v_autorizado
      FROM usuario
     WHERE id_usuario = p_id_usuario
       AND perfil = 'Coordenador';
    IF v_autorizado = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Somente Coordenador pode lancar nota de exame.';
    END IF;

    IF p_exame IS NULL OR p_exame < 0 OR p_exame > 10 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A nota do exame deve estar entre 0 e 10.';
    END IF;

    SELECT COUNT(*) INTO v_existe
      FROM matricula
     WHERE id_matricula = p_id_matricula;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Matricula nao encontrada.';
    END IF;
    SELECT situacao INTO v_situacao
      FROM matricula
     WHERE id_matricula = p_id_matricula;
    IF v_situacao <> 'Em Exame' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'So e permitido lancar exame para matricula Em Exame.';
    END IF;

    UPDATE matricula
       SET exame = p_exame,
           id_usuario = p_id_usuario
     WHERE id_matricula = p_id_matricula;
END$$

-- Historico completo do aluno, ordenado por semestre e disciplina.
CREATE PROCEDURE sp_historico_aluno(
    IN p_id_aluno INT
)
READS SQL DATA
BEGIN
    SELECT id_matricula, id_turma, id_aluno, aluno, ra, disciplina,
           semestre, n1, n2, exame, media_final, faltas, total_aulas,
           frequencia, situacao
      FROM vw_boletim
     WHERE id_aluno = p_id_aluno
     ORDER BY semestre, disciplina;
END$$

-- Fecha em lote as turmas abertas do semestre, apenas para Coordenador.
-- O cursor e a transacao garantem que um erro nao deixe fechamento parcial.
CREATE PROCEDURE sp_fechar_semestre(
    IN p_semestre   CHAR(6),
    IN p_id_usuario INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_autorizado INT DEFAULT 0;
    DECLARE v_fim INT DEFAULT 0;
    DECLARE v_transacao_aberta INT DEFAULT 0;
    DECLARE v_id_turma INT;
    DECLARE v_total_fechadas INT DEFAULT 0;

    DECLARE c_turmas CURSOR FOR
        SELECT id_turma
          FROM turma
         WHERE semestre = p_semestre
           AND status = 'Aberta'
         ORDER BY id_turma;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_transacao_aberta = 1 THEN
            ROLLBACK;
        END IF;
        RESIGNAL;
    END;

    SELECT COUNT(*) INTO v_autorizado
      FROM usuario
     WHERE id_usuario = p_id_usuario
       AND perfil = 'Coordenador';
    IF v_autorizado = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Somente Coordenador pode fechar o semestre.';
    END IF;

    IF p_semestre IS NULL OR p_semestre NOT REGEXP '^[0-9]{4}[.][12]$' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Semestre invalido. Use o formato AAAA.S, por exemplo 2026.2.';
    END IF;

    START TRANSACTION;
    SET v_transacao_aberta = 1;
    OPEN c_turmas;

    loop_turmas: LOOP
        FETCH c_turmas INTO v_id_turma;
        IF v_fim = 1 THEN
            LEAVE loop_turmas;
        END IF;

        UPDATE turma
           SET status = 'Encerrada'
         WHERE id_turma = v_id_turma
           AND status = 'Aberta';
        SET v_total_fechadas = v_total_fechadas + ROW_COUNT();
    END LOOP;

    CLOSE c_turmas;
    COMMIT;
    SET v_transacao_aberta = 0;

    SELECT p_semestre AS semestre_fechado,
           v_total_fechadas AS turmas_encerradas;
END$$

DELIMITER ;

DELIMITER ;
-- <<< FIM DE 02b_procedures.sql


-- ============================================================
-- >>> INICIO DE 02c_procedures_cadastro.sql
-- ============================================================

-- ============================================================
-- SGA - Faculdade do Bug Infinito (FBI)
-- 02c_procedures_cadastro.sql: cadastro de aluno pela interface
-- Responsável: Guilherme
-- ============================================================

-- sp_cadastrar_aluno, sp_editar_aluno, sp_excluir_aluno
-- vw_alunos (listagem)

DELIMITER ;
-- <<< FIM DE 02c_procedures_cadastro.sql


-- ============================================================
-- >>> INICIO DE 03_dados.sql
-- ============================================================

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

DELIMITER ;
-- <<< FIM DE 03_dados.sql


-- ============================================================
-- >>> INICIO DE 04_testes.sql
-- ============================================================

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

DELIMITER ;
-- <<< FIM DE 04_testes.sql
