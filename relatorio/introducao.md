# Introdução

O **SGA (Sistema de Gestão Acadêmica)** centraliza o controle de turmas, matrículas, notas, frequência, históricos e perfis de acesso de uma faculdade, substituindo as planilhas manuais. O projeto cobre a modelagem e a programação do banco de dados relacional (MySQL) e uma interface cliente desktop de consulta e operação.

## Equipe

| Integrante | Responsabilidade principal |
|---|---|
| Guilherme | Modelagem (MER, DDL, índices), massa de dados, procedures de cadastro de aluno, telas do Coordenador e montagem do relatório |
| Diego | Regras de negócio dentro do banco: functions, views e triggers, e o script de entrega `SGA_completo.sql` |
| Mykael | As seis stored procedures do enunciado, o roteiro de testes (`04_testes.sql`) e a prova de que as regras funcionam |
| Leo | Base da interface: conexão, login com hash, menu por perfil e telas do Secretário |

## Tecnologias

- **Banco de dados:** MySQL 8 (a partir da 8.0.16, que passou a aplicar os `CHECK`), com MySQL Workbench.
- **Interface:** aplicação desktop em Java 17 com Swing, JDBC (MySQL Connector/J 9.5.0) e Maven. A aparência usa a biblioteca FlatLaf. PHP não é usado.
- **Comunicação interface ↔ banco:** somente por **Stored Procedures** (`CALL sp_...`) e **Views** (`SELECT ... FROM vw_...`), sempre com parâmetros. A aplicação não envia `INSERT`, `UPDATE` nem `DELETE`.
- **Senhas:** guardadas com hash SHA-256; a senha em texto nunca chega ao banco.
- **Versionamento:** Git/GitHub, uma branch por integrante, Pull Request para a `main`.

## Arquitetura

As regras de negócio vivem no banco, não na tela. A interface apenas coleta dados, chama procedures e mostra o resultado. Quando uma regra é quebrada, o banco devolve uma mensagem legível (`SIGNAL SQLSTATE '45000'`), e a tela só a exibe.

```text
  Interface Java (Swing)           MySQL (sga_fbi)
  ┌──────────────────────┐         ┌──────────────────────────────────────┐
  │ Login / Dashboard    │  CALL   │ Procedures  sp_...  (porta de entrada)│
  │ Alunos, Notas,       │ ──────► │ Triggers    trg_... (RN05, RN08, ...) │
  │ Relatórios           │         │ Functions   fn_...  (média, situação) │
  │                      │ SELECT  │ Views       vw_...  (consultas)       │
  │                      │ ◄────── │ Tabelas + CHECK/FK/UNIQUE             │
  └──────────────────────┘         └──────────────────────────────────────┘
```

## Organização do repositório

| Pasta | Conteúdo |
|---|---|
| `database/` | Scripts SQL na ordem de execução e o `SGA_completo.sql` gerado para a entrega |
| `app/` | Código-fonte da interface Java (projeto Maven) |
| `relatorio/` | Este relatório e seus rascunhos por assunto |
| `apresentacao/` | Slides da apresentação oral |
| `docs/` | Requisitos, divisão de tarefas e checklists |

## Como executar

1. No MySQL Workbench, execute os scripts nesta ordem: `01_ddl.sql`, `02a_functions_views_triggers.sql`, `02b_procedures.sql`, `02c_procedures_cadastro.sql`, `03_dados.sql` e, para a prova das regras, `04_testes.sql`. Alternativamente, rode só o `SGA_completo.sql`, que reúne todos na mesma ordem.
2. Defina as variáveis de ambiente `SGA_DB_USER` e `SGA_DB_PASSWORD` (e, se necessário, `SGA_DB_URL`).
3. Na pasta `app/`, execute `mvn clean compile exec:java` (JDK 17+ e Maven 3.9+).
4. Entre com um dos usuários de teste, todos com a senha `Senha@123`: `coord.ana` e `coord.bruno` (Coordenadores) ou `sec.carla`, `sec.diego` e `sec.elisa` (Secretários).
