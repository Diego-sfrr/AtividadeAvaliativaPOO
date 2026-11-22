# Normalização até a 3FN

Esta seção justifica que o modelo lógico (nove tabelas) está na terceira forma normal e aponta, com transparência, a única redundância deliberada.

## 1ª Forma Normal (1FN)

Toda coluna guarda um valor atômico e não há grupos repetidos.

- Notas ficam em colunas próprias (`n1`, `n2`, `exame`) e não em uma lista dentro de um campo.
- Os pré-requisitos de uma disciplina não ficam em uma coluna com vários códigos: o relacionamento N:N entre disciplinas virou a tabela `pre_requisito`.
- O vínculo entre aluno e turma, que é N:N, virou a tabela `matricula`, com uma linha por aluno em cada turma.
- CPF, e-mail, RA e login são colunas únicas e indivisíveis.

## 2ª Forma Normal (2FN)

Nenhum atributo depende de apenas parte de uma chave composta.

- Oito das nove tabelas têm chave primária simples (`id_...`), então a dependência parcial não é possível.
- A única chave composta é a de `pre_requisito` (`id_disciplina`, `id_disciplina_requisito`), e a tabela não tem nenhum outro atributo.
- Em `matricula`, a chave primária é o `id_matricula`. O par (`id_aluno`, `id_turma`) é uma chave candidata, protegida por `UNIQUE`, e todos os atributos (notas, faltas, situação) dependem da matrícula inteira, isto é, do aluno **naquela** turma.

## 3ª Forma Normal (3FN)

Nenhum atributo não-chave depende de outro atributo não-chave (sem dependência transitiva). Os dados de cada entidade ficam na própria tabela, e as outras apenas a referenciam por chave estrangeira:

| Informação | Fica em | Não é repetida em |
|---|---|---|
| Nome do curso, turno e mensalidade | `curso` | `aluno`, `disciplina` (guardam só `id_curso`) |
| Nome e carga horária da disciplina | `disciplina` | `turma`, `matricula` |
| Nome e titulação do professor | `professor` | `turma` (guarda só `id_professor`) |
| Vagas e total de aulas da oferta | `turma` | `matricula` |
| Nome do aluno e RA | `aluno` | `matricula` |
| Nome e perfil do usuário | `usuario` | `matricula`, `log_nota` |

Exemplo: o valor da mensalidade depende do curso, e não do aluno. Se estivesse em `aluno`, haveria a dependência transitiva `id_aluno → id_curso → valor_mensalidade`. Por isso ele fica em `curso`, e o faturamento é calculado por uma view (`vw_faturamento_curso`).

## Redundância deliberada: `media_final` e `situacao`

As colunas `matricula.media_final` e `matricula.situacao` são **derivadas** de `n1`, `n2`, `exame` e das faltas. Em rigor, isso é uma dependência transitiva e fere a 3FN. A decisão foi mantê-las por três motivos:

1. O enunciado trata a média final e a situação como informação da matrícula, consultada em boletim, histórico e relatórios.
2. A regra de pré-requisito (RN06) precisa encontrar a situação `Aprovado` de disciplinas já cursadas, e gravar o resultado evita recalcular em cada consulta.
3. A consistência não depende de ninguém lembrar de atualizar: os triggers `trg_situacao_inicial` e `trg_atualiza_situacao` recalculam os dois campos a cada `INSERT` e `UPDATE`, sempre pelas mesmas functions. Nenhuma procedure nem tela grava esses valores diretamente.

Com essa proteção, a redundância não gera anomalia de atualização: os valores derivados nunca divergem das notas que os originam.

## Integridade além da normalização

- **Chaves estrangeiras** com a ação padrão (`RESTRICT`): não se exclui aluno, turma ou usuário que já tenha matrícula ou log.
- **UNIQUE** em RA, CPF, e-mail e login, e em (`id_aluno`, `id_turma`) na matrícula.
- **CHECK** para notas de 0 a 10 (RN07), faltas não negativas, CPF com 11 dígitos, semestre no formato `AAAA.1` ou `AAAA.2` e os conjuntos de valores permitidos de perfil, turno, status e situação. Os `CHECK` de texto comparam com `COLLATE utf8mb4_bin`, então só aceitam a grafia exata combinada pelo grupo.
