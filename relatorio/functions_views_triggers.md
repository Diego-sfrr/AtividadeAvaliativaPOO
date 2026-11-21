# Functions, Views e Triggers do SGA

Responsável: Diego. Base para a seção "Explicação detalhada das procedures, views, functions, triggers" do relatório e para a seção "Principais Dificuldades Encontradas e Soluções". O script que implementa tudo isto é o [`database/02a_functions_views_triggers.sql`](../database/02a_functions_views_triggers.sql).

## Visão geral

As regras de negócio acadêmicas ficam dentro do banco. A interface e as procedures não calculam média nem situação: gravam as notas e as faltas, e o banco devolve o resto.

| Objeto | Tipo | Regra / requisito | Para que serve |
|--------|------|-------------------|----------------|
| `fn_calcular_media` | Function | RN01, RN03 | Média parcial e média final |
| `fn_frequencia` | Function | fórmula do enunciado | % de presença de uma matrícula |
| `fn_situacao` | Function | RN02, RN03, RN04 | Situação de uma matrícula |
| `fn_cr_aluno` | Function (opcional) | ponto extra | Coeficiente de Rendimento ponderado |
| `fn_frequencia_calc` | Function auxiliar | fórmula do enunciado | Mesma conta da `fn_frequencia`, recebendo os valores |
| `fn_situacao_calc` | Function auxiliar | RN02, RN03, RN04 | Mesma regra da `fn_situacao`, recebendo os valores |
| `vw_boletim` | View | enunciado | Boletim e tela de lançamento de notas |
| `vw_turmas_lotacao` | View | enunciado | Consulta de turmas e vagas |
| `vw_desempenho_turma` | View | enunciado | Relatório de desempenho do Coordenador |
| `vw_faturamento_curso` | View (além do mínimo) | perfil Coordenador | Relatório de faturamento por curso |
| `trg_valida_vagas` | Trigger BEFORE INSERT | RN05 | Bloqueia matrícula em turma lotada |
| `trg_situacao_inicial` | Trigger BEFORE INSERT (além do mínimo) | RN01 a RN04 | Média e situação já na inserção |
| `trg_atualiza_situacao` | Trigger BEFORE UPDATE | RN01 a RN04 | Recalcula média e situação |
| `trg_auditoria_nota` | Trigger AFTER UPDATE | RN08 | Grava a auditoria em `log_nota` |

Quem depende de quem:

```
fn_calcular_media ──┐
                    ├─> fn_situacao_calc ─┬─> fn_situacao
fn_frequencia_calc ─┤                     ├─> trg_situacao_inicial
        │           │                     └─> trg_atualiza_situacao
        ├─> fn_frequencia
        └─> vw_boletim
```

Por isso a ordem dentro do arquivo é functions → views → triggers.

## Functions

### `fn_calcular_media(p_n1, p_n2, p_exame)` → `DECIMAL(4,2)`

Implementa a RN01 (média parcial = (N1 + N2) / 2) e a RN03 (média final = (média parcial + exame) / 2).

| Entrada | Resultado |
|---------|-----------|
| Falta N1 ou N2 | `NULL` (ainda não existe média) |
| Parcial fora da faixa de exame | A própria média parcial |
| Parcial na faixa de exame, sem exame | A média parcial (por enquanto) |
| Parcial na faixa de exame, com exame | (parcial + exame) / 2 |

Exemplos: `(8, 9, NULL)` = 8,50; `(5, 6, NULL)` = 5,50; `(5, 6, 7)` = 6,25; `(8, 9, 2)` = 8,50.

O exame só entra na conta de quem está na faixa de exame (parcial de 4,00 a 6,99). Sem isso, um aluno aprovado direto com 8,50 que recebesse por engano um exame 2,0 ficaria com média 5,25 e situação "Aprovado", duas informações que não combinam.

### `fn_frequencia(p_id_matricula)` → `DECIMAL(5,2)`

Devolve a porcentagem de presença: (total_aulas − faltas) / total_aulas × 100. O `total_aulas` vem da turma e as `faltas`, da matrícula. Matrícula inexistente devolve `NULL`.

O resultado é **truncado** em duas casas, não arredondado. Com arredondamento, 74,996% apareceria como 75,00% no boletim de um aluno reprovado por falta.

### `fn_situacao(p_id_matricula)` → `VARCHAR(19)`

Combina RN02, RN03 e RN04, nesta ordem:

| Condição | Situação | Regra |
|----------|----------|-------|
| Frequência < 75% | `Reprovado por Falta` | RN04 |
| Falta N1 ou N2 | `Cursando` | |
| Parcial ≥ 7,00 | `Aprovado` | RN02 |
| Parcial < 4,00 | `Reprovado por Nota` | RN02 |
| Parcial de 4,00 a 6,99, sem exame | `Em Exame` | RN02 |
| (Parcial + exame) / 2 ≥ 5,00 | `Aprovado` | RN03 |
| Senão | `Reprovado por Nota` | RN03 |

