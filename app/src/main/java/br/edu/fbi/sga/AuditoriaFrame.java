package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.FlowLayout;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.sql.SQLException;
import java.util.List;

import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTable;

/**
 * Auditoria de notas (RN08), só para o Coordenador: lê a vw_log_nota, que o
 * trg_auditoria_nota alimenta a cada nota ou falta alterada.
 */
public final class AuditoriaFrame extends JFrame {

    private final SgaRepository repository;
    private final JPanel centro = new JPanel(new BorderLayout());
    private final JLabel resumo = new JLabel(" ");

    /** Falso depois de um erro: evita reabrir o aviso a cada reativação da janela. */
    private boolean carregadoOk = true;

    public AuditoriaFrame(SgaRepository repository) {
        super("SGA | Auditoria de notas");

        this.repository = repository;

        setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
        setSize(1300, 640);
        setLocationRelativeTo(null);
        setLayout(new BorderLayout());
        getContentPane().setBackground(Tema.FUNDO);

        add(Tema.cabecalho("Auditoria de notas",
                "Quem alterou nota ou falta, quando e de qual valor para qual (RN08)"),
                BorderLayout.NORTH);

        centro.setBackground(Tema.FUNDO);
        centro.setBorder(BorderFactory.createEmptyBorder(16, 24, 0, 24));
        add(centro, BorderLayout.CENTER);

        resumo.setForeground(Tema.TEXTO_SUAVE);

        JButton atualizar = Tema.primario(new JButton("Atualizar"));
        JButton fechar = Tema.secundario(new JButton("Fechar"));
        atualizar.addActionListener(e -> carregar());
        fechar.addActionListener(e -> dispose());

        JPanel botoes = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 0));
        botoes.setOpaque(false);
        botoes.add(atualizar);
        botoes.add(fechar);

        JPanel rodape = new JPanel(new BorderLayout());
        rodape.setBackground(Tema.FUNDO);
        rodape.setBorder(BorderFactory.createEmptyBorder(12, 24, 14, 24));
        rodape.add(botoes, BorderLayout.WEST);
        rodape.add(resumo, BorderLayout.EAST);
        add(rodape, BorderLayout.SOUTH);

        // Ao voltar da tela de notas, a linha nova já aparece sem clicar.
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowActivated(WindowEvent e) {
                if (carregadoOk) {
                    carregar();
                }
            }
        });

        carregar();
    }

    private void carregar() {
        try {
            List<String[]> linhas = repository.consultarAuditoriaNotas();
            carregadoOk = true;

            centro.removeAll();

            if (linhas.size() <= 1) {
                JLabel vazio = new JLabel("Nenhuma alteração de nota registrada ainda.");
                vazio.setForeground(Tema.TEXTO_SUAVE);
                centro.add(vazio, BorderLayout.NORTH);
                resumo.setText(" ");
            } else {
                JTable tabela = Tabelas.tabela(linhas);
                // id_log é só a ordem de desempate da consulta: não precisa aparecer.
                tabela.removeColumn(tabela.getColumn("id_log"));
                // Colunas na largura do conteúdo (nome, disciplina e data inteiros);
                // se passar da janela, aparece a rolagem horizontal.
                tabela.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);
                for (int c = 0; c < tabela.getColumnCount(); c++) {
                    var coluna = tabela.getColumnModel().getColumn(c);
                    int largura = coluna.getPreferredWidth() - 12;
                    coluna.setPreferredWidth(largura);
                    coluna.setWidth(largura);
                }
                JScrollPane scroll = new JScrollPane(tabela);
                scroll.setBorder(BorderFactory.createLineBorder(Tema.BORDA));
                scroll.getViewport().setBackground(Color.WHITE);
                centro.add(scroll, BorderLayout.CENTER);

                int n = linhas.size() - 1;
                resumo.setText(n + (n == 1 ? " alteração" : " alterações")
                        + " (as 500 mais recentes, da mais nova para a mais antiga)");
            }

            centro.revalidate();
            centro.repaint();

        } catch (SQLException e) {
            carregadoOk = false;
            JOptionPane.showMessageDialog(this, e.getMessage(),
                    "Operação não concluída", JOptionPane.ERROR_MESSAGE);
        }
    }
}
