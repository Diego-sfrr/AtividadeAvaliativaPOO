# 1. Em um minuto

Você fez a **cara do sistema**: a aplicação desktop em Java que o usuário enxerga. Ela tem a tela de login, o menu que muda conforme o perfil (Secretário ou Coordenador), as telas de alunos e de matrícula, o boletim, o histórico e a consulta de turmas. O ponto principal do seu trabalho é que **a interface não tem regra de negócio**: ela só chama procedures e consulta views, sempre com parâmetros, e mostra a mensagem que o banco devolver.

Roteiro de fala, para ler em voz alta (cerca de 1 minuto):

> "Eu fiz a interface, em Java com Swing e JDBC. A regra do projeto é que a tela não pode mandar SQL solto: ela só chama procedures com CALL e consulta views com SELECT, sempre com parâmetros, nunca juntando o texto digitado. Todo o acesso ao banco passa por uma única classe, a SgaRepository. No login, a senha é transformada em hash SHA-256 ainda no aplicativo, e só o hash vai para o banco, que confere e devolve o perfil da pessoa. Com o perfil, o menu muda: o Secretário não vê notas, fechamento nem relatórios. Mas o banco também barra, então mesmo que alguém contorne a tela, a procedure recusa. Na matrícula, o usuário escolhe aluno e turma em listas, só aparecem alunos ativos e turmas abertas com vaga, e as regras de pré-requisito e de vagas quem confere é o banco."

# 2. Palavras que você precisa saber

**Interface gráfica e Swing.** A janela que o usuário vê. Swing é a biblioteca do Java para isso: `JFrame` é uma janela, `JPanel` é uma área dentro dela, `JButton` é um botão, `JTable` é uma tabela, `JOptionPane` são as caixinhas de mensagem.

**JDBC.** A "ponte" entre o Java e o banco de dados. O programa abre uma conexão e manda comandos por ela.

**Driver (MySQL Connector/J).** A peça que ensina o JDBC a falar com o MySQL. Vem como dependência no `pom.xml`.

**Maven e `pom.xml`.** Maven é a ferramenta que baixa as dependências e compila o projeto. O `pom.xml` lista o que o projeto precisa (o driver do MySQL, a biblioteca de visual) e a versão do Java.

**CallableStatement.** Objeto do JDBC que chama uma **procedure**: `{call sp_nome(?, ?)}`. Cada `?` é um parâmetro que se preenche depois.

**PreparedStatement.** Objeto do JDBC que roda um `SELECT` com `?` no lugar dos valores. O valor é enviado separado do comando, então não dá para "injetar" código.

**Injeção de SQL.** Ataque em que o usuário digita um pedaço de SQL num campo ("`' OR 1=1 --`") e, se o programa colar esse texto na consulta, ele executa. Parâmetros (`?`) evitam isso.

**Hash SHA-256.** Uma "impressão digital" de 64 caracteres calculada a partir do texto. Do hash não se volta para a senha. O banco guarda só o hash, e na hora do login compara o hash da senha digitada com o hash guardado.

**Variável de ambiente.** Configuração do computador que o programa lê (por exemplo, `SGA_DB_PASSWORD`). Assim a senha do banco não fica escrita no código nem no GitHub.

**Perfil.** O papel do usuário: `Coordenador` (acesso total) ou `Secretario` (sem notas, fechamento nem financeiro).

**Record.** Uma classe curta do Java só para guardar dados. O `Usuario` é um record com id, nome, e-mail e perfil.

**ResultSet.** O resultado de uma consulta, que o código percorre linha a linha com `next()`.

**SQLException.** O erro do banco chegando ao Java. O texto dele (`getMessage()`) é exatamente a mensagem que a procedure escreveu com `SIGNAL`.

# 3. O código, linha por linha

Esta parte percorre os arquivos da interface na ordem em que a execução passa por eles: entrada do programa, conexão, hash, login, acesso ao banco, menu e telas de aluno e matrícula. (O código das telas do Coordenador, `NotasFrame` e `RelatoriosFrame`, está explicado no guia do Guilherme.)

## 3.1 SgaApplication.java: o ponto de entrada

```java
public final class SgaApplication {
    private SgaApplication() { }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            Tema.instalar();
            new LoginFrame().setVisible(true);
        });
    }
}
```

| Linha | O que faz |
|---|---|
| public final class SgaApplication | Define a classe. `final` significa que ninguém pode estender (herdar) dela |
| private SgaApplication() { } | Construtor privado: proíbe criar objetos desta classe. Ela só serve para guardar o `main` |
| public static void main(String[] args) | O `main` é onde todo programa Java começa a rodar |
| SwingUtilities.invokeLater(...) | Manda criar a janela na "fila" da interface gráfica. Regra do Swing: janelas só podem ser criadas por esse caminho |
| Tema.instalar() | Liga o visual moderno (cores, fontes, tabelas) antes de qualquer janela aparecer |
| new LoginFrame().setVisible(true) | Cria a tela de login e a mostra. O programa começa por ela |

