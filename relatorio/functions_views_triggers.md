# Functions, Views e Triggers

Responsável: Diego. Base para a seção "Explicação de procedures, views, functions, triggers" do relatório. O script que implementa tudo isto é o [`database/02a_functions_views_triggers.sql`](../database/02a_functions_views_triggers.sql).

## 1. Visão geral

As regras de negócio acadêmicas (RN01 a RN08) ficam **dentro do banco**, e não na interface. Assim, qualquer tela, procedure ou script que mexa nas tabelas passa pelas mesmas regras e não há como gravar uma média ou situação inconsistente.

| Objeto | Tipo | Regras cobertas |
|--------|------|-----------------|
| `fn_calcular_media` | function | RN01, RN03 |
| `fn_frequencia` | function | RN04 (cálculo da frequência) |
| `fn_situacao` | function | RN02, RN03, RN04 |
| `fn_cr_aluno` | function (opcional) | Coeficiente de rendimento |
| `fn_frequencia_valores`, `fn_situacao_valores` | functions auxiliares | Mesma lógica, recebendo valores em vez do id |
| `vw_boletim` | view | Consulta do boletim |
| `vw_turmas_lotacao` | view | Apoio à RN05 |
| `vw_desempenho_turma` | view | Relatório de desempenho |
| `vw_faturamento_curso` | view | Relatório financeiro (Coordenador) |
| `trg_valida_vagas` | trigger | RN05 |
| `trg_atualiza_situacao` | trigger | RN02, RN03, RN04 |
| `trg_auditoria_nota` | trigger | RN08 |
| `trg_calcula_situacao_insert` | trigger (extra) | RN02, RN03, RN04 na inserção |

Ordem no arquivo: functions, depois views, depois triggers, porque views e triggers usam as functions.

## 2. Functions

### fn_calcular_media(n1, n2, exame) → DECIMAL(4,2)
Implementa RN01 e RN03.
- Se `n1` ou `n2` forem nulos, devolve `NULL`.
- Média parcial = `ROUND((n1 + n2) / 2, 2)`.
- Se houver exame e a parcial estiver entre 4,0 e 6,99, devolve `ROUND((parcial + exame) / 2, 2)` (RN03).
- Nos demais casos devolve a parcial.

### fn_frequencia(id_matricula) → DECIMAL(5,2)
Busca `faltas` na matrícula e `total_aulas` na turma e aplica `(total_aulas − faltas) / total_aulas × 100`, limitado entre 0 e 100. Devolve `NULL` se a matrícula não existe. O cálculo em si está em `fn_frequencia_valores(total_aulas, faltas)`, que as views também usam.

### fn_situacao(id_matricula) → VARCHAR
Busca os dados da matrícula e chama `fn_situacao_valores`, que decide nesta ordem:

| Ordem | Condição | Resultado |
|-------|----------|-----------|
| 1 | Frequência < 75% (RN04) | `Reprovado por Falta` |
| 2 | `n1` ou `n2` nulos | `Cursando` |
| 3 | Parcial ≥ 7 (RN02) | `Aprovado` |
| 4 | Parcial < 4 (RN02) | `Reprovado por Nota` |
| 5 | Entre 4 e 6,99, sem exame | `Em Exame` |
| 6 | Com exame: (parcial + exame) / 2 ≥ 5 (RN03) | `Aprovado` |
| 7 | Com exame, média final < 5 | `Reprovado por Nota` |

A frequência vem primeiro porque a RN04 vale independentemente das notas. A comparação de 75% é feita em inteiros (`(total − faltas) × 100 < 75 × total`), sem arredondamento.

### fn_cr_aluno(id_aluno) → DECIMAL(4,2) (opcional)
Média das `media_final` das disciplinas já concluídas (Aprovado, Reprovado por Nota ou Reprovado por Falta), ponderada pela carga horária da disciplina. Reprovado por Falta entra com nota 0. Sem disciplina concluída, devolve `NULL`.

## 3. Views

| View | Colunas principais | Uso |
|------|--------------------|-----|
| `vw_boletim` | id_matricula, id_turma, aluno, RA, disciplina, semestre, N1, N2, exame, média final, faltas, frequência, situação | Boletim; `id_matricula` e `id_turma` identificam a linha na tela de lançar notas |
| `vw_turmas_lotacao` | turma, disciplina, professor, semestre, vagas totais, matriculados, vagas restantes, % de ocupação | Consulta de turmas |
| `vw_desempenho_turma` | turma, disciplina, semestre, média global, maior e menor nota, % de aprovados, % de reprovados | Relatório de desempenho. Os percentuais consideram todas as matrículas da turma |
| `vw_faturamento_curso` | curso, turno, mensalidade, alunos ativos, faturamento mensal | Relatório financeiro, restrito ao Coordenador |

Como a interface só pode chamar procedures e consultar views, essas views são o caminho de leitura das telas.

## 4. Triggers

