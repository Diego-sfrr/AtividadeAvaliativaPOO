# 1. Em um minuto

Você fez a **base de tudo**: o desenho do banco de dados (as 9 tabelas, com as regras de integridade), os dados de teste, o cadastro de aluno e as telas do Coordenador (lançar notas e exame, fechar semestre, relatórios). Além do mínimo, também entraram o CR do aluno, a Auditoria de notas e o painel Início.

Roteiro de fala, para ler em voz alta (cerca de 1 minuto):

> "Eu fiz a modelagem do banco. São nove tabelas, normalizadas até a terceira forma normal: o dado de cada coisa fica em um lugar só, e as outras tabelas só apontam para ele com chave estrangeira. As regras que o enunciado pede já estão no próprio banco, com chave primária, estrangeira, UNIQUE e CHECK: por exemplo, nota só de 0 a 10, e os textos como 'Em Exame' só aceitam a grafia exata. Também fiz o cadastro de aluno, que é feito por procedures, e a massa de dados, com 20 alunos, 5 turmas e 35 matrículas, montada para cobrir cada teste obrigatório. Na interface, fiz as telas do Coordenador: lançar notas e exame, fechar o semestre e os relatórios de desempenho, lotação e faturamento. Nenhuma tela calcula nada: o banco calcula a média e a situação, e a tela só mostra."

# 2. Palavras que você precisa saber

**Tabela, coluna, linha.** Tabela é como uma planilha: cada coluna é um tipo de informação (nome, CPF) e cada linha é um registro (um aluno).

**Chave primária (PK).** A coluna que identifica cada linha de forma única, como o RG de uma pessoa. No SGA são os `id_...`, que o banco numera sozinho (`AUTO_INCREMENT`).

**Chave estrangeira (FK).** Uma coluna que aponta para a chave primária de outra tabela. Em `aluno`, a coluna `id_curso` aponta para o curso do aluno. O banco recusa apontar para um curso que não existe.

**UNIQUE.** Proíbe repetir valor. Dois alunos não podem ter o mesmo RA, CPF ou e-mail.

**CHECK.** Uma regra que a linha tem que cumprir para ser gravada, por exemplo `n1 BETWEEN 0 AND 10`. Se não cumprir, o banco recusa e devolve erro. Só funciona a partir do MySQL 8.0.16.

**NOT NULL e NULL.** `NOT NULL` obriga a preencher. `NULL` é "vazio, ainda não existe valor". A nota de quem ainda não fez a prova é `NULL`, e isso é diferente de zero.

**DECIMAL(4,2).** Número com até 4 dígitos no total e 2 depois da vírgula, de 0,00 a 99,99. Usado nas notas.

**Normalização e 3FN.** Organizar as tabelas para que cada informação apareça só uma vez. Na 3FN, nenhuma coluna depende de outra coluna que não seja a chave. Exemplo: a mensalidade depende do curso, então fica na tabela `curso`, e não em `aluno`.

**Relacionamento 1:N e N:N.** 1:N: um curso tem muitos alunos. N:N: um aluno cursa muitas turmas e uma turma tem muitos alunos; isso se resolve com uma tabela do meio, a `matricula`.

**Índice.** Um "índice remissivo" da tabela: faz a busca por uma coluna ser rápida. O banco cria um sozinho para PK e UNIQUE.

**Procedure.** Um programa guardado no banco, que a gente chama com `CALL`. As telas só falam com o banco por procedures e views.

**View.** Uma consulta salva com nome, que se usa como se fosse uma tabela (`SELECT * FROM vw_alunos`).

**SIGNAL SQLSTATE '45000'.** Jeito de uma procedure dar erro com mensagem escrita por nós. A tela só mostra essa mensagem.

**DELIMITER.** Trecho do script que muda o caractere que termina um comando (de `;` para `$$`), porque dentro da procedure existem vários `;`.

**JDBC, CallableStatement, PreparedStatement.** JDBC é a ponte entre o Java e o banco. `CallableStatement` chama procedures; `PreparedStatement` faz um `SELECT` com parâmetros (`?`), sem juntar texto, o que evita injeção de SQL.

**Swing.** A biblioteca do Java para janelas. `JFrame` é uma janela, `JTable` é uma tabela, `JOptionPane` é a caixinha de mensagem.

# 3. O código, linha por linha

Esta parte percorre os seus arquivos na ordem de execução: `01_ddl.sql`, `02c_procedures_cadastro.sql`, `03_dados.sql` e depois o Java das telas do Coordenador.

## 3.1 O arquivo 01_ddl.sql (modelagem)

> O cabeçalho do arquivo (linhas 1 a 26) é só comentário. Ele registra os combinados do grupo: textos com grafia exata, senha em SHA-256, notas de 0 a 10, CPF só com os 11 dígitos e semestre no formato AAAA.S.

### Criar o banco (linhas 28 a 32)

```sql
DROP DATABASE IF EXISTS sga_fbi;
CREATE DATABASE sga_fbi
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE sga_fbi;
```

| Linha | O que faz |
|---|---|
| DROP DATABASE IF EXISTS | Apaga o banco `sga_fbi` se ele já existir. Por isso o script pode ser rodado quantas vezes quiser: sempre recomeça do zero |
| CREATE DATABASE sga_fbi | Cria o banco vazio |
| CHARACTER SET utf8mb4 | Aceita todos os caracteres, inclusive acentos e emojis |
| COLLATE utf8mb4_0900_ai_ci | Regra de comparação de texto: ignora maiúscula e acento ("ai" e "ci"). É por isso que os CHECK de texto usam outra regra, a binária (veja a tabela `usuario`) |
| USE sga_fbi | Diz ao MySQL que os próximos comandos são nesse banco |

### Tabela usuario (linhas 37 a 52)

```sql
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
```