## 3.2 Usuario.java: quem está logado

```java
public record Usuario(int id, String nome, String email, String perfil) {
    public boolean isCoordenador() {
        return "Coordenador".equalsIgnoreCase(perfil);
    }

    public boolean isSecretario() {
        return "Secretario".equalsIgnoreCase(perfil);
    }
}
```

| Linha | O que faz |
|---|---|
| public record Usuario(int id, String nome, String email, String perfil) | Cria de uma vez a classe com esses 4 campos, um construtor e os métodos `id()`, `nome()`, `email()` e `perfil()`. Note que **não existe campo de senha**: a senha nunca fica no objeto |
| isCoordenador() | Devolve `true` se o perfil for `Coordenador`. `equalsIgnoreCase` compara sem ligar para maiúscula/minúscula |
| isSecretario() | Mesma ideia para `Secretario` (sem acento, como no banco) |

## 3.3 DatabaseConfig.java: abrir a conexão

```java
public static Connection openConnection() throws SQLException {
    String url = envOrDefault("SGA_DB_URL", "jdbc:mysql://localhost:3306/sga_fbi?serverTimezone=America/Cuiaba");
    String user = System.getenv("SGA_DB_USER");
    String password = System.getenv("SGA_DB_PASSWORD");
    if (user == null || user.isBlank() || password == null) {
        throw new SQLException("Configure SGA_DB_USER e SGA_DB_PASSWORD antes de abrir o SGA.");
    }
    return DriverManager.getConnection(url, user, password);
}
```

| Linha | O que faz |
|---|---|
| public static Connection openConnection() throws SQLException | Método que devolve uma conexão aberta com o banco. `throws SQLException` avisa que pode dar erro de banco |
| envOrDefault("SGA_DB_URL", "jdbc:mysql://localhost:3306/sga_fbi?...") | Endereço do banco. Se a variável `SGA_DB_URL` não existir, usa o padrão: MySQL na própria máquina, porta 3306, banco `sga_fbi`. O `serverTimezone` define o fuso horário |
| System.getenv("SGA_DB_USER") | Lê o usuário do MySQL da variável de ambiente. **Não está escrito no código** |
| System.getenv("SGA_DB_PASSWORD") | Lê a senha do MySQL, também da variável de ambiente |
| if (user == null OU user.isBlank() OU password == null) | Se faltar usuário ou senha, para e explica o que configurar (o `ou` é escrito com duas barras verticais no Java). A senha pode ser vazia, mas precisa existir |
| DriverManager.getConnection(url, user, password) | Abre de fato a conexão com o MySQL |

```java
private static String envOrDefault(String name, String fallback) {
    String value = System.getenv(name);
    return value == null || value.isBlank() ? fallback : value;
}
```

| Linha | O que faz |
|---|---|
| String value = System.getenv(name) | Lê a variável com esse nome |
| return value == null OU value.isBlank() ? fallback : value | Se a variável não existe ou está em branco, devolve o valor padrão (`fallback`); senão, devolve o valor da variável. O `? :` é um "se/senão" em uma linha |

## 3.4 PasswordHash.java: transformar a senha em hash

```java
public static String sha256(char[] password) {
    ByteBuffer encoded = null;
    byte[] bytes = null;
    try {
        encoded = StandardCharsets.UTF_8.newEncoder().encode(CharBuffer.wrap(password));
        bytes = new byte[encoded.remaining()];
        encoded.get(bytes);
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    } catch (NoSuchAlgorithmException | CharacterCodingException exception) {
        throw new IllegalStateException("Não foi possível calcular o hash SHA-256 da senha.", exception);
    } finally {
        if (bytes != null) Arrays.fill(bytes, (byte) 0);
        if (encoded != null && encoded.hasArray()) Arrays.fill(encoded.array(), (byte) 0);
        Arrays.fill(password, '\0');
    }
}
```

