
package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.sql.SQLException;
import java.time.LocalDate;
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

public final class AlunosFrame extends JFrame {

    private final SgaRepository repository;
    private final JTable tabela = new JTable();
    private final List<CursoOpcao> cursos = new ArrayList<>();

    private DefaultTableModel modelo;

    public AlunosFrame(SgaRepository repository) {
        super("SGA | Gerenciamento de alunos");

        this.repository = repository;

        setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        setSize(1100, 620);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout(8, 8));

        JLabel titulo = new JLabel("  Gerenciamento de alunos");
        add(titulo, BorderLayout.NORTH);

        tabela.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        tabela.setAutoCreateRowSorter(true);

        add(new JScrollPane(tabela), BorderLayout.CENTER);

        JPanel botoes = new JPanel(new FlowLayout(FlowLayout.LEFT));

        JButton novo = new JButton("Cadastrar aluno");
        JButton editar = new JButton("Editar selecionado");
        JButton excluir = new JButton("Excluir selecionado");
        JButton atualizar = new JButton("Atualizar lista");
        JButton fechar = new JButton("Fechar");

        novo.addActionListener(e -> cadastrar());
        editar.addActionListener(e -> editarSelecionado());
        excluir.addActionListener(e -> excluirSelecionado());
        atualizar.addActionListener(e -> atualizarTabela());
        fechar.addActionListener(e -> dispose());

        botoes.add(novo);
        botoes.add(editar);
        botoes.add(excluir);
        botoes.add(atualizar);
        botoes.add(fechar);

        add(botoes, BorderLayout.SOUTH);