| Linha | O que faz |
|---|---|
| id_usuario INT NOT NULL AUTO_INCREMENT | Número de identificação; o banco conta sozinho: 1, 2, 3... |
| nome, email VARCHAR(100) | Texto de até 100 caracteres. `VARCHAR` ocupa só o que é usado |
| cpf CHAR(11) | Texto de tamanho fixo, 11 caracteres: só os dígitos, sem ponto nem traço |
| login VARCHAR(30) | Nome que a pessoa digita para entrar |
| senha_hash CHAR(64) | Guarda o SHA-256 da senha, que sempre tem 64 caracteres hexadecimais. A senha em si nunca é guardada |
| perfil VARCHAR(11) | `Secretario` ou `Coordenador`. 11 é o tamanho da palavra `Coordenador` |
| pk_usuario PRIMARY KEY | Define `id_usuario` como identificador único |
| uq_usuario_cpf, _email, _login UNIQUE | Não pode haver dois usuários com o mesmo CPF, e-mail ou login |
| ck_usuario_cpf CHECK REGEXP_LIKE | `REGEXP_LIKE` testa um padrão. `^[0-9]{11}$` significa "começa, tem exatamente 11 dígitos de 0 a 9, termina" |
| ck_usuario_senha_hash | Exige 64 caracteres entre 0-9 e a-f minúsculos; o `'c'` pede comparação sensível a maiúscula. Garante que ninguém grave uma senha em texto puro por engano |
| ck_usuario_perfil COLLATE utf8mb4_bin | A comparação binária enxerga maiúscula e acento. Sem isso, `'secretario'` passaria no teste. Com isso, só `Secretario` e `Coordenador`, exatamente assim |

### Tabela curso (linhas 58 a 69)

```sql
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
```

| Linha | O que faz |
|---|---|
| valor_mensalidade DECIMAL(10,2) | Dinheiro com centavos, até 99.999.999,99. Coluna **extra**: o enunciado não pede, mas sem ela não existe relatório de faturamento |
| uq_curso_nome_turno UNIQUE (nome, turno) | A combinação nome + turno é única: o mesmo curso pode existir em turnos diferentes, mas não duas vezes no mesmo turno |
| ck_curso_carga_horaria | A carga horária total precisa ser maior que zero |
| ck_curso_turno | Só `Matutino`, `Vespertino` ou `Noturno`, com grafia exata |
| ck_curso_mensalidade | A mensalidade não pode ser negativa (zero é permitido) |

### Tabela disciplina (linhas 74 a 86)

```sql
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
```

| Linha | O que faz |
|---|---|
| id_curso INT NOT NULL | Toda disciplina pertence a um curso (relacionamento 1:N) |
| periodo TINYINT | Em que semestre da grade a disciplina é oferecida. `TINYINT` é um inteiro pequeno (cabe até 127) |
| uq_disciplina_curso_nome | Dentro de um curso não há duas disciplinas com o mesmo nome |
| fk_disciplina_curso FOREIGN KEY REFERENCES | `id_curso` precisa existir na tabela `curso`. Não se cria disciplina de curso inexistente, nem se apaga um curso que tenha disciplinas |
| ck_disciplina_periodo BETWEEN 1 AND 12 | O período vai de 1 a 12 |

### Tabela pre_requisito (linhas 92 a 101)

```sql
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
```

| Linha | O que faz |
|---|---|
| Duas colunas, as duas apontando para disciplina | É um **autorrelacionamento N:N**: uma disciplina pode exigir várias, e pode ser exigida por várias. A tabela do meio guarda os pares "esta exige aquela" |
| PRIMARY KEY (id_disciplina, id_disciplina_requisito) | Chave composta pelas duas colunas: o mesmo par não se repete |
| Duas FOREIGN KEY | As duas colunas precisam ser disciplinas que existem |
| ck_pre_requisito_diferente | Uma disciplina não pode ser pré-requisito dela mesma |

### Tabela professor (linhas 106 a 118)

```sql
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
```

| Linha | O que faz |
|---|---|
| titulacao VARCHAR(12) | Formação do professor; 12 é o tamanho de `Especialista` |
| data_admissao DATE | Só a data (ano-mês-dia), sem hora |
| uq_professor_cpf, uq_professor_email | CPF e e-mail não se repetem |
| ck_professor_titulacao | Só `Graduado`, `Especialista`, `Mestre` ou `Doutor`, com grafia exata |

### Tabela aluno (linhas 123 a 140)

```sql
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
```

| Linha | O que faz |
|---|---|
| ra VARCHAR(20) | Registro Acadêmico: o "número de matrícula" do aluno na faculdade. Único |
| status VARCHAR(8) NOT NULL DEFAULT 'Ativo' | Situação do aluno. `DEFAULT` é o valor usado quando ninguém informa nada: aluno novo entra como `Ativo`. 8 é o tamanho de `Trancado` |
| uq_aluno_ra, _cpf, _email | RA, CPF e e-mail únicos |
| fk_aluno_curso | O aluno tem que pertencer a um curso que existe (1:N) |
| ck_aluno_status | Só `Ativo`, `Trancado` ou `Formado` |

### Tabela turma (linhas 146 a 163)

```sql
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
```

| Linha | O que faz |
|---|---|
| Turma = uma oferta | Liga uma disciplina, um professor e um semestre. Uma disciplina pode ter várias turmas |
| semestre CHAR(6) | Texto no formato `2026.2`: 6 caracteres exatos |
| vagas e total_aulas | Quantas vagas a turma tem e quantas aulas o semestre tem. O `total_aulas` é a base do cálculo da frequência |
| status ... DEFAULT 'Aberta' | Coluna **extra**: a `sp_fechar_semestre` precisa marcar a turma como `Encerrada` |
| ck_turma_semestre | `^[0-9]{4}[.][12]$`: quatro dígitos, um ponto, e 1 ou 2. Aceita `2026.1` e `2026.2`, recusa `2026.3` |
| ck_turma_vagas, ck_turma_total_aulas | Têm que ser maiores que zero |

### Tabela matricula (linhas 170 a 197)

```sql
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
```

| Linha | O que faz |
|---|---|
| matricula = aluno × turma | É a tabela que resolve o N:N entre aluno e turma. Cada linha é "este aluno nesta turma", com as notas dele |
| data_matricula DEFAULT (CURRENT_DATE) | Se ninguém informar a data, vale o dia de hoje |
| n1, n2, exame DECIMAL(4,2) NULL | As notas começam vazias (`NULL`) e vão sendo preenchidas. O exame só existe para quem caiu em exame |
| faltas INT NOT NULL DEFAULT 0 | Quantidade de faltas; começa em zero |
| media_final | **Derivada**: não é digitada. O trigger calcula a partir de n1, n2 e exame |
| situacao DEFAULT 'Cursando' | Também derivada, calculada pelo trigger. `VARCHAR(19)` porque `Reprovado por Falta` tem 19 letras |
| id_usuario | Quem fez a última operação (a matrícula ou o lançamento de notas). É daí que a Auditoria sabe o autor |
| uq_matricula_aluno_turma UNIQUE | O mesmo aluno não se matricula duas vezes na mesma turma |

