
# SGA - Sistema de Gestão Acadêmica

Aplicação desktop desenvolvida em Java Swing e MySQL para gerenciamento acadêmico.

## Tecnologias utilizadas

- Java 17
- Apache Maven
- Java Swing
- JDBC
- MySQL 8
- MySQL Connector/J 9.5.0

## Pré-requisitos

- JDK 17 ou superior.
- Apache Maven.
- MySQL Server 8.
- Apache NetBeans (opcional, para abrir e executar o projeto).
- Banco de dados `sga_fbi` criado e configurado.

## Banco de dados

Os scripts SQL estão na pasta `database` do repositório principal.

A ordem de execução é:

1. `01_ddl.sql` - Criação do banco e das tabelas.
2. `02a_functions_views_triggers.sql` - Functions, views e triggers.
3. `02b_procedures.sql` - Procedures de login, matrícula, notas, exame, histórico e fechamento.
4. `02c_procedures_cadastro.sql` - Procedures de cadastro de alunos e view de alunos.
5. `03_dados.sql` - Inserção dos dados de teste.
6. `04_testes.sql` - Testes das regras de negócio.

Os scripts devem ser executados nessa ordem, utilizando o MySQL Workbench.

## Configuração da conexão

O aplicativo utiliza variáveis de ambiente para acessar o MySQL.

No PowerShell, configure:

```powershell
$env:SGA_DB_URL = "jdbc:mysql://localhost:3306/sga_fbi?serverTimezone=America/Cuiaba"
$env:SGA_DB_USER = "root"
$env:SGA_DB_PASSWORD = "SUA_SENHA_DO_MYSQL"
```

Substitua a senha pelo valor configurado no seu MySQL.

As credenciais não devem ser armazenadas diretamente no código ou enviadas ao GitHub.

## Como executar

Entre na pasta `app` pelo terminal:

```powershell
cd app
```

Execute:

```powershell
mvn clean compile exec:java
```

O Maven utilizará o `pom.xml` para baixar as dependências e iniciar a aplicação.

Classe principal:

`br.edu.fbi.sga.SgaApplication`

## Funcionalidades implementadas

### Login e controle de acesso
- Autenticação utilizando SHA-256.
- Login integrado à procedure `sp_LoginUsuario`.
- Identificação do perfil do usuário.
- Menus diferentes para Secretário e Coordenador.

### Secretário
- Consulta de turmas.
- Consulta de boletim.
- Consulta de histórico acadêmico.
- Realização de matrículas.
- Listagem de alunos.
- Cadastro de alunos.
- Edição de alunos.
- Exclusão de alunos.

### Coordenador
- Consulta de turmas.
- Consulta de boletim e histórico.
- Consulta de desempenho das turmas.
- Consulta de faturamento por curso.
- Lançamento de notas.
- Lançamento de exame.
- Fechamento de semestre.

## Regras de implementação

- As operações de cadastro, edição e exclusão são executadas por stored procedures.
- As consultas utilizam views do banco de dados.
- As operações acadêmicas utilizam procedures.
- O aplicativo utiliza consultas parametrizadas.
- As regras de negócio são validadas pelo banco de dados.
- As permissões dos usuários são diferenciadas por perfil.

## Usuários para teste

Após executar o arquivo `03_dados.sql`, podem ser utilizados:

| Perfil | Login | Senha |
|---|---|---|
| Coordenador | coord.ana | Senha@123 |
| Coordenador | coord.bruno | Senha@123 |
| Secretário | sec.carla | Senha@123 |
| Secretário | sec.diego | Senha@123 |
| Secretário | sec.elisa | Senha@123 |

## Estrutura do projeto

```text
app/
├── pom.xml
├── README.md
└── src/
    └── main/
        └── java/
            └── br/edu/fbi/sga/
                ├── SgaApplication.java
                ├── LoginFrame.java
                ├── DashboardFrame.java
                ├── DatabaseConfig.java
                ├── PasswordHash.java
                ├── SgaRepository.java
                ├── Usuario.java
                └── AlunosFrame.java
```
