package br.edu.fbi.sga;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Font;
import java.sql.SQLException;

import javax.swing.BorderFactory;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JTextField;
import javax.swing.SwingConstants;

@SuppressWarnings("serial")
public final class LoginFrame extends JFrame {
    private final JTextField loginField = new JTextField();
    private final JPasswordField passwordField = new JPasswordField();
    private final SgaRepository repository = new SgaRepository();

    public LoginFrame() {
        super("SGA | Entrar");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setResizable(false);

        // Faixa de marca no topo
        JLabel marca = new JLabel("SGA", SwingConstants.CENTER);
        marca.setFont(new Font("Segoe UI", Font.BOLD, 40));
        marca.setForeground(Color.WHITE);

        JLabel nome = new JLabel("Sistema de Gestão Acadêmica", SwingConstants.CENTER);
        nome.setForeground(new Color(0xCBD5E1));

        JPanel faixa = new JPanel(new BorderLayout(0, 2));
        faixa.setBackground(Tema.MARINHO);
        faixa.setBorder(BorderFactory.createEmptyBorder(28, 24, 24, 24));
        faixa.add(marca, BorderLayout.CENTER);
        faixa.add(nome, BorderLayout.SOUTH);

        // Formulário
        JLabel boasVindas = new JLabel("Entre na sua conta");
        boasVindas.setFont(new Font("Segoe UI", Font.BOLD, 18));
        boasVindas.setAlignmentX(LEFT_ALIGNMENT);

        JLabel sub = new JLabel("Acesse com seu login e senha");
        sub.setForeground(Tema.TEXTO_SUAVE);
        sub.setAlignmentX(LEFT_ALIGNMENT);

        loginField.putClientProperty("JTextField.placeholderText", "Login");
        passwordField.putClientProperty("JTextField.placeholderText", "Senha");
        passwordField.putClientProperty("JPasswordField.showRevealButton", true);
        for (JTextField campo : new JTextField[] {loginField, passwordField}) {
            campo.setAlignmentX(LEFT_ALIGNMENT);
            campo.setPreferredSize(new Dimension(300, 38));
            campo.setMaximumSize(new Dimension(Integer.MAX_VALUE, 38));
        }

        JButton enter = Tema.primario(new JButton("Entrar"));
        enter.setAlignmentX(LEFT_ALIGNMENT);
        enter.setMaximumSize(new Dimension(Integer.MAX_VALUE, 40));
        enter.addActionListener(event -> authenticate());
        passwordField.addActionListener(event -> authenticate());

        JPanel form = new JPanel();
        form.setLayout(new BoxLayout(form, BoxLayout.Y_AXIS));
        form.setBackground(Color.WHITE);
        form.setBorder(BorderFactory.createEmptyBorder(26, 32, 30, 32));
        form.add(boasVindas);
        form.add(javax.swing.Box.createVerticalStrut(2));
        form.add(sub);
        form.add(javax.swing.Box.createVerticalStrut(20));
        form.add(loginField);
        form.add(javax.swing.Box.createVerticalStrut(10));
        form.add(passwordField);
        form.add(javax.swing.Box.createVerticalStrut(18));
        form.add(enter);

        JPanel content = new JPanel(new BorderLayout());
        content.add(faixa, BorderLayout.NORTH);
        content.add(form, BorderLayout.CENTER);
        setContentPane(content);
        getRootPane().setDefaultButton(enter);
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
