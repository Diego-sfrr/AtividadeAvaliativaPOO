package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Font;
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.util.Locale;

import javax.swing.BorderFactory;
import javax.swing.JLabel;
import javax.swing.JPanel;

import br.edu.fbi.sga.SgaRepository.CrAluno;

/** Cartões brancos (rótulo + número grande) usados no painel inicial e no CR do aluno. */
final class Cartoes {

    private static final NumberFormat NOTA =
            NumberFormat.getNumberInstance(Locale.forLanguageTag("pt-BR"));

    static {
        NOTA.setMinimumFractionDigits(2);
        NOTA.setMaximumFractionDigits(2);
    }

    private Cartoes() { }

    /**
     * Cartão com rótulo pequeno em cima, número grande no meio e uma linha de
     * apoio embaixo (pode ser vazia). A cor pinta só o número.
     */
    static JPanel cartao(String rotulo, String valor, String apoio, Color cor) {
        JLabel r = new JLabel(rotulo);
        r.setForeground(Tema.TEXTO_SUAVE);
        r.setFont(r.getFont().deriveFont(Font.BOLD, 12f));

        JLabel v = new JLabel(valor);
        v.setForeground(cor);
        v.setFont(new Font("Segoe UI", Font.BOLD, 28));

        JLabel a = new JLabel(apoio == null || apoio.isEmpty() ? " " : apoio);
        a.setForeground(Tema.TEXTO_SUAVE);
        a.setFont(a.getFont().deriveFont(12f));

        JPanel c = new JPanel(new BorderLayout(0, 2));
        c.setBackground(Color.WHITE);
        c.setBorder(BorderFactory.createCompoundBorder(
                BorderFactory.createLineBorder(Tema.BORDA),
                BorderFactory.createEmptyBorder(14, 16, 14, 16)));
        c.add(r, BorderLayout.NORTH);
        c.add(v, BorderLayout.CENTER);
        c.add(a, BorderLayout.SOUTH);
        return c;
    }

    /** Cartão do CR no topo do histórico e do boletim. {@code cr} nulo vira "—". */
    static JPanel cr(CrAluno cr) {
        String apoio = cr.aluno() + "  ·  RA " + cr.ra();

        if (cr.cr() == null) {
            return faixa(cartao("COEFICIENTE DE RENDIMENTO (CR)", "—",
                    "sem disciplinas concluídas  ·  " + apoio, Tema.TEXTO_SUAVE));
        }

        return faixa(cartao("COEFICIENTE DE RENDIMENTO (CR)", NOTA.format(cr.cr()),
                "média final ponderada pela carga horária  ·  " + apoio,
                corDaNota(cr.cr())));
    }

    /** Cor da nota segundo as faixas do SGA: 7+ aprovado, 4 a 7 exame, abaixo reprovado. */
    static Color corDaNota(BigDecimal nota) {
        if (nota.compareTo(new BigDecimal("7")) >= 0) {
            return Tema.VERDE;
        }
        if (nota.compareTo(new BigDecimal("4")) >= 0) {
            return Tema.LARANJA;
        }
        return Tema.VERMELHO;
    }

    /** Dá um respiro embaixo para a tabela não colar no cartão. */
    private static JPanel faixa(JPanel cartao) {
        JPanel f = new JPanel(new BorderLayout());
        f.setOpaque(false);
        f.setBorder(BorderFactory.createEmptyBorder(0, 0, 14, 0));
        f.add(cartao, BorderLayout.WEST);
        return f;
    }
}