| Linha | O que faz |
|---|---|
| public static String sha256(char[] password) | Recebe a senha como vetor de caracteres (`char[]`) e devolve o hash em texto. Usar `char[]` em vez de `String` permite apagar a senha da memória depois |
| ByteBuffer encoded = null; byte[] bytes = null | Declaram as variáveis antes do `try`, para o `finally` poder limpá-las |
| StandardCharsets.UTF_8.newEncoder().encode(CharBuffer.wrap(password)) | Converte os caracteres em bytes, no padrão UTF-8. O SHA-256 trabalha com bytes, não com letras |
| bytes = new byte[encoded.remaining()]; encoded.get(bytes) | Copia os bytes para um vetor simples |
| MessageDigest.getInstance("SHA-256").digest(bytes) | Calcula o SHA-256 dos bytes: 32 bytes de resultado |
| HexFormat.of().formatHex(...) | Escreve esses 32 bytes em hexadecimal minúsculo, o que dá os 64 caracteres que o banco espera |
| catch (NoSuchAlgorithmException, CharacterCodingException) | Se o Java não tiver o SHA-256 ou a senha tiver caractere inválido, lança um erro com mensagem clara |
| finally { ... Arrays.fill(..., 0) } | O `finally` roda **sempre**. Aqui apaga (preenche com zero) os bytes, o buffer e a própria senha da memória, para ela não ficar esperando o coletor de lixo |

## 3.5 LoginFrame.java: a tela de login

O começo do arquivo monta o visual (faixa escura com "SGA", campos, botão). O que importa para a explicação é o método que trata o clique em **Entrar**:

```java
private void authenticate() {
    String login = loginField.getText().trim();
    char[] password = passwordField.getPassword();
    if (login.isEmpty() || password.length == 0) {
        JOptionPane.showMessageDialog(this, "Informe o login e a senha.", "Dados incompletos", JOptionPane.WARNING_MESSAGE);
        return;
    }
    String hash = PasswordHash.sha256(password);
```

| Linha | O que faz |
|---|---|
| loginField.getText().trim() | Lê o que foi digitado em Login e tira os espaços das pontas |
| passwordField.getPassword() | Lê a senha como `char[]` (e não como texto), pelo mesmo motivo de segurança |
| if (login.isEmpty() OU password.length == 0) | Se faltar login ou senha, mostra o aviso "Informe o login e a senha." e nem consulta o banco |
| PasswordHash.sha256(password) | Transforma a senha em hash. A partir daqui só existe o hash |

```java
    try {
        Usuario usuario = repository.autenticar(login, hash);
        if (usuario == null) {
            JOptionPane.showMessageDialog(this, "Login ou senha inválidos.", "Acesso negado", JOptionPane.ERROR_MESSAGE);
            passwordField.setText("");
            return;
        }
        if (!usuario.isCoordenador() && !usuario.isSecretario()) {
            JOptionPane.showMessageDialog(this, "O usuário possui um perfil não reconhecido.", "Acesso negado", JOptionPane.ERROR_MESSAGE);
            return;
        }
        new DashboardFrame(usuario, repository).setVisible(true);
        dispose();
    } catch (SQLException exception) {
        JOptionPane.showMessageDialog(this, exception.getMessage(), "Não foi possível acessar o banco", JOptionPane.ERROR_MESSAGE);
    } finally {
        passwordField.setText("");
    }
}
```

| Linha | O que faz |
|---|---|
| repository.autenticar(login, hash) | Chama a procedure `sp_LoginUsuario` (veja 3.6). Devolve um `Usuario` ou `null` |
| if (usuario == null) | `null` significa que login ou senha não conferem. A mensagem é a mesma nos dois casos, para **não revelar** qual dos dois errou |
| passwordField.setText("") | Limpa o campo de senha depois de uma tentativa |
| if (!isCoordenador E !isSecretario) | Proteção extra: se o banco devolvesse um perfil que o app não conhece, não deixa entrar. O `E` é escrito com dois `&` no Java |
| new DashboardFrame(usuario, repository).setVisible(true) | Abre a janela principal, passando o usuário logado. É o perfil dele que monta o menu |
| dispose() | Fecha a tela de login |
| catch (SQLException exception) | Se o banco estiver fora do ar ou a senha do MySQL estiver errada, mostra a mensagem do erro |
| finally { passwordField.setText("") } | Roda sempre: o campo de senha termina vazio |

## 3.6 SgaRepository.java: a única porta para o banco

### autenticar (login pela procedure)

```java
public Usuario autenticar(String login, String senhaHash) throws SQLException {
    try (Connection connection = DatabaseConfig.openConnection();
         CallableStatement call = connection.prepareCall("{call sp_LoginUsuario(?, ?)}")) {

        call.setString(1, login);
        call.setString(2, senhaHash);

        boolean hasResult = call.execute();

        while (true) {
            if (hasResult) {
                try (ResultSet rows = call.getResultSet()) {
                    if (rows != null && rows.next()) {
                        return new Usuario(
                                rows.getInt("id_usuario"),
                                rows.getString("nome"),
                                rows.getString("email"),
                                rows.getString("perfil")
                        );
                    }
                }
            } else if (call.getUpdateCount() == -1) {
                break;
            }

            hasResult = call.getMoreResults();
        }

        return null;
    }
}
```