```sql
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
```

| Linha | O que faz |
|---|---|
| Três FOREIGN KEY | Aluno, turma e usuário têm que existir |
| ck_matricula_n1, n2, exame, media_final | **RN07**: nota entre 0 e 10. Quando o valor é `NULL` o CHECK não reclama (vazio é permitido) |
| ck_matricula_faltas | Faltas não podem ser negativas |
| ck_matricula_situacao | Só as cinco situações combinadas, com grafia exata. Por isso `'Em Exame'` com E maiúsculo, e `'Em exame'` é recusado |

### Tabela log_nota (linhas 205 a 218)

```sql
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
```

| Linha | O que faz |
|---|---|
| Tabela de auditoria (**RN08**) | Quem escreve nela é o trigger `trg_auditoria_nota`, não uma pessoa. Cada alteração de nota vira linhas aqui |
| campo | Qual coluna mudou: `n1`, `n2`, `exame` ou `faltas` |
| valor_antigo, valor_novo DECIMAL(6,2) | Antes e depois. Têm 6 dígitos para caber também as faltas, que podem passar de 99 |
| usuario | Id do usuário do sistema que fez a alteração (vem de `matricula.id_usuario`) |
| data_hora DEFAULT CURRENT_TIMESTAMP | O banco carimba a data e a hora sozinho |

### Índices (linhas 227 a 236)

```sql
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
```

| Linha | O que faz |
|---|---|
| CREATE INDEX nome ON tabela (coluna) | Cria um índice para acelerar buscas e junções por aquela coluna |
| Índices nas chaves estrangeiras | Toda vez que uma view junta duas tabelas (JOIN), ela usa a chave estrangeira. O índice evita varrer a tabela inteira |
| idx_aluno_nome | A tela do Secretário busca aluno por nome |
| idx_turma_semestre | O fechamento de semestre e o histórico filtram e ordenam por semestre |
| Quem não ganhou índice | RA, CPF, e-mail e login já têm (os UNIQUE criam). As colunas que já são o começo de uma chave composta (`disciplina.id_curso`, `pre_requisito.id_disciplina`, `matricula.id_aluno`) também já são cobertas |

## 3.2 O arquivo 02c_procedures_cadastro.sql (cadastro de aluno)

### sp_cadastrar_aluno, cabeçalho e proteção contra repetição (linhas 123 a 151)

```sql
DELIMITER $$

CREATE PROCEDURE sp_cadastrar_aluno(
    IN p_ra               VARCHAR(20),
    IN p_nome             VARCHAR(100),
    IN p_cpf              CHAR(11),
    IN p_email            VARCHAR(100),
    IN p_data_nascimento  DATE,
    IN p_id_curso         INT
)
BEGIN
    DECLARE EXIT HANDLER FOR 1062
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'RA, CPF ou e-mail já cadastrado para outro aluno.';

    SET p_ra    = TRIM(p_ra);
    SET p_nome  = TRIM(p_nome);
    SET p_email = TRIM(p_email);
```

| Linha | O que faz |
|---|---|
| DELIMITER $$ | A partir daqui, o comando termina em `$$` e não em `;`, para o MySQL não achar que a procedure acabou no primeiro `;` |
| CREATE PROCEDURE sp_cadastrar_aluno(...) | Define a procedure e os seus **parâmetros**. `IN` significa "valor que entra". O prefixo `p_` é o combinado do grupo para parâmetros |
| BEGIN | Início do corpo da procedure |
| DECLARE EXIT HANDLER FOR 1062 | "Se acontecer o erro 1062 (valor duplicado em coluna UNIQUE), pare e faça o seguinte". É a rede de segurança para duas pessoas cadastrando o mesmo aluno ao mesmo tempo |
| SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT | Devolve o erro com a nossa mensagem em português. `45000` é o código "erro definido pelo usuário" |
| SET p_ra = TRIM(p_ra) | `TRIM` tira espaços do começo e do fim. Evita cadastrar "  2026010 " com espaços escondidos |

### sp_cadastrar_aluno, as conferências (linhas 153 a 180)

```sql
    IF p_ra IS NULL OR p_ra = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o RA do aluno.';
    END IF;
    IF p_nome IS NULL OR p_nome = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o nome do aluno.';
    END IF;
    IF p_cpf IS NULL OR NOT REGEXP_LIKE(p_cpf, '^[0-9]{11}$') THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'CPF inválido: informe os 11 dígitos, sem ponto nem traço.';
    END IF;
    IF p_email IS NULL OR p_email NOT LIKE '_%@_%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'E-mail inválido.';
    END IF;
    IF p_data_nascimento IS NULL OR p_data_nascimento > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de nascimento inválida.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM curso WHERE id_curso = p_id_curso) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Curso não encontrado.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE ra = p_ra) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe um aluno com este RA.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE cpf = p_cpf) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe um aluno com este CPF.';
    END IF;
    IF EXISTS (SELECT 1 FROM aluno WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Já existe um aluno com este e-mail.';
    END IF;
```

| Linha | O que faz |
|---|---|
| IF p_ra IS NULL OR p_ra = '' | Se o RA veio vazio (nulo ou texto em branco), dá erro "Informe o RA do aluno." |
| Idem para o nome | Mesma ideia: nome obrigatório |
| NOT REGEXP_LIKE(p_cpf, ...) | Se o CPF não tiver exatamente 11 dígitos, erro com a orientação de como digitar |
| p_email NOT LIKE '_%@_%' | `_` significa "qualquer caractere" e `%` "qualquer quantidade". O padrão exige pelo menos um caractere, depois `@`, depois pelo menos um caractere. É uma conferência simples de e-mail |
| p_data_nascimento > CURRENT_DATE | Ninguém nasce no futuro: data maior que hoje é inválida |
| NOT EXISTS (SELECT 1 FROM curso ...) | Confere se o curso existe. `SELECT 1` só serve para perguntar "existe alguma linha?" |
| IF EXISTS ... ra, cpf e email | Procura aluno com o mesmo valor. Se achar, erro com mensagem clara. É por isso que a tela mostra "Já existe um aluno com este RA." e não um erro técnico de chave duplicada |

