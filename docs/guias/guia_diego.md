# 1. Em um minuto

**A sua parte em uma frase:** você escreveu a parte do banco que "pensa sozinha". As regras da faculdade (média, situação do aluno, vagas, auditoria das notas) ficam escritas dentro do MySQL, em **6 functions, 4 views e 4 triggers**, no arquivo `database/02a_functions_views_triggers.sql`.

**Por que isso importa:** quem lança uma nota só grava N1, N2, exame e faltas. Ninguém calcula nada à mão e nenhuma tela decide quem passou. O banco calcula, sempre do mesmo jeito, e a regra existe em um lugar só. Se alguém tentar mexer nos dados por outro caminho (outra tela, outro script), as regras valem do mesmo jeito.

**Roteiro para falar em voz alta (cerca de 1 minuto):**

> Eu fiz a parte do banco que trabalha sozinha. Quando o Coordenador lança as notas de um aluno, ninguém precisa calcular nada: eu criei triggers, que são gatilhos que disparam automaticamente quando uma matrícula é inserida ou alterada. Um deles calcula a média e a situação do aluno. Para isso eu escrevi functions, onde a regra está num lugar só: a média é N1 mais N2 dividido por dois, o exame só entra para quem está entre 4 e 7, e quem tem presença abaixo de 75% reprova por falta, mesmo com nota alta. Outro trigger impede a matrícula em turma lotada e usa um bloqueio de linha, o FOR UPDATE, para duas pessoas não pegarem a última vaga ao mesmo tempo. O terceiro grava automaticamente cada mudança de nota na tabela de auditoria, com valor antigo, valor novo e quem mexeu. Por fim, criei quatro views, que são consultas prontas com nome: boletim, lotação das turmas, desempenho da turma e faturamento por curso. A interface só consulta essas views. O resultado é que a regra de negócio vive dentro do banco e vale para qualquer caminho que alguém use para mexer nos dados.

**Números para ter na cabeça:** 6 functions (4 pedidas ou opcionais mais 2 auxiliares), 4 views (3 do enunciado mais a de faturamento), 4 triggers (3 do enunciado mais o `trg_situacao_inicial`). Todos os 4 triggers ficam na tabela `matricula`.

# 2. Palavras que você precisa saber

- **Function (função):** um pedaço de código guardado no banco que recebe valores e **devolve um valor**. Dá para usar dentro de um SELECT, como `SELECT fn_frequencia(17)`. Exemplo da vida real: a calculadora do celular. Você dá os números e ela devolve o resultado.
- **View:** uma consulta SELECT guardada com um nome. Ela **não guarda dados**, só a receita. Cada vez que você consulta a view, o banco refaz o SELECT e mostra os dados de agora. Exemplo: um atalho de "relatório pronto" no sistema da secretaria.
- **Trigger (gatilho):** código que o banco executa **sozinho** quando acontece um INSERT, UPDATE ou DELETE numa tabela. Ninguém chama o trigger; ele dispara. Exemplo: o alarme que toca sozinho quando a porta abre.
- **BEFORE e AFTER:** o momento em que o trigger roda. `BEFORE` roda **antes** de a linha ser gravada, e ainda dá tempo de mudar o que vai ser gravado ou de cancelar tudo. `AFTER` roda **depois** que a linha já foi gravada, e serve para registrar o que aconteceu.
- **NEW e OLD:** dentro de um trigger, `NEW` é a linha **como vai ficar** (valores novos) e `OLD` é a linha **como era** (valores antigos). No INSERT só existe `NEW`. No UPDATE existem os dois. Exemplo: `OLD.n1` é a nota que estava, `NEW.n1` é a nota que está chegando.
- **NULL:** significa "não tem valor / ainda não foi informado". Não é zero. Uma nota ainda não lançada é NULL. Qualquer conta com NULL dá NULL, e uma comparação como `NULL = NULL` não dá verdadeiro (dá NULL, que o IF trata como falso).
- **Operador `<=>`:** é a comparação "igual" que **sabe lidar com NULL**. `NULL <=> NULL` dá verdadeiro e `NULL <=> 7.5` dá falso. Com o `=` comum, as duas contas dariam NULL. Por isso o auditor usa `NOT (OLD.n1 <=> NEW.n1)` para perguntar "mudou?".
- **SIGNAL SQLSTATE '45000':** é o jeito de **lançar um erro de propósito** no MySQL. O código `45000` quer dizer "erro definido pelo programador". O `MESSAGE_TEXT` é a frase que aparece para o usuário. Dentro de um trigger BEFORE, o SIGNAL cancela a operação inteira.
- **DELIMITER:** comando do cliente (Workbench), não do SQL. Normalmente o `;` encerra um comando. Dentro de uma function há vários `;` e o cliente cortaria o comando no primeiro. Então trocamos o terminador para `$$` enquanto criamos a function e depois voltamos para `;`.
- **DECLARE, SET, RETURN:** `DECLARE` cria uma variável local (aqui sempre com prefixo `v_`). `SET` dá valor a ela. `RETURN` devolve o resultado da function e encerra na hora.
- **DETERMINISTIC, NO SQL, READS SQL DATA:** etiquetas que dizem como a function se comporta. `DETERMINISTIC`: com os mesmos valores de entrada, sempre devolve o mesmo resultado. `NO SQL`: só faz contas, não consulta tabelas. `READS SQL DATA`: consulta tabelas, mas não grava. O MySQL pede que você declare uma delas.
- **DECIMAL(4,2):** número com no máximo 4 dígitos no total, 2 deles depois da vírgula. Vai de 0,00 a 99,99. Usamos para notas porque DECIMAL é exato (não tem erro de arredondamento como o `FLOAT`).
- **ROUND e TRUNCATE:** `ROUND(x, 2)` arredonda para 2 casas (6,995 vira 7,00). `TRUNCATE(x, 2)` simplesmente **corta** depois da 2ª casa (74,999 vira 74,99). Usamos ROUND nas médias e TRUNCATE na frequência. O motivo está no passo a passo.
- **COALESCE, NULLIF, GREATEST:** `COALESCE(a, b)` devolve o primeiro valor que não é NULL (usamos para trocar NULL por 0). `NULLIF(a, b)` devolve NULL se `a` for igual a `b` (usamos para evitar dividir por zero). `GREATEST(a, b)` devolve o maior dos dois.
- **JOIN, LEFT JOIN e GROUP BY:** `JOIN` junta tabelas mostrando só as linhas que têm par nas duas. `LEFT JOIN` mantém **todas as linhas da tabela da esquerda**, mesmo sem par na direita (as colunas da direita ficam NULL). `GROUP BY` junta linhas em grupos para usar `COUNT`, `AVG`, `SUM`, `MAX`, `MIN` por grupo.
- **Transação e FOR UPDATE:** transação é um pacote de operações que vale tudo ou nada (COMMIT confirma, ROLLBACK desfaz). `SELECT ... FOR UPDATE` lê uma linha e **a trava**: outras sessões que tentarem travar a mesma linha ficam esperando até a transação terminar. Exemplo: o caixa que fica "reservado" para você até você terminar de pagar.
- **FOLLOWS:** quando há dois triggers do mesmo tipo na mesma tabela, `FOLLOWS outro` diz que este roda **depois** do outro.
- **DROP ... IF EXISTS:** apaga o objeto se ele existir e não dá erro se não existir. É por isso que o script pode ser rodado várias vezes.
- **Regra de negócio (RN):** regra da faculdade que o sistema precisa respeitar. RN01 média parcial; RN02 faixas de aprovação; RN03 exame; RN04 reprovação por falta; RN05 limite de vagas; RN08 auditoria das notas. Estão em `docs/REQUISITOS.md`.
- **Auditoria (log):** um diário de bordo. Cada alteração de nota vira uma linha em `log_nota` com o que mudou, de quanto para quanto, quem mudou e quando.

# 3. O código, linha por linha

Como ler esta parte: cada bloco tem o trecho **exatamente como está no arquivo**, e logo abaixo uma tabela explicando. A coluna da esquerda é o número da linha (ou o intervalo) do arquivo `02a_functions_views_triggers.sql`.

## Cabeçalho do arquivo (linhas 1 a 49)

> Os comentários do começo dizem: este é o arquivo do Diego; a ordem de execução do projeto é 01_ddl, depois este arquivo, depois 02b, 02c, 03_dados e 04_testes; dentro deste arquivo a ordem é functions, depois views, depois triggers, porque as views e os triggers usam as functions; o script pode ser rodado de novo porque cada objeto tem DROP IF EXISTS. Em seguida há a lista de tudo que existe aqui e as quatro decisões do grupo: (1) médias arredondadas para 2 casas ANTES de comparar com 7, 4 e 5; (2) frequência truncada (não arredondada), para 74,999% nunca virar 75,00%; (3) o exame só entra na média de quem está na faixa de exame (parcial de 4,00 a 6,99); (4) "Reprovado por Falta" ganha de tudo, inclusive antes de as notas serem lançadas.

## Preparação: escolher o banco e limpar (linhas 51 a 69)

### USE e DROP dos triggers (linhas 51 a 57)

```sql
USE sga_fbi;

-- Limpeza, na ordem inversa da dependência
DROP TRIGGER IF EXISTS trg_auditoria_nota;
DROP TRIGGER IF EXISTS trg_atualiza_situacao;
DROP TRIGGER IF EXISTS trg_situacao_inicial;
DROP TRIGGER IF EXISTS trg_valida_vagas;
```