| Linha | O que faz |
|---|---|
| try (Connection ...; CallableStatement call = ...) | Abre a conexão e prepara a chamada. O `try (...)` fecha as duas sozinho no final, mesmo se houver erro |
| "{call sp_LoginUsuario(?, ?)}" | A chamada da procedure, com dois parâmetros: login e hash |
| call.setString(1, login) e call.setString(2, senhaHash) | Preenchem os `?`. O valor digitado nunca é colado no comando |
| boolean hasResult = call.execute() | Executa. Devolve `true` se veio um conjunto de linhas |
| while (true) { ... } | Percorre os resultados da procedure até achar as linhas. O JDBC pode entregá-las depois de outros retornos, então não se pode supor que são as primeiras |
| if (rows != null E rows.next()) | `next()` anda para a primeira linha. Se existe, o login confere |
| new Usuario(rows.getInt("id_usuario"), ...) | Monta o objeto com os dados da linha, **lidos pelo nome da coluna**. Note que a senha não vem |
| else if (call.getUpdateCount() == -1) break | Quando não há mais resultados, sai do laço |
| hasResult = call.getMoreResults() | Vai ao próximo resultado |
| return null | Se terminou sem achar linha, o login é inválido: devolve `null` |

### consultarView (lista de views permitidas)

```java
public List<String[]> consultarView(String viewName) throws SQLException {
    String sql = switch (viewName) {
        case "vw_turmas_lotacao",
             "vw_desempenho_turma",
             "vw_faturamento_curso",
             "vw_cr_aluno" -> "SELECT * FROM " + viewName;

        default -> throw new IllegalArgumentException(
                "View não permitida: " + viewName
        );
    };

    try (Connection connection = DatabaseConfig.openConnection();
         Statement statement = connection.createStatement();
         ResultSet rows = statement.executeQuery(sql)) {

        return readRows(rows);
    }
}
```

| Linha | O que faz |
|---|---|
| String sql = switch (viewName) { ... } | O `switch` escolhe o que fazer conforme o nome recebido |
| case "vw_turmas_lotacao", ... -> "SELECT * FROM " + viewName | Só para esses nomes (a **lista permitida**) o código monta o `SELECT`. Como o nome tem que ser um dos da lista, aqui colar o nome é seguro |
| default -> throw new IllegalArgumentException(...) | Qualquer outro nome (por exemplo `usuario`, que tem senha) é recusado. Impede que a tela leia tabelas |
| statement.executeQuery(sql) | Roda a consulta |
| return readRows(rows) | Converte o resultado em lista de textos |

### Consultas com parâmetro (boletim) e procedures (matrícula)

```java
public List<String[]> consultarBoletimAluno(int alunoId) throws SQLException {
    String sql = "SELECT * FROM vw_boletim "
            + "WHERE id_aluno = ? ORDER BY semestre, disciplina";

    try (Connection connection = DatabaseConfig.openConnection();
         PreparedStatement statement = connection.prepareStatement(sql)) {

        statement.setInt(1, alunoId);

        try (ResultSet rows = statement.executeQuery()) {
            return readRows(rows);
        }
    }
}
```

| Linha | O que faz |
|---|---|
| "SELECT * FROM vw_boletim WHERE id_aluno = ? ORDER BY semestre, disciplina" | Boletim de um aluno, ordenado por semestre e disciplina. O `?` é o aluno |
| statement.setInt(1, alunoId) | Preenche o `?` com o número. Como é número e vai por parâmetro, não há risco de injeção |
| statement.executeQuery() | Roda e devolve as linhas |

```java
public void matricularAluno(int alunoId, int turmaId, int usuarioId)
        throws SQLException {

    try (Connection connection = DatabaseConfig.openConnection();
         CallableStatement call = connection.prepareCall(
                 "{call sp_matricular_aluno(?, ?, ?)}")) {

        call.setInt(1, alunoId);
        call.setInt(2, turmaId);
        call.setInt(3, usuarioId);

        call.execute();
    }
}
```

| Linha | O que faz |
|---|---|
| "{call sp_matricular_aluno(?, ?, ?)}" | Chama a procedure do Mykael com aluno, turma e o usuário que está matriculando |
| call.setInt(1..3, ...) | Preenche os três parâmetros |
| call.execute() | Executa. Se o banco recusar (turma lotada, sem pré-requisito, aluno trancado), vira uma `SQLException` com a mensagem do banco, e a tela só a mostra |

