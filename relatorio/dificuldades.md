# Principais dificuldades encontradas e soluções

Cada integrante registra abaixo os problemas técnicos que enfrentou e como os resolveu. Em comum a todos, a decisão de manter as regras no banco e a tela fina fez com que muitos problemas aparecessem como erros de SQL, e não como bugs de interface.

## Guilherme: modelagem, massa de dados e telas do Coordenador

**A massa de dados precisa passar pelos triggers.** Se os dados entrassem antes da programação, as matrículas do semestre anterior ficariam sem média e sem situação, e a regra de pré-requisito nunca encontraria um aluno `Aprovado`. A solução foi definir, no combinado do grupo, que o `03_dados.sql` roda depois de functions, views, triggers e procedures, com `trg_valida_vagas` e `trg_situacao_inicial` já ativos. Quem erra a massa é barrado pelo próprio banco. Como os identificadores dos cenários de teste dependem de o `AUTO_INCREMENT` começar do 1, o `01_ddl.sql` apaga e recria o banco, e o topo do `03_dados.sql` documenta os logins e os IDs de cada cenário.

**Grafia exata dos textos.** O grupo combinou `'Em Exame'` com E maiúsculo, mas a comparação padrão do MySQL ignora maiúsculas e minúsculas, então `'Em exame'` passaria pelo `CHECK`. A solução foi comparar com `COLLATE utf8mb4_bin` nos `CHECK` de texto, que aceitam só a grafia exata.

**Excluir aluno com matrícula.** As chaves estrangeiras usam `RESTRICT`, e uma exclusão assim estouraria um erro técnico de chave estrangeira na cara do usuário. A solução foi não deixar a tela mandar `DELETE`: a `sp_excluir_aluno` confere antes e responde "Aluno tem matrículas: tranque o aluno em vez de excluir.".

**Telas que dependem de identificadores.** Para lançar notas, a tela precisa saber qual matrícula está editando. A solução foi pedir ao Diego que a `vw_boletim` trouxesse `id_matricula` e `id_turma`; assim a tela lista as matrículas de uma turma e o Coordenador seleciona a linha, sem digitar números.

**Procedures que devolvem resultado.** O `sp_fechar_semestre` termina com um resumo (`SELECT situacao, COUNT(*)`). Com JDBC, o resultado de um `CALL` pode vir depois de outros retornos, então a leitura percorre `execute()` e `getMoreResults()` até achar o conjunto de linhas, em vez de supor que ele é o primeiro.

**Fechamento é tudo ou nada.** Como a procedure recusa o semestre inteiro se houver uma única matrícula sem notas, a tela precisava deixar isso claro. A solução foi listar só os semestres com turma aberta, pedir confirmação antes de executar e mostrar a mensagem do banco, que aponta o aluno que falta.

## Diego: functions, views e triggers

**O trigger `BEFORE UPDATE` enxerga a linha antiga.** A primeira ideia para o `trg_atualiza_situacao` era `SET NEW.situacao = fn_situacao(NEW.id_matricula)`. Não funciona: a function faz um `SELECT` na tabela, e dentro de um `BEFORE UPDATE` a tabela ainda tem os valores antigos, então a situação sairia sempre um lançamento atrasada. A solução foi separar a regra da busca dos dados. As functions `fn_situacao_calc` e `fn_frequencia_calc` recebem os valores como parâmetro; o trigger as chama com `NEW.*` e a `fn_situacao(id)` apenas lê a linha e chama a mesma auxiliar. A regra continua escrita em um lugar só.

**Comparar valores que podem ser NULL.** As notas começam `NULL`, e `OLD.n1 <> NEW.n1` devolve `NULL` (tratado como falso) quando um dos lados é nulo. Com essa comparação, o primeiro lançamento de nota não seria auditado. A solução foi o operador `<=>`, que compara tratando `NULL` como um valor: `IF NOT (OLD.n1 <=> NEW.n1)`.