| Linha | O que faz |
|-------|-----------|
| 51 | `USE sga_fbi;` diz ao MySQL em qual banco tudo será criado. |
| 53 | Comentário: a limpeza segue a ordem inversa da dependência. É boa prática remover primeiro quem usa os outros objetos e só depois quem é usado. |
| 54 a 57 | Um `DROP TRIGGER IF EXISTS` para cada um dos quatro triggers. Se o trigger já existe (de uma execução anterior), é apagado; se não existe, nada acontece. Assim o script pode rodar de novo sem dar erro de "já existe". |

### DROP das views e das functions (linhas 59 a 69)

```sql
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
```

| Linha | O que faz |
|-------|-----------|
| 59 a 62 | Apaga as 4 views, se existirem. |
| 64 a 69 | Apaga as 6 functions, se existirem. As auxiliares (`fn_situacao_calc`, `fn_frequencia_calc`) são apagadas depois de quem as usa, seguindo a mesma ordem inversa. |

## Functions

### Troca do delimitador (linha 75)

```sql
DELIMITER $$
```

| Linha | O que faz |
|-------|-----------|
| 75 | `DELIMITER $$` muda o terminador de comando de `;` para `$$`. Dentro do corpo de uma function usamos `;` depois de cada instrução. Sem a troca, o Workbench acharia que o comando acabou no primeiro `;` e quebraria tudo. Cada function termina com `END$$`. Só voltamos ao normal na linha 284. |

## fn_calcular_media (linhas 90 a 112)

> Resumo do comentário: RN01 diz que a média parcial é (N1 + N2) / 2. RN03 diz que a média final é (parcial + exame) / 2. Se falta N1 ou N2, o resultado é NULL (ainda não tem média). Se a parcial está fora da faixa de exame, vale a própria parcial. Se está na faixa e não tem exame, vale a parcial por enquanto. Se está na faixa e tem exame, vale (parcial + exame) / 2.

### Assinatura (linhas 90 a 97)

```sql
CREATE FUNCTION fn_calcular_media(
    p_n1    DECIMAL(4,2),
    p_n2    DECIMAL(4,2),
    p_exame DECIMAL(4,2)
)
RETURNS DECIMAL(4,2)
DETERMINISTIC
NO SQL
```

| Linha | O que faz |
|-------|-----------|
| 90 | `CREATE FUNCTION fn_calcular_media(` começa a criar a function. O prefixo `fn_` é o combinado do grupo. |
| 91 a 93 | Três parâmetros: `p_n1`, `p_n2` e `p_exame`, todos `DECIMAL(4,2)`. O prefixo `p_` marca que é parâmetro. |
| 95 | `RETURNS DECIMAL(4,2)`: a function devolve um número com 2 casas decimais, o mesmo formato da coluna `media_final`. |
| 96 | `DETERMINISTIC`: com as mesmas notas, a resposta é sempre a mesma. |
| 97 | `NO SQL`: a function só faz contas e não consulta nenhuma tabela. |

### Corpo, parte 1: sem notas, sem média (linhas 98 a 103)

```sql
BEGIN
    DECLARE v_parcial DECIMAL(4,2);

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN NULL;
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 98 | `BEGIN` abre o corpo da function. |
| 99 | Cria a variável local `v_parcial` para guardar a média parcial. |
| 101 a 103 | Se N1 **ou** N2 for NULL, devolve NULL e termina. Sem as duas notas não existe média; devolver NULL (e não 0) deixa claro que "ainda não tem média". |

### Corpo, parte 2: parcial e final (linhas 105 a 112)

```sql
    SET v_parcial = ROUND((p_n1 + p_n2) / 2, 2);

    IF p_exame IS NOT NULL AND v_parcial >= 4 AND v_parcial < 7 THEN
        RETURN ROUND((v_parcial + p_exame) / 2, 2);
    END IF;

    RETURN v_parcial;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 105 | Calcula a média parcial: soma as notas, divide por 2 e **arredonda para 2 casas** com `ROUND`. O arredondamento acontece aqui, antes de qualquer comparação. Por quê: (6,99 + 7,00) / 2 dá 6,995. Como a coluna guarda só 2 casas, o boletim mostraria 7,00. Se comparássemos 6,995 com 7, o aluno ficaria "Em Exame" com média 7,00 na tela, o que não faz sentido. Arredondando antes, a situação sempre combina com a média que aparece. |
| 107 a 109 | Só se **tem exame** E a parcial está na faixa de exame (a partir de 4 e abaixo de 7), a média final vira (parcial + exame) / 2, também arredondada. Por quê a faixa: quem passou direto não deve ser puxado para baixo por um exame digitado por engano. Um aluno com 8,50 que recebesse exame 2,0 ficaria com 5,25, e continuaria "Aprovado": informações que não combinam. |
| 111 | Nos demais casos (fora da faixa, ou na faixa mas sem exame), devolve a própria parcial. |
| 112 | `END$$` fecha o corpo e termina o comando (por causa do delimitador `$$`). |

**Exemplos:** N1 = 8 e N2 = 9 dão 8,50. N1 = 5 e N2 = 6 dão parcial 5,50, que está na faixa de exame. Sem exame a média é 5,50. Com exame 7, a média final é (5,50 + 7) / 2 = 6,25. N1 = 8, N2 = 9 e exame 2: parcial 8,50, fora da faixa, então o exame é ignorado e a média é 8,50.

## fn_frequencia_calc (linhas 124 a 139)

> Resumo: é a função "auxiliar" que calcula a frequência recebendo os valores (faltas e total de aulas). Ela existe para o trigger BEFORE UPDATE poder usar os valores novos (NEW) e para as views não precisarem de um SELECT a mais por linha. Fórmula: (total de aulas menos faltas) dividido pelo total de aulas, vezes 100, **truncado** em 2 casas. Total de aulas NULL ou 0 devolve NULL. Mais faltas que aulas devolve 0,00.

### Assinatura (linhas 124 a 130)

```sql
CREATE FUNCTION fn_frequencia_calc(
    p_faltas      INT,
    p_total_aulas INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
NO SQL
```

| Linha | O que faz |
|-------|-----------|
| 124 a 127 | Dois parâmetros inteiros: número de faltas e total de aulas da turma. |
| 128 | Devolve `DECIMAL(5,2)`: até 5 dígitos, 2 depois da vírgula, o que comporta 100,00. |
| 129 e 130 | `DETERMINISTIC` e `NO SQL`: só faz conta com o que recebeu. |

### Corpo (linhas 131 a 139)

```sql
BEGIN
    IF p_total_aulas IS NULL OR p_total_aulas <= 0 THEN
        RETURN NULL;
    END IF;

    RETURN TRUNCATE(
        GREATEST(p_total_aulas - COALESCE(p_faltas, 0), 0) * 100 / p_total_aulas,
        2);
END$$
```

| Linha | O que faz |
|-------|-----------|
| 131 | `BEGIN`. |
| 132 a 134 | Se o total de aulas é NULL, zero ou negativo, devolve NULL. Isso evita **divisão por zero** e dá "sem frequência" quando a turma não tem aulas cadastradas. |
| 136 a 138 | `TRUNCATE(..., 2)` corta a conta em 2 casas. Por dentro: `COALESCE(p_faltas, 0)` troca faltas NULL por 0. `p_total_aulas` menos as faltas dá as aulas assistidas. `GREATEST(..., 0)` impede resultado negativo se alguém tiver mais faltas que aulas (vira 0,00). Depois multiplica por 100 e divide pelo total. Por quê TRUNCATE e não ROUND: o mínimo é 75%. Se o aluno tem 74,996% e arredondássemos, apareceria 75,00% no boletim de um reprovado por falta. Cortando, ele aparece 74,99%. |
| 139 | `END$$`. |

**Exemplo:** turma de 80 aulas e 25 faltas: (80 − 25) × 100 / 80 = 68,75. Com 20 faltas dá exatamente 75,00 (passa). Com 21 faltas dá 73,75 (reprova por falta).

## fn_frequencia (linhas 148 a 162)

> Resumo: porcentagem de presença de **uma matrícula**, pelo id dela. O total de aulas vem da turma e as faltas vêm da matrícula. Matrícula que não existe devolve NULL.

### Assinatura e variáveis (linhas 148 a 153)

```sql
CREATE FUNCTION fn_frequencia(p_id_matricula INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_faltas      INT;
    DECLARE v_total_aulas INT;
```

| Linha | O que faz |
|-------|-----------|
| 148 | Recebe só o `id_matricula`. |
| 149 | Devolve a frequência em `DECIMAL(5,2)`. |
| 150 | `READS SQL DATA`: esta function **lê tabelas** (por isso não é `NO SQL`), mas não grava nada. Não tem `DETERMINISTIC` porque o resultado depende do que está nas tabelas naquele momento. |
| 151 | `BEGIN`. |
| 152 e 153 | Duas variáveis para guardar as faltas e o total de aulas que serão buscados. |

### Busca e cálculo (linhas 155 a 162)

```sql
    SELECT m.faltas, t.total_aulas
      INTO v_faltas, v_total_aulas
      FROM matricula m
      JOIN turma t ON t.id_turma = m.id_turma
     WHERE m.id_matricula = p_id_matricula;

    RETURN fn_frequencia_calc(v_faltas, v_total_aulas);
END$$
```

| Linha | O que faz |
|-------|-----------|
| 155 a 159 | `SELECT ... INTO` busca as faltas da matrícula (`m.faltas`) e o total de aulas da turma dela (`t.total_aulas`) e coloca nas duas variáveis. O `JOIN` liga a matrícula à sua turma. Se o id não existir, nenhuma linha volta e as variáveis continuam NULL. |
| 161 | Não repete a fórmula: chama `fn_frequencia_calc` com os valores buscados. Com as variáveis NULL, a auxiliar devolve NULL, e é assim que "matrícula inexistente devolve NULL". |
| 162 | `END$$`. |