Os outros métodos seguem o mesmo molde: `historicoAluno` (procedure), `listarAlunos` e `listarCursos` (`SELECT` na `vw_alunos`), `cadastrarAluno`, `editarAluno` e `excluirAluno` (procedures do Guilherme), `lancarNotas`, `lancarExame` e `fecharSemestre` (procedures do Mykael).

### readRows: do resultado do banco para a tela

```java
private List<String[]> readRows(ResultSet rows) throws SQLException {
    int columnCount = rows.getMetaData().getColumnCount();

    List<String[]> result = new ArrayList<>();

    String[] columns = new String[columnCount];

    for (int i = 0; i < columnCount; i++) {
        columns[i] = rows.getMetaData().getColumnLabel(i + 1);
    }

    result.add(columns);

    while (rows.next()) {
        String[] values = new String[columnCount];

        for (int i = 0; i < columnCount; i++) {
            values[i] = rows.getString(i + 1);
        }

        result.add(values);
    }

    return result;
}
```

| Linha | O que faz |
|---|---|
| rows.getMetaData().getColumnCount() | Descobre quantas colunas o resultado tem |
| List<String[]> result = new ArrayList<>() | Cria a lista que será devolvida; cada item é uma linha (vetor de textos) |
| columns[i] = rows.getMetaData().getColumnLabel(i + 1) | Guarda o **nome** de cada coluna. As colunas do JDBC começam em 1, por isso `i + 1` |
| result.add(columns) | A primeira linha da lista é o cabeçalho |
| while (rows.next()) | Para cada linha do banco... |
| values[i] = rows.getString(i + 1) | ...lê cada coluna como texto (valores vazios viram `null`) |
| return result | Devolve tudo: cabeçalho e linhas. Assim qualquer view vira tabela na tela sem código específico |

## 3.7 DashboardFrame.java: o menu por perfil

```java
// Menu por perfil
addButton("Início", this::showInicio);

addSection("CONSULTAS");
addButton("Turmas", () -> {
    titulo("Turmas", "Vagas, matriculados e ocupação de cada turma");
    showView("vw_turmas_lotacao");
});
addButton("Boletim", this::showBoletim);
addButton("Histórico", this::showHistory);

addSection("SECRETARIA");
addButton("Matricular", this::enrollStudent);

// Secretário e Coordenador (acesso total) gerenciam alunos
if (usuario.isSecretario() || usuario.isCoordenador()) {
    addButton("Alunos", this::showAlunos);
}

// Funcionalidades exclusivas do Coordenador
if (usuario.isCoordenador()) {
    addSection("COORDENAÇÃO");
    addButton("Notas e exame", this::showNotas);
    addButton("Fechar semestre", this::closeSemester);
    addButton("Relatórios", this::showRelatorios);
    addButton("Auditoria", this::showAuditoria);
}
```

| Linha | O que faz |
|---|---|
| addButton("Início", this::showInicio) | Cria um botão no menu lateral. O segundo parâmetro é "o que fazer quando clicar" (aqui, chamar o método `showInicio`) |
| addSection("CONSULTAS") | Coloca um título cinza separando grupos de botões |
| addButton("Turmas", () -> { ... }) | Botão que muda o título da tela e mostra a view `vw_turmas_lotacao` |
| Boletim, Histórico, Matricular | Botões que **todo** usuário logado vê |
| if (usuario.isSecretario() OU usuario.isCoordenador()) | O botão Alunos aparece para os dois perfis (o Coordenador tem acesso total) |
| if (usuario.isCoordenador()) { ... } | **Este é o controle de acesso da tela**: os botões de notas, fechamento, relatórios e auditoria só são **criados** se o usuário for Coordenador. Para o Secretário eles não existem |

> Lembre de dizer ao professor: isto é a primeira camada. A segunda está no banco: as procedures conferem o perfil e recusam o Secretário mesmo que o botão existisse.

## 3.8 DashboardFrame.java: a matrícula sem digitar números

O método `enrollStudent` faz o que o enunciado pede de uma tela de matrícula, sem o usuário precisar saber IDs. Em blocos:

```java
List<String[]> alunos = repository.listarAlunos();
...
JComboBox<AlunoOpcao> comboAlunos = new JComboBox<>();

for (int i = 1; i < alunos.size(); i++) {
    String[] linha = alunos.get(i);
    String status = cell(linha, idxStatus);

    // Somente alunos ativos podem se matricular
    if ("Ativo".equalsIgnoreCase(status)) {
        comboAlunos.addItem(new AlunoOpcao(
                Integer.parseInt(cell(linha, idxIdAluno)),
                cell(linha, idxNome),
                cell(linha, idxRa),
                cell(linha, idxCurso)
        ));
    }
}
```

