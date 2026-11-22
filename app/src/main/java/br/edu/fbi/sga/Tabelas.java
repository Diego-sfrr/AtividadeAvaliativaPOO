package br.edu.fbi.sga;

import java.util.List;

import javax.swing.JTable;
import javax.swing.table.DefaultTableModel;

/** Utilitários para exibir o resultado de views/procedures em JTable. */
final class Tabelas {

    private Tabelas() { }

    /** Índice da coluna (ignorando maiúsculas) ou -1 se não existir. */
    static int coluna(String[] cabecalho, String nome) {
        for (int i = 0; i < cabecalho.length; i++) {
            if (nome.equalsIgnoreCase(cabecalho[i])) {
                return i;
            }
        }
        return -1;
    }

    /** Valor da célula, tratando linha curta e NULL. */
    static String celula(String[] linha, int indice) {
        if (indice < 0 || indice >= linha.length || linha[indice] == null) {
            return "";
        }
        return linha[indice].trim();
    }

    /** Modelo somente leitura; a primeira linha de {@code linhas} é o cabeçalho. */
    static DefaultTableModel modelo(List<String[]> linhas) {
        String[] cabecalho = linhas.isEmpty() ? new String[0] : linhas.get(0);
        DefaultTableModel modelo = new DefaultTableModel(cabecalho, 0) {
            @Override
            public boolean isCellEditable(int linha, int coluna) {
                return false;
            }
        };
        for (int i = 1; i < linhas.size(); i++) {
            modelo.addRow(linhas.get(i));
        }
        return modelo;
    }

    static JTable tabela(List<String[]> linhas) {
        JTable tabela = new JTable(modelo(linhas));
        tabela.setAutoCreateRowSorter(true);
        tabela.setFillsViewportHeight(true);
        return tabela;
    }
}
