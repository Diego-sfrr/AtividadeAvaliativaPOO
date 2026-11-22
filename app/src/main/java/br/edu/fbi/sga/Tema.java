package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTable;
import javax.swing.SwingConstants;
import javax.swing.UIManager;
import javax.swing.table.DefaultTableCellRenderer;
import javax.swing.table.TableColumn;

import com.formdev.flatlaf.FlatLaf;
import com.formdev.flatlaf.FlatLightLaf;

/** Aparência do SGA: cores, fontes e estilos compartilhados pelas telas. */
final class Tema {

    static final Color AZUL = new Color(0x2563EB);
    static final Color MARINHO = new Color(0x0F172A);
    static final Color MARINHO_CLARO = new Color(0x1E293B);
    static final Color FUNDO = new Color(0xF1F5F9);
    static final Color BORDA = new Color(0xE2E8F0);
    static final Color TEXTO = new Color(0x0F172A);
    static final Color TEXTO_SUAVE = new Color(0x64748B);

    private static final Color VERDE = new Color(0x15803D);
    private static final Color VERMELHO = new Color(0xB91C1C);
    private static final Color LARANJA = new Color(0xB45309);

    private Tema() { }

    /** Instala o tema. Chamar uma vez, antes de criar qualquer janela. */
    static void instalar() {
        FlatLaf.setGlobalExtraDefaults(Map.of("@accentColor", "#2563EB"));
        FlatLightLaf.setup();

        UIManager.put("defaultFont", new Font("Segoe UI", Font.PLAIN, 14));
        UIManager.put("Component.arc", 10);
        UIManager.put("Button.arc", 12);
        UIManager.put("TextComponent.arc", 10);
        UIManager.put("ScrollBar.showButtons", false);
        UIManager.put("ScrollBar.thumbArc", 999);
        UIManager.put("ScrollBar.width", 12);

        UIManager.put("Table.rowHeight", 32);
        UIManager.put("Table.showHorizontalLines", true);
        UIManager.put("Table.showVerticalLines", false);
        UIManager.put("Table.intercellSpacing", new Dimension(0, 1));
        UIManager.put("Table.gridColor", BORDA);
        UIManager.put("Table.alternateRowColor", new Color(0xF8FAFC));
        UIManager.put("Table.selectionBackground", new Color(0xDBEAFE));
        UIManager.put("Table.selectionForeground", TEXTO);
        UIManager.put("TableHeader.background", FUNDO);
        UIManager.put("TableHeader.foreground", TEXTO_SUAVE);
        UIManager.put("TableHeader.font", new Font("Segoe UI", Font.BOLD, 12));
        UIManager.put("TableHeader.bottomSeparatorColor", BORDA);
        UIManager.put("TableHeader.height", 38);

        UIManager.put("TabbedPane.selectedBackground", Color.WHITE);
        UIManager.put("TabbedPane.tabHeight", 40);
        UIManager.put("TabbedPane.font", new Font("Segoe UI", Font.BOLD, 13));

        UIManager.put("Button.toolbar.hoverBackground", MARINHO_CLARO);
        UIManager.put("Button.toolbar.pressedBackground", new Color(0x334155));
    }

    // ------------------------------------------------------------
    // Componentes
    // ------------------------------------------------------------

    /** Faixa de título no topo das janelas. */
    static JPanel cabecalho(String titulo, String subtitulo) {
        JLabel t = new JLabel(titulo);
        t.setFont(new Font("Segoe UI", Font.BOLD, 22));
        t.setForeground(TEXTO);

        JLabel s = new JLabel(subtitulo);
        s.setForeground(TEXTO_SUAVE);

        JPanel textos = new JPanel(new BorderLayout(0, 2));
        textos.setOpaque(false);
        textos.add(t, BorderLayout.NORTH);
        textos.add(s, BorderLayout.SOUTH);

        JPanel faixa = new JPanel(new BorderLayout());
        faixa.setBackground(Color.WHITE);
        faixa.setBorder(BorderFactory.createCompoundBorder(
                BorderFactory.createMatteBorder(0, 0, 1, 0, BORDA),
                BorderFactory.createEmptyBorder(16, 24, 16, 24)));
        faixa.add(textos, BorderLayout.CENTER);
        return faixa;
    }

    /** Botão de destaque (azul). */
    static JButton primario(JButton b) {
        b.setBackground(AZUL);
        b.setForeground(Color.WHITE);
        b.setFont(b.getFont().deriveFont(Font.BOLD));
        b.setMargin(new java.awt.Insets(6, 16, 6, 16));
        return b;
    }

    /** Botão comum, com a mesma margem do primário. */
    static JButton secundario(JButton b) {
        b.setMargin(new java.awt.Insets(6, 16, 6, 16));
        return b;
    }

    // ------------------------------------------------------------
    // Tabelas
    // ------------------------------------------------------------

    /** Estilo das tabelas: listras, células coloridas por situação, colunas ajustadas. */
    static void estilizar(JTable tabela) {
        tabela.setFillsViewportHeight(true);
        tabela.setShowGrid(false);
        tabela.setShowHorizontalLines(true);
        tabela.getTableHeader().setReorderingAllowed(false);
        tabela.setDefaultRenderer(Object.class, new Celula());
        esconderColunasTecnicas(tabela);
        rotular(tabela);
        ajustarColunas(tabela);
    }

    /** No boletim, os identificadores internos só atrapalham a leitura. */
    private static void esconderColunasTecnicas(JTable tabela) {
        if (indice(tabela, "id_matricula") < 0 || indice(tabela, "disciplina") < 0) {
            return;
        }
        for (String nome : new String[] {"id_matricula", "id_turma", "id_aluno"}) {
            int i = indice(tabela, nome);
            if (i >= 0) {
                tabela.removeColumn(tabela.getColumnModel().getColumn(i));
            }
        }
    }

