package jp.pcai.auth;

import java.net.URI;

record UpstreamConfig(String issuer, String audience, String jwksUrl, boolean autoRegister, boolean syncAttributes) {
    static UpstreamConfig fromEnvironment() {
        return new UpstreamConfig(
            httpsUrl("PCAI_UPSTREAM_ISSUER"),
            required("PCAI_UPSTREAM_AUDIENCE"),
            httpsUrl("PCAI_UPSTREAM_JWKS_URL"),
            flag("PCAI_AUTO_REGISTER"), flag("PCAI_SYNC_USER_ATTRIBUTES"));
    }
    private static boolean flag(String name) {
        String value = required(name);
        if (!value.equals("true") && !value.equals("false")) throw new IllegalStateException("Invalid boolean: " + name);
        return Boolean.parseBoolean(value);
    }
    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank() || !value.equals(value.strip()))
            throw new IllegalStateException("Missing or invalid environment variable: " + name);
        return value;
    }
    private static String httpsUrl(String name) {
        String value = required(name);
        try {
            URI uri = URI.create(value);
            if ("https".equals(uri.getScheme()) && uri.getHost() != null
                && uri.getUserInfo() == null && uri.getFragment() == null
                && uri.getQuery() == null) return value;
        } catch (IllegalArgumentException ignored) { }
        throw new IllegalStateException("Invalid HTTPS URL in environment variable: " + name);
    }
}
