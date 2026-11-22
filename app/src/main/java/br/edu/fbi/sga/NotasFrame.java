package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.JTextField;
import javax.swing.ListSelectionModel;
import javax.swing.table.DefaultTableModel;

/**
 * Tela do Coordenador para lançar notas (N1, N2, faltas) e exame.
 * Lê as matrículas da turma pela vw_boletim e grava pelas procedures
 * sp_lancar_notas e sp_lancar_exame; média e situação vêm do banco.
 */
public final class NotasFrame extends JFrame {

    private static final String[] COLUNAS_EXIBIDAS = {
        "id_matricula", "ra", "aluno", "n1", "n2", "exame",
        "media_final", "faltas", "total_aulas", "frequencia", "situacao"
    };

    private final SgaRepository repository;
    private final int usuarioId;

    private final JComboBox<TurmaOpcao> comboTurmas = new JComboBox<>();
    private final JTable tabela = new JTable();
    private final JLabel aviso = new JLabel(" ");

    /** Linhas completas da turma atual (índice 0 = cabeçalho). */
    private List<String[]> linhas = List.of();

    public NotasFrame(SgaRepository repository, int usuarioId) {
        super("SGA | Notas e exame");

        this.repository = repository;
        this.usuarioId = usuarioId;

        setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        setSize(1100, 560);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout(8, 8));

        JPanel topo = new JPanel(new FlowLayout(FlowLayout.LEFT));
        topo.add(new JLabel("Turma (aberta):"));
        topo.add(comboTurmas);
        add(topo, BorderLayout.NORTH);

        tabela.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        tabela.setAutoCreateRowSorter(true);
        tabela.setFillsViewportHeight(true);
        add(new JScrollPane(tabela), BorderLayout.CENTER);

        JPanel rodape = new JPanel(new BorderLayout());
        JPanel botoes = new JPanel(new FlowLayout(FlowLayout.LEFT));

        JButton notas = new JButton("Lançar notas");
        JButton exame = new JButton("Lançar exame");
        JButton atualizar = new JButton("Atualizar");
        JButton fechar = new JButton("Fechar");

        notas.addActionListener(e -> lancarNotas());
        exame.addActionListener(e -> lancarExame());
        atualizar.addActionListener(e -> carregarMatriculas());
        fechar.addActionListener(e -> dispose());

        botoes.add(notas);
        botoes.add(exame);
        botoes.add(atualizar);
        botoes.add(fechar);

        rodape.add(botoes, BorderLayout.NORTH);
        rodape.add(aviso, BorderLayout.SOUTH);
        add(rodape, BorderLayout.SOUTH);

