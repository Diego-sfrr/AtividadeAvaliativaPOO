
package br.edu.fbi.sga;

import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.table.DefaultTableModel;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.GridLayout;

import java.sql.SQLException;
import java.util.List;

@SuppressWarnings("serial")
public final class DashboardFrame extends JFrame {

    private final Usuario usuario;
    private final SgaRepository repository;

    private final JPanel actions =
            new JPanel(new FlowLayout(FlowLayout.LEFT));

    private final JPanel content =
            new JPanel(new BorderLayout());

    public DashboardFrame(Usuario usuario, SgaRepository repository) {
        super("SGA | Painel");

        this.usuario = usuario;
        this.repository = repository;

        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(1000, 620);
        setLocationRelativeTo(null);

        add(new JLabel("  Olá, " + usuario.nome()
                + " | Perfil: " + usuario.perfil()), BorderLayout.NORTH);

        add(actions, BorderLayout.SOUTH);
        add(content, BorderLayout.CENTER);

        addButton("Turmas", () ->
                showView("vw_turmas_lotacao"));

        addButton("Boletim", this::showBoletim);
        addButton("Matricular", this::enrollStudent);
        addButton("Histórico", this::showHistory);

        // Funcionalidades do Secretário
        if (usuario.isSecretario()) {
            addButton("Alunos", this::showAlunos);
        }

        // Funcionalidades do Coordenador
        if (usuario.isCoordenador()) {

            addButton("Desempenho", () ->
                    showView("vw_desempenho_turma"));

            addButton("Faturamento", () ->
                    showView("vw_faturamento_curso"));

            addButton("Lançar notas", this::launchGrades);
            addButton("Lançar exame", this::launchExam);
            addButton("Fechar semestre", this::closeSemester);
        }

        addButton("Sair", () -> {
            new LoginFrame().setVisible(true);
            dispose();
        });
    }

    private void addButton(String label, Runnable action) {
        JButton button = new JButton(label);
        button.addActionListener(event -> action.run());
        actions.add(button);
    }

    // ==========================================
    // ALUNOS
    // ==========================================

    private void showAlunos() {
        new AlunosFrame(repository).setVisible(true);
    }

    // ==========================================
    // CONSULTAS
    // ==========================================

    private void showView(String viewName) {
        try {
            showRows(repository.consultarView(viewName));
        } catch (SQLException | IllegalArgumentException exception) {
            showError(exception);
        }
    }

    private void showHistory() {

        String value = JOptionPane.showInputDialog(
                this,
                "ID do aluno:",
                "Consultar histórico",
                JOptionPane.QUESTION_MESSAGE
        );

        if (value == null) {
            return;
        }

        try {
            showRows(repository.historicoAluno(
                    Integer.parseInt(value.trim())));

        } catch (NumberFormatException exception) {
            JOptionPane.showMessageDialog(
                    this,
                    "Informe um ID numérico.",
                    "Valor inválido",
                    JOptionPane.WARNING_MESSAGE
            );

        } catch (SQLException exception) {
            showError(exception);
        }
    }

    private void showBoletim() {

        try {
            int alunoId = askInt(
                    "ID do aluno para consultar o boletim:");

            showRows(repository.consultarBoletimAluno(alunoId));

        } catch (CancelledInput ignored) {
        } catch (NumberFormatException exception) {
            JOptionPane.showMessageDialog(
                    this,
                    "Informe um ID numérico.",
                    "Valor inválido",
                    JOptionPane.WARNING_MESSAGE
            );

        } catch (SQLException exception) {
            showError(exception);
        }
    }

    // ==========================================
    // MATRÍCULAS
    // ==========================================

