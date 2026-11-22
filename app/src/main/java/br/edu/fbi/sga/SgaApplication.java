package br.edu.fbi.sga;

import javax.swing.SwingUtilities;

public final class SgaApplication {
    private SgaApplication() { }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            Tema.instalar();
            new LoginFrame().setVisible(true);
        });
    }
}