        carregarTurmas();
        comboTurmas.addActionListener(e -> carregarMatriculas());
        carregarMatriculas();
    }

    // ------------------------------------------------------------
    // Carga de dados
    // ------------------------------------------------------------

    private void carregarTurmas() {
        try {
            List<String[]> turmas = repository.consultarView("vw_turmas_lotacao");
            String[] c = turmas.get(0);

            int iId = Tabelas.coluna(c, "id_turma");
            int iDisc = Tabelas.coluna(c, "disciplina");
            int iSem = Tabelas.coluna(c, "semestre");
            int iProf = Tabelas.coluna(c, "professor");
            int iStatus = Tabelas.coluna(c, "status");

            for (int i = 1; i < turmas.size(); i++) {
                String[] l = turmas.get(i);
                if ("Aberta".equalsIgnoreCase(Tabelas.celula(l, iStatus))) {
                    comboTurmas.addItem(new TurmaOpcao(
                            Integer.parseInt(Tabelas.celula(l, iId)),
                            Tabelas.celula(l, iDisc),
                            Tabelas.celula(l, iSem),
                            Tabelas.celula(l, iProf)));
                }
            }

            if (comboTurmas.getItemCount() == 0) {
                aviso.setText("  Não há turmas abertas.");
            }
        } catch (SQLException e) {
            mostrarErro(e);
        }
    }

    private void carregarMatriculas() {
        TurmaOpcao turma = (TurmaOpcao) comboTurmas.getSelectedItem();
        if (turma == null) {
            tabela.setModel(new DefaultTableModel());
            linhas = List.of();
            return;
        }

        try {
            linhas = repository.boletimDaTurma(turma.id());
            String[] c = linhas.get(0);

            List<Integer> indices = new ArrayList<>();
            for (String nome : COLUNAS_EXIBIDAS) {
                int i = Tabelas.coluna(c, nome);
                if (i >= 0) {
                    indices.add(i);
                }
            }

            String[] cabecalho = new String[indices.size()];
            for (int j = 0; j < cabecalho.length; j++) {
                cabecalho[j] = c[indices.get(j)];
            }

            DefaultTableModel modelo = new DefaultTableModel(cabecalho, 0) {
                @Override
                public boolean isCellEditable(int row, int column) {
                    return false;
                }
            };

            for (int i = 1; i < linhas.size(); i++) {
                String[] origem = linhas.get(i);
                String[] destino = new String[indices.size()];
                for (int j = 0; j < destino.length; j++) {
                    destino[j] = origem[indices.get(j)];
                }
                modelo.addRow(destino);
            }

            tabela.setModel(modelo);
            aviso.setText("  " + (linhas.size() - 1) + " matrícula(s) em "
                    + turma.disciplina() + " (" + turma.semestre() + ").");

        } catch (SQLException e) {
            mostrarErro(e);
        }
    }

    // ------------------------------------------------------------
    // Ações
    // ------------------------------------------------------------

    /** Linha completa da matrícula selecionada ou null (já avisa o usuário). */
    private String[] matriculaSelecionada() {
        int visual = tabela.getSelectedRow();
        if (visual < 0) {
            JOptionPane.showMessageDialog(this,
                    "Selecione uma matrícula na tabela.",
                    "Nenhuma matrícula selecionada",
                    JOptionPane.WARNING_MESSAGE);
            return null;
        }

        int modelo = tabela.convertRowIndexToModel(visual);
        return linhas.get(modelo + 1);
    }

    private void lancarNotas() {
        String[] m = matriculaSelecionada();
        if (m == null) {
            return;
        }

        String[] c = linhas.get(0);
        int idMatricula = Integer.parseInt(Tabelas.celula(m, Tabelas.coluna(c, "id_matricula")));
        String aluno = Tabelas.celula(m, Tabelas.coluna(c, "aluno"));
        String totalAulas = Tabelas.celula(m, Tabelas.coluna(c, "total_aulas"));

        JTextField n1 = new JTextField(Tabelas.celula(m, Tabelas.coluna(c, "n1")));
        JTextField n2 = new JTextField(Tabelas.celula(m, Tabelas.coluna(c, "n2")));
        JTextField faltas = new JTextField(Tabelas.celula(m, Tabelas.coluna(c, "faltas")));

        JPanel painel = new JPanel(new GridLayout(0, 2, 6, 6));
        painel.add(new JLabel("N1 (0 a 10):"));
        painel.add(n1);
        painel.add(new JLabel("N2 (0 a 10):"));
        painel.add(n2);
        painel.add(new JLabel("Faltas (de " + totalAulas + " aulas):"));
        painel.add(faltas);

        int escolha = JOptionPane.showConfirmDialog(this, painel,
                "Lançar notas: " + aluno,
                JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
        if (escolha != JOptionPane.OK_OPTION) {
            return;
        }

        try {
            double valorN1 = lerNota(n1.getText(), "N1");
            double valorN2 = lerNota(n2.getText(), "N2");
            int valorFaltas = lerFaltas(faltas.getText());

            repository.lancarNotas(idMatricula, valorN1, valorN2, valorFaltas, usuarioId);
            carregarMatriculas();

        } catch (IllegalArgumentException | SQLException e) {
            mostrarErro(e);
        }
    }

    private void lancarExame() {
        String[] m = matriculaSelecionada();
        if (m == null) {
            return;
        }

        String[] c = linhas.get(0);
        String situacao = Tabelas.celula(m, Tabelas.coluna(c, "situacao"));
        String aluno = Tabelas.celula(m, Tabelas.coluna(c, "aluno"));

        if (!"Em Exame".equalsIgnoreCase(situacao)) {
            JOptionPane.showMessageDialog(this,
                    "Exame só pode ser lançado para matrícula Em Exame.\n"
                    + aluno + " está como: " + situacao + ".",
                    "Exame indisponível", JOptionPane.INFORMATION_MESSAGE);
            return;
        }

        int idMatricula = Integer.parseInt(Tabelas.celula(m, Tabelas.coluna(c, "id_matricula")));
        String media = Tabelas.celula(m, Tabelas.coluna(c, "media_final"));

        JTextField exame = new JTextField();
        JPanel painel = new JPanel(new GridLayout(0, 2, 6, 6));
        painel.add(new JLabel("Média parcial:"));
        painel.add(new JLabel(media));
        painel.add(new JLabel("Nota do exame (0 a 10):"));
        painel.add(exame);

        int escolha = JOptionPane.showConfirmDialog(this, painel,
                "Lançar exame: " + aluno,
                JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
        if (escolha != JOptionPane.OK_OPTION) {
            return;
        }

        try {
            repository.lancarExame(idMatricula, lerNota(exame.getText(), "Exame"), usuarioId);
            carregarMatriculas();

        } catch (IllegalArgumentException | SQLException e) {
            mostrarErro(e);
        }
    }

    // ------------------------------------------------------------
    // Validação de entrada
    // ------------------------------------------------------------

    private static double lerNota(String texto, String rotulo) {
        double valor;
        try {
            valor = Double.parseDouble(texto.trim().replace(',', '.'));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(rotulo + ": informe um número (ex.: 7,5).");
        }
        if (valor < 0 || valor > 10) {
            throw new IllegalArgumentException(rotulo + ": a nota deve estar entre 0 e 10.");
        }
        return valor;
    }

    private static int lerFaltas(String texto) {
        try {
            int valor = Integer.parseInt(texto.trim());
            if (valor < 0) {
                throw new NumberFormatException();
            }
            return valor;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Faltas: informe um número inteiro, zero ou mais.");
        }
    }

    private void mostrarErro(Exception e) {
        JOptionPane.showMessageDialog(this, e.getMessage(),
                "Operação não concluída", JOptionPane.ERROR_MESSAGE);
    }

    private record TurmaOpcao(int id, String disciplina, String semestre, String professor) {
        @Override
        public String toString() {
            return "Turma " + id + " | " + disciplina + " | " + semestre
                    + " | Prof.: " + professor;
        }
    }
}