Por que duas functions? A regra fica escrita **uma vez só** (na `_calc`). `fn_frequencia` só busca os dados e repassa.

## fn_situacao_calc (linhas 178 a 223)

> Resumo: esta é a function mais importante. Ela tem **toda a regra de situação** (RN02, RN03 e RN04) num lugar só e é chamada pela `fn_situacao` e pelos triggers. A ordem das regras é: frequência abaixo de 75% reprova por falta; falta N1 ou N2 é "Cursando"; parcial a partir de 7 aprova; parcial abaixo de 4 reprova por nota; de 4,00 a 6,99 sem exame fica "Em Exame"; com exame, (parcial + exame) / 2 a partir de 5 aprova; senão reprova por nota.

### Assinatura e variáveis (linhas 178 a 190)

```sql
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
```

| Linha | O que faz |
|-------|-----------|
| 178 a 184 | Recebe os valores soltos: as três notas, as faltas e o total de aulas. Não recebe o id da matrícula, e isso é de propósito: assim o trigger pode passar os valores novos (`NEW`). |
| 185 | Devolve texto de até 19 caracteres: o maior é 'Reprovado por Falta', que tem 19. |
| 186 e 187 | `DETERMINISTIC` e `NO SQL`: só decide com base no que recebeu. |
| 189 e 190 | Variáveis locais: a frequência e a média parcial. |

### Regra 1 e 2: falta e "Cursando" (linhas 192 a 200)

```sql
    -- RN04: reprovação por falta independe das notas
    SET v_frequencia = fn_frequencia_calc(p_faltas, p_total_aulas);
    IF v_frequencia IS NOT NULL AND v_frequencia < 75 THEN
        RETURN 'Reprovado por Falta';
    END IF;

    IF p_n1 IS NULL OR p_n2 IS NULL THEN
        RETURN 'Cursando';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 192 | Comentário: a reprovação por falta não depende das notas (RN04). |
| 193 | Calcula a frequência usando a auxiliar. |
| 194 a 196 | Se a frequência existe (não é NULL) e é menor que 75, devolve 'Reprovado por Falta' **na hora**. Isso vem antes de olhar as notas: média 9,0 com 73,75% de presença reprova. Também vale para quem ainda não tem nota, porque as faltas não diminuem. |
| 198 a 200 | Se falta N1 ou N2, ainda não dá para julgar a nota: devolve 'Cursando'. |

### Regra 3: faixas de aprovação (linhas 202 a 211)

```sql
    -- RN01 / RN02
    SET v_parcial = ROUND((p_n1 + p_n2) / 2, 2);

    IF v_parcial >= 7 THEN
        RETURN 'Aprovado';
    END IF;

    IF v_parcial < 4 THEN
        RETURN 'Reprovado por Nota';
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 202 | Comentário: RN01 e RN02. |
| 203 | Calcula a média parcial, **arredondada antes** de comparar (mesma razão da `fn_calcular_media`). |
| 205 a 207 | Parcial a partir de 7: 'Aprovado'. |
| 209 a 211 | Parcial abaixo de 4: 'Reprovado por Nota'. Quem chega na linha seguinte está, portanto, entre 4,00 e 6,99. |

### Regra 4: exame (linhas 213 a 223)

```sql
    IF p_exame IS NULL THEN
        RETURN 'Em Exame';
    END IF;

    -- RN03: a média final já sai certa da fn_calcular_media
    IF fn_calcular_media(p_n1, p_n2, p_exame) >= 5 THEN
        RETURN 'Aprovado';
    END IF;

    RETURN 'Reprovado por Nota';
END$$
```

| Linha | O que faz |
|-------|-----------|
| 213 a 215 | Na faixa de exame e sem nota de exame: 'Em Exame'. O aluno espera a prova. |
| 217 a 220 | Já tem exame. Pede a média final à `fn_calcular_media` (que faz (parcial + exame) / 2, arredondado) e, se for 5 ou mais, 'Aprovado' (RN03). Reaproveitar a function evita escrever a fórmula duas vezes. |
| 222 | Se não alcançou 5: 'Reprovado por Nota'. |
| 223 | `END$$`. |

**Exemplos (todos conferidos no MySQL):**

| Entrada (n1, n2, exame, faltas, aulas) | Resultado e motivo |
|-------------------------------------|--------------------|
| 6,99 e 7,00, sem exame, 0 faltas, 80 aulas | Aprovado: a parcial 6,995 vira 7,00. |
| 9 e 9, 21 faltas, 80 aulas | Reprovado por Falta: presença 73,75%. |
| 5 e 6, exame 3, 0 faltas | Reprovado por Nota: (5,50 + 3) / 2 = 4,25. |
| 5 e 6, exame 4,5, 0 faltas | Aprovado: (5,50 + 4,5) / 2 = 5,00, que é o mínimo. |
| 6 e 7,5 (parcial 6,75), exame 6 | Aprovado: (6,75 + 6) / 2 = 6,375, arredondado para 6,38. |

## fn_situacao (linhas 231 a 253)

> Resumo: a situação de **uma matrícula**, pelo id. Só busca a linha e chama a `fn_situacao_calc`. Matrícula inexistente devolve NULL.

### Assinatura e variáveis (linhas 231 a 240)

```sql
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
```

| Linha | O que faz |
|-------|-----------|
| 231 a 233 | Recebe o `id_matricula` e devolve texto de até 19 caracteres. `READS SQL DATA` porque consulta tabelas. |
| 235 a 239 | Variáveis para guardar cada valor que será buscado da matrícula e da turma. |
| 240 | `v_achou INT DEFAULT 0`: uma "bandeirinha" que começa em 0 e vira 1 se a matrícula for encontrada. |

### Busca e chamada (linhas 242 a 253)

```sql
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
```

| Linha | O que faz |
|-------|-----------|
| 242 a 246 | Busca as notas, as faltas e o total de aulas. A última coluna do SELECT é o número `1`, que vai para `v_achou`. Por quê isso: todas as notas podem ser NULL de verdade (aluno sem nota). Então não dá para descobrir "achei ou não" olhando se as variáveis são NULL. O `1` só chega a `v_achou` quando existe uma linha. |
| 248 a 250 | Se `v_achou` continua 0, a matrícula não existe e devolve NULL. |
| 252 | Chama a `fn_situacao_calc` com os valores buscados. |
| 253 | `END$$`. |

## fn_cr_aluno (linhas 266 a 282)

> Resumo: Coeficiente de Rendimento (CR), a "média geral" do aluno ponderada pela carga horária das disciplinas. CR = soma (média final × carga horária) / soma (carga horária). Entram só as disciplinas já concluídas (Aprovado, Reprovado por Nota, Reprovado por Falta). "Cursando" e "Em Exame" ficam fora porque ainda não têm resultado. Reprovação por falta sem nota conta como média 0. Aluno sem disciplina concluída devolve NULL. É a function opcional (ponto extra) e é usada pela view `vw_cr_aluno` do arquivo 02c.

### Assinatura e variável (linhas 266 a 270)

```sql
CREATE FUNCTION fn_cr_aluno(p_id_aluno INT)
RETURNS DECIMAL(4,2)
READS SQL DATA
BEGIN
    DECLARE v_cr DECIMAL(4,2);
```

| Linha | O que faz |
|-------|-----------|
| 266 a 268 | Recebe o `id_aluno` e devolve `DECIMAL(4,2)`. `READS SQL DATA`: consulta tabelas. |
| 270 | Variável `v_cr` para guardar o resultado. |

### Consulta e retorno (linhas 272 a 282)

```sql
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
```

| Linha | O que faz |
|-------|-----------|
| 272 e 273 | Soma de (média final × carga horária) dividida pela soma das cargas horárias, arredondada para 2 casas. `COALESCE(m.media_final, 0)` troca média NULL por 0 (caso da reprovação por falta sem nota). |
| 274 | `INTO v_cr` guarda o resultado na variável. |
| 275 a 277 | Liga matrícula, turma e disciplina, para chegar à carga horária de cada disciplina. |
| 278 e 279 | Só do aluno pedido e só das situações já concluídas. |
| 281 | Devolve o CR. Se não houver nenhuma linha, a soma é NULL e o CR é NULL. |
| 282 | `END$$`. |

**Exemplo real da massa de dados:** a aluna 1 concluiu Lógica (média 8,50, 80 h) e Banco de Dados (média 7,50, 60 h). POO está "Cursando" e fica de fora. CR = (8,50 × 80 + 7,50 × 60) / 140 = 1130 / 140 = 8,07.

### Volta do delimitador (linha 284)

```sql
DELIMITER ;
```

| Linha | O que faz |
|-------|-----------|
| 284 | `DELIMITER ;` devolve o terminador normal. Daqui em diante cada comando termina em `;` de novo. |

## Views

## vw_boletim (linhas 302 a 321)

> Resumo: uma linha por matrícula, com as colunas do enunciado (aluno, ra, disciplina, semestre, n1, n2, exame, media_final, faltas, situacao). Além do mínimo, tem `id_matricula` e `id_turma` (para a tela de notas saber qual matrícula está editando), `id_aluno` (filtro), `total_aulas` e `frequencia`.

### Colunas da matrícula e do aluno (linhas 302 a 308)

```sql
CREATE VIEW vw_boletim AS
SELECT m.id_matricula,
       m.id_turma,
       a.id_aluno,
       a.nome        AS aluno,
       a.ra,
       d.nome        AS disciplina,
```

