package br.edu.fbi.sga;

import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JTextField;
import java.awt.BorderLayout;
import java.awt.GridLayout;
import java.sql.SQLException;

@SuppressWarnings("serial")
public final class LoginFrame extends JFrame {
    private final JTextField loginField = new JTextField(20);
    private final JPasswordField passwordField = new JPasswordField(20);
    private final SgaRepository repository = new SgaRepository();

    public LoginFrame() {
        super("SGA | Entrar");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setResizable(false);
        JPanel form = new JPanel(new GridLayout(2, 2, 8, 8));
        form.add(new JLabel("Login"));
        form.add(loginField);
        form.add(new JLabel("Senha"));
        form.add(passwordField);
        JButton enter = new JButton("Entrar");
        enter.addActionListener(event -> authenticate());
        passwordField.addActionListener(event -> authenticate());
        JPanel content = new JPanel(new BorderLayout(10, 14));
        content.add(new JLabel("Faculdade do Bug Infinito - Sistema de Gestão Acadêmica"), BorderLayout.NORTH);
        content.add(form, BorderLayout.CENTER);
        content.add(enter, BorderLayout.SOUTH);
        content.setBorder(javax.swing.BorderFactory.createEmptyBorder(18, 18, 18, 18));
        setContentPane(content);
        pack();
        setLocationRelativeTo(null);
    }

    private void authenticate() {
        String login = loginField.getText().trim();
        char[] password = passwordField.getPassword();
        if (login.isEmpty() || password.length == 0) {
            JOptionPane.showMessageDialog(this, "Informe o login e a senha.", "Dados incompletos", JOptionPane.WARNING_MESSAGE);
            return;
        }
        String hash = PasswordHash.sha256(password);
        try {
            Usuario usuario = repository.autenticar(login, hash);
            if (usuario == null) {
                JOptionPane.showMessageDialog(this, "Login ou senha inválidos.", "Acesso negado", JOptionPane.ERROR_MESSAGE);
                passwordField.setText("");
                return;
            }
            if (!usuario.isCoordenador() && !usuario.isSecretario()) {
                JOptionPane.showMessageDialog(this, "O usuário possui um perfil não reconhecido.", "Acesso negado", JOptionPane.ERROR_MESSAGE);
                return;
            }
            new DashboardFrame(usuario, repository).setVisible(true);
            dispose();
        } catch (SQLException exception) {
            JOptionPane.showMessageDialog(this, exception.getMessage(), "Não foi possível acessar o banco", JOptionPane.ERROR_MESSAGE);
        } finally {
            passwordField.setText("");
        }
    }
}