    private static int indice(JTable tabela, String nome) {
        try {
            return tabela.getColumnModel().getColumnIndex(nome);
        } catch (IllegalArgumentException e) {
            return -1;
        }
    }

    private static final Map<String, String> ROTULOS = Map.ofEntries(
            Map.entry("id_aluno", "ID aluno"), Map.entry("id_curso", "ID curso"),
            Map.entry("id_turma", "Turma"), Map.entry("id_matricula", "Matrícula"),
            Map.entry("id_log", "ID"), Map.entry("ra", "RA"), Map.entry("cpf", "CPF"),
            Map.entry("email", "E-mail"), Map.entry("data_nascimento", "Nascimento"),
            Map.entry("vagas_restantes", "Restantes"), Map.entry("perc_ocupacao", "Ocupação %"),
            Map.entry("media_turma", "Média"), Map.entry("maior_nota", "Maior nota"),
            Map.entry("menor_nota", "Menor nota"), Map.entry("perc_aprovados", "Aprovados %"),
            Map.entry("perc_reprovados", "Reprovados %"), Map.entry("perc_em_andamento", "Em andamento %"),
            Map.entry("valor_mensalidade", "Mensalidade"), Map.entry("alunos_ativos", "Alunos ativos"),
            Map.entry("faturamento_mensal", "Faturamento mensal"), Map.entry("n1", "N1"),
            Map.entry("n2", "N2"), Map.entry("media_final", "Média final"),
            Map.entry("total_aulas", "Aulas"), Map.entry("frequencia", "Freq. %"),
            Map.entry("situacao", "Situação"), Map.entry("carga_horaria", "Carga horária"),
            Map.entry("data_hora", "Data/hora"), Map.entry("valor_antigo", "Valor antigo"),
            Map.entry("valor_novo", "Valor novo"));

    /** Troca nomes de coluna do banco (snake_case) por rótulos legíveis. */
    private static void rotular(JTable tabela) {
        for (int c = 0; c < tabela.getColumnCount(); c++) {
            TableColumn coluna = tabela.getColumnModel().getColumn(c);
            String nome = String.valueOf(coluna.getIdentifier());
            String rotulo = ROTULOS.get(nome);
            if (rotulo == null) {
                String t = nome.replace('_', ' ');
                rotulo = t.isEmpty() ? t : Character.toUpperCase(t.charAt(0)) + t.substring(1);
            }
            coluna.setHeaderValue(rotulo);
        }
        tabela.getTableHeader().repaint();
    }

    /** Largura de cada coluna conforme o conteúdo (até um limite). */
    static void ajustarColunas(JTable tabela) {
        for (int c = 0; c < tabela.getColumnCount(); c++) {
            TableColumn coluna = tabela.getColumnModel().getColumn(c);

            Component cab = tabela.getTableHeader().getDefaultRenderer()
                    .getTableCellRendererComponent(tabela, coluna.getHeaderValue(), false, false, -1, c);
            int largura = cab.getPreferredSize().width;

            int linhas = Math.min(tabela.getRowCount(), 60);
            for (int r = 0; r < linhas; r++) {
                Component cel = tabela.prepareRenderer(tabela.getCellRenderer(r, c), r, c);
                largura = Math.max(largura, cel.getPreferredSize().width);
            }

            coluna.setPreferredWidth(Math.min(largura + 28, 340));
        }
    }

    /** Colunas que guardam dinheiro: aparecem em reais (R$ 1.234,56). */
    private static final Set<String> DINHEIRO =
            Set.of("valor_mensalidade", "faturamento_mensal");

    static final NumberFormat MOEDA =
            NumberFormat.getCurrencyInstance(Locale.forLanguageTag("pt-BR"));

    private static final class Celula extends DefaultTableCellRenderer {
        private static final long serialVersionUID = 1L;

        @Override
        public Component getTableCellRendererComponent(JTable tabela, Object valor,
                boolean selecionada, boolean foco, int linha, int coluna) {

            String texto = valor == null ? "" : valor.toString();
            super.getTableCellRendererComponent(tabela, texto, selecionada, false, linha, coluna);

            setBorder(BorderFactory.createEmptyBorder(0, 12, 0, 12));
            setHorizontalAlignment(ehNumero(texto) ? SwingConstants.RIGHT : SwingConstants.LEFT);
            setFont(tabela.getFont());

            if (!selecionada) {
                setBackground(linha % 2 == 0 ? Color.WHITE : new Color(0xF8FAFC));
                setForeground(TEXTO);
            }

            String nomeColuna = tabela.getColumnName(coluna).toLowerCase();
            if (DINHEIRO.contains(nomeColuna) && ehNumero(texto)) {
                setText(MOEDA.format(new BigDecimal(texto.replace(',', '.'))));
                setHorizontalAlignment(SwingConstants.RIGHT);
            }
            if (nomeColuna.equals("situacao") || nomeColuna.equals("status")) {
                setFont(getFont().deriveFont(Font.BOLD));
                if (!selecionada) {
                    setForeground(corDaSituacao(texto));
                }
            }
            return this;
        }

        private static boolean ehNumero(String t) {
            return !t.isEmpty() && t.matches("-?\\d+([.,]\\d+)?");
        }

        private static Color corDaSituacao(String t) {
            return switch (t) {
                case "Aprovado", "Ativo", "Aberta", "Formado" -> VERDE;
                case "Reprovado por Nota", "Reprovado por Falta" -> VERMELHO;
                case "Em Exame", "Trancado" -> LARANJA;
                case "Cursando" -> AZUL;
                default -> TEXTO_SUAVE;
            };
        }
    }
}