| Linha | O que faz |
|-------|-----------|
| 302 | `CREATE VIEW vw_boletim AS` dá nome à consulta que vem a seguir. |
| 303 e 304 | Os ids da matrícula e da turma, que a tela de lançar notas usa. |
| 305 | `id_aluno`, para filtrar o boletim de um aluno. |
| 306 | O nome do aluno, com o apelido `aluno` (`AS aluno`). O apelido é o nome que a coluna terá no resultado. |
| 307 | O RA do aluno. |
| 308 | O nome da disciplina, com o apelido `disciplina` (as duas tabelas têm uma coluna `nome`, por isso o apelido). |

### Colunas de notas e frequência (linhas 309 a 317)

```sql
       t.semestre,
       m.n1,
       m.n2,
       m.exame,
       m.media_final,
       m.faltas,
       t.total_aulas,
       fn_frequencia_calc(m.faltas, t.total_aulas) AS frequencia,
       m.situacao
```

| Linha | O que faz |
|-------|-----------|
| 309 | Semestre da turma. |
| 310 a 314 | As notas (`n1`, `n2`, `exame`), a média final gravada e as faltas. |
| 315 | Total de aulas da turma. |
| 316 | Coluna **calculada**: chama `fn_frequencia_calc` com as faltas e o total de aulas da própria linha. Usamos a `_calc` e não a `fn_frequencia(id)` para não fazer um SELECT extra por linha. |
| 317 | A situação gravada na matrícula. |

### De onde vêm os dados (linhas 318 a 321)

```sql
  FROM matricula m
  JOIN aluno a      ON a.id_aluno = m.id_aluno
  JOIN turma t      ON t.id_turma = m.id_turma
  JOIN disciplina d ON d.id_disciplina = t.id_disciplina;
```

| Linha | O que faz |
|-------|-----------|
| 318 | A tabela principal é `matricula` (apelido `m`): uma linha da view por matrícula. |
| 319 a 321 | `JOIN` com aluno, turma e disciplina, ligando pelas chaves estrangeiras. Como toda matrícula tem aluno, turma e disciplina, o JOIN comum não perde nenhuma linha. |

**Uso:** `SELECT * FROM vw_boletim WHERE id_aluno = 1 ORDER BY semestre;` (boletim do aluno) e `SELECT * FROM vw_boletim WHERE id_turma = 3 ORDER BY aluno;` (diário da turma).

## vw_turmas_lotacao (linhas 332 a 346)

> Resumo: uma linha por turma (inclusive as sem ninguém matriculado): vagas, matriculados, vagas restantes e porcentagem de ocupação. Tem também `semestre` e `status` para a tela de matrícula listar só as turmas "Aberta".

### Colunas (linhas 332 a 341)

```sql
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
```

| Linha | O que faz |
|-------|-----------|
| 332 a 334 | Cria a view e traz o id da turma e o nome da disciplina (apelido `disciplina`). |
| 335 | O nome do professor, com apelido `professor`. |
| 336 e 337 | Semestre e status da turma. |
| 338 | Vagas totais da turma. |
| 339 | `COUNT(m.id_matricula)` conta quantas matrículas a turma tem. Contamos a coluna `id_matricula` e não "todas as linhas" porque, com o LEFT JOIN, uma turma vazia tem uma linha com `m.id_matricula` NULL, e o COUNT de uma coluna ignora NULL, dando 0 (o certo). Um contador de linhas daria 1. |
| 340 | Vagas restantes: vagas menos matriculados. |
| 341 | Porcentagem de ocupação: matriculados × 100 / vagas, com 2 casas. Não há divisão por zero porque o CHECK da tabela exige `vagas > 0`. |

### Junções e agrupamento (linhas 342 a 346)

```sql
  FROM turma t
  JOIN disciplina d     ON d.id_disciplina = t.id_disciplina
  JOIN professor p      ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre, t.status, t.vagas;
```

| Linha | O que faz |
|-------|-----------|
| 342 a 344 | Parte da `turma` e junta disciplina e professor (todas as turmas têm os dois). |
| 345 | `LEFT JOIN matricula`: mantém a turma mesmo sem matrículas. É isso que faz a turma vazia aparecer com 0 matriculados. |
| 346 | `GROUP BY`: agrupa por turma. Listamos também as colunas que não estão dentro de COUNT, porque o MySQL, no modo `ONLY_FULL_GROUP_BY` (o padrão), exige isso. |

**Exemplo da massa de dados:** turma 3 (POO) tem 4 vagas e 4 matriculados: vagas restantes 0 e ocupação 100,00. Turma 4 (Banco de Dados): 10 vagas, 9 matriculados, 1 restante, 90,00%.

## vw_desempenho_turma (linhas 358 a 377)

> Resumo: uma linha por turma, com média global, maior e menor nota (sobre a `media_final` de quem já tem média), % de aprovados e % de reprovados (por nota mais por falta). Os percentuais são sobre o **total de matriculados**, então aprovados mais reprovados só fecha 100% quando ninguém está "Cursando" nem "Em Exame". Por isso existe a coluna `perc_em_andamento`. Turma sem matrícula: contagens 0 e o resto NULL.

### Estatísticas de nota (linhas 358 a 366)

```sql
CREATE VIEW vw_desempenho_turma AS
SELECT t.id_turma,
       d.nome                        AS disciplina,
       p.nome                        AS professor,
       t.semestre,
       COUNT(m.id_matricula)         AS matriculados,
       ROUND(AVG(m.media_final), 2)  AS media_turma,
       MAX(m.media_final)            AS maior_nota,
       MIN(m.media_final)            AS menor_nota,
```

| Linha | O que faz |
|-------|-----------|
| 358 a 362 | Cria a view com id, disciplina, professor e semestre da turma. |
| 363 | Total de matriculados (conta a coluna da matrícula, igual à view anterior). |
| 364 | `AVG(m.media_final)`: média das médias da turma, com 2 casas. O AVG ignora NULL, então aluno sem média não puxa o resultado para baixo. |
| 365 e 366 | Maior e menor `media_final` da turma. |

### Percentuais (linhas 367 a 372)

```sql
       ROUND(COALESCE(SUM(m.situacao = 'Aprovado'), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_aprovados,
       ROUND(COALESCE(SUM(m.situacao IN ('Reprovado por Nota', 'Reprovado por Falta')), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_reprovados,
       ROUND(COALESCE(SUM(m.situacao IN ('Cursando', 'Em Exame')), 0) * 100
             / NULLIF(COUNT(m.id_matricula), 0), 2) AS perc_em_andamento
```

| Linha | O que faz |
|-------|-----------|
| 367 e 368 | Porcentagem de aprovados. `m.situacao = 'Aprovado'` vale 1 quando é verdade e 0 quando não é, então `SUM(...)` conta quantos são aprovados. O `COALESCE(..., 0)` troca NULL por 0 (turma sem matrícula). O `NULLIF(COUNT(...), 0)` troca o divisor 0 por NULL: dividir por NULL dá NULL em vez de dar erro de divisão por zero. |
| 369 e 370 | Mesma ideia para reprovados: `IN ('Reprovado por Nota', 'Reprovado por Falta')` junta os dois tipos. |
| 371 e 372 | Mesma ideia para quem ainda está em andamento (Cursando ou Em Exame). |

### De onde vêm os dados (linhas 373 a 377)

```sql
  FROM turma t
  JOIN disciplina d     ON d.id_disciplina = t.id_disciplina
  JOIN professor p      ON p.id_professor = t.id_professor
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.id_turma, d.nome, p.nome, t.semestre;
```

| Linha | O que faz |
|-------|-----------|
| 373 a 375 | Parte da turma e junta disciplina e professor. |
| 376 | `LEFT JOIN` com a matrícula, para a turma sem matrículas continuar aparecendo. |
| 377 | `GROUP BY` por turma (mais as colunas não agregadas). |

**Exemplo da massa de dados:** na turma 3 (POO), as médias existentes são 6,50 e 9,50, então `media_turma` = 8,00, `maior_nota` = 9,50 e `menor_nota` = 6,50. Há 4 matriculados: 1 reprovado por falta (25%) e 3 em andamento (75%). Aprovados: 0%. Repare que 0 + 25 + 75 fecha 100.

## vw_faturamento_curso (linhas 386 a 396)

> Resumo: faturamento mensal **previsto** por curso, para o relatório financeiro do Coordenador: número de alunos com status "Ativo" vezes a mensalidade. Trancados e formados não pagam, então não entram. Curso sem aluno ativo aparece com 0. É uma view além do mínimo do enunciado, e usa a coluna `valor_mensalidade` que o grupo acrescentou em `curso`.

### Colunas (linhas 386 a 392)

```sql
CREATE VIEW vw_faturamento_curso AS
SELECT c.id_curso,
       c.nome                                  AS curso,
       c.turno,
       c.valor_mensalidade,
       COUNT(a.id_aluno)                       AS alunos_ativos,
       COUNT(a.id_aluno) * c.valor_mensalidade AS faturamento_mensal
```

| Linha | O que faz |
|-------|-----------|
| 386 a 390 | Cria a view com id do curso, nome (apelido `curso`), turno e valor da mensalidade. |
| 391 | `COUNT(a.id_aluno)`: quantos alunos ativos o curso tem (conta só os que têm par no LEFT JOIN). |
| 392 | Faturamento = quantidade de alunos ativos × mensalidade. |

### Junção e agrupamento (linhas 393 a 396)

```sql
  FROM curso c
  LEFT JOIN aluno a ON a.id_curso = c.id_curso
                   AND a.status = 'Ativo'
 GROUP BY c.id_curso, c.nome, c.turno, c.valor_mensalidade;
```

