
package br.edu.fbi.sga;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public final class SgaRepository {

    public Usuario autenticar(String login, String senhaHash) throws SQLException {
        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall("{call sp_LoginUsuario(?, ?)}")) {

            call.setString(1, login);
            call.setString(2, senhaHash);

            boolean hasResult = call.execute();

            while (true) {
                if (hasResult) {
                    try (ResultSet rows = call.getResultSet()) {
                        if (rows != null && rows.next()) {
                            return new Usuario(
                                    rows.getInt("id_usuario"),
                                    rows.getString("nome"),
                                    rows.getString("email"),
                                    rows.getString("perfil")
                            );
                        }
                    }
                } else if (call.getUpdateCount() == -1) {
                    break;
                }

                hasResult = call.getMoreResults();
            }

            return null;
        }
    }

    public List<String[]> consultarView(String viewName) throws SQLException {
        String sql = switch (viewName) {
            case "vw_turmas_lotacao",
                 "vw_desempenho_turma",
                 "vw_faturamento_curso" -> "SELECT * FROM " + viewName;

            default -> throw new IllegalArgumentException(
                    "View não permitida: " + viewName
            );
        };

        try (Connection connection = DatabaseConfig.openConnection();
             Statement statement = connection.createStatement();
             ResultSet rows = statement.executeQuery(sql)) {

            return readRows(rows);
        }
    }

    public List<String[]> consultarBoletimAluno(int alunoId) throws SQLException {
        String sql = "SELECT * FROM vw_boletim "
                + "WHERE id_aluno = ? ORDER BY semestre, disciplina";

        try (Connection connection = DatabaseConfig.openConnection();
             PreparedStatement statement = connection.prepareStatement(sql)) {

            statement.setInt(1, alunoId);

            try (ResultSet rows = statement.executeQuery()) {
                return readRows(rows);
            }
        }
    }

    public void matricularAluno(int alunoId, int turmaId, int usuarioId)
            throws SQLException {

        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_matricular_aluno(?, ?, ?)}")) {

            call.setInt(1, alunoId);
            call.setInt(2, turmaId);
            call.setInt(3, usuarioId);

            call.execute();
        }
    }

    public List<String[]> historicoAluno(int alunoId) throws SQLException {
        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_historico_aluno(?)}")) {

            call.setInt(1, alunoId);

            boolean hasResult = call.execute();

            while (true) {
                if (hasResult) {
                    try (ResultSet rows = call.getResultSet()) {
                        if (rows != null) {
                            return readRows(rows);
                        }
                    }
                } else if (call.getUpdateCount() == -1) {
                    break;
                }

                hasResult = call.getMoreResults();
            }

            return List.of();
        }
    }

    public void lancarNotas(int matriculaId, double n1, double n2,
            int faltas, int usuarioId) throws SQLException {

        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_lancar_notas(?, ?, ?, ?, ?)}")) {

            call.setInt(1, matriculaId);
            call.setDouble(2, n1);
            call.setDouble(3, n2);
            call.setInt(4, faltas);
            call.setInt(5, usuarioId);

            call.execute();
        }
    }

    public void lancarExame(int matriculaId, double exame, int usuarioId)
            throws SQLException {

        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_lancar_exame(?, ?, ?)}")) {

            call.setInt(1, matriculaId);
            call.setDouble(2, exame);
            call.setInt(3, usuarioId);

            call.execute();
        }
    }

    public void fecharSemestre(String semestre, int usuarioId)
            throws SQLException {

        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_fechar_semestre(?, ?)}")) {

            call.setString(1, semestre);
            call.setInt(2, usuarioId);

            call.execute();
        }
    }

    // ==========================================
    // GERENCIAMENTO DE ALUNOS
    // ==========================================

    public List<String[]> listarAlunos() throws SQLException {
        String sql = "SELECT * FROM vw_alunos ORDER BY id_aluno ASC";

        try (Connection connection = DatabaseConfig.openConnection();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet rows = statement.executeQuery()) {

            return readRows(rows);
        }
    }

    public List<String[]> listarCursos() throws SQLException {
        String sql = "SELECT DISTINCT id_curso, curso, turno "
                + "FROM vw_alunos ORDER BY curso, turno";

        try (Connection connection = DatabaseConfig.openConnection();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet rows = statement.executeQuery()) {

            return readRows(rows);
        }
    }

    public void cadastrarAluno(String ra, String nome, String cpf,
            String email, LocalDate nascimento, int idCurso)
            throws SQLException {

        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_cadastrar_aluno(?, ?, ?, ?, ?, ?)}")) {

            call.setString(1, ra);
            call.setString(2, nome);
            call.setString(3, cpf);
            call.setString(4, email);
            call.setDate(5, java.sql.Date.valueOf(nascimento));
            call.setInt(6, idCurso);

            call.execute();
        }
    }

    public void editarAluno(int idAluno, String ra, String nome,
            String cpf, String email, LocalDate nascimento,
            int idCurso, String status) throws SQLException {

        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_editar_aluno(?, ?, ?, ?, ?, ?, ?, ?)}")) {

            call.setInt(1, idAluno);
            call.setString(2, ra);
            call.setString(3, nome);
            call.setString(4, cpf);
            call.setString(5, email);
            call.setDate(6, java.sql.Date.valueOf(nascimento));
            call.setInt(7, idCurso);
            call.setString(8, status);

            call.execute();
        }
    }

    public void excluirAluno(int idAluno) throws SQLException {
        try (Connection connection = DatabaseConfig.openConnection();
             CallableStatement call = connection.prepareCall(
                     "{call sp_excluir_aluno(?)}")) {

            call.setInt(1, idAluno);

            call.execute();
        }
    }

    // ==========================================
    // LEITURA DOS RESULTADOS DO BANCO
    // ==========================================

    private List<String[]> readRows(ResultSet rows) throws SQLException {
        int columnCount = rows.getMetaData().getColumnCount();

        List<String[]> result = new ArrayList<>();

        String[] columns = new String[columnCount];

        for (int i = 0; i < columnCount; i++) {
            columns[i] = rows.getMetaData().getColumnLabel(i + 1);
        }

        result.add(columns);

        while (rows.next()) {
            String[] values = new String[columnCount];

            for (int i = 0; i < columnCount; i++) {
                values[i] = rows.getString(i + 1);
            }

            result.add(values);
        }

        return result;
    }
}
