package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.GridLayout;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.text.NumberFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import javax.swing.BorderFactory;
import javax.swing.JPanel;

/**
 * Painel "Início": cartões de resumo e o gráfico de desempenho por turma.
 * Tudo vem de views (vw_turmas_lotacao, vw_alunos, vw_desempenho_turma e,
 * só para o Coordenador, vw_faturamento_curso).
 */
final class InicioPanel extends JPanel {

    private static final long serialVersionUID = 1L;

    /** Palavras que não entram na sigla da disciplina ("Banco de Dados" = BD). */
    private static final Set<String> LIGACOES =
            Set.of("a", "e", "o", "de", "da", "do", "das", "dos", "em", "para");

    /** @param financeiro true só para o Coordenador: mostra o faturamento. */
    InicioPanel(SgaRepository repository, boolean financeiro) throws SQLException {
        super(new BorderLayout(0, 16));
        setOpaque(false);

        List<String[]> turmas = repository.consultarView("vw_turmas_lotacao");
        List<String[]> alunos = repository.listarAlunos();
        List<String[]> desempenho = repository.consultarView("vw_desempenho_turma");

        int abertas = contar(turmas, "status", "Aberta");
        int ativos = contar(alunos, "status", "Ativo");

        JPanel cartoes = new JPanel(new GridLayout(1, financeiro ? 4 : 3, 16, 0));
        cartoes.setOpaque(false);
        cartoes.add(Cartoes.cartao("TURMAS ABERTAS", String.valueOf(abertas),
                "de " + (turmas.size() - 1) + " turmas no total", Tema.TEXTO));
        cartoes.add(Cartoes.cartao("ALUNOS ATIVOS", String.valueOf(ativos),
                "de " + (alunos.size() - 1) + " alunos cadastrados", Tema.TEXTO));
        cartoes.add(cartaoMedia(desempenho));

        if (financeiro) {
            cartoes.add(cartaoFaturamento(repository.consultarView("vw_faturamento_curso")));
        }

        JPanel grafico = new JPanel(new BorderLayout());
        grafico.setBackground(Color.WHITE);
        grafico.setBorder(BorderFactory.createLineBorder(Tema.BORDA));
        grafico.add(new GraficoDesempenho(grupos(desempenho)), BorderLayout.CENTER);

        add(cartoes, BorderLayout.NORTH);
        add(grafico, BorderLayout.CENTER);
    }

    private static int contar(List<String[]> linhas, String coluna, String valor) {
        if (linhas.size() <= 1) {
            return 0;
        }
        int idx = Tabelas.coluna(linhas.get(0), coluna);
        int n = 0;
        for (int i = 1; i < linhas.size(); i++) {
            if (valor.equalsIgnoreCase(Tabelas.celula(linhas.get(i), idx))) {
                n++;
            }
        }
        return n;
    }

    /** Média das médias das turmas (só as que já têm média). */
    private static JPanel cartaoMedia(List<String[]> desempenho) {
        BigDecimal soma = BigDecimal.ZERO;
        int n = 0;
        if (desempenho.size() > 1) {
            int idx = Tabelas.coluna(desempenho.get(0), "media_turma");
            for (int i = 1; i < desempenho.size(); i++) {
                String v = Tabelas.celula(desempenho.get(i), idx);
                if (!v.isEmpty()) {
                    soma = soma.add(new BigDecimal(v));
                    n++;
                }
            }
        }

        if (n == 0) {
            return Cartoes.cartao("MÉDIA GERAL", "—", "ainda sem notas lançadas",
                    Tema.TEXTO_SUAVE);
        }

        BigDecimal media = soma.divide(BigDecimal.valueOf(n), 2, java.math.RoundingMode.HALF_UP);
        NumberFormat f = NumberFormat.getNumberInstance(Locale.forLanguageTag("pt-BR"));
        f.setMinimumFractionDigits(2);
        f.setMaximumFractionDigits(2);
        return Cartoes.cartao("MÉDIA GERAL", f.format(media),
                "média das médias de " + n + (n == 1 ? " turma" : " turmas"),
                Cartoes.corDaNota(media));
    }

    private static JPanel cartaoFaturamento(List<String[]> faturamento) {
        BigDecimal total = BigDecimal.ZERO;
        if (faturamento.size() > 1) {
            int idx = Tabelas.coluna(faturamento.get(0), "faturamento_mensal");
            for (int i = 1; i < faturamento.size(); i++) {
                String v = Tabelas.celula(faturamento.get(i), idx);
                if (!v.isEmpty()) {
                    total = total.add(new BigDecimal(v));
                }
            }
        }
        return Cartoes.cartao("FATURAMENTO PREVISTO", Tema.MOEDA.format(total),
                "mensal · ativos × mensalidade", Tema.VERDE);
    }

    /** Uma entrada do gráfico por turma que já tem matrículas. */
    private static List<GraficoDesempenho.Grupo> grupos(List<String[]> desempenho) {
        List<GraficoDesempenho.Grupo> grupos = new ArrayList<>();
        if (desempenho.size() <= 1) {
            return grupos;
        }

        String[] cab = desempenho.get(0);
        int iId = Tabelas.coluna(cab, "id_turma");
        int iDisc = Tabelas.coluna(cab, "disciplina");
        int iSem = Tabelas.coluna(cab, "semestre");
        int iApr = Tabelas.coluna(cab, "perc_aprovados");
        int iRep = Tabelas.coluna(cab, "perc_reprovados");
        int iAnd = Tabelas.coluna(cab, "perc_em_andamento");

        for (int i = 1; i < desempenho.size(); i++) {
            String[] l = desempenho.get(i);
            if (Tabelas.celula(l, iApr).isEmpty()) {
                continue; // turma sem matrículas: percentuais NULL
            }
            String disciplina = Tabelas.celula(l, iDisc);
            grupos.add(new GraficoDesempenho.Grupo(
                    "T" + Tabelas.celula(l, iId) + " " + sigla(disciplina),
                    "Turma " + Tabelas.celula(l, iId) + " · " + disciplina
                            + " · " + Tabelas.celula(l, iSem),
                    Double.parseDouble(Tabelas.celula(l, iApr)),
                    Double.parseDouble(Tabelas.celula(l, iRep)),
                    Double.parseDouble(Tabelas.celula(l, iAnd))));
        }
        return grupos;
    }

    /** "Programação Orientada a Objetos" = POO; palavra única = 4 primeiras letras. */
    static String sigla(String disciplina) {
        String[] palavras = disciplina.trim().split("\\s+");
        if (palavras.length == 1) {
            String p = palavras[0];
            return p.substring(0, Math.min(4, p.length())).toUpperCase(Locale.ROOT);
        }
        StringBuilder sb = new StringBuilder();
        for (String p : palavras) {
            if (!p.isEmpty() && !LIGACOES.contains(p.toLowerCase(Locale.ROOT))) {
                sb.append(Character.toUpperCase(p.charAt(0)));
            }
        }
        return sb.toString();
    }
}