> Por que conferir antes, se o UNIQUE já proíbe? Porque o erro do UNIQUE é técnico e feio ("Duplicate entry..."). Conferindo antes, o usuário lê uma mensagem em português que diz qual campo repetiu. O UNIQUE e o handler 1062 continuam valendo como segunda proteção.

### sp_cadastrar_aluno, a gravação (linhas 182 a 186)

```sql
    INSERT INTO aluno (ra, nome, cpf, email, data_nascimento, id_curso, status)
    VALUES (p_ra, p_nome, p_cpf, p_email, p_data_nascimento, p_id_curso, 'Ativo');

    SELECT LAST_INSERT_ID() AS id_aluno;
END$$
```

| Linha | O que faz |
|---|---|
| INSERT INTO aluno (...) VALUES (...) | Grava o aluno novo. Só chega aqui se todas as conferências passaram. O status entra sempre como `Ativo` |
| SELECT LAST_INSERT_ID() AS id_aluno | Devolve o número que o banco acabou de dar ao aluno, para a tela poder usá-lo |
| END$$ | Fim da procedure |

### sp_editar_aluno (linhas 199 a 264)

Funciona como o cadastro, com estas diferenças:

| Trecho | O que muda |
|---|---|
| Parâmetro p_id_aluno e p_status | Recebe também qual aluno editar e o novo status |
| IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno) | Primeiro confere se o aluno existe: "Aluno não encontrado." |
| IF p_status ... NOT IN ('Ativo', 'Trancado', 'Formado') | Confere o status, com `COLLATE utf8mb4_bin` para exigir grafia exata |
| WHERE ra = p_ra AND id_aluno <> p_id_aluno | Ao procurar RA, CPF ou e-mail repetido, **ignora o próprio aluno** (`<>` significa "diferente de"). Senão, editar sem trocar o RA acusaria "já existe" por causa dele mesmo |
| UPDATE aluno SET ... WHERE id_aluno = p_id_aluno | Em vez de `INSERT`, atualiza todas as colunas daquele aluno |

### sp_excluir_aluno (linhas 274 a 285)

```sql
CREATE PROCEDURE sp_excluir_aluno(IN p_id_aluno INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM aluno WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aluno não encontrado.';
    END IF;
    IF EXISTS (SELECT 1 FROM matricula WHERE id_aluno = p_id_aluno) THEN
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Aluno tem matrículas: tranque o aluno em vez de excluir.';
    END IF;

    DELETE FROM aluno WHERE id_aluno = p_id_aluno;
END$$

DELIMITER ;
```

| Linha | O que faz |
|---|---|
| IF NOT EXISTS (... aluno ...) | O aluno tem que existir |
| IF EXISTS (SELECT 1 FROM matricula WHERE id_aluno = ...) | Se o aluno já tem alguma matrícula, **não exclui**. Apagá-lo quebraria a chave estrangeira e destruiria o histórico escolar |
| MESSAGE_TEXT ... tranque o aluno | A mensagem já orienta o que fazer: mudar o status para `Trancado` |
| DELETE FROM aluno WHERE ... | Só apaga quem nunca se matriculou (cadastrado por engano, por exemplo) |
| DELIMITER ; | Volta o terminador de comando ao normal |

### As views vw_alunos, vw_cr_aluno e vw_log_nota

| View | O que entrega | Quem usa |
|---|---|---|
| vw_alunos | Uma linha por aluno, com o nome do curso e o turno: `id_aluno`, `ra`, `nome`, `cpf`, `email`, `data_nascimento`, `id_curso`, `curso`, `turno` e `status` | A tela de Gerenciamento de alunos |
| vw_cr_aluno | `id_aluno`, `aluno`, `ra` e `cr`, onde `cr` vem da function `fn_cr_aluno(id)`. Aluno sem disciplina concluída fica com `cr` vazio (`NULL`) | O cartão de CR no histórico e no boletim |
| vw_log_nota | Cada linha do `log_nota` com o nome do aluno, a disciplina, o semestre e o nome de quem alterou, juntando as tabelas log_nota, matricula, aluno, turma, disciplina e usuario | A tela de Auditoria |

O trecho que cria a `vw_cr_aluno` é este:

```sql
CREATE VIEW vw_cr_aluno AS
SELECT a.id_aluno,
       a.nome AS aluno,
       a.ra,
       fn_cr_aluno(a.id_aluno) AS cr
  FROM aluno a;
```

| Linha | O que faz |
|---|---|
| CREATE VIEW vw_cr_aluno AS | Cria uma consulta salva com esse nome |
| a.nome AS aluno | Mostra a coluna `nome` com o apelido `aluno` |
| fn_cr_aluno(a.id_aluno) AS cr | Chama a function do Diego para cada aluno e mostra o resultado na coluna `cr` |
| FROM aluno a | De onde vêm as linhas. O `a` é um apelido curto para a tabela |

## 3.3 O arquivo 03_dados.sql (massa de dados)

O arquivo só tem `INSERT`. Ele roda **depois** de functions, views, triggers e procedures. Por isso, quando uma matrícula é inserida, os triggers já estão ativos: calculam média e situação, e o `trg_valida_vagas` recusa o que passar das vagas. Se a massa estivesse errada, o banco reclamaria.

Em cada `INSERT`, a ideia é a mesma: `INSERT INTO tabela (colunas) VALUES (linha 1), (linha 2), ...;`. As senhas usam `SHA2('Senha@123', 256)`, que calcula o hash SHA-256 de `Senha@123` no próprio banco; assim a senha em texto nunca fica gravada.

| Tabela | Quantidade | Detalhes |
|---|---|---|
| usuario | 5 | 2 Coordenadores (coord.ana, coord.bruno) e 3 Secretários (sec.carla, sec.diego, sec.elisa), todos com a senha Senha@123 |
| curso | 3 | ADS (Noturno, R$ 650,00), Ciência da Computação (Matutino, R$ 1.200,00) e Sistemas de Informação (Vespertino, R$ 980,00) |
| disciplina | 6 | Lógica de Programação, Programação Orientada a Objetos, Banco de Dados, Algoritmos, Estruturas de Dados e Introdução a Sistemas de Informação |
| pre_requisito | 2 | POO exige Lógica de Programação; Estruturas de Dados exige Algoritmos |
| professor | 5 | Titulações variadas (Doutor, Mestre, Especialista, Graduado) |
| aluno | 20 | Os de 1 a 9 em ADS, de 10 a 16 em Ciência da Computação e de 17 a 20 em Sistemas de Informação. O aluno 19 está Trancado e o 20 está Formado |
| turma | 5 | Duas encerradas de 2026.1 e três abertas de 2026.2 |
| matricula | 35 | Distribuídas nas 5 turmas, de modo a cobrir todos os testes |