### trg_valida_vagas (BEFORE INSERT em matricula) — RN05
Conta as matrículas da turma. Se já for igual ou maior que `vagas`, lança `SIGNAL SQLSTATE '45000'` com a mensagem "Turma lotada".

### trg_atualiza_situacao (BEFORE UPDATE em matricula)
Antes de gravar, recalcula `media_final` e `situacao` com `NEW.n1`, `NEW.n2`, `NEW.exame` e `NEW.faltas`. Assim os dois campos nunca ficam desatualizados em relação às notas.

### trg_calcula_situacao_insert (BEFORE INSERT em matricula) — extra
Faz o mesmo cálculo na inserção. Sem ele, uma matrícula inserida já com notas (como na massa de dados) ficaria com situação errada, porque o trigger de UPDATE só roda em atualizações.

### trg_auditoria_nota (AFTER UPDATE em matricula) — RN08
Compara `OLD` e `NEW` de `n1`, `n2`, `exame` e `faltas` e grava uma linha em `log_nota` para cada campo alterado, com valor antigo, valor novo e o usuário (`NEW.id_usuario`). A comparação usa `<=>`, que trata `NULL` (por exemplo, nota lançada pela primeira vez).

## 5. Principais dificuldades encontradas e soluções

**O trigger não enxerga a linha nova.** No `BEFORE UPDATE`, chamar `fn_situacao(NEW.id_matricula)` leria a tabela, que ainda tem os valores antigos, e a situação gravada ficaria sempre uma atualização atrasada. Solução: criar `fn_situacao_valores`, que recebe `n1, n2, exame, faltas, total_aulas` como parâmetros. O trigger a chama com `NEW.*`, e a `fn_situacao` apenas busca a linha e chama a mesma função auxiliar, então a regra existe em um só lugar. O mesmo foi feito com `fn_frequencia_valores`.

**Comparação com NULL na auditoria.** `OLD.n1 <> NEW.n1` resulta em `NULL` quando um dos lados é vazio, e o `IF` trata isso como falso: a primeira nota lançada não seria auditada. Solução: usar `NOT (OLD.n1 <=> NEW.n1)`.

**Arredondamento inconsistente.** Com n1 = 7,00 e n2 = 6,99 a média é 6,995. Exibida com duas casas aparece 7,00, mas comparada sem arredondar daria "Em Exame". Solução: arredondar a média parcial para duas casas e usar sempre o valor arredondado nas comparações, para a situação bater com o que o usuário vê.

**Exame fora da faixa.** Um exame lançado para quem já passou ou já reprovou não deveria mudar a média. Solução: a `fn_calcular_media` só usa o exame quando a parcial está entre 4,0 e 6,99, e a `fn_situacao_valores` segue a mesma regra.

**Matrículas inseridas com notas.** O trigger pedido no enunciado é só `BEFORE UPDATE`. Solução: o trigger extra `trg_calcula_situacao_insert`.

**Ordem de execução.** Views e triggers chamam functions, e as functions leem as tabelas. Solução: o arquivo cria functions, views e triggers nessa ordem, e o `01_ddl.sql` roda antes. Cada objeto é recriado com `DROP ... IF EXISTS` ou `CREATE OR REPLACE`, então o script pode ser executado várias vezes. As functions declaram `DETERMINISTIC` ou `READS SQL DATA`, para o MySQL aceitá-las com o log binário ligado.

## 6. Casos de teste (resultados esperados)

Valores calculados a partir das regras. Substituir pelos prints do MySQL Workbench depois de rodar o `SGA_completo.sql`.

| Chamada | Cenário | Esperado |
|---------|---------|----------|
| `fn_calcular_media(6, 5, NULL)` | Parcial 5,5 | 5,50 |
| `fn_calcular_media(6, 5, 8)` | (5,5 + 8) / 2 | 6,75 |
| `fn_situacao_valores(9, 9, NULL, 30, 40)` | Média 9, frequência 25% (RN04) | Reprovado por Falta |
| `fn_situacao_valores(8, 8, NULL, 2, 40)` | Média 8, frequência 95% | Aprovado |
| `fn_situacao_valores(5, 6, NULL, 0, 40)` | Parcial 5,5 sem exame | Em Exame |
| `fn_situacao_valores(5, 6, 4, 0, 40)` | (5,5 + 4) / 2 = 4,75 | Reprovado por Nota |
| `fn_situacao_valores(5, 6, 6, 0, 40)` | (5,5 + 6) / 2 = 5,75 | Aprovado |
| `fn_situacao_valores(2, 3, NULL, 0, 40)` | Parcial 2,5 | Reprovado por Nota |
| `fn_situacao_valores(NULL, NULL, NULL, 0, 40)` | Sem notas | Cursando |
| `UPDATE matricula SET n1 = 8 ...` | Alteração de nota | Uma linha em `log_nota` com campo `n1` |
| `INSERT` em turma com todas as vagas ocupadas | RN05 | Erro 45000, "Turma lotada" |