| Linha | O que faz |
|-------|-----------|
| 393 | Parte de `curso`. |
| 394 e 395 | `LEFT JOIN aluno` com **duas condições no ON**: mesmo curso **e** status 'Ativo'. Por quê no ON e não num WHERE: um WHERE depois do LEFT JOIN eliminaria os cursos sem aluno ativo e eles sumiriam do relatório. No ON, o curso continua aparecendo, com 0. |
| 396 | `GROUP BY` por curso. |

**Exemplo:** Análise e Desenvolvimento de Sistemas: 9 alunos ativos × R$ 650,00 = R$ 5.850,00. Ciência da Computação: 7 × 1.200,00 = 8.400,00. Sistemas de Informação: 2 ativos (um está Trancado e um Formado) × 980,00 = 1.960,00.

## Triggers

### Troca do delimitador (linha 402)

```sql
DELIMITER $$
```

| Linha | O que faz |
|-------|-----------|
| 402 | De novo `DELIMITER $$`, porque os triggers também têm vários `;` dentro. |

## trg_valida_vagas (linhas 414 a 442)

> Resumo: trigger BEFORE INSERT, regra RN05. Bloqueia a matrícula quando a turma já está com todas as vagas ocupadas. Vale para qualquer INSERT, inclusive os da massa de dados e os feitos fora da `sp_matricular_aluno`. O `SELECT ... FOR UPDATE` trava a linha da turma até o fim da transação: duas matrículas simultâneas na última vaga entram em fila, e a segunda já enxerga a turma lotada.

### Cabeçalho e variáveis (linhas 414 a 420)

```sql
CREATE TRIGGER trg_valida_vagas
BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_vagas        INT;
    DECLARE v_matriculados INT;
    DECLARE v_msg          VARCHAR(128);
```

| Linha | O que faz |
|-------|-----------|
| 414 | Cria o trigger `trg_valida_vagas`. |
| 415 | `BEFORE INSERT ON matricula`: roda **antes** de cada nova matrícula ser gravada. É BEFORE porque ainda dá tempo de cancelar. |
| 416 | `FOR EACH ROW`: roda uma vez para cada linha inserida. |
| 417 | `BEGIN` abre o corpo. |
| 418 a 420 | Variáveis: vagas da turma, quantidade de matriculados e a mensagem de erro. |

### Ler e travar a turma (linhas 422 a 426)

```sql
    SELECT vagas
      INTO v_vagas
      FROM turma
     WHERE id_turma = NEW.id_turma
       FOR UPDATE;
```

| Linha | O que faz |
|-------|-----------|
| 422 a 425 | Busca o número de vagas da turma da nova matrícula. `NEW.id_turma` é a turma que está sendo inserida. |
| 426 | `FOR UPDATE` **trava a linha dessa turma** até a transação terminar. Quem tentar matricular em outra pessoa na mesma turma fica esperando. É o que impede a "corrida" pela última vaga. |

### Contar os matriculados (linhas 428 a 433)

```sql
    -- Turma inexistente: v_vagas fica NULL e quem recusa é a FK.
    IF v_vagas IS NOT NULL THEN
        SELECT COUNT(*)
          INTO v_matriculados
          FROM matricula
         WHERE id_turma = NEW.id_turma;
```

| Linha | O que faz |
|-------|-----------|
| 428 | Comentário: se a turma não existe, `v_vagas` fica NULL e quem recusa é a chave estrangeira. |
| 429 | Só continua se a turma existe (`v_vagas` não é NULL). |
| 430 a 433 | Conta quantas matrículas essa turma já tem. Como a turma está travada, ninguém consegue inserir enquanto contamos. |

### Recusar quando está cheia (linhas 435 a 442)

```sql
        IF v_matriculados >= v_vagas THEN
            SET v_msg = CONCAT('Turma lotada: a turma ', NEW.id_turma,
                               ' já tem ', v_matriculados, ' de ', v_vagas,
                               ' vagas ocupadas.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 435 | Se os matriculados já são **iguais ou mais** que as vagas, a turma está lotada. (Maior ou igual, e não só maior: com 4 de 4, o quinto não entra.) |
| 436 a 438 | Monta uma mensagem legível com `CONCAT`, por exemplo "Turma lotada: a turma 3 já tem 4 de 4 vagas ocupadas." |
| 439 | `SIGNAL SQLSTATE '45000'` lança o erro com essa mensagem. Como é um trigger BEFORE, o INSERT é cancelado e nada é gravado. |
| 440 a 442 | Fecha os dois IF e o corpo (`END$$`). |

## trg_situacao_inicial (linhas 453 a 468)

> Resumo: BEFORE INSERT, além do mínimo do enunciado. Calcula `media_final` e `situacao` também na inserção. Sem ele, uma matrícula inserida já com notas (a massa de dados do semestre encerrado, por exemplo) ficaria "Cursando" e sem média até o primeiro UPDATE. O que vier em `media_final` e `situacao` no INSERT é **substituído** pelo valor calculado. Usa `FOLLOWS`: roda depois do `trg_valida_vagas`.

### Cabeçalho (linhas 453 a 458)

```sql
CREATE TRIGGER trg_situacao_inicial
BEFORE INSERT ON matricula
FOR EACH ROW
FOLLOWS trg_valida_vagas
BEGIN
    DECLARE v_total_aulas INT;
```

| Linha | O que faz |
|-------|-----------|
| 453 a 455 | Trigger BEFORE INSERT na `matricula`, uma vez por linha. |
| 456 | `FOLLOWS trg_valida_vagas`: define a ordem. Primeiro confere as vagas e, só se passar, calcula a situação. Sem o FOLLOWS valeria a ordem de criação; com ele a ordem fica escrita e explícita. |
| 457 | `BEGIN`. |
| 458 | Variável para o total de aulas da turma. |

### Cálculo (linhas 460 a 468)

```sql
    SELECT total_aulas
      INTO v_total_aulas
      FROM turma
     WHERE id_turma = NEW.id_turma;

    SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
    SET NEW.situacao    = fn_situacao_calc(NEW.n1, NEW.n2, NEW.exame,
                                           NEW.faltas, v_total_aulas);
END$$
```

| Linha | O que faz |
|-------|-----------|
| 460 a 463 | Busca o `total_aulas` da turma da nova matrícula. Precisamos dele para calcular a frequência. |
| 465 | `SET NEW.media_final = ...`: o trigger **muda a linha antes de gravar**. Chama `fn_calcular_media` com as notas que chegaram no INSERT. |
| 466 e 467 | Faz o mesmo com `NEW.situacao`, usando `fn_situacao_calc` com notas, faltas e total de aulas. Aqui usamos a `_calc` (que recebe valores) porque a linha ainda não existe na tabela. |
| 468 | `END$$`. |

## trg_atualiza_situacao (linhas 483 a 504)

> Resumo: BEFORE UPDATE, RN01 a RN04. Recalcula `media_final` e `situacao` sempre que `n1`, `n2`, `exame`, `faltas` ou a turma mudam. Quem lança nota só dá UPDATE nas notas, e a média e a situação saem daqui. Usa `NEW` com as functions auxiliares, porque dentro de um BEFORE UPDATE a `fn_situacao(id)` ainda leria os valores antigos da tabela. Se o UPDATE não mexe em nota, falta nem turma, o trigger não recalcula. Isso deixa a `sp_fechar_semestre` gravar uma situação de fechamento.

### Cabeçalho (linhas 483 a 487)

```sql
CREATE TRIGGER trg_atualiza_situacao
BEFORE UPDATE ON matricula
FOR EACH ROW
BEGIN
    DECLARE v_total_aulas INT;
```

| Linha | O que faz |
|-------|-----------|
| 483 a 485 | Trigger BEFORE UPDATE na `matricula`, uma vez por linha atualizada. |
| 486 | `BEGIN`. |
| 487 | Variável para o total de aulas. |

### A condição: algo importante mudou? (linhas 489 a 493)

```sql
    IF NOT (OLD.n1 <=> NEW.n1)
       OR NOT (OLD.n2 <=> NEW.n2)
       OR NOT (OLD.exame <=> NEW.exame)
       OR NOT (OLD.faltas <=> NEW.faltas)
       OR NOT (OLD.id_turma <=> NEW.id_turma) THEN
```

| Linha | O que faz |
|-------|-----------|
| 489 a 493 | Pergunta, campo a campo, se **mudou** `n1`, `n2`, `exame`, `faltas` ou `id_turma`. Cada pergunta é `NOT (OLD.campo <=> NEW.campo)`: "o valor antigo NÃO é igual ao novo". O `<=>` é necessário porque as notas podem ser NULL, e com `<>` comum a conta NULL contra um número daria NULL (tratado como falso) e o primeiro lançamento de nota passaria despercebido. Os `OR` fazem o IF valer se **qualquer um** dos campos mudou. |

### Recalcular (linhas 495 a 504)

```sql
        SELECT total_aulas
          INTO v_total_aulas
          FROM turma
         WHERE id_turma = NEW.id_turma;

        SET NEW.media_final = fn_calcular_media(NEW.n1, NEW.n2, NEW.exame);
        SET NEW.situacao    = fn_situacao_calc(NEW.n1, NEW.n2, NEW.exame,
                                               NEW.faltas, v_total_aulas);
    END IF;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 495 a 498 | Busca o total de aulas da turma (a nova, se a matrícula mudou de turma). |