**Arredondamento nas fronteiras das regras.** (N1 + N2) / 2 pode ter três casas decimais, mas `media_final` guarda duas. Comparando o valor sem arredondar, 6,995 seria `Em Exame` com a média 7,00 aparecendo no boletim. Decidimos arredondar antes de comparar, para a situação sempre combinar com a média exibida. Na frequência o problema é o inverso, e a solução foi truncar, para 74,996% não virar 75,00%.

**Matrícula inserida já com notas.** O enunciado pede o recálculo só no `UPDATE`, mas a massa de dados insere o semestre anterior com as notas prontas. Essas linhas ficariam `Cursando`, e a validação de pré-requisito nunca encontraria um `Aprovado`. A solução foi o trigger extra `trg_situacao_inicial`, no `BEFORE INSERT`, que usa as mesmas functions.

**Duas matrículas na última vaga.** Contar os matriculados e comparar com as vagas não basta quando duas sessões fazem isso ao mesmo tempo: as duas contam antes de a outra inserir. O `SELECT ... FOR UPDATE` na linha da turma faz a segunda esperar a primeira terminar.

## Mykael: procedures e testes

**Commit implícito.** `CREATE PROCEDURE` e `START TRANSACTION` encerram a transação em andamento. Isso impediu montar todos os testes em uma transação única com `ROLLBACK` no fim, e o roteiro teve de ser dividido em duas fases: os testes de procedures simples rodam em uma transação desfeita ao final, e o do fechamento de semestre cria e apaga os próprios dados.

**Testes que devem falhar paravam o script.** No Workbench, o primeiro erro interrompe a execução, o que impedia provar que o banco recusa dados inválidos. A solução foi a procedure auxiliar `sp_teste_erro`, que executa o caso esperado dentro de um handler, captura a mensagem e a registra na tabela esperado × obtido, sem parar o script.

**Perfil verificado antes da transação.** Na `sp_fechar_semestre`, o `EXIT HANDLER` faz `ROLLBACK`. Se a conferência de perfil acontecesse dentro da transação, um Secretário barrado dispararia um `ROLLBACK` desnecessário. A solução foi conferir perfil e formato do semestre antes do `START TRANSACTION`, de modo que quem não pode fechar o semestre não mexe em nada.

## Leo: interface e acesso ao banco

**Nada de SQL cru.** O enunciado proíbe tráfego de SQL pela rede. A solução foi concentrar todo o acesso na classe `SgaRepository`, com um método por procedure ou view, parâmetros sempre vinculados (`CallableStatement` e `PreparedStatement`) e uma lista de views permitidas para as consultas sem parâmetro.

**Resultados de procedures.** `sp_LoginUsuario` e `sp_historico_aluno` devolvem linhas, mas o JDBC pode apresentá-las depois de outros retornos. A leitura percorre os resultados até achar o conjunto de linhas e trata o resultado vazio como "login negado".

**Senha nunca em texto.** A aplicação calcula o SHA-256 em `char[]` e apaga o vetor e os bytes da memória logo após o cálculo, para a senha não ficar em uma `String` esperando o coletor de lixo. Só o hash segue para o banco.

**Configuração fora do repositório.** Usuário e senha do MySQL são lidos de variáveis de ambiente (`SGA_DB_USER`, `SGA_DB_PASSWORD`, `SGA_DB_URL`), assim nenhuma credencial vai para o Git.

**Matrícula sem digitar IDs.** Em vez de pedir os números de aluno e turma, a tela monta duas listas a partir de `vw_alunos` e `vw_turmas_lotacao`, com só os alunos ativos e as turmas abertas com vaga, e pede confirmação antes de gravar.

## Do grupo: integração

A junção das branches gerou conflitos em arquivos que mais de uma pessoa tocou (README, scripts SQL e checklists de tarefas). O combinado de cada um trabalhar só na própria branch e de abrir Pull Request por bloco pronto reduziu o problema. Os conflitos que sobraram foram resolvidos trazendo a `main` para a branch antes de abrir o PR, e o `SGA_completo.sql` passou a ser gerado por script (`gerar_SGA_completo.ps1`), para ninguém editá-lo à mão.