        carregarCursos();
        atualizarTabela();
    }

    private void carregarCursos() {
        try {
            cursos.clear();

            List<String[]> linhas = repository.listarCursos();

            for (int i = 1; i < linhas.size(); i++) {
                String[] linha = linhas.get(i);

                int id = Integer.parseInt(linha[0]);
                String descricao = linha[1] + " - " + linha[2];

                cursos.add(new CursoOpcao(id, descricao));
            }

        } catch (Exception e) {
            mostrarErro(e);
        }
    }

    private void atualizarTabela() {
        try {
            List<String[]> linhas = repository.listarAlunos();

            if (linhas.isEmpty()) {
                tabela.setModel(new DefaultTableModel());
                return;
            }

            String[] colunas = linhas.get(0);

            modelo = new DefaultTableModel(colunas, 0) {
                @Override
                public boolean isCellEditable(int row, int column) {
                    return false;
                }
            };

            for (int i = 1; i < linhas.size(); i++) {
                modelo.addRow(linhas.get(i));
            }

            tabela.setModel(modelo);

        } catch (SQLException e) {
            mostrarErro(e);
        }
    }

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

    private void editarSelecionado() {

        int linhaSelecionada = tabela.getSelectedRow();

        if (linhaSelecionada < 0) {
            JOptionPane.showMessageDialog(
                    this, "Selecione um aluno na tabela."
            );
            return;
        }

        int linha = tabela.convertRowIndexToModel(linhaSelecionada);

        try {
            DadosAluno atual = new DadosAluno(
                    Integer.parseInt(valor(linha, "id_aluno")),
                    valor(linha, "ra"),
                    valor(linha, "nome"),
                    valor(linha, "cpf"),
                    valor(linha, "email"),
                    LocalDate.parse(valor(linha, "data_nascimento")),
                    Integer.parseInt(valor(linha, "id_curso")),
                    valor(linha, "status")
            );

            DadosAluno novos = exibirFormulario("Editar aluno", atual);

            if (novos == null) {
                return;
            }

            repository.editarAluno(
                    atual.idAluno(),
                    novos.ra(),
                    novos.nome(),
                    novos.cpf(),
                    novos.email(),
                    novos.nascimento(),
                    novos.idCurso(),
                    novos.status()
            );

            JOptionPane.showMessageDialog(
                    this, "Aluno atualizado com sucesso."
            );

            atualizarTabela();

        } catch (Exception e) {
            mostrarErro(e);
        }
    }

    private void excluirSelecionado() {

        int linhaSelecionada = tabela.getSelectedRow();

        if (linhaSelecionada < 0) {
            JOptionPane.showMessageDialog(
                    this, "Selecione um aluno na tabela."
            );
            return;
        }

        int linha = tabela.convertRowIndexToModel(linhaSelecionada);

        int idAluno = Integer.parseInt(valor(linha, "id_aluno"));
        String nome = valor(linha, "nome");

        int confirmacao = JOptionPane.showConfirmDialog(
                this,
                "Deseja realmente excluir o aluno " + nome + "?",
                "Confirmar exclusão",
                JOptionPane.YES_NO_OPTION
        );

        if (confirmacao != JOptionPane.YES_OPTION) {
            return;
        }

        try {
            repository.excluirAluno(idAluno);

            JOptionPane.showMessageDialog(
                    this, "Aluno excluído com sucesso."
            );

            atualizarTabela();

        } catch (Exception e) {
            mostrarErro(e);
        }
    }

    private String valor(int linha, String coluna) {

        int indice = modelo.findColumn(coluna);
        Object valor = modelo.getValueAt(linha, indice);

        return valor == null ? "" : valor.toString();
    }

    private DadosAluno exibirFormulario(
            String titulo, DadosAluno atual) {

        JTextField ra = new JTextField(
                atual == null ? "" : atual.ra()
        );

        JTextField nome = new JTextField(
                atual == null ? "" : atual.nome()
        );

        JTextField cpf = new JTextField(
                atual == null ? "" : atual.cpf()
        );

        JTextField email = new JTextField(
                atual == null ? "" : atual.email()
        );

        JTextField nascimento = new JTextField(
                atual == null ? "" : atual.nascimento().toString()
        );

        JComboBox<CursoOpcao> curso = new JComboBox<>(
                cursos.toArray(CursoOpcao[]::new)
        );

        JComboBox<String> status = new JComboBox<>(
                new String[]{"Ativo", "Trancado", "Formado"}
        );

        if (atual != null) {

            for (int i = 0; i < curso.getItemCount(); i++) {

                if (curso.getItemAt(i).id() == atual.idCurso()) {
                    curso.setSelectedIndex(i);
                    break;
                }
            }

            status.setSelectedItem(atual.status());
        }

        JPanel painel = new JPanel(new GridLayout(0, 2, 8, 8));

        painel.add(new JLabel("RA:"));
        painel.add(ra);

        painel.add(new JLabel("Nome completo:"));
        painel.add(nome);

        painel.add(new JLabel("CPF (11 números):"));
        painel.add(cpf);

        painel.add(new JLabel("E-mail:"));
        painel.add(email);

        painel.add(new JLabel("Nascimento (AAAA-MM-DD):"));
        painel.add(nascimento);

        painel.add(new JLabel("Curso:"));
        painel.add(curso);

        painel.add(new JLabel("Status:"));
        painel.add(status);

        int resultado = JOptionPane.showConfirmDialog(
                this,
                painel,
                titulo,
                JOptionPane.OK_CANCEL_OPTION,
                JOptionPane.PLAIN_MESSAGE
        );

        if (resultado != JOptionPane.OK_OPTION) {
            return null;
        }

        try {

            if (curso.getSelectedItem() == null) {
                throw new IllegalArgumentException(
                        "Não há cursos disponíveis."
                );
            }

            CursoOpcao cursoSelecionado =
                    (CursoOpcao) curso.getSelectedItem();

            return new DadosAluno(
                    atual == null ? 0 : atual.idAluno(),
                    ra.getText().trim(),
                    nome.getText().trim(),
                    cpf.getText().trim(),
                    email.getText().trim(),
                    LocalDate.parse(nascimento.getText().trim()),
                    cursoSelecionado.id(),
                    (String) status.getSelectedItem()
            );

        } catch (Exception e) {

            JOptionPane.showMessageDialog(
                    this,
                    "Confira os campos. A data deve estar no formato AAAA-MM-DD.\n"
                    + e.getMessage(),
                    "Dados inválidos",
                    JOptionPane.WARNING_MESSAGE
            );

            return null;
        }
    }

    private void mostrarErro(Exception e) {

        JOptionPane.showMessageDialog(
                this,
                e.getMessage(),
                "Operação não concluída",
                JOptionPane.ERROR_MESSAGE
        );
    }

    private record CursoOpcao(int id, String descricao) {

        @Override
        public String toString() {
            return descricao;
        }
    }

    private record DadosAluno(
            int idAluno,
            String ra,
            String nome,
            String cpf,
            String email,
            LocalDate nascimento,
            int idCurso,
            String status) {
    }
}