| Linha | O que faz |
|---|---|
| repository.listarAlunos() | Lê a view `vw_alunos` (todos os alunos) |
| new JComboBox<AlunoOpcao>() | Cria uma lista suspensa (caixa de seleção) cujos itens são objetos `AlunoOpcao` |
| for (int i = 1; ...) | Percorre as linhas. Começa em 1 porque a posição 0 é o cabeçalho |
| cell(linha, idxStatus) | Pega o texto da coluna `status` daquela linha. Os índices (`idxStatus`, `idxNome`...) foram descobertos antes **pelo nome da coluna**, com `findColumn` |
| if ("Ativo".equalsIgnoreCase(status)) | Só alunos ativos entram na lista. Trancados e formados nem aparecem. O banco também recusaria (RN09) |
| comboAlunos.addItem(new AlunoOpcao(...)) | Adiciona o aluno na lista, guardando o id por trás; o que aparece é "nome, RA e curso" |

```java
List<String[]> turmas = repository.consultarView("vw_turmas_lotacao");
...
JComboBox<TurmaOpcao> comboTurmas = new JComboBox<>();

for (int i = 1; i < turmas.size(); i++) {
    String[] linha = turmas.get(i);
    String status = cell(linha, idxStatusTurma);
    int vagasRestantes = Integer.parseInt(cell(linha, idxVagasRestantes));

    // Somente turmas abertas com vagas disponíveis
    if ("Aberta".equalsIgnoreCase(status)
            && vagasRestantes > 0) {
        comboTurmas.addItem(new TurmaOpcao(...));
    }
}
```

| Linha | O que faz |
|---|---|
| repository.consultarView("vw_turmas_lotacao") | Lê as turmas com vagas, matriculados e vagas restantes |
| Integer.parseInt(cell(linha, idxVagasRestantes)) | Converte o texto "2" no número 2 |
| if ("Aberta" ... E vagasRestantes > 0) | Só turmas abertas e com vaga aparecem. Assim a tela já evita o erro mais comum, mas **a regra de verdade (RN05) continua no trigger** do banco |

```java
int confirmar = JOptionPane.showConfirmDialog(
        this,
        "Confirma a matrícula?\n\n"
        + "Aluno: " + alunoSelecionado.nome()
        + " (RA: " + alunoSelecionado.ra() + ")\n"
        + "Turma: " + turmaSelecionada.disciplina()
        + " - " + turmaSelecionada.semestre(),
        "Confirmar matrícula",
        JOptionPane.YES_NO_OPTION,
        JOptionPane.QUESTION_MESSAGE
);

if (confirmar != JOptionPane.YES_OPTION) {
    return;
}

// Chama a procedure do Mykael
repository.matricularAluno(
        alunoSelecionado.id(),
        turmaSelecionada.id(),
        usuario.id()
);
```

| Linha | O que faz |
|---|---|
| JOptionPane.showConfirmDialog(...) | Mostra "Confirma a matrícula?" com o aluno e a turma escolhidos e botões Sim e Não |
| if (confirmar != JOptionPane.YES_OPTION) return | Se não clicou em Sim, desiste, sem gravar nada |
| repository.matricularAluno(alunoSelecionado.id(), turmaSelecionada.id(), usuario.id()) | Chama a procedure. O terceiro parâmetro é o usuário logado, que fica registrado na matrícula |
| catch (SQLException exception) { showError(exception); } | No fim do método, qualquer erro do banco (por exemplo, "Falta pré-requisito...") aparece numa caixa vermelha |

## 3.9 AlunosFrame.java: cadastro, edição e exclusão

A janela mostra a `vw_alunos` numa tabela e tem os botões Cadastrar, Editar, Excluir e Atualizar. Cada ação chama uma procedure do Guilherme. O cadastro, por exemplo:

```java
private void cadastrar() {
    DadosAluno dados = exibirFormulario("Cadastrar aluno", null);

    if (dados == null) {
        return;
    }

    try {
        repository.cadastrarAluno(
                dados.ra(),
                dados.nome(),
                dados.cpf(),
                dados.email(),
                dados.nascimento(),
                dados.idCurso()
        );

        JOptionPane.showMessageDialog(
                this, "Aluno cadastrado com sucesso."
        );

        atualizarTabela();

    } catch (Exception e) {
        mostrarErro(e);
    }
}
```

