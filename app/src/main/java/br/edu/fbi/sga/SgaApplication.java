package br.edu.fbi.sga;

import javax.swing.SwingUtilities;
import javax.swing.UIManager;

public final class SgaApplication {
    private SgaApplication() { }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            try {
                UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
            } catch (Exception ignored) {
                // Mantém o tema Swing padrão se o tema do sistema não estiver disponível.
            }
            new LoginFrame().setVisible(true);
        });
    }
}
