import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;
import java.util.jar.*;

public class FirstUpload {
    static final Path ROOT = Path.of("").toAbsolutePath();
    static final Path OUTPUT = ROOT.resolve("UPLOAD_TO_PLAY");
    static final String UNSIGNED = "NumberSlidePro-unsigned.aab";
    static final String SIGNED = "NumberSlidePro-upload-signed.aab";
    static final String DEFAULT_ALIAS = "upload";

    static void run(String tool, List<String> args) throws Exception {
        String suffix = System.getProperty("os.name").startsWith("Windows") ? ".exe" : "";
        Path executable = Path.of(System.getProperty("java.home"), "bin", tool + suffix);
        var command = new ArrayList<String>();
        command.add(executable.toString());
        command.addAll(args);
        int status = new ProcessBuilder(command).inheritIO().start().waitFor();
        if (status != 0) throw new IOException(tool + " exited with code " + status);
    }

    static String digest(Path file) throws Exception {
        var sha = MessageDigest.getInstance("SHA-256");
        try (var in = new DigestInputStream(Files.newInputStream(file), sha)) {
            in.transferTo(OutputStream.nullOutputStream());
        }
        return HexFormat.of().formatHex(sha.digest());
    }

    static void verifyDownload(Path input) throws Exception {
        String name = input.getFileName().toString();
        String expected = null;
        for (var line : Files.readAllLines(input.resolveSibling("SHA256SUMS"))) {
            String[] fields = line.trim().split("\\s+\\*?", 2);
            if (fields.length == 2 && fields[1].equals(name)) expected = fields[0];
        }
        if (expected == null || !expected.equalsIgnoreCase(digest(input))) {
            throw new SecurityException("Bundle checksum mismatch. Extract a fresh copy of the complete package.");
        }
    }

    static X509Certificate verifySigner(Path file) throws Exception {
        X509Certificate signer = null;
        boolean manifestFound = false;
        try (var jar = new JarFile(file.toFile(), true)) {
            for (var e : Collections.list(jar.entries())) {
                if (e.isDirectory()) continue;
                try (var content = jar.getInputStream(e)) { content.transferTo(OutputStream.nullOutputStream()); }
                if (e.getName().toUpperCase(Locale.ROOT).matches("META-INF/(MANIFEST\\.MF|[^/]+\\.(SF|RSA|DSA|EC)|SIG-[^/]+)")) continue;
                var signers = e.getCodeSigners();
                if (signers == null || signers.length != 1) throw new SecurityException("Missing or unexpected signer: " + e.getName());
                var cert = (X509Certificate)signers[0].getSignerCertPath().getCertificates().get(0);
                if (signer != null && !signer.equals(cert)) throw new SecurityException("Multiple signing identities.");
                signer = cert;
                if (e.getName().equals("base/manifest/AndroidManifest.xml")) manifestFound = true;
            }
        }
        if (!manifestFound || signer == null) throw new SecurityException("A signed Android App Bundle is required.");
        signer.checkValidity();
        var subject = signer.getSubjectX500Principal().getName().toLowerCase(Locale.ROOT);
        if (subject.contains("android debug") || subject.contains("local preview")) {
            throw new SecurityException("A preview/debug certificate cannot be used as the upload identity.");
        }
        return signer;
    }

    static void passwordArgs(List<String> args) {
        // Optional for automated testing or a user's local secret manager. Interactive runs prompt in the JDK.
        if (System.getenv("NUMBER_SLIDE_STOREPASS") != null) {
            args.addAll(List.of("-storepass:env", "NUMBER_SLIDE_STOREPASS"));
        }
        if (System.getenv("NUMBER_SLIDE_KEYPASS") != null) {
            args.addAll(List.of("-keypass:env", "NUMBER_SLIDE_KEYPASS"));
        }
    }

    static void ensureKey(Path key, String alias, boolean allowCreate) throws Exception {
        if (Files.isRegularFile(key)) return;
        if (!allowCreate) throw new IOException("Existing keystore not found. Restore it before signing.");
        Files.createDirectories(key.getParent());
        Path temp = Files.createTempDirectory(key.getParent(), ".create-upload-");
        Path generated = temp.resolve("upload.p12");
        try {
            System.out.println("Create a strong password for your permanent Number Slide Pro upload key.");
            var args = new ArrayList<>(List.of("-genkeypair", "-storetype", "PKCS12", "-keystore", generated.toString(),
                "-alias", alias, "-keyalg", "RSA", "-keysize", "3072", "-validity", "10000",
                "-dname", "CN=Number Slide Pro Upload"));
            passwordArgs(args);
            run("keytool", args);
            Files.move(generated, key); // Never replace a key created by another run.
        } finally {
            Files.deleteIfExists(generated);
            Files.deleteIfExists(temp);
        }
        System.out.println("Back up this encrypted keystore and save its password: " + key);
    }

    static void prepare(String[] args) throws Exception {
        if (args.length > 2) throw new IllegalArgumentException("Usage: FirstUpload.java [existing-keystore [alias]]");
        Path android = ROOT.resolve("android");
        Path supplied = android.resolve(SIGNED);
        boolean signedInCI = Files.isRegularFile(supplied);
        Path input = signedInCI ? supplied : android.resolve(UNSIGNED);
        verifyDownload(input);
        Files.createDirectories(OUTPUT);
        Path destination = OUTPUT.resolve(SIGNED);
        Path stage = Files.createTempDirectory(OUTPUT, ".verify-");
        Path candidate = stage.resolve(SIGNED);
        try {
            if (signedInCI) {
                Files.copy(input, candidate);
            } else {
                String local = System.getenv("LOCALAPPDATA");
                Path home = local == null ? Path.of(System.getProperty("user.home"), ".local", "share") : Path.of(local);
                Path key = args.length == 0 ? home.resolve("Bilvok/NumberSlidePro/Signing/upload.p12") : Path.of(args[0]).toAbsolutePath();
                String alias = args.length > 1 ? args[1] : DEFAULT_ALIAS;
                ensureKey(key, alias, args.length == 0 && !Files.exists(destination));
                var sign = new ArrayList<>(List.of("-keystore", key.toString(), "-digestalg", "SHA-256",
                    "-signedjar", candidate.toString()));
                passwordArgs(sign);
                sign.add(input.toString());
                sign.add(alias);
                run("jarsigner", sign);
            }
            var cert = verifySigner(candidate);
            if (Files.exists(destination) && !verifySigner(destination).equals(cert)) {
                throw new SecurityException("Existing output uses a different certificate; check your upload keystore.");
            }
            Files.move(candidate, destination, StandardCopyOption.REPLACE_EXISTING);
            Files.write(OUTPUT.resolve("upload-certificate.der"), cert.getEncoded());
            System.out.println("Verified signed bundle: " + destination);
            System.out.println("Upload certificate SHA-256: " +
                HexFormat.ofDelimiter(":").withUpperCase().formatHex(MessageDigest.getInstance("SHA-256").digest(cert.getEncoded())));
        } finally {
            Files.deleteIfExists(candidate);
            Files.deleteIfExists(stage);
        }
    }

    public static void main(String[] args) {
        try { prepare(args); }
        catch (Exception e) { System.err.println("First-upload preparation stopped: " + e.getMessage()); System.exit(1); }
    }
}
