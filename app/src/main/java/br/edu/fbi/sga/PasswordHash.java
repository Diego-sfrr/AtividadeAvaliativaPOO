package br.edu.fbi.sga;

import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class PasswordHash {
    private PasswordHash() { }

    public static String sha256(char[] password) {
        ByteBuffer encoded = null;
        byte[] bytes = null;
        try {
            encoded = StandardCharsets.UTF_8.newEncoder().encode(CharBuffer.wrap(password));
            bytes = new byte[encoded.remaining()];
            encoded.get(bytes);
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException | CharacterCodingException exception) {
            throw new IllegalStateException("Não foi possível calcular o hash SHA-256 da senha.", exception);
        } finally {
            if (bytes != null) Arrays.fill(bytes, (byte) 0);
            if (encoded != null && encoded.hasArray()) Arrays.fill(encoded.array(), (byte) 0);
            Arrays.fill(password, '\0');
        }
    }
}