**Os cenários de teste que a massa cobre** (é a "cola" para explicar por que os dados são esses):

| Cenário | Onde está | Para que serve |
|---|---|---|
| Turma lotada | Turma 3 (POO 2026.2): 4 vagas e 4 matriculados | Testar a RN05 (aluno 5 tenta entrar e é barrado por falta de vaga) |
| Falta pré-requisito | Aluno 16 reprovado em Algoritmos tenta Estruturas de Dados (turma 5) | Testar a RN06 |
| Aluno trancado e formado | Alunos 19 e 20 | Testar a RN09 |
| Cai em Em Exame | Matrícula 18 (aluno 2, turma 3): N1 6,0 e N2 7,0 | Testar o exame: média parcial 6,5, lançar exame depois |
| Média alta com muitas faltas | Matrícula 19 (aluno 3, turma 3): 9,5 e 9,5 com 25 faltas | Testar a RN04: Reprovado por Falta mesmo com a nota alta |
| Auditoria | Qualquer alteração de nota, por exemplo na matrícula 17 | Testar a RN08 |
| Histórico completo | Semestre 2026.1 com todos os desfechos | Ter aprovados, reprovados e exame para os relatórios e para o pré-requisito |

> Atenção: os **números** (id das matrículas, das turmas) só valem se o banco acabou de ser criado pelo `01_ddl.sql`, porque o `AUTO_INCREMENT` começa do 1. Por isso o `SGA_completo.sql` sempre recria o banco antes.

## 3.4 O Java das telas do Coordenador

### SgaRepository: como a tela fala com o banco

A classe `SgaRepository` é a **única** que conversa com o banco. Estes dois métodos são os das telas do Coordenador.

```java
public List<String[]> boletimDaTurma(int turmaId) throws SQLException {
    String sql = "SELECT * FROM vw_boletim "
            + "WHERE id_turma = ? ORDER BY aluno";

    try (Connection connection = DatabaseConfig.openConnection();
         PreparedStatement statement = connection.prepareStatement(sql)) {

        statement.setInt(1, turmaId);

        try (ResultSet rows = statement.executeQuery()) {
            return readRows(rows);
        }
    }
}
```

| Linha | O que faz |
|---|---|
| public List<String[]> boletimDaTurma(int turmaId) | Método que recebe o número de uma turma e devolve uma lista de linhas; cada linha é um vetor de textos. A primeira linha da lista é o cabeçalho (nomes das colunas) |
| String sql = "SELECT * FROM vw_boletim WHERE id_turma = ? ORDER BY aluno" | A consulta: todas as matrículas da turma, em ordem alfabética de aluno. O `?` é o espaço do parâmetro, preenchido depois. **Só** `SELECT` em view |
| try (Connection ... PreparedStatement ...) | Abre a conexão e prepara a consulta. O `try (...)` fecha tudo sozinho no fim, mesmo se der erro |
| statement.setInt(1, turmaId) | Coloca o número da turma no lugar do `?`. É assim que se evita injeção de SQL: o valor nunca é colado no texto da consulta |
| statement.executeQuery() | Roda a consulta e devolve as linhas |
| return readRows(rows) | Converte o resultado em lista de textos (método auxiliar da classe) |

```java
public List<String[]> fecharSemestre(String semestre, int usuarioId)
        throws SQLException {

    try (Connection connection = DatabaseConfig.openConnection();
         CallableStatement call = connection.prepareCall(
                 "{call sp_fechar_semestre(?, ?)}")) {

        call.setString(1, semestre);
        call.setInt(2, usuarioId);

        boolean hasResult = call.execute();

        while (true) {
            if (hasResult) {
                try (ResultSet rows = call.getResultSet()) {
                    if (rows != null) {
                        return readRows(rows);
                    }
                }
            } else if (call.getUpdateCount() == -1) {
                break;
            }

            hasResult = call.getMoreResults();
        }

        return List.of();
    }
}
```

| Linha | O que faz |
|---|---|
| CallableStatement call = connection.prepareCall("{call sp_fechar_semestre(?, ?)}") | Prepara a chamada da procedure, com dois parâmetros |
| call.setString(1, semestre) e call.setInt(2, usuarioId) | Preenchem o semestre (por exemplo "2026.2") e o id de quem está fechando. O banco confere se esse usuário é Coordenador |
| boolean hasResult = call.execute() | Executa. Devolve `true` se o primeiro retorno é um conjunto de linhas |
| while (true) { ... } | Percorre os retornos da procedure um por um. Uma procedure pode devolver vários resultados (por exemplo, de comandos internos); o que nos interessa é o resumo final |
| if (hasResult) ... return readRows(rows) | Quando acha o conjunto de linhas (o resumo por situação), converte e devolve |
| else if (call.getUpdateCount() == -1) break | Se não há mais nada a ler, sai do laço |
| hasResult = call.getMoreResults() | Passa para o próximo retorno |
| return List.of() | Se não veio nenhuma linha, devolve uma lista vazia |

Por que esse laço? Porque a procedure `sp_fechar_semestre` termina com um `SELECT situacao, COUNT(*)` que é o resumo mostrado na tela. O Java não pode supor que ele seja o primeiro retorno.

### NotasFrame: lançar notas

A tela `NotasFrame` mostra um seletor de turma (só as abertas) e uma tabela com as matrículas da turma. Ao escolher uma linha e clicar em "Lançar notas", roda este método:

```java
private void lancarNotas() {
    String[] m = matriculaSelecionada();
    if (m == null) {
        return;
    }

    String[] c = linhas.get(0);
    int idMatricula = Integer.parseInt(Tabelas.celula(m, Tabelas.coluna(c, "id_matricula")));
    String aluno = Tabelas.celula(m, Tabelas.coluna(c, "aluno"));
    String totalAulas = Tabelas.celula(m, Tabelas.coluna(c, "total_aulas"));
```

