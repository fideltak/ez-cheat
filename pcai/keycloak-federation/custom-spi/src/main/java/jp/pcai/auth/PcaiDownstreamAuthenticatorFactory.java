package jp.pcai.auth;

import java.util.List;
import org.keycloak.Config;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.models.AuthenticationExecutionModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.provider.ProviderConfigProperty;

public final class PcaiDownstreamAuthenticatorFactory implements AuthenticatorFactory {
    public static final String ID = "pcai-downstream-authenticator";
    private volatile Authenticator authenticator;
    @Override public String getId() { return ID; }
    @Override public String getDisplayType() { return "PCAI Downstream Authenticator"; }
    @Override public String getReferenceCategory() { return null; }
    @Override public String getHelpText() { return "Validate a PCAI ID token and provision or synchronize users if enabled."; }
    @Override public boolean isConfigurable() { return false; }
    @Override public boolean isUserSetupAllowed() { return false; }
    @Override public AuthenticationExecutionModel.Requirement[] getRequirementChoices() {
        return new AuthenticationExecutionModel.Requirement[]{AuthenticationExecutionModel.Requirement.REQUIRED, AuthenticationExecutionModel.Requirement.DISABLED};
    }
    @Override public List<ProviderConfigProperty> getConfigProperties() {
        return List.of();
    }
    @Override public Authenticator create(KeycloakSession session) {
        Authenticator current = authenticator;
        if (current == null) {
            synchronized (this) {
                if (authenticator == null) authenticator = new PcaiDownstreamAuthenticator(UpstreamConfig.fromEnvironment());
                current = authenticator;
            }
        }
        return current;
    }
    @Override public void init(Config.Scope config) {}
    @Override public void postInit(KeycloakSessionFactory factory) {}
    @Override public void close() {}
}
