# Aplicação Java do SGA

Primeira versão da interface desktop, feita com Java Swing e JDBC. A tela autentica pelo `sp_LoginUsuario`; as consultas usam as views do banco e as operações acadêmicas do Coordenador chamam stored procedures.

## Pré-requisitos

- JDK 17 ou superior.
- Maven 3.9 ou superior.
- MySQL 8 e os scripts do grupo carregados no schema `sga_fbi`.
- Procedures e views existentes no banco: `sp_LoginUsuario`, `sp_historico_aluno`, `sp_lancar_notas`, `sp_lancar_exame`, `sp_fechar_semestre`, `vw_turmas_lotacao`, `vw_boletim` e `vw_desempenho_turma`.

> O aplicativo espera que o schema `sga_fbi` já tenha sido criado e carregado com as procedures e views listadas acima. A massa oficial e as procedures de cadastro devem ser integradas pelo grupo antes da entrega final.

## Configuração no PowerShell

Defina as credenciais do usuário MySQL que será usado localmente. Não coloque senha em código ou em commit:

```powershell
$env:SGA_DB_URL = "jdbc:mysql://localhost:3306/sga_fbi?serverTimezone=America/Cuiaba"
$env:SGA_DB_USER = "seu_usuario_mysql"
$env:SGA_DB_PASSWORD = "sua_senha_local"
```

## Executar

No terminal, entre nesta pasta `app` e rode:

```powershell
mvn clean compile exec:java
```

O Maven baixa o MySQL Connector/J declarado no `pom.xml`. O projeto usa a linha 9.5 do conector, publicada como dependência Maven pela Oracle/MySQL.

## Fluxo implementado

- Login: calcula SHA-256 hexadecimal minúsculo localmente e chama `sp_LoginUsuario(login, hash)`.
- Secretário: consulta turmas, boletim filtrado por aluno e histórico; pode solicitar matrícula pelo `sp_matricular_aluno`.
- Coordenador: tem as consultas anteriores, relatório de faturamento e pode lançar notas, lançar exame e fechar semestre.
- A aplicação não armazena senhas em arquivo. As regras de perfil e as validações devem continuar aplicadas no banco pelas procedures.
- Cadastro, edição e exclusão de alunos ainda não aparecem no menu; dependem das procedures de cadastro (`sp_cadastrar_aluno`, `sp_editar_aluno`, `sp_excluir_aluno`) que ainda não estão no SQL integrado.

As assinaturas precisam coincidir com os scripts SQL finais. Se o grupo alterar nomes de colunas, views ou parâmetros, ajuste `SgaRepository` de acordo.