| Linha | O que faz |
|---|---|
| exibirFormulario("Cadastrar aluno", null) | Abre o formulário vazio (RA, nome, CPF, e-mail, nascimento, curso, status). O `null` significa "não é edição, não há dados atuais". Se o usuário cancelar, devolve `null` |
| if (dados == null) return | Cancelou: não faz nada |
| repository.cadastrarAluno(...) | Chama `sp_cadastrar_aluno`. A tela **não valida CPF nem e-mail**: quem valida é a procedure |
| JOptionPane.showMessageDialog(... "Aluno cadastrado com sucesso.") | Avisa o sucesso |
| atualizarTabela() | Recarrega a lista, que já mostra o aluno novo |
| catch (Exception e) { mostrarErro(e); } | Se a procedure recusar (RA repetido, CPF inválido...), mostra a mensagem do banco |

A exclusão (`excluirSelecionado`) pede confirmação ("Deseja realmente excluir o aluno ...?") e chama `sp_excluir_aluno`. Se o aluno tem matrículas, o banco responde "Aluno tem matrículas: tranque o aluno em vez de excluir." e a tela mostra essa frase.

# 4. Como as peças se encaixam

```text
  Usuario digita login e senha
          |
   LoginFrame --(senha vira hash SHA-256 no app)--> SgaRepository.autenticar
          |                                              |
          |                                   CALL sp_LoginUsuario (Mykael)
          |                                              |
          +<------ Usuario (id, nome, e-mail, perfil) ---+
          |
   DashboardFrame monta o menu conforme o perfil
          |
          +-- Consultas: SELECT nas views do Diego (vw_boletim, vw_turmas_lotacao...)
          +-- Matricular: CALL sp_matricular_aluno (Mykael)
          +-- Alunos: CALL sp_cadastrar/editar/excluir_aluno (Guilherme)
          +-- Coordenador: notas, exame, fechamento, relatorios, auditoria
```

Em uma frase: **a interface é uma "casca"** entre o usuário e o banco. Tudo que importa (regras, cálculos, permissões) está no banco, e a tela apenas coleta, chama e mostra.

# 5. Perguntas que o professor pode fazer (com respostas)

**1. Como a interface se comunica com o banco?**
Só por duas vias: `CALL` de procedures e `SELECT` em views, sempre com parâmetros. Não há `INSERT`, `UPDATE` nem `DELETE` no código Java. Tudo passa pela classe `SgaRepository`.

**2. O que é injeção de SQL e como vocês evitam?**
É quando o usuário digita um trecho de SQL e o programa o cola na consulta. Evitamos usando `PreparedStatement` e `CallableStatement`, em que o valor vai separado do comando, em um parâmetro `?`. A única consulta com texto montado é a de views sem parâmetro, e ela só aceita nomes de uma lista permitida.

**3. Onde fica a senha do MySQL? Está no código?**
Não. Fica em variáveis de ambiente (`SGA_DB_USER` e `SGA_DB_PASSWORD`), lidas pela classe `DatabaseConfig`. Assim não vai para o GitHub.

**4. Como funciona o login?**
O usuário digita login e senha. O aplicativo calcula o SHA-256 da senha e chama a procedure `sp_LoginUsuario` com o login e o hash. O banco compara com o hash guardado e devolve id, nome, e-mail e perfil, nunca a senha. Se não conferir, devolve vazio e a tela diz "Login ou senha inválidos".

**5. Por que a mensagem de login inválido não diz qual campo errou?**
Para não ajudar quem tenta adivinhar: dizer "usuário não existe" revelaria quais logins são válidos.

**6. Por que a senha é lida como `char[]` e apagada?**
Porque uma `String` fica na memória até o coletor de lixo e não dá para apagá-la. Um `char[]` pode ser preenchido com zeros logo depois do uso, reduzindo o tempo em que a senha existe na memória.

**7. Como o controle de acesso por perfil é feito?**
Em duas camadas. Na tela, o menu só cria os botões de notas, fechamento, relatórios e auditoria se o usuário for Coordenador. No banco, as procedures `sp_lancar_notas`, `sp_lancar_exame` e `sp_fechar_semestre` conferem o perfil e recusam o Secretário. Mesmo que alguém contornasse a tela, o banco barra.

**8. O que o Secretário consegue fazer?**
Consultar turmas, boletim e histórico, cadastrar, editar e excluir alunos, e matricular. Não vê notas, fechamento de semestre, relatórios de desempenho e faturamento, nem a auditoria.

**9. A tela valida os dados ou o banco?**
Os dois, com papéis diferentes. A tela faz verificações de conforto (por exemplo, nota entre 0 e 10, ou mostrar só alunos ativos). A regra de verdade está no banco, que recusa o que for inválido mesmo se a tela falhar.

**10. Como a tela mostra o erro de uma regra de negócio, como "turma lotada"?**
O banco levanta um erro com a mensagem escrita por nós (`SIGNAL`). O JDBC o entrega como `SQLException`, e a tela mostra `getMessage()` numa caixa de erro. Não há tradução de erro técnico na tela.

