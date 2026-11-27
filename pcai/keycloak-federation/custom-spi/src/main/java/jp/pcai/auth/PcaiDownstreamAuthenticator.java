package jp.pcai.auth;

import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.nio.charset.StandardCharsets;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;

public final class PcaiDownstreamAuthenticator implements Authenticator {
    private final JwtValidator validator = new JwtValidator();
    private final UpstreamConfig config;
    PcaiDownstreamAuthenticator(UpstreamConfig config) { this.config = config; }
    @Override public void authenticate(AuthenticationFlowContext context) {
        try {
            List<String> headers = context.getHttpRequest().getHttpHeaders().getRequestHeader("Authorization");
            if (headers == null || headers.size() != 1 || !headers.get(0).startsWith("Bearer ")) { reject(context); return; }
            JwtValidator.Identity identity = validator.validate(headers.get(0).substring(7), config.issuer(), config.audience(), config.jwksUrl());
            List<UserModel> matches = find(context.getSession(), context.getRealm(), identity);
            UserModel user;
            if (matches.isEmpty()) {
                if (!config.autoRegister() || context.getUser() != null) { reject(context); return; }
                user = register(context, identity);
            } else {
                if (matches.size() != 1) { reject(context); return; }
                user = matches.get(0);
            }
            if (!user.isEnabled() || user.getServiceAccountClientLink() != null) { reject(context); return; }
            if (context.getUser() != null && !context.getUser().getId().equals(user.getId())) { reject(context); return; }
            if (config.syncAttributes()) sync(context.getSession(), context.getRealm(), user, identity);
            context.setUser(user);
            context.success();
        } catch (Exception e) {
            // Do not log tokens, claims, or user attributes.
            reject(context);
        }
    }
    private static List<UserModel> find(KeycloakSession session, RealmModel realm, JwtValidator.Identity identity) {
        try (var users = session.users().searchForUserByUserAttributeStream(realm, "upstream_subject", identity.subject())) {
            return users.filter(u -> List.of(identity.issuer()).equals(u.getAttributeStream("upstream_issuer").toList())
                && List.of(identity.subject()).equals(u.getAttributeStream("upstream_subject").toList())).limit(2).toList();
        }
    }
    private static String username(JwtValidator.Identity identity) {
        String name = identity.username();
        if (name == null || name.length() < 3 || !name.matches("[a-zA-Z0-9._@-]+"))
            throw new IllegalArgumentException("Missing or unsupported username");
        return name.toLowerCase(Locale.ROOT);
    }
    private static void sync(KeycloakSession session, RealmModel realm, UserModel user, JwtValidator.Identity identity) {
        // Username remains stable after creation; identity binding is issuer + subject.
        if (identity.email() != null && !identity.email().equals(user.getEmail())) {
            var existing = session.users().getUserByEmail(realm, identity.email());
            if (existing != null && !existing.getId().equals(user.getId())) throw new IllegalArgumentException("Email conflict");
            user.setEmail(identity.email());
            user.setEmailVerified(false);
        }
        if (identity.firstName() != null) user.setFirstName(identity.firstName());
        if (identity.lastName() != null) user.setLastName(identity.lastName());
    }
    private static UserModel register(AuthenticationFlowContext context, JwtValidator.Identity identity) {
        KeycloakSession session = context.getSession();
        RealmModel realm = context.getRealm();
        String name = username(identity);
        if (session.users().getUserByUsername(realm, name) != null) throw new IllegalArgumentException("Username conflict");
        if (identity.email() != null && session.users().getUserByEmail(realm, identity.email()) != null) throw new IllegalArgumentException("Email conflict");
        String id = UUID.nameUUIDFromBytes((realm.getId() + "\n" + identity.issuer() + "\n" + identity.subject()).getBytes(StandardCharsets.UTF_8)).toString();
        // No default roles/groups or required actions; authorization is external to this SPI.
        UserModel user = session.users().addUser(realm, id, name, true, false);
        user.setSingleAttribute("upstream_issuer", identity.issuer());
        user.setSingleAttribute("upstream_subject", identity.subject());
        sync(session, realm, user, identity);
        user.setEnabled(true);
        return user;
    }
    private void reject(AuthenticationFlowContext context) {
        context.failure(AuthenticationFlowError.INVALID_CREDENTIALS,
            context.form().setError("Access denied").createErrorPage(jakarta.ws.rs.core.Response.Status.FORBIDDEN));
    }
    @Override public void action(AuthenticationFlowContext context) { reject(context); }
    @Override public boolean requiresUser() { return false; }
    @Override public boolean configuredFor(KeycloakSession s, RealmModel r, UserModel u) { return true; }
    @Override public void setRequiredActions(KeycloakSession s, RealmModel r, UserModel u) {}
    @Override public void close() {}
}
