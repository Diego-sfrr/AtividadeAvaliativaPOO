package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.text.NumberFormat;
import java.util.List;
import java.util.Locale;

import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTabbedPane;

/** Relatórios do Coordenador: desempenho por turma, lotação e faturamento por curso. */
public final class RelatoriosFrame extends JFrame {

    private final SgaRepository repository;
    private final JTabbedPane abas = new JTabbedPane();

    public RelatoriosFrame(SgaRepository repository) {
        super("SGA | Relatórios");

        this.repository = repository;

        setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        setSize(1100, 560);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout(8, 8));

        add(abas, BorderLayout.CENTER);

        JPanel botoes = new JPanel(new FlowLayout(FlowLayout.LEFT));
        JButton atualizar = new JButton("Atualizar");
        JButton fechar = new JButton("Fechar");
        atualizar.addActionListener(e -> carregar());
        fechar.addActionListener(e -> dispose());
        botoes.add(atualizar);
        botoes.add(fechar);
        add(botoes, BorderLayout.SOUTH);

        carregar();
    }

    private void carregar() {
        int aba = Math.max(abas.getSelectedIndex(), 0);
        abas.removeAll();

        try {
            abas.addTab("Desempenho por turma",
                    painelSimples(repository.consultarView("vw_desempenho_turma")));
            abas.addTab("Lotação das turmas",
                    painelSimples(repository.consultarView("vw_turmas_lotacao")));
            abas.addTab("Faturamento por curso",
                    painelFaturamento(repository.consultarView("vw_faturamento_curso")));

            abas.setSelectedIndex(Math.min(aba, abas.getTabCount() - 1));

        } catch (SQLException e) {
            JOptionPane.showMessageDialog(this, e.getMessage(),
                    "Operação não concluída", JOptionPane.ERROR_MESSAGE);
        }
    }

    private static JPanel painelSimples(List<String[]> linhas) {
        JPanel painel = new JPanel(new BorderLayout());
        if (linhas.size() <= 1) {
            painel.add(new JLabel("  Nenhum registro retornado."), BorderLayout.NORTH);
        } else {
            painel.add(new JScrollPane(Tabelas.tabela(linhas)), BorderLayout.CENTER);
        }
        return painel;
    }

    /** Tabela de faturamento com o total mensal somado embaixo. */
    private static JPanel painelFaturamento(List<String[]> linhas) {
        JPanel painel = painelSimples(linhas);

        if (linhas.size() > 1) {
            int iFat = Tabelas.coluna(linhas.get(0), "faturamento_mensal");
            int iAlunos = Tabelas.coluna(linhas.get(0), "alunos_ativos");

            BigDecimal total = BigDecimal.ZERO;
            int alunos = 0;
            for (int i = 1; i < linhas.size(); i++) {
                String valor = Tabelas.celula(linhas.get(i), iFat);
                if (!valor.isEmpty()) {
                    total = total.add(new BigDecimal(valor));
                }
                String qtd = Tabelas.celula(linhas.get(i), iAlunos);
                if (!qtd.isEmpty()) {
                    alunos += Integer.parseInt(qtd);
                }
            }

            String moeda = NumberFormat
                    .getCurrencyInstance(Locale.forLanguageTag("pt-BR")).format(total);
            painel.add(new JLabel("  Total mensal: " + moeda
                    + "  (" + alunos + " alunos ativos)"), BorderLayout.SOUTH);
        }

        return painel;
    }
}
