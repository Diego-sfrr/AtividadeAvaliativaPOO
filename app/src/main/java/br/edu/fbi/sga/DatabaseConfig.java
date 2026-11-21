package br.edu.fbi.sga;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public final class DatabaseConfig {
    private DatabaseConfig() { }

    public static Connection openConnection() throws SQLException {
        String url = envOrDefault("SGA_DB_URL", "jdbc:mysql://localhost:3306/sga_fbi?serverTimezone=America/Cuiaba");
        String user = System.getenv("SGA_DB_USER");
        String password = System.getenv("SGA_DB_PASSWORD");
        if (user == null || user.isBlank() || password == null) {
            throw new SQLException("Configure SGA_DB_USER e SGA_DB_PASSWORD antes de abrir o SGA.");
        }
        return DriverManager.getConnection(url, user, password);
    }

    private static String envOrDefault(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }
}
