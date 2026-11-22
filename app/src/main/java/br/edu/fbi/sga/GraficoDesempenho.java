package br.edu.fbi.sga;

import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.event.MouseEvent;
import java.awt.geom.RoundRectangle2D;
import java.text.NumberFormat;
import java.util.List;
import java.util.Locale;

import javax.swing.JPanel;
import javax.swing.ToolTipManager;

/**
 * Gráfico de barras agrupadas (Java2D) com o desempenho de cada turma:
 * % de aprovados, reprovados e em andamento, de 0 a 100%.
 */
final class GraficoDesempenho extends JPanel {

    private static final long serialVersionUID = 1L;

    /** Uma turma no gráfico; os percentuais vão de 0 a 100. */
    record Grupo(String rotulo, String completo,
            double aprovados, double reprovados, double andamento) { }

    private static final Color COR_APROVADOS = Tema.VERDE;
    private static final Color COR_REPROVADOS = Tema.VERMELHO;
    private static final Color COR_ANDAMENTO = Tema.AZUL;

    private static final String[] LEGENDA =
            {"Aprovados", "Reprovados", "Em andamento"};
    private static final Color[] CORES =
            {COR_APROVADOS, COR_REPROVADOS, COR_ANDAMENTO};

    private static final int MARGEM_ESQ = 52;
    private static final int MARGEM_DIR = 24;
    private static final int MARGEM_TOPO = 56;
    private static final int MARGEM_BASE = 40;

    private final transient List<Grupo> grupos;
    private final NumberFormat percentual =
            NumberFormat.getNumberInstance(Locale.forLanguageTag("pt-BR"));

    /** Posição de cada grupo na última pintura (para a dica ao passar o mouse). */
    private int[] grupoX = new int[0];
    private int grupoLargura;

    GraficoDesempenho(List<Grupo> grupos) {
        this.grupos = grupos;
        percentual.setMaximumFractionDigits(1);
        setBackground(Color.WHITE);
        setPreferredSize(new Dimension(640, 320));
        ToolTipManager.sharedInstance().registerComponent(this);
    }

    @Override
    public String getToolTipText(MouseEvent e) {
        for (int i = 0; i < grupoX.length; i++) {
            if (e.getX() >= grupoX[i] && e.getX() <= grupoX[i] + grupoLargura) {
                Grupo g = grupos.get(i);
                return "<html><b>" + g.completo() + "</b><br>Aprovados: "
                        + percentual.format(g.aprovados()) + "%<br>Reprovados: "
                        + percentual.format(g.reprovados()) + "%<br>Em andamento: "
                        + percentual.format(g.andamento()) + "%</html>";
            }
        }
        return null;
    }

    @Override
    protected void paintComponent(Graphics g0) {
        super.paintComponent(g0);

        Graphics2D g = (Graphics2D) g0.create();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);

        int w = getWidth();
        int h = getHeight();

        // Título e legenda
        g.setFont(new Font("Segoe UI", Font.BOLD, 16));
        g.setColor(Tema.TEXTO);
        g.drawString("Aprovados × Reprovados por turma", 20, 30);
        desenharLegenda(g, w);

        int areaX = MARGEM_ESQ;
        int areaY = MARGEM_TOPO;
        int areaW = w - MARGEM_ESQ - MARGEM_DIR;
        int areaH = h - MARGEM_TOPO - MARGEM_BASE;
        if (areaW <= 0 || areaH <= 0) {
            g.dispose();
            return;
        }

        // Eixo Y: 0 a 100% (linhas de grade a cada 25%)
        g.setFont(new Font("Segoe UI", Font.PLAIN, 12));
        FontMetrics fm = g.getFontMetrics();
        g.setStroke(new BasicStroke(1f));
        for (int p = 0; p <= 100; p += 25) {
            int y = areaY + areaH - areaH * p / 100;
            g.setColor(p == 0 ? new Color(0xCBD5E1) : Tema.BORDA);
            g.drawLine(areaX, y, areaX + areaW, y);
            String t = p + "%";
            g.setColor(Tema.TEXTO_SUAVE);
            g.drawString(t, areaX - 8 - fm.stringWidth(t), y + fm.getAscent() / 2 - 1);
        }

        if (grupos.isEmpty()) {
            g.setColor(Tema.TEXTO_SUAVE);
            String vazio = "Sem turmas com matrículas para mostrar.";
            g.drawString(vazio, areaX + (areaW - fm.stringWidth(vazio)) / 2, areaY + areaH / 2);
            g.dispose();
            return;
        }

        // Barras: cada turma ocupa uma faixa; as 3 barras ficam no meio dela
        int n = grupos.size();
        double faixa = (double) areaW / n;
        int barra = (int) Math.max(8, Math.min(46, faixa * 0.8 / 3));
        int folga = 4;
        grupoLargura = 3 * barra + 2 * folga;
        grupoX = new int[n];

        for (int i = 0; i < n; i++) {
            Grupo gr = grupos.get(i);
            int x0 = (int) (areaX + faixa * i + (faixa - grupoLargura) / 2);
            grupoX[i] = x0;

            double[] valores = {gr.aprovados(), gr.reprovados(), gr.andamento()};
            for (int k = 0; k < 3; k++) {
                int bx = x0 + k * (barra + folga);
                int altura = (int) Math.round(areaH * Math.max(0, Math.min(100, valores[k])) / 100);

                if (altura > 0) {
                    g.setColor(CORES[k]);
                    // cantos de cima arredondados: retângulo arredondado com a base reta por cima
                    g.fill(new RoundRectangle2D.Double(bx, areaY + areaH - altura, barra, altura, 8, 8));
                    g.fillRect(bx, areaY + areaH - Math.min(altura, 8), barra, Math.min(altura, 8));
                }

                if (valores[k] > 0 && barra >= 28) {
                    String t = percentual.format(valores[k]) + "%";
                    g.setFont(new Font("Segoe UI", Font.BOLD, 11));
                    FontMetrics f2 = g.getFontMetrics();
                    g.setColor(Tema.TEXTO);
                    g.drawString(t, bx + (barra - f2.stringWidth(t)) / 2,
                            areaY + areaH - altura - 5);
                }
            }

            // Rótulo curto da turma
            g.setFont(new Font("Segoe UI", Font.BOLD, 12));
            FontMetrics f3 = g.getFontMetrics();
            g.setColor(Tema.TEXTO);
            g.drawString(gr.rotulo(),
                    (int) (areaX + faixa * i + (faixa - f3.stringWidth(gr.rotulo())) / 2),
                    areaY + areaH + 22);
        }

        g.dispose();
    }

    private void desenharLegenda(Graphics2D g, int largura) {
        g.setFont(new Font("Segoe UI", Font.PLAIN, 12));
        FontMetrics fm = g.getFontMetrics();

        int total = 0;
        for (String t : LEGENDA) {
            total += 14 + 6 + fm.stringWidth(t) + 18;
        }

        int x = largura - MARGEM_DIR - total + 18;
        int y = 24;
        for (int i = 0; i < LEGENDA.length; i++) {
            g.setColor(CORES[i]);
            g.fill(new RoundRectangle2D.Double(x, y - 11, 14, 14, 4, 4));
            g.setColor(Tema.TEXTO_SUAVE);
            g.drawString(LEGENDA[i], x + 20, y);
            x += 14 + 6 + fm.stringWidth(LEGENDA[i]) + 18;
        }
    }
}