| Linha | O que faz |
|---|---|
| String[] m = matriculaSelecionada() | Pega a linha que o usuário clicou. Se não clicou em nenhuma, o método já avisou "Selecione uma matrícula" e devolve `null` |
| if (m == null) return | Se não há linha selecionada, não faz nada |
| String[] c = linhas.get(0) | A primeira linha da lista é o cabeçalho com os nomes das colunas |
| Tabelas.coluna(c, "id_matricula") | Descobre em qual posição está a coluna chamada `id_matricula`. A tela procura **pelo nome**, não pela posição |
| Integer.parseInt(...) | Converte o texto "17" para o número 17 |

```java
    JTextField n1 = new JTextField(Tabelas.celula(m, Tabelas.coluna(c, "n1")));
    JTextField n2 = new JTextField(Tabelas.celula(m, Tabelas.coluna(c, "n2")));
    JTextField faltas = new JTextField(Tabelas.celula(m, Tabelas.coluna(c, "faltas")));

    JPanel painel = new JPanel(new GridLayout(0, 2, 6, 6));
    painel.add(new JLabel("N1 (0 a 10):"));
    painel.add(n1);
    painel.add(new JLabel("N2 (0 a 10):"));
    painel.add(n2);
    painel.add(new JLabel("Faltas (de " + totalAulas + " aulas):"));
    painel.add(faltas);

    int escolha = JOptionPane.showConfirmDialog(this, painel,
            "Lançar notas: " + aluno,
            JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
    if (escolha != JOptionPane.OK_OPTION) {
        return;
    }
```

| Linha | O que faz |
|---|---|
| new JTextField(...) | Cria caixas de texto, já preenchidas com os valores atuais (se a nota ainda não existe, fica vazia) |
| new JPanel(new GridLayout(0, 2, 6, 6)) | Um painel em grade de 2 colunas: rótulo à esquerda, caixa à direita. O `0` significa "quantas linhas precisar" |
| painel.add(...) | Coloca rótulos e caixas no painel, em ordem |
| "Faltas (de " + totalAulas + " aulas)" | Mostra quantas aulas a turma tem, para o Coordenador saber o limite |
| JOptionPane.showConfirmDialog(...) | Abre a caixinha com o formulário e os botões OK e Cancelar. O `this` diz de qual janela ela depende |
| if (escolha != JOptionPane.OK_OPTION) return | Se o usuário cancelou ou fechou, desiste |

```java
    try {
        double valorN1 = lerNota(n1.getText(), "N1");
        double valorN2 = lerNota(n2.getText(), "N2");
        int valorFaltas = lerFaltas(faltas.getText());

        repository.lancarNotas(idMatricula, valorN1, valorN2, valorFaltas, usuarioId);
        carregarMatriculas();

    } catch (IllegalArgumentException | SQLException e) {
        mostrarErro(e);
    }
}
```

| Linha | O que faz |
|---|---|
| lerNota(n1.getText(), "N1") | Converte o texto digitado em número e confere se está entre 0 e 10 (veja `lerNota` abaixo) |
| repository.lancarNotas(...) | Chama a procedure `sp_lancar_notas`. A tela **não** calcula média nem situação |
| carregarMatriculas() | Recarrega a tabela, que já mostra a média e a situação calculadas pelo banco |
| catch (IllegalArgumentException, SQLException) | Qualquer erro, da própria tela (número inválido) ou do banco (regra quebrada), cai aqui |
| mostrarErro(e) | Mostra uma caixa vermelha com a mensagem do erro, sem alterar nada |

### NotasFrame: lançar exame

```java
if (!"Em Exame".equalsIgnoreCase(situacao)) {
    JOptionPane.showMessageDialog(this,
            "Exame só pode ser lançado para matrícula Em Exame.\n"
            + aluno + " está como: " + situacao + ".",
            "Exame indisponível", JOptionPane.INFORMATION_MESSAGE);
    return;
}
```

| Linha | O que faz |
|---|---|
| if (!"Em Exame".equalsIgnoreCase(situacao)) | Se a situação da matrícula não for "Em Exame", a tela avisa antes de chamar o banco. É uma gentileza de tela: a regra de verdade também está na procedure `sp_lancar_exame` |
| return | Para por aqui; não abre o formulário |

O resto do método é igual ao de lançar notas, mas pede só a nota do exame e chama `repository.lancarExame(...)`.

### NotasFrame: validar o que foi digitado

```java
private static double lerNota(String texto, String rotulo) {
    double valor;
    try {
        valor = Double.parseDouble(texto.trim().replace(',', '.'));
    } catch (NumberFormatException e) {
        throw new IllegalArgumentException(rotulo + ": informe um número (ex.: 7,5).");
    }
    if (valor < 0 || valor > 10) {
        throw new IllegalArgumentException(rotulo + ": a nota deve estar entre 0 e 10.");
    }
    return valor;
}
```

| Linha | O que faz |
|---|---|
| texto.trim().replace(',', '.') | Tira os espaços e troca vírgula por ponto, porque o brasileiro digita `7,5` e o Java entende `7.5` |
| Double.parseDouble(...) | Converte o texto em número. Se não for número (por exemplo "abc"), dá `NumberFormatException` |
| catch ... throw new IllegalArgumentException(...) | Troca o erro técnico por uma mensagem clara, dizendo qual campo está errado |
| if (valor < 0 ou valor > 10) | Em Java o "ou" se escreve com duas barras verticais. Fora da faixa de 0 a 10, recusa. O banco recusaria também (CHECK da RN07), mas assim o usuário ganha a mensagem na hora |

`lerFaltas` faz o mesmo para um inteiro: aceita zero ou mais, e recusa letras e números negativos.

### RelatoriosFrame

```java
abas.addTab("Desempenho por turma",
        painelSimples(repository.consultarView("vw_desempenho_turma")));
abas.addTab("Lotação das turmas",
        painelSimples(repository.consultarView("vw_turmas_lotacao")));
abas.addTab("Faturamento por curso",
        painelFaturamento(repository.consultarView("vw_faturamento_curso")));
```

| Linha | O que faz |
|---|---|
| abas.addTab(titulo, painel) | Adiciona uma aba na janela |
| repository.consultarView("vw_desempenho_turma") | Lê a view de desempenho. A classe só aceita os nomes de view que estão na lista permitida |
| painelSimples(...) | Monta uma tabela com as linhas devolvidas |
| painelFaturamento(...) | Igual, mas também soma a coluna `faturamento_mensal` e mostra o **total mensal previsto em reais** e a quantidade de alunos ativos embaixo da tabela |

### Fechar semestre (DashboardFrame, método closeSemester)

A sequência do método é:

