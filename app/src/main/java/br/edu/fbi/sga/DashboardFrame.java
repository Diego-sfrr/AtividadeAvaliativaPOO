package br.edu.fbi.sga;

import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.JTextField;
import javax.swing.table.DefaultTableModel;
import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.sql.SQLException;
import java.util.List;

@SuppressWarnings("serial")
public final class DashboardFrame extends JFrame {
    private final Usuario usuario;
    private final SgaRepository repository;
    private final JPanel actions = new JPanel(new FlowLayout(FlowLayout.LEFT));
    private final JPanel content = new JPanel(new BorderLayout());

    public DashboardFrame(Usuario usuario, SgaRepository repository) {
        super("SGA | Painel");
        this.usuario = usuario;
        this.repository = repository;
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(1000, 620);
        setLocationRelativeTo(null);
        add(new JLabel("  Olá, " + usuario.nome() + " | Perfil: " + usuario.perfil()), BorderLayout.NORTH);
        add(actions, BorderLayout.SOUTH);
        add(content, BorderLayout.CENTER);
        addButton("Turmas", () -> showView("vw_turmas_lotacao"));
        addButton("Boletim", this::showBoletim);
        addButton("Matricular", this::enrollStudent);
        addButton("Histórico", this::showHistory);
        if (usuario.isCoordenador()) {
            addButton("Desempenho", () -> showView("vw_desempenho_turma"));
            addButton("Faturamento", () -> showView("vw_faturamento_curso"));
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

    private void showView(String viewName) {
        try {
            showRows(repository.consultarView(viewName));
        } catch (SQLException | IllegalArgumentException exception) {
            showError(exception);
        }
    }

    private void showHistory() {
        String value = JOptionPane.showInputDialog(this, "ID do aluno:", "Consultar histórico", JOptionPane.QUESTION_MESSAGE);
        if (value == null) return;
        try {
            showRows(repository.historicoAluno(Integer.parseInt(value.trim())));
        } catch (NumberFormatException exception) {
            JOptionPane.showMessageDialog(this, "Informe um ID numérico.", "Valor inválido", JOptionPane.WARNING_MESSAGE);
        } catch (SQLException exception) {
            showError(exception);
        }
    }

    private void showBoletim() {
        try {
            int alunoId = askInt("ID do aluno para consultar o boletim:");
            showRows(repository.consultarBoletimAluno(alunoId));
        } catch (CancelledInput ignored) {
        } catch (NumberFormatException exception) {
            JOptionPane.showMessageDialog(this, "Informe um ID numérico.", "Valor inválido", JOptionPane.WARNING_MESSAGE);
        } catch (SQLException exception) {
            showError(exception);
        }
    }

    private void enrollStudent() {
        try {
            int alunoId = askInt("ID do aluno:");
            int turmaId = askInt("ID da turma:");
            repository.matricularAluno(alunoId, turmaId, usuario.id());
            JOptionPane.showMessageDialog(this, "Matrícula realizada.");
        } catch (CancelledInput ignored) {
        } catch (Exception exception) {
            showError(exception);
        }
    }

    private void launchGrades() {
        try {
            int id = askInt("ID da matrícula:");
            double n1 = askDouble("Nota N1 (0 a 10):");
            double n2 = askDouble("Nota N2 (0 a 10):");
            int faltas = askInt("Quantidade de faltas:");
            repository.lancarNotas(id, n1, n2, faltas, usuario.id());
            JOptionPane.showMessageDialog(this, "Notas enviadas ao banco.");
        } catch (CancelledInput ignored) {
        } catch (Exception exception) {
            showError(exception);
        }
    }

    private void launchExam() {
        try {
            int id = askInt("ID da matrícula:");
            double grade = askDouble("Nota do exame (0 a 10):");
            repository.lancarExame(id, grade, usuario.id());
            JOptionPane.showMessageDialog(this, "Nota do exame enviada ao banco.");
        } catch (CancelledInput ignored) {
        } catch (Exception exception) {
            showError(exception);
        }
    }

    private void closeSemester() {
        String semester = JOptionPane.showInputDialog(this, "Semestre (ex.: 2026.2):", "Fechar semestre", JOptionPane.QUESTION_MESSAGE);
        if (semester == null || semester.isBlank()) return;
        try {
            repository.fecharSemestre(semester.trim(), usuario.id());
            JOptionPane.showMessageDialog(this, "Solicitação de fechamento concluída.");
        } catch (SQLException exception) {
            showError(exception);
        }
    }

    private int askInt(String prompt) throws CancelledInput {
        String value = JOptionPane.showInputDialog(this, prompt);
        if (value == null) throw new CancelledInput();
        return Integer.parseInt(value.trim());
    }

    private double askDouble(String prompt) throws CancelledInput {
        String value = JOptionPane.showInputDialog(this, prompt);
        if (value == null) throw new CancelledInput();
        return Double.parseDouble(value.trim().replace(',', '.'));
    }

    private void showRows(List<String[]> rows) {
        content.removeAll();
        if (rows.isEmpty()) {
            content.add(new JLabel("Nenhum registro retornado."), BorderLayout.NORTH);
        } else {
            String[] headers = rows.get(0);
            Object[][] data = rows.subList(1, rows.size()).stream().map(row -> (Object[]) row).toArray(Object[][]::new);
            JTable table = new JTable(new DefaultTableModel(data, headers) {
                @Override public boolean isCellEditable(int row, int column) { return false; }
            });
            content.add(new JScrollPane(table), BorderLayout.CENTER);
        }
        content.revalidate();
        content.repaint();
    }

    private void showError(Exception exception) {
        JOptionPane.showMessageDialog(this, exception.getMessage(), "Operação não concluída", JOptionPane.ERROR_MESSAGE);
    }

    @SuppressWarnings("serial")
    private static final class CancelledInput extends Exception { }
}