| 500 | Grava em `NEW.media_final` a média recalculada com os valores novos. |
| 501 e 502 | Grava em `NEW.situacao` a situação recalculada. Como é BEFORE, os dois valores vão para a tabela **na mesma operação**, sem UPDATE extra. |
| 503 | Fecha o IF. Se nada importante mudou, o trigger não faz nada, e a linha vai como veio. |
| 504 | `END$$`. |

**Por que não recalcular sempre:** a `sp_fechar_semestre` faz `UPDATE matricula SET situacao = 'Reprovado por Nota'` para quem ficou "Em Exame" e não fez a prova. Se o trigger recalculasse sempre, ele desfaria isso e voltaria para "Em Exame".

## trg_auditoria_nota (linhas 515 a 538)

> Resumo: AFTER UPDATE, RN08. Grava em `log_nota` uma linha por campo alterado: `n1`, `n2`, `exame` e `faltas` (as faltas entram porque também mudam a situação). O usuário vem de `NEW.id_usuario`: quem altera nota precisa gravar o próprio id na matrícula, no mesmo UPDATE. O `<=>` trata NULL: de NULL para 7,5 conta como alteração e de NULL para NULL não.

### Cabeçalho (linhas 515 a 518)

```sql
CREATE TRIGGER trg_auditoria_nota
AFTER UPDATE ON matricula
FOR EACH ROW
BEGIN
```

| Linha | O que faz |
|-------|-----------|
| 515 a 517 | Trigger AFTER UPDATE na `matricula`. É AFTER porque só faz sentido registrar a mudança **depois** que ela foi gravada, e porque ele não precisa alterar a linha. |
| 518 | `BEGIN`. |

### Auditoria de n1 e n2 (linhas 519 a 527)

```sql
    IF NOT (OLD.n1 <=> NEW.n1) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'n1', OLD.n1, NEW.n1, NEW.id_usuario);
    END IF;

    IF NOT (OLD.n2 <=> NEW.n2) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'n2', OLD.n2, NEW.n2, NEW.id_usuario);
    END IF;
```

| Linha | O que faz |
|-------|-----------|
| 519 | Se `n1` mudou (`NOT (OLD.n1 <=> NEW.n1)`)... |
| 520 e 521 | ...insere uma linha em `log_nota`: qual matrícula, qual campo (o texto `'n1'`), valor antigo (`OLD.n1`), valor novo (`NEW.n1`) e o usuário (`NEW.id_usuario`). A data e a hora são preenchidas sozinhas pela tabela (`DEFAULT CURRENT_TIMESTAMP`). |
| 522 | Fecha o IF. |
| 524 a 527 | Exatamente a mesma coisa para `n2`. |

### Auditoria de exame, faltas e fim (linhas 529 a 538)

```sql
    IF NOT (OLD.exame <=> NEW.exame) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'exame', OLD.exame, NEW.exame, NEW.id_usuario);
    END IF;

    IF NOT (OLD.faltas <=> NEW.faltas) THEN
        INSERT INTO log_nota (id_matricula, campo, valor_antigo, valor_novo, usuario)
        VALUES (NEW.id_matricula, 'faltas', OLD.faltas, NEW.faltas, NEW.id_usuario);
    END IF;
END$$
```

| Linha | O que faz |
|-------|-----------|
| 529 a 532 | Mesma coisa para `exame`. |
| 534 a 537 | Mesma coisa para `faltas`. A coluna `log_nota.valor_antigo` é `DECIMAL(6,2)` justamente para caber faltas também (por exemplo 30,00). |
| 538 | `END$$`. |

Se uma única UPDATE mexer em n1 e n2, são **duas linhas** no log (uma por campo). Se mexer em algo que não é nota, nenhuma linha é gravada.

### Fim do arquivo (linha 540)

```sql
DELIMITER ;
```

| Linha | O que faz |
|-------|-----------|
| 540 | `DELIMITER ;` devolve o terminador normal. Acabou o arquivo. |

# 4. Como as peças se encaixam

Pense no sistema como uma fábrica com quatro setores. O seu setor (functions, views e triggers) fica **no meio**: recebe o que o setor do Mykael grava e entrega o que as telas mostram.

```
 Telas (Leo / Guilherme)        so chamam procedures e consultam views
        |                                          ^
        | CALL sp_...                              | SELECT
        v                                          |
 Procedures do MYKAEL                       VIEWS do DIEGO
 (matricular, lancar notas,                 (vw_boletim, vw_turmas_lotacao,
  lancar exame, fechar semestre)             vw_desempenho_turma,
        |                                     vw_faturamento_curso)
        | INSERT / UPDATE                           ^
        v                                           | leem
 Tabela matricula (do GUILHERME) -------------------+
        |
        | dispara sozinho
        v
 TRIGGERS do DIEGO (4)                      Tabela log_nota
  trg_valida_vagas       BEFORE INSERT      (auditoria)
  trg_situacao_inicial   BEFORE INSERT             ^
  trg_atualiza_situacao  BEFORE UPDATE             |
  trg_auditoria_nota     AFTER  UPDATE  ------ grava
        |
        | chamam
        v
 FUNCTIONS do DIEGO
  fn_calcular_media, fn_frequencia_calc, fn_situacao_calc
  (as views tambem usam fn_frequencia_calc)
```

Em palavras:

- **Guilherme** criou as tabelas e os CHECKs (`01_ddl.sql`) e a massa de dados (`03_dados.sql`). Os seus triggers e views trabalham em cima dessas tabelas. Cada INSERT da massa de dados dispara os seus triggers, e é por isso que as 35 matrículas já nascem com média e situação certas.
- **Mykael** escreveu as procedures. Elas só gravam `n1`, `n2`, `exame`, `faltas` e o `id_usuario` na matrícula. Quem calcula média e situação são os **seus** triggers. A `sp_matricular_aluno` conta com o seu `trg_valida_vagas` para barrar turma lotada. A `sp_fechar_semestre` conta com o fato de o seu `trg_atualiza_situacao` **não** recalcular quando só a situação muda. A `sp_historico_aluno` lê a sua `vw_boletim`.
- **Leo e Guilherme** (telas): o boletim e o diário de notas lêem `vw_boletim`; a consulta de turmas e a matrícula usam `vw_turmas_lotacao`; os relatórios do Coordenador usam `vw_desempenho_turma` e `vw_faturamento_curso`. A tela mostra a mensagem de erro que o banco devolve (por exemplo "Turma lotada...").
- **O combinado entre vocês:** quem grava nota não grava `media_final` nem `situacao` (o trigger sobrescreve). E quem altera nota grava o próprio `id_usuario` no mesmo UPDATE, para a auditoria saber quem foi.

# 5. Perguntas que o professor pode fazer (com respostas)

**1. Por que a regra de vagas é um trigger e não está só dentro da procedure de matrícula?**

Porque o trigger vale para **qualquer** INSERT na tabela `matricula`, venha de onde vier: da procedure, da massa de dados, de um script ou de alguém digitando no Workbench. Se a regra estivesse só na procedure, um INSERT direto passaria por cima dela. A procedure do Mykael ainda confere várias coisas antes (para dar mensagens mais específicas), mas a garantia final de que a turma não passa das vagas é do trigger.

**2. O que acontece se duas pessoas tentarem se matricular na última vaga ao mesmo tempo?**

O `SELECT vagas ... FOR UPDATE` do `trg_valida_vagas` trava a linha da turma. A primeira sessão trava, conta, insere e termina a transação. A segunda fica **esperando** na trava. Quando a primeira termina, a segunda destrava, conta de novo, já enxerga a turma cheia e recebe "Turma lotada". Dá para mostrar isso ao vivo com duas abas do Workbench (passo 8 do guia): a segunda aba espera e depois recebe "Turma lotada: a turma 4 já tem 10 de 10 vagas ocupadas." Sem o FOR UPDATE, as duas contariam 9, as duas achariam que cabe e a turma ficaria com 11.

**3. Qual a diferença entre BEFORE e AFTER? Por que escolheu cada um?**

`BEFORE` roda antes de gravar: dá para cancelar (SIGNAL) e dá para mudar a linha (`SET NEW.situacao = ...`). Por isso o de vagas e os dois de cálculo são BEFORE. `AFTER` roda depois de gravar e não pode mudar a linha: serve para registrar. Por isso a auditoria é AFTER: só registra a mudança depois que ela aconteceu. Além disso, em InnoDB, se o UPDATE falhar (por exemplo por um CHECK), o comando inteiro é desfeito, inclusive o que o trigger gravou no log.

**4. O que são NEW e OLD?**

São as duas versões da linha dentro do trigger. `OLD` é a linha antes da alteração e `NEW` é a linha como vai ficar. No INSERT só existe `NEW`. No UPDATE existem os dois. Na auditoria comparo `OLD.n1` com `NEW.n1` para saber se a nota mudou e gravo os dois valores no log.

**5. Por que existem duas functions, `fn_situacao` e `fn_situacao_calc`? Não era mais simples uma só?**

Tentei uma só, e não funciona dentro do trigger. A `fn_situacao(id)` faz um SELECT na tabela. Dentro de um `BEFORE UPDATE`, a tabela ainda tem os valores **antigos**, então a situação sairia sempre um lançamento atrasada. A solução foi separar: `fn_situacao_calc` recebe os valores como parâmetro (o trigger passa os `NEW`) e tem toda a regra. A `fn_situacao(id)` só busca a linha e chama a `_calc`. A regra continua escrita em um lugar só. O mesmo vale para `fn_frequencia` e `fn_frequencia_calc`.

**6. Para que serve o operador `<=>`? Por que não usar `<>`?**