1. Lê da `vw_turmas_lotacao` quais semestres ainda têm turma com status `Aberta` (método `semestresAbertos`). Se não houver nenhuma, avisa e para.
2. Mostra uma lista com esses semestres.
3. Depois da escolha, mostra uma caixa de confirmação: "As turmas serão encerradas e as notas não poderão mais ser alteradas. Matrículas Em Exame sem exame ficam como Reprovado por Nota."
4. Se o usuário confirma, chama `repository.fecharSemestre(semestre, usuarioId)` e mostra o resumo por situação. Se a procedure recusar (por exemplo, falta nota de alguém), a mensagem do banco aparece e **nada muda**, porque o fechamento é uma transação "tudo ou nada".

### Os extras: CR, Auditoria e painel Início

| Arquivo | O que faz |
|---|---|
| Cartoes.java | Desenha os cartões brancos (CR do aluno, cartões do painel) |
| `consultarCr` em SgaRepository | `SELECT aluno, ra, cr FROM vw_cr_aluno WHERE id_aluno = ?`, com parâmetro. Devolve nulo se o aluno não existe, e `cr` vazio se ele não tem disciplina concluída |
| AuditoriaFrame.java | Mostra o `consultarAuditoriaNotas`, que é `SELECT * FROM vw_log_nota ORDER BY data_hora DESC, id_log DESC LIMIT 500` (as 500 alterações mais recentes). Recarrega sozinha quando a janela volta a ficar ativa, então a linha nova aparece depois de lançar uma nota |
| InicioPanel.java | O painel inicial: cartões de turmas abertas, alunos ativos, média geral e faturamento previsto (este só para o Coordenador), mais o gráfico |
| GraficoDesempenho.java | Gráfico de barras desenhado com Java2D: aprovados em verde, reprovados em vermelho e em andamento em azul, por turma, a partir da `vw_desempenho_turma` |
| Tema.java e Tabelas.java | A aparência (cores, fonte, tabelas listradas, situação colorida, dinheiro em R$) e utilitários para montar tabelas a partir do resultado do banco |

# 4. Como as peças se encaixam

```text
 Seu 01_ddl.sql ........ as 9 tabelas e as regras de integridade (a base de todos)
        |
        +--> Diego (02a): functions, views e triggers usam as suas tabelas
        |                 triggers calculam media_final e situacao na matricula
        |                 trigger de auditoria escreve no seu log_nota
        |
        +--> Mykael (02b): procedures de login, matricula, notas, exame, historico e fechamento
        |
        +--> Seu 02c: cadastro de aluno e as views vw_alunos, vw_cr_aluno, vw_log_nota
        |
        +--> Seu 03_dados.sql: roda por ultimo, com todos os triggers ativos
        |
        +--> Interface (Leo + voce): telas chamam so procedures e views
                 Secretario: alunos, matricula, boletim, historico
                 Coordenador: notas e exame, fechar semestre, relatorios, auditoria
```

Em uma frase: **o seu DDL é o chão de todos**. Sem as tabelas e os CHECK, as functions do Diego, as procedures do Mykael e as telas do Leo não teriam onde se apoiar.

# 5. Perguntas que o professor pode fazer (com respostas)

**1. Até que forma normal o modelo está normalizado e por quê?**
Até a terceira (3FN). Cada informação fica em uma tabela só: nome e mensalidade do curso em `curso`, nome do professor em `professor`, vagas da oferta em `turma`. As outras tabelas apontam por chave estrangeira, então não há dependência de coluna não-chave com outra não-chave.

**2. Existe alguma redundância?**
Sim, uma, e é de propósito: `media_final` e `situacao` em `matricula` são derivadas das notas e das faltas. Foram mantidas porque o enunciado as trata como dado da matrícula, a regra de pré-requisito precisa achar `Aprovado` rapidamente, e a consistência é garantida pelos triggers, que recalculam a cada inserção e atualização. Nenhuma tela escreve esses valores.

**3. Como o N:N entre aluno e turma foi resolvido?**
Com a tabela `matricula`, que tem uma linha por aluno em cada turma e ainda carrega os atributos próprios da relação: notas, faltas e situação. Um `UNIQUE (id_aluno, id_turma)` impede matrícula repetida.

**4. E o N:N entre disciplinas, o pré-requisito?**
É um autorrelacionamento: a tabela `pre_requisito` tem duas colunas que apontam para `disciplina`, com chave primária composta. Um CHECK impede uma disciplina de ser pré-requisito dela mesma.

**5. Para que servem os CHECK? Não bastava validar na tela?**
Não bastava. A tela pode ter bug ou ser contornada; o banco é a última barreira. O CHECK garante a regra para qualquer caminho de entrada: nota de 0 a 10 (RN07), faltas não negativas, CPF com 11 dígitos, status e perfil só com valores permitidos.

**6. Por que `COLLATE utf8mb4_bin` nos CHECK de texto?**
Porque a comparação padrão do MySQL ignora maiúsculas e acentos. Sem a binária, `'em exame'` passaria no CHECK de situação e quebraria as comparações do resto do sistema. Com ela, só vale a grafia exata combinada.

**7. Por que `DECIMAL` e não `FLOAT` para nota e dinheiro?**
`FLOAT` é aproximado e pode dar 6,9999999 em vez de 7. `DECIMAL` é exato, e as regras comparam a média com 7,0, 4,0 e 5,0, então precisa ser exato.

**8. Por que a senha é `CHAR(64)`?**
Porque guarda o SHA-256 em hexadecimal, que sempre tem 64 caracteres. Um CHECK exige exatamente 64 caracteres hexadecimais minúsculos, o que impede gravar uma senha em texto puro por engano.

**9. Por que não dá para excluir um aluno que tem matrícula?**
Pela chave estrangeira (`RESTRICT`): apagar o aluno deixaria matrículas apontando para ninguém e destruiria o histórico. A `sp_excluir_aluno` confere antes e orienta: tranque o aluno (mude o status), em vez de excluir.

**10. Por que o cadastro de aluno é por procedure e não um `INSERT` na tela?**
Porque a regra do projeto é que a interface só use procedures e views. Além disso, a procedure valida tudo e devolve mensagem clara, e fica um único lugar com a regra de cadastro.

**11. Para que servem os índices que você criou?**
Para acelerar junções e buscas. As chaves estrangeiras ganharam índice porque as views fazem `JOIN` por elas o tempo todo; `idx_aluno_nome` ajuda a busca por nome e `idx_turma_semestre` ajuda o fechamento e o histórico, que filtram por semestre.

