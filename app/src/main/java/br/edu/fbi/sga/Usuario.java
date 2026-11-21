package br.edu.fbi.sga;

public record Usuario(int id, String nome, String email, String perfil) {
    public boolean isCoordenador() {
        return "Coordenador".equalsIgnoreCase(perfil);
    }

    public boolean isSecretario() {
        return "Secretario".equalsIgnoreCase(perfil);
    }
}