As notas começam NULL. Em SQL, comparar qualquer coisa com NULL usando `=` ou `<>` dá NULL, que o IF trata como falso. Então `OLD.n1 <> NEW.n1`, quando `OLD.n1` é NULL e `NEW.n1` é 7,5, não diria "mudou", e o primeiro lançamento de nota não seria auditado. O `<=>` trata NULL como um valor comum: `NULL <=> NULL` é verdadeiro e `NULL <=> 7.5` é falso.

**7. Por que arredonda a média antes de comparar com 7, 4 e 5?**

Porque (N1 + N2) / 2 pode ter 3 casas decimais e a coluna `media_final` guarda 2. Com N1 = 6,99 e N2 = 7,00 a conta dá 6,995. A coluna grava 7,00. Se eu comparasse 6,995 com 7, o aluno ficaria "Em Exame" com média 7,00 na tela, o que é incoerente. Arredondando primeiro, a situação sempre combina com a média que o boletim mostra.

**8. E por que a frequência é truncada e não arredondada?**

É o problema inverso. Se arredondasse, 74,996% viraria 75,00% e um aluno reprovado por falta apareceria no boletim com exatamente o mínimo. Truncando, 74,996% aparece como 74,99%, que é menor que 75. Na média, arredondar favorece a coerência; na frequência, truncar evita um falso "passou".

**9. Um aluno com média 9,0 e 70% de presença passa ou reprova?**

Reprova, com a situação "Reprovado por Falta". A RN04 diz que a frequência abaixo de 75% reprova independentemente das notas, e na `fn_situacao_calc` essa é a primeira checagem, antes de olhar nota. Na massa de dados, a matrícula 19 (9,5 e 9,5 com 25 faltas em 80 aulas, presença 68,75%) é exatamente esse caso.

**10. O exame vale para todos os alunos?**

Não. Só entra na média quem tem parcial de 4,00 a 6,99. Quem tem 7 ou mais já passou, e quem tem menos de 4 já reprovou. Se alguém digitar um exame para um aluno que já está aprovado, a `fn_calcular_media` ignora o exame. Sem isso, um aluno com 8,50 que levasse um exame 2,0 ficaria com média 5,25 e a situação "Aprovado", duas informações incoerentes.

**11. O que é uma view? Ela guarda os dados? Ela deixa a consulta mais rápida?**

A view é um SELECT guardado com um nome. Não guarda dados: a cada consulta o banco refaz o SELECT e mostra os dados atuais. Por isso nunca fica desatualizada. Ela **não** é mais rápida por si só (não é cache). As vantagens são: reutilizar a consulta, esconder joins complicados, e a interface só precisar de `SELECT * FROM vw_...`. No nosso projeto o Java acessa o banco só por procedures e views.

**12. Por que `LEFT JOIN` na `vw_turmas_lotacao`? E por que `COUNT(m.id_matricula)` e não contar todas as linhas?**

Com `JOIN` comum, uma turma sem nenhum matriculado sumiria da lista, mas a tela de matrícula precisa mostrá-la com todas as vagas livres. O `LEFT JOIN` mantém a turma. Quando não há matrícula, as colunas dela vêm NULL, e o `COUNT(m.id_matricula)` ignora NULL e dá 0. Se eu contasse as linhas, a turma vazia daria 1, errado.

**13. O `trg_atualiza_situacao` não recalcula sempre? Por quê?**

Só recalcula se mudou nota, exame, faltas ou turma. Isso é de propósito: a `sp_fechar_semestre` precisa gravar uma situação de fechamento (um "Em Exame" sem prova vira "Reprovado por Nota") dando UPDATE só na situação. Se o trigger recalculasse sempre, voltaria para "Em Exame". Consequência honesta: quem der UPDATE direto só na coluna `situacao` consegue gravar o valor que quiser (desde que passe no CHECK que só aceita as 5 grafias válidas). Num sistema real isso seria restrito por permissões do usuário do banco.

**14. Como a auditoria sabe quem alterou a nota?**

O MySQL só sabe quem é o usuário do **banco** (o da conexão), não o usuário do SGA. Por isso o combinado do grupo é que quem altera a nota grave o próprio `id_usuario` na matrícula, no mesmo UPDATE, e o trigger lê `NEW.id_usuario`. As procedures `sp_lancar_notas` e `sp_lancar_exame` fazem isso. **Limitação:** se alguém der UPDATE direto em uma nota sem informar o `id_usuario`, o log fica com o id que já estava lá, ou seja, o de quem fez a última operação. Dá para ver isso no passo 6 do guia, na última UPDATE de faltas.

**15. Qual a diferença entre function e procedure? Por que isso aqui são functions?**

A function devolve **um valor** e pode ser usada dentro de uma expressão, como em `SELECT fn_situacao(17)` ou dentro de uma view. A procedure é chamada com `CALL`, pode gravar dados, devolver tabelas de resultado e tratar transações. Cálculo de média, frequência e situação são contas que devolvem um valor e que eu preciso usar dentro de views e triggers, então são functions.

**16. O que significam `DETERMINISTIC`, `NO SQL` e `READS SQL DATA`?**

São declarações do comportamento da function. `DETERMINISTIC`: as mesmas entradas dão sempre a mesma saída (a `fn_calcular_media` é assim). `NO SQL`: não executa nenhum comando SQL, só contas. `READS SQL DATA`: consulta tabelas mas não grava (`fn_situacao`, `fn_frequencia`, `fn_cr_aluno`). O MySQL pede que se declare uma delas; se o servidor tiver o log binário ligado, a declaração é exigida.

**17. (Armadilha) `media_final` e `situacao` podem ser calculadas. Guardar isso na tabela não fere a 3ª forma normal?**

Em rigor, sim: são dados derivados de outros e isso é uma dependência transitiva. O relatório do grupo assume isso abertamente como **redundância deliberada**, por três motivos: boletim, histórico e relatórios usam esses valores o tempo todo; a regra de pré-requisito (RN06) precisa achar a situação "Aprovado" de disciplinas antigas, e gravar evita recalcular; e a consistência não depende de ninguém lembrar de atualizar, porque os triggers recalculam a cada INSERT e UPDATE sempre pelas mesmas functions. A redundância é controlada, então não gera anomalia de atualização.

**18. (Armadilha) O que acontece se a turma da matrícula não existir? O trigger não daria erro?**

O trigger não reclama: o `SELECT` não acha a linha, `v_vagas` fica NULL e o IF da linha 429 pula a checagem. Quem recusa é a chave estrangeira `fk_matricula_turma`, que não aceita `id_turma` inexistente. Cada camada cuida do que é dela.

**19. (Armadilha) Por que o erro é `SQLSTATE '45000'`?**

É o código padrão do SQL para "exceção definida pelo usuário". Usamos o mesmo em todo o projeto (combinado do grupo) e sempre com um `MESSAGE_TEXT` legível, porque a interface mostra só essa mensagem para o usuário.

# 6. Passo a passo para mostrar funcionando

Antes de começar, rode o `SGA_completo.sql` no MySQL Workbench (ele recria o banco do zero com tudo e a massa de dados) e execute `USE sga_fbi;`.

**Dicas para o Workbench:** selecione **uma linha ou um bloco** e use Ctrl+Enter para rodar só o que está selecionado. Quando um comando deve dar erro, rode **sozinho**, porque o erro interrompe um script inteiro. Se der erro dentro de um `START TRANSACTION`, rode `ROLLBACK;` antes de continuar. Os números de `id_log` e `id_matricula` novos podem ser diferentes dos que aparecem aqui; o resto deve ser igual.

Todos os resultados abaixo foram conferidos em um MySQL 8.0 temporário carregado com o `SGA_completo.sql`.

## Passo 1: functions de média e frequência

```sql
USE sga_fbi;

SELECT fn_calcular_media(8, 9, NULL) AS a,     -- 8.50
       fn_calcular_media(5, 6, NULL) AS b,     -- 5.50
       fn_calcular_media(5, 6, 7)    AS c,     -- 6.25
       fn_calcular_media(8, 9, 2)    AS d,     -- 8.50 (exame ignorado)
       fn_calcular_media(6.99, 7.00, NULL) AS e, -- 7.00 (arredondou antes)
       fn_calcular_media(8, NULL, NULL)    AS f; -- NULL
```

Esperado: 8.50, 5.50, 6.25, 8.50, 7.00 e NULL.

```sql
SELECT fn_frequencia(17) AS aluno1_poo,        -- 97.50
       fn_frequencia(9999) AS inexistente,     -- NULL
       fn_frequencia_calc(25, 80) AS f25,      -- 68.75
       fn_frequencia_calc(20, 80) AS f20,      -- 75.00
       fn_frequencia_calc(21, 80) AS f21;      -- 73.75
```

Esperado: 97.50, NULL, 68.75, 75.00 e 73.75.

## Passo 2: function de situação

```sql
SELECT fn_situacao(1)  AS m1,   -- Aprovado
       fn_situacao(17) AS m17,  -- Cursando (falta N2)
       fn_situacao(18) AS m18,  -- Em Exame
       fn_situacao(19) AS m19,  -- Reprovado por Falta (media 9,5 mas 68,75% de presenca)
       fn_situacao(7)  AS m7,   -- Reprovado por Nota
       fn_situacao(9999) AS inexistente; -- NULL
```

Esperado, nessa ordem: Aprovado, Cursando, Em Exame, Reprovado por Falta, Reprovado por Nota e NULL.

```sql
SELECT fn_situacao_calc(5, 6, 4.5, 0, 80) AS no_limite,   -- Aprovado (media final 5.00)
       fn_situacao_calc(5, 6, 3,   0, 80) AS abaixo,      -- Reprovado por Nota (4.25)
       fn_situacao_calc(9, 9, NULL, 21, 80) AS falta;     -- Reprovado por Falta
```