**12. Por que a massa de dados roda depois dos triggers e procedures?**
Para que os triggers já estejam ativos na hora do `INSERT`: eles calculam média e situação das matrículas do semestre anterior e o `trg_valida_vagas` confere as vagas. Se a massa estivesse errada, o banco recusaria. E a regra de pré-requisito só funciona se as matrículas antigas já estiverem como `Aprovado`.

**13. Como a tela evita injeção de SQL?**
Nunca monta o SQL juntando texto digitado. Usa `PreparedStatement` e `CallableStatement` com parâmetros (`?`), e as views sem parâmetro passam por uma lista de nomes permitidos.

**14. O que acontece se o Coordenador tentar fechar o semestre com uma nota faltando?**
A procedure recusa o fechamento inteiro e diz qual matrícula está sem nota. Como é uma transação, nada é alterado: ou fecha tudo, ou nada.

**15. Um Secretário consegue lançar nota se chamar a procedure direto?**
Não. A procedure confere o perfil do usuário no banco e responde "Apenas o Coordenador pode lançar notas." A tela esconder o botão é só uma camada a mais.

**16. (Armadilha) A coluna `valor_mensalidade` não estava no enunciado. Por que existe?**
Porque o relatório de faturamento por curso, que o enunciado pede ao Coordenador, precisa de um valor, e nenhuma tabela mínima tinha. O grupo acrescentou a coluna em `curso`, e a view `vw_faturamento_curso` calcula alunos ativos vezes mensalidade.

**17. (Armadilha) O SHA-256 sem "sal" é seguro?**
Para este trabalho cumpre o que o enunciado pede (hash, nunca texto puro). Numa aplicação real o ideal seria um algoritmo próprio para senhas, como bcrypt, com sal, que é mais lento e resiste melhor a ataques com tabelas prontas. É uma limitação consciente.

# 6. Passo a passo para mostrar funcionando

Antes de começar: no MySQL Workbench, abra e execute o arquivo `database/SGA_completo.sql` inteiro (cria o banco do zero). Depois abra uma aba nova e rode `USE sga_fbi;`.

**A. Ver a estrutura de uma tabela**

```sql
SHOW CREATE TABLE matricula;
```

Mostra o `CREATE TABLE` com todas as chaves e os CHECK. Bom para apontar "aqui está a RN07".

**B. O CHECK barrando uma nota inválida (RN07)**

```sql
UPDATE matricula SET n1 = 11 WHERE id_matricula = 17;
```

Resultado esperado: erro `Check constraint 'ck_matricula_n1' is violated.` Nada é gravado.

**C. A grafia exata (COLLATE utf8mb4_bin)**

```sql
UPDATE aluno SET status = 'ativo' WHERE id_aluno = 1;
```

Resultado esperado: erro de violação do `ck_aluno_status`, porque o valor é `Ativo` com A maiúsculo.

**D. Cadastro de aluno e erro de RA repetido**

```sql
CALL sp_cadastrar_aluno('2026999', 'Maria Teste', '99900000002', 'maria.teste@aluno.fbi.edu.br', '2005-03-14', 1);
CALL sp_cadastrar_aluno('2025001', 'Outra Pessoa', '99900000003', 'outra@aluno.fbi.edu.br', '2005-03-14', 1);
```

Esperado: o primeiro devolve `id_aluno` 21. O segundo dá o erro `Já existe um aluno com este RA.`

**E. Excluir aluno com matrícula, e sem matrícula**

```sql
CALL sp_excluir_aluno(1);
CALL sp_excluir_aluno(21);
```

Esperado: o primeiro dá `Aluno tem matrículas: tranque o aluno em vez de excluir.` O segundo funciona (o aluno 21 acabou de ser criado e nunca se matriculou).

**F. As views dos relatórios**

```sql
SELECT * FROM vw_faturamento_curso;
SELECT * FROM vw_desempenho_turma;
```

Esperado: 3 cursos no faturamento (ADS com 9 alunos ativos e R$ 5.850,00; Ciência da Computação com 7 e R$ 8.400,00; Sistemas de Informação com 2 e R$ 1.960,00) e 5 turmas no desempenho.

**G. A auditoria (RN08)**

```sql
UPDATE matricula SET n1 = 8.5, id_usuario = 1 WHERE id_matricula = 17;
SELECT * FROM log_nota ORDER BY id_log DESC LIMIT 3;
```

Esperado: uma linha nova no `log_nota` com `campo` = `n1`, `valor_antigo` = 8,00 e `valor_novo` = 8,50, escrita pelo trigger. Na tela do Coordenador, o menu **Auditoria** mostra a mesma linha.

**H. A mesma coisa pela interface (mais bonito para a banca)**

1. Entrar como `coord.ana` (senha `Senha@123`).
2. Menu **Notas e exame**, turma de Programação Orientada a Objetos, selecionar Daniel Pacheco e **Lançar notas**: N1 7,5, N2 8 e 3 faltas. A média 7,75 e a situação Aprovado aparecem na hora.
3. Selecionar Bernardo Cavalcante (Em Exame) e **Lançar exame**: nota 5. Vira Aprovado com média final 5,75.
4. Menu **Auditoria**: as linhas dessas alterações estão lá.
5. Menu **Relatórios**: as três abas.

Depois de qualquer ensaio, rode o `SGA_completo.sql` de novo para voltar os dados ao início.

# 7. Se você só tem 5 minutos antes de apresentar

1. São 9 tabelas na 3FN; o dado de cada coisa fica em um lugar só.
2. Aluno × turma é N:N e virou a tabela `matricula`, com as notas.
3. Disciplina × disciplina é N:N e virou `pre_requisito`.
4. As regras vão no DDL: PK, FK, UNIQUE e CHECK (nota de 0 a 10, textos com grafia exata).
5. `media_final` e `situacao` são a única redundância, mantida pelos triggers.
6. Não se exclui aluno com matrícula: tranca-se. Quem avisa é a `sp_excluir_aluno`.
7. A massa de dados roda depois dos triggers, com um cenário para cada teste obrigatório.
8. A tela só chama procedures e views, sempre com parâmetros.
9. Quem calcula é o banco; a tela só mostra.
10. Coordenador lança notas e fecha o semestre; o banco recusa o Secretário mesmo sem botão.