    private void enrollStudent() {

        try {

            // Busca os alunos cadastrados
            List<String[]> alunos = repository.listarAlunos();

            if (alunos == null || alunos.size() <= 1) {
                JOptionPane.showMessageDialog(
                        this,
                        "Não existem alunos cadastrados.",
                        "Matrícula",
                        JOptionPane.INFORMATION_MESSAGE
                );
                return;
            }

            // Identifica as colunas da view de alunos
            String[] colunasAlunos = alunos.get(0);

            int idxIdAluno = findColumn(colunasAlunos, "id_aluno");
            int idxRa = findColumn(colunasAlunos, "ra");
            int idxNome = findColumn(colunasAlunos, "nome");
            int idxCurso = findColumn(colunasAlunos, "curso");
            int idxStatus = findColumn(colunasAlunos, "status");

            // Cria a seleção de alunos
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

            if (comboAlunos.getItemCount() == 0) {
                JOptionPane.showMessageDialog(
                        this,
                        "Não existem alunos ativos disponíveis.",
                        "Matrícula",
                        JOptionPane.INFORMATION_MESSAGE
                );
                return;
            }

            // Busca as turmas e sua disponibilidade
            List<String[]> turmas =
                    repository.consultarView("vw_turmas_lotacao");

            if (turmas == null || turmas.size() <= 1) {
                JOptionPane.showMessageDialog(
                        this,
                        "Não existem turmas cadastradas.",
                        "Matrícula",
                        JOptionPane.INFORMATION_MESSAGE
                );
                return;
            }

            String[] colunasTurmas = turmas.get(0);

            int idxIdTurma = findColumn(colunasTurmas, "id_turma");
            int idxDisciplina = findColumn(colunasTurmas, "disciplina");
            int idxProfessor = findColumn(colunasTurmas, "professor");
            int idxSemestre = findColumn(colunasTurmas, "semestre");
            int idxStatusTurma = findColumn(colunasTurmas, "status");
            int idxVagasRestantes =
                    findColumn(colunasTurmas, "vagas_restantes");

            // Cria a seleção de turmas
            JComboBox<TurmaOpcao> comboTurmas = new JComboBox<>();

            for (int i = 1; i < turmas.size(); i++) {

                String[] linha = turmas.get(i);

                String status = cell(linha, idxStatusTurma);

                int vagasRestantes =
                        Integer.parseInt(cell(linha, idxVagasRestantes));

                // Somente turmas abertas com vagas disponíveis
                if ("Aberta".equalsIgnoreCase(status)
                        && vagasRestantes > 0) {

                    comboTurmas.addItem(new TurmaOpcao(
                            Integer.parseInt(cell(linha, idxIdTurma)),
                            cell(linha, idxDisciplina),
                            cell(linha, idxProfessor),
                            cell(linha, idxSemestre),
                            vagasRestantes
                    ));
                }
            }

            if (comboTurmas.getItemCount() == 0) {
                JOptionPane.showMessageDialog(
                        this,
                        "Não existem turmas abertas com vagas disponíveis.",
                        "Matrícula",
                        JOptionPane.INFORMATION_MESSAGE
                );
                return;
            }

            // Monta a janela de seleção
            JPanel painel = new JPanel(new GridLayout(0, 1, 6, 6));

            painel.add(new JLabel("Selecione o aluno:"));
            painel.add(comboAlunos);

            painel.add(new JLabel("Selecione a turma:"));
            painel.add(comboTurmas);

            int escolha = JOptionPane.showConfirmDialog(
                    this,
                    painel,
                    "Realizar matrícula",
                    JOptionPane.OK_CANCEL_OPTION,
                    JOptionPane.PLAIN_MESSAGE
            );

            if (escolha != JOptionPane.OK_OPTION) {
                return;
            }

            AlunoOpcao alunoSelecionado =
                    (AlunoOpcao) comboAlunos.getSelectedItem();

            TurmaOpcao turmaSelecionada =
                    (TurmaOpcao) comboTurmas.getSelectedItem();

            if (alunoSelecionado == null || turmaSelecionada == null) {
                return;
            }

            // Confirma a operação antes de inserir
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

            JOptionPane.showMessageDialog(
                    this,
                    "Matrícula realizada com sucesso!",
                    "Matrícula",
                    JOptionPane.INFORMATION_MESSAGE
            );

        } catch (SQLException exception) {
            showError(exception);

        } catch (IllegalArgumentException exception) {
            showError(exception);
        }
    }

    // ==========================================
    // AUXILIARES DA MATRÍCULA
    // ==========================================

    private int findColumn(String[] headers, String name)
            throws SQLException {

        for (int i = 0; i < headers.length; i++) {

            if (name.equalsIgnoreCase(headers[i])) {
                return i;
            }
        }

        throw new SQLException(
                "A coluna '" + name
                + "' não foi encontrada no resultado do banco."
        );
    }