A falta é testada primeiro porque a RN04 vale "independente das notas": média 9,0 com 73,75% de presença é `Reprovado por Falta`. Isso inclui o aluno que ainda não tem nota, já que as faltas não diminuem e o `total_aulas` é o total do semestre.

As médias são arredondadas para duas casas **antes** da comparação com 7,0, 4,0 e 5,0. Assim a situação sempre bate com a média exibida: N1 = 6,99 e N2 = 7,00 dão 6,995, que é gravado como 7,00 e resulta em `Aprovado`.

### Functions auxiliares: `fn_frequencia_calc` e `fn_situacao_calc`

Fazem a mesma conta das duas functions acima, mas recebendo os valores (`n1`, `n2`, `exame`, `faltas`, `total_aulas`) em vez do `id_matricula`. Toda a regra está nelas; `fn_frequencia` e `fn_situacao` só buscam a linha e repassam. A razão de existirem está em "Dificuldades", abaixo.

### `fn_cr_aluno(p_id_aluno)` → `DECIMAL(4,2)` (opcional)

Coeficiente de Rendimento ponderado pela carga horária:

```
CR = SOMA(média final × carga horária da disciplina) / SOMA(carga horária)
```

Entram só as disciplinas concluídas (`Aprovado`, `Reprovado por Nota`, `Reprovado por Falta`). `Cursando` e `Em Exame` ficam de fora porque ainda não têm resultado. Reprovação por falta sem nota lançada conta como média 0. Aluno sem disciplina concluída devolve `NULL`.

## Views

### `vw_boletim`

Uma linha por matrícula, com as colunas do enunciado: `aluno`, `ra`, `disciplina`, `semestre`, `n1`, `n2`, `exame`, `media_final`, `faltas` e `situacao`.

Além do mínimo, conforme o combinado do grupo: `id_matricula` e `id_turma` (a tela de lançar notas precisa saber qual matrícula está editando), `id_aluno` (filtro do boletim), `total_aulas` e `frequencia`.

```sql
SELECT * FROM vw_boletim WHERE id_aluno = ? ORDER BY semestre;  -- boletim do aluno
SELECT * FROM vw_boletim WHERE id_turma = ? ORDER BY aluno;     -- diário da turma
```

### `vw_turmas_lotacao`

Uma linha por turma: `id_turma`, `disciplina`, `professor`, `vagas`, `matriculados`, `vagas_restantes` e `perc_ocupacao`. Inclui `semestre` e `status` para a tela de matrícula listar só as turmas abertas. Usa `LEFT JOIN` com `matricula`, então a turma sem nenhum matriculado aparece com 0.

### `vw_desempenho_turma`

Uma linha por turma: `media_turma` (média global), `maior_nota`, `menor_nota`, `perc_aprovados` e `perc_reprovados` (por nota + por falta). As três primeiras são calculadas sobre a `media_final` dos alunos que já têm média.

Os percentuais são sobre o total de matriculados. Enquanto houver aluno `Cursando` ou `Em Exame`, aprovados + reprovados não fecha 100%; a coluna `perc_em_andamento` mostra a diferença.

### `vw_faturamento_curso` (além do mínimo)

O enunciado dá ao Coordenador um relatório de faturamento por curso, mas nenhuma tabela mínima tem valor. O grupo acrescentou `curso.valor_mensalidade`, e a view calcula o faturamento mensal previsto: alunos com status `Ativo` × mensalidade. Trancados e formados não entram.

## Triggers

Os quatro ficam na tabela `matricula`.

### `trg_valida_vagas` (BEFORE INSERT) — RN05

Conta os matriculados da turma e, se já forem iguais ao número de vagas, cancela o `INSERT` com `SIGNAL SQLSTATE '45000'` e a mensagem "Turma lotada: a turma X já tem N de N vagas ocupadas." Por ser trigger, vale para qualquer inserção, inclusive as da massa de dados.

A leitura das vagas usa `SELECT ... FOR UPDATE`, que trava a linha da turma até o fim da transação. Duas matrículas simultâneas na última vaga entram em fila e a segunda já encontra a turma lotada.

### `trg_situacao_inicial` (BEFORE INSERT) — além do mínimo

Calcula `media_final` e `situacao` também na inserção. O enunciado só pede o cálculo no `UPDATE`, mas sem este trigger uma matrícula inserida já com notas (as do semestre encerrado na massa de dados) ficaria `Cursando` e sem média, e a RN06 (pré-requisito) depende de encontrar a situação `Aprovado`. Roda depois do `trg_valida_vagas` (`FOLLOWS`).