**11. Por que a matrícula usa listas e não campos para digitar o id do aluno e da turma?**
Para evitar erro de digitação e o usuário não precisar saber números. As listas mostram só alunos ativos e turmas abertas com vaga, e o id fica guardado por trás de cada item.

**12. Por que as colunas são lidas pelo nome e não pela posição?**
Se alguém acrescentar uma coluna numa view, a posição das outras muda e a tela quebraria. Pelo nome, continua funcionando.

**13. O que acontece se o MySQL estiver desligado?**
O `getConnection` lança `SQLException` e a tela mostra uma caixa "Não foi possível acessar o banco" com a mensagem do erro, em vez de travar.

**14. Por que Java e Swing?**
O enunciado pede uma interface desktop sem PHP. Java com Swing e JDBC dá acesso direto ao MySQL pelo driver Connector/J e roda em qualquer computador com JDK 17.

**15. (Armadilha) O SHA-256 no aplicativo não é só "mover" o problema? Quem rouba o hash não consegue entrar?**
Com o hash, quem tiver acesso ao banco pode tentar adivinhar senhas fracas (ataque com tabelas prontas). Numa aplicação real o ideal seria um algoritmo próprio para senhas, com sal (bcrypt), e conexão criptografada entre app e banco. É uma limitação conhecida; o enunciado pede hash SHA-256 ou BCRYPT e cumprimos com SHA-256.

# 6. Passo a passo para mostrar funcionando

Antes de começar: rode o `SGA_completo.sql` no Workbench (cria o banco do zero), defina as variáveis `SGA_DB_USER` e `SGA_DB_PASSWORD` e abra o app (instruções no "Roteiro do grupo"). Senha de todos os usuários de teste: `Senha@123`.

1. **Login inválido.** Digite `coord.ana` e uma senha errada. Aparece "Login ou senha inválidos." (Acesso negado). Ótimo para mostrar que não diz qual campo errou.
2. **Campos vazios.** Clique em Entrar sem a senha. Aparece "Informe o login e a senha." sem consultar o banco.
3. **Entrar como Secretário** (`sec.carla`). Mostre o menu: Início, Turmas, Boletim, Histórico, Matricular e Alunos. Não há Notas e exame, Fechar semestre, Relatórios nem Auditoria. O painel Início não tem o cartão de faturamento.
4. **Matrícula barrada pelo banco.** Menu **Matricular**: aluno Rafael Domingues, turma Estruturas de Dados. Aparece "Falta pré-requisito: o aluno não foi aprovado em Algoritmos." Explique: a tela não sabe de pré-requisito; quem decidiu foi a procedure.
5. **Matrícula válida.** Aluno Queila Macedo, turma Banco de Dados. Aparece "Matrícula realizada com sucesso!".
6. **Cadastro de aluno.** Menu **Alunos**, **Cadastrar aluno**. Preencha RA `2026099`, um nome, CPF `30000000099` (11 dígitos), e-mail, nascimento `2005-03-21`, e escolha o curso. Depois tente cadastrar outro com o mesmo RA: "Já existe um aluno com este RA."
7. **Exclusão recusada.** Na lista, selecione a Alice Monteiro (id 1) e **Excluir selecionado**: "Aluno tem matrículas: tranque o aluno em vez de excluir."
8. **Boletim e histórico.** Menu **Boletim** e digite 2; menu **Histórico** e digite 3 (mostra o CR no topo).
9. **Mostrar o código.** No IntelliJ, abra `SgaRepository.java` no método `autenticar` e mostre que a única coisa enviada é o login e o hash; e o `DashboardFrame.java` no bloco `if (usuario.isCoordenador())`.

Depois de qualquer ensaio, rode o `SGA_completo.sql` de novo para o banco voltar ao início.

# 7. Se você só tem 5 minutos antes de apresentar

1. Java 17, Swing, JDBC e Maven; a aparência usa a biblioteca FlatLaf.
2. A tela não tem regra de negócio: só chama procedures e consulta views.
3. Nenhum INSERT, UPDATE ou DELETE no Java; sempre com parâmetros, sem juntar texto.
4. Todo acesso ao banco passa pela classe `SgaRepository`.
5. A senha do MySQL fica em variável de ambiente, fora do código.
6. No login, a senha vira SHA-256 no app; só o hash vai para o banco, que devolve o perfil.
7. O erro de login não diz se errou o usuário ou a senha.
8. O menu muda por perfil, mas o banco também barra: duas camadas.
9. Na matrícula, listas mostram só alunos ativos e turmas abertas com vaga; o banco confere pré-requisito e vagas.
10. A mensagem de erro que aparece na tela é a que o banco escreveu.