    private String cell(String[] row, int index) {

        if (index < 0 || index >= row.length || row[index] == null) {
            return "";
        }

        return row[index].trim();
    }

    // ==========================================
    // NOTAS E EXAME
    // ==========================================

    private void launchGrades() {

        try {
            int id = askInt("ID da matrícula:");
            double n1 = askDouble("Nota N1 (0 a 10):");
            double n2 = askDouble("Nota N2 (0 a 10):");
            int faltas = askInt("Quantidade de faltas:");

            repository.lancarNotas(
                    id, n1, n2, faltas, usuario.id());

            JOptionPane.showMessageDialog(
                    this,
                    "Notas enviadas ao banco."
            );

        } catch (CancelledInput ignored) {
        } catch (Exception exception) {
            showError(exception);
        }
    }

    private void launchExam() {

        try {
            int id = askInt("ID da matrícula:");
            double grade = askDouble("Nota do exame (0 a 10):");

            repository.lancarExame(
                    id, grade, usuario.id());

            JOptionPane.showMessageDialog(
                    this,
                    "Nota do exame enviada ao banco."
            );

        } catch (CancelledInput ignored) {
        } catch (Exception exception) {
            showError(exception);
        }
    }

    // ==========================================
    // FECHAMENTO DO SEMESTRE
    // ==========================================

    private void closeSemester() {

        String semester = JOptionPane.showInputDialog(
                this,
                "Semestre (ex.: 2026.2):",
                "Fechar semestre",
                JOptionPane.QUESTION_MESSAGE
        );

        if (semester == null || semester.isBlank()) {
            return;
        }

        try {
            repository.fecharSemestre(
                    semester.trim(), usuario.id());

            JOptionPane.showMessageDialog(
                    this,
                    "Solicitação de fechamento concluída."
            );

        } catch (SQLException exception) {
            showError(exception);
        }
    }

    // ==========================================
    // ENTRADA DE DADOS
    // ==========================================

    private int askInt(String prompt) throws CancelledInput {

        String value = JOptionPane.showInputDialog(this, prompt);

        if (value == null) {
            throw new CancelledInput();
        }

        return Integer.parseInt(value.trim());
    }

    private double askDouble(String prompt) throws CancelledInput {

        String value = JOptionPane.showInputDialog(this, prompt);

        if (value == null) {
            throw new CancelledInput();
        }

        return Double.parseDouble(
                value.trim().replace(',', '.'));
    }

    // ==========================================
    // EXIBIÇÃO DAS CONSULTAS
    // ==========================================

    private void showRows(List<String[]> rows) {

        content.removeAll();

        if (rows.isEmpty() || rows.size() == 1) {

            content.add(
                    new JLabel("Nenhum registro retornado."),
                    BorderLayout.NORTH
            );

        } else {

            String[] headers = rows.get(0);

            Object[][] data = rows.subList(1, rows.size())
                    .stream()
                    .map(row -> (Object[]) row)
                    .toArray(Object[][]::new);

            JTable table = new JTable(
                    new DefaultTableModel(data, headers) {

                        @Override
                        public boolean isCellEditable(
                                int row, int column) {
                            return false;
                        }
                    }
            );

            content.add(
                    new JScrollPane(table),
                    BorderLayout.CENTER
            );
        }

        content.revalidate();
        content.repaint();
    }

    // ==========================================
    // MENSAGENS DE ERRO
    // ==========================================

    private void showError(Exception exception) {

        JOptionPane.showMessageDialog(
                this,
                exception.getMessage(),
                "Operação não concluída",
                JOptionPane.ERROR_MESSAGE
        );
    }

    // ==========================================
    // OPÇÕES DOS COMBOS
    // ==========================================

    private record AlunoOpcao(
            int id,
            String nome,
            String ra,
            String curso) {

        @Override
        public String toString() {
            return nome + " | RA: " + ra + " | " + curso;
        }
    }

    private record TurmaOpcao(
            int id,
            String disciplina,
            String professor,
            String semestre,
            int vagasRestantes) {

        @Override
        public String toString() {
            return "Turma " + id
                    + " | " + disciplina
                    + " | " + semestre
                    + " | Prof.: " + professor
                    + " | Vagas: " + vagasRestantes;
        }
    }

    @SuppressWarnings("serial")
    private static final class CancelledInput extends Exception {
    }
}