### `trg_atualiza_situacao` (BEFORE UPDATE) — RN01 a RN04

Quando `n1`, `n2`, `exame`, `faltas` ou a turma mudam, recalcula `NEW.media_final` e `NEW.situacao`. Por ser `BEFORE`, o valor calculado já é gravado na mesma operação. As procedures de lançamento só precisam fazer o `UPDATE` das notas.

Se o `UPDATE` não mexe em nenhum desses campos, o trigger não recalcula. Isso permite que a `sp_fechar_semestre` grave uma situação de fechamento, por exemplo transformar em `Reprovado por Nota` quem ficou `Em Exame` e não fez a prova.

### `trg_auditoria_nota` (AFTER UPDATE) — RN08

Grava em `log_nota` uma linha por campo alterado (`n1`, `n2`, `exame` e `faltas`), com valor antigo, valor novo, usuário e data/hora. As faltas entram porque também mudam a situação do aluno. O usuário vem de `NEW.id_usuario`: quem altera nota grava o próprio id na matrícula, no mesmo `UPDATE`.

## O que as outras partes precisam saber

| Para | Combinado |
|------|-----------|
| Mykael (`sp_lancar_notas`, `sp_lancar_exame`) | Basta `UPDATE matricula SET n1 = ..., n2 = ..., faltas = ..., id_usuario = p_id_usuario`. Não gravar `media_final` nem `situacao`: o trigger sobrescreve. |
| Mykael (`sp_matricular_aluno`) | O trigger já barra turma lotada com SQLSTATE 45000. A procedure pode validar antes para dar a própria mensagem, mas não precisa. |
| Mykael (`sp_fechar_semestre`) | Um `UPDATE` só de `situacao` é respeitado. Se mexer em nota no mesmo `UPDATE`, a situação é recalculada. |
| Guilherme (`03_dados.sql`) | Informar só `n1`, `n2`, `exame` e `faltas` no `INSERT`. `media_final` e `situacao` são calculadas; o que vier nessas colunas é substituído. |
| Leo e Guilherme (telas) | Boletim e diário: `vw_boletim`. Turmas: `vw_turmas_lotacao`. Relatórios: `vw_desempenho_turma` e `vw_faturamento_curso`. |

## Como testar

O [`database/teste_dev_02a.sql`](../database/teste_dev_02a.sql) testa cada objeto com dados temporários, mostrando resultado esperado e obtido lado a lado, e desfaz tudo com `ROLLBACK`. Ele não substitui o `04_testes.sql`.

## Dificuldades e soluções (parte do Diego)

**O trigger BEFORE UPDATE enxerga a linha antiga.** A primeira ideia para o `trg_atualiza_situacao` era `SET NEW.situacao = fn_situacao(NEW.id_matricula)`. Não funciona: a function faz um `SELECT` na tabela, e dentro de um `BEFORE UPDATE` a tabela ainda tem os valores antigos, então a situação sairia sempre um lançamento atrasada. A solução foi separar a regra da busca dos dados. As functions `fn_situacao_calc` e `fn_frequencia_calc` recebem os valores como parâmetro; o trigger as chama com `NEW.*` e a `fn_situacao(id)` apenas lê a linha e chama a mesma auxiliar. A regra continua escrita em um lugar só.

**Comparar valores que podem ser NULL.** As notas começam `NULL`, e `OLD.n1 <> NEW.n1` devolve `NULL` (tratado como falso) quando um dos lados é nulo. Com essa comparação, o primeiro lançamento de nota não seria auditado. A solução foi o operador `<=>`, que compara tratando `NULL` como um valor: `IF NOT (OLD.n1 <=> NEW.n1)`.

**Arredondamento nas fronteiras das regras.** (N1 + N2) / 2 pode ter três casas decimais, mas `media_final` guarda duas. Comparando o valor sem arredondar, 6,995 seria `Em Exame` com a média 7,00 aparecendo no boletim. Decidimos arredondar antes de comparar, para a situação sempre combinar com a média exibida. Na frequência o problema é o inverso, e a solução foi truncar, para 74,996% não virar 75,00%.

**Matrícula inserida já com notas.** O enunciado pede o recálculo só no `UPDATE`, mas a massa de dados insere o semestre anterior com as notas prontas. Essas linhas ficariam `Cursando`, e a validação de pré-requisito nunca encontraria um `Aprovado`. A solução foi o trigger extra `trg_situacao_inicial`, no `BEFORE INSERT`, que usa as mesmas functions.

**Duas matrículas na última vaga.** Contar os matriculados e comparar com as vagas não basta quando duas sessões fazem isso ao mesmo tempo: as duas contam antes de a outra inserir. O `SELECT ... FOR UPDATE` na linha da turma faz a segunda esperar a primeira terminar.