Esperado: Aprovado, Reprovado por Nota, Reprovado por Falta.

```sql
SELECT fn_cr_aluno(1) AS cr_aluno1,   -- 8.07
       fn_cr_aluno(9) AS cr_aluno9;   -- NULL (ainda nao concluiu nada)
```

## Passo 3: as quatro views

```sql
SELECT * FROM vw_boletim WHERE id_aluno = 3 ORDER BY semestre;
```

Esperado: 3 linhas da Camila Rezende: Lógica (2026.1, média 8.75, 97.50%, Aprovado), POO (2026.2, média 9.50, frequência 68.75, **Reprovado por Falta**) e Banco de Dados (2026.2, N2 NULL, Cursando).

```sql
SELECT * FROM vw_turmas_lotacao WHERE status = 'Aberta';
```

Esperado: turma 3 (4 vagas, 4 matriculados, 0 restantes, 100.00), turma 4 (10, 9, 1, 90.00) e turma 5 (8, 6, 2, 75.00).

```sql
SELECT id_turma, disciplina, matriculados, media_turma, maior_nota, menor_nota,
       perc_aprovados, perc_reprovados, perc_em_andamento
  FROM vw_desempenho_turma ORDER BY id_turma;
```

Esperado: 5 linhas. A turma 1 (Lógica) tem média 6.56, 62.50% aprovados e 37.50% reprovados. A turma 3 mostra 0.00 aprovados, 25.00 reprovados e 75.00 em andamento.

```sql
SELECT * FROM vw_faturamento_curso;
```

Esperado: Análise e Desenvolvimento de Sistemas, 9 ativos, 5850.00; Ciência da Computação, 7 ativos, 8400.00; Sistemas de Informação, 2 ativos, 1960.00.

## Passo 4: trigger de vagas (erro de propósito)

A turma 3 tem 4 vagas e 4 matriculados. Aluno 5 está Ativo e não está na turma. Rode **sozinho**:

```sql
INSERT INTO matricula (id_aluno, id_turma, id_usuario) VALUES (5, 3, 3);
```

Esperado, no Workbench: **Error Code: 1644. Turma lotada: a turma 3 já tem 4 de 4 vagas ocupadas.** Nada é gravado. Confira: `SELECT COUNT(*) FROM matricula WHERE id_turma = 3;` continua 4.

## Passo 5: trigger que calcula já na inserção

A turma 4 tem 1 vaga sobrando. O aluno 10 está Ativo e ainda não está nela. Rode um por vez:

```sql
START TRANSACTION;

INSERT INTO matricula (id_aluno, id_turma, n1, n2, faltas, id_usuario)
VALUES (10, 4, 6, 7, 0, 3);

SELECT id_matricula, n1, n2, media_final, situacao
  FROM matricula WHERE id_aluno = 10 AND id_turma = 4;
```

Esperado: n1 6.00, n2 7.00, **media_final 6.50** e **situacao Em Exame**. Eu não informei média nem situação: o `trg_situacao_inicial` calculou.

Agora a turma 4 está cheia (10 de 10). Tente matricular o aluno 11:

```sql
INSERT INTO matricula (id_aluno, id_turma, id_usuario) VALUES (11, 4, 3);
```

Esperado: **Error Code: 1644. Turma lotada: a turma 4 já tem 10 de 10 vagas ocupadas.** Depois desfaça tudo:

```sql
ROLLBACK;
```

## Passo 6: triggers de cálculo e de auditoria

A matrícula 20 (aluno 4, turma 3) não tem nenhuma nota. Rode em sequência:

```sql
START TRANSACTION;

UPDATE matricula
   SET n1 = 7, n2 = 8, faltas = 0, id_usuario = 1
 WHERE id_matricula = 20;

SELECT n1, n2, media_final, faltas, situacao FROM matricula WHERE id_matricula = 20;
SELECT campo, valor_antigo, valor_novo, usuario FROM log_nota WHERE id_matricula = 20;
```

Esperado na primeira consulta: 7.00, 8.00, **7.50**, 0, **Aprovado**. Na segunda, **duas linhas** (n1 NULL para 7.00 e n2 NULL para 8.00, usuário 1). As faltas não mudaram (0 para 0), então não geram linha.

Agora mude para a faixa de exame e coloque um exame, ainda na mesma transação:

```sql
UPDATE matricula SET n1 = 5, n2 = 6, id_usuario = 2 WHERE id_matricula = 20;
SELECT media_final, situacao FROM matricula WHERE id_matricula = 20;   -- 5.50 Em Exame

UPDATE matricula SET exame = 3, id_usuario = 2 WHERE id_matricula = 20;
SELECT media_final, situacao FROM matricula WHERE id_matricula = 20;   -- 4.25 Reprovado por Nota

UPDATE matricula SET faltas = 30 WHERE id_matricula = 20;
SELECT media_final, situacao FROM matricula WHERE id_matricula = 20;   -- 4.25 Reprovado por Falta

SELECT campo, valor_antigo, valor_novo, usuario FROM log_nota
 WHERE id_matricula = 20 ORDER BY id_log;
```

Esperado: 5.50 Em Exame; 4.25 Reprovado por Nota; 4.25 Reprovado por Falta (30 faltas em 80 aulas dá 62,50% de presença). O log deve ter 6 linhas: n1, n2 (usuário 1), n1, n2, exame (usuário 2) e faltas (30,00, também com usuário 2, porque esse último UPDATE não informou `id_usuario`; é a limitação que está na pergunta 14). Para terminar:

```sql
ROLLBACK;
SELECT COUNT(*) FROM log_nota WHERE id_matricula = 20;   -- 0 de novo
```

## Passo 7: nota inválida e trigger que não recalcula

Rode sozinho (a nota 11 é barrada pela constraint, que é do Guilherme):

```sql
UPDATE matricula SET n1 = 11 WHERE id_matricula = 20;
```

Esperado: **Error Code: 3819. Check constraint 'ck_matricula_n1' is violated.** O log não ganha linha, porque o comando inteiro foi desfeito.

Para mostrar que um UPDATE só na situação não é recalculado (é o que a `sp_fechar_semestre` usa):

```sql
START TRANSACTION;
UPDATE matricula SET situacao = 'Reprovado por Nota' WHERE id_matricula = 18;
SELECT media_final, situacao FROM matricula WHERE id_matricula = 18;  -- 6.50 Reprovado por Nota
UPDATE matricula SET faltas = 6 WHERE id_matricula = 18;
SELECT media_final, situacao FROM matricula WHERE id_matricula = 18;  -- recalculou: Em Exame
ROLLBACK;
```

Esperado: no primeiro SELECT a situação fica "Reprovado por Nota" (o trigger não mexeu). No segundo, como as faltas mudaram de 5 para 6, o trigger recalcula e a situação volta a ser "Em Exame".

## Passo 8 (opcional, mais impressionante): duas pessoas na última vaga

Abra **duas abas** de consulta no Workbench (duas conexões). Na **aba 1**:

```sql
START TRANSACTION;
INSERT INTO matricula (id_aluno, id_turma, id_usuario) VALUES (10, 4, 3);
-- NAO rode COMMIT ainda
```

Na **aba 2**, enquanto a aba 1 está aberta:

```sql
INSERT INTO matricula (id_aluno, id_turma, id_usuario) VALUES (11, 4, 3);
```

A aba 2 **fica esperando** (o relógio do Workbench não termina). Volte à aba 1 e rode `COMMIT;`. A aba 2 então responde: **Error Code: 1644. Turma lotada: a turma 4 já tem 10 de 10 vagas ocupadas.** Isso é o `FOR UPDATE` funcionando. Para voltar ao estado original, na aba 1 rode:

```sql
DELETE FROM matricula WHERE id_aluno = 10 AND id_turma = 4;
```

Se o Workbench reclamar do "safe update mode", desligue em Edit, Preferences, SQL Editor, "Safe Updates". Esse teste das duas conexões foi conferido com dois clientes `mysql` em paralelo (a segunda esperou o COMMIT da primeira e recebeu a mensagem acima). Se a aba 2 demorar mais de 50 segundos, o MySQL desiste com um erro de "Lock wait timeout"; é só repetir mais rápido.

# 7. Se você só tem 5 minutos antes de apresentar

1. "Eu fiz 6 functions, 4 views e 4 triggers: a parte do banco que calcula e vigia sozinha."
2. "Quem lança nota só grava N1, N2, exame e faltas; média e situação saem do trigger, sempre pela mesma regra."
3. "Média parcial é (N1 + N2) / 2; o exame só entra para quem está de 4,00 a 6,99; aprovado com final de 5 ou mais."
4. "Frequência abaixo de 75% reprova por falta, mesmo com média 9, e essa é a primeira checagem."
5. "Arredondo a média antes de comparar para a situação bater com o que aparece no boletim; na frequência eu trunco para 74,996 não virar 75."
6. "Trigger BEFORE roda antes de gravar e pode cancelar ou mudar a linha; AFTER roda depois e serve para registrar."
7. "NEW é a linha como vai ficar e OLD é como era; uso o operador de igualdade segura, o `<=>`, porque as notas podem ser NULL."
8. "Separei a regra em functions `_calc` que recebem valores, porque dentro do BEFORE UPDATE a tabela ainda tem o valor antigo."
9. "O `SELECT ... FOR UPDATE` trava a turma, então duas matrículas na última vaga entram em fila e a segunda recebe Turma lotada."
10. "View é um SELECT guardado com nome, não guarda dados; a interface só consulta views e chama procedures."
