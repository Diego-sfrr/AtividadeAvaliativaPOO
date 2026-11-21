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
