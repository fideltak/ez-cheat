package jp.pcai.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigInteger;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.Signature;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

final class JwtValidator {
    record Identity(String issuer, String subject, String username, String email, String firstName, String lastName) {}
    private record Cached(JsonNode keys, long expires) {}
    private final ObjectMapper json = new ObjectMapper().enable(com.fasterxml.jackson.core.JsonParser.Feature.STRICT_DUPLICATE_DETECTION);
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).followRedirects(HttpClient.Redirect.NEVER).build();
    private final Map<String,Cached> cache = new HashMap<>();
    private static byte[] decode(String s) { return Base64.getUrlDecoder().decode(s); }
    private static void require(boolean condition) { if (!condition) throw new IllegalArgumentException("Invalid authentication assertion"); }
    private static String text(JsonNode n, String key) { JsonNode v=n.get(key); require(v!=null && v.isTextual() && !v.asText().isBlank()); return v.asText(); }
    private static String optionalText(JsonNode n, String key) {
        JsonNode v = n.get(key);
        if (v == null || v.isNull()) return null;
        require(v.isTextual() && v.asText().length() <= 255);
        return v.asText().isBlank() ? null : v.asText();
    }
    private static long number(JsonNode n,String key) { JsonNode v=n.get(key); require(v!=null && v.isIntegralNumber() && v.canConvertToLong()); return v.longValue(); }
    private synchronized JsonNode keys(String url) throws Exception {
        URI uri=URI.create(url); require("https".equals(uri.getScheme()) && uri.getHost()!=null && uri.getUserInfo()==null);
        long now=Instant.now().getEpochSecond(); Cached c=cache.get(url);
        if(c!=null && now<c.expires()) return c.keys();
        var response=http.send(HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(5)).GET().build(), HttpResponse.BodyHandlers.ofByteArray());
        require(response.statusCode()==200 && response.body().length<=262144);
        JsonNode k=json.readTree(response.body()).get("keys"); require(k!=null && k.isArray());
        cache.put(url,new Cached(k,now+60)); return k;
    }
    Identity validate(String token,String issuer,String audience,String jwksUrl) throws Exception {
        require(issuer!=null && !issuer.isBlank() && audience!=null && !audience.isBlank() && jwksUrl!=null);
        require(token.length()<=32768);
        String[] parts=token.split("\\.",-1); require(parts.length==3);
        JsonNode header=json.readTree(decode(parts[0]));
        require("RS256".equals(text(header,"alg")) && !header.has("crit"));
        String kid=text(header,"kid"); JsonNode match=null;
        for(JsonNode k:keys(jwksUrl)) {
            if(kid.equals(k.path("kid").asText()) && "RSA".equals(k.path("kty").asText()) && (!k.has("use") || "sig".equals(k.path("use").asText())) && (!k.has("alg") || "RS256".equals(k.path("alg").asText()))) { require(match==null); match=k; }
        }
        require(match!=null);
        BigInteger n=new BigInteger(1,decode(text(match,"n"))), e=new BigInteger(1,decode(text(match,"e")));
        require(n.bitLength()>=2048);
        var key=KeyFactory.getInstance("RSA").generatePublic(new RSAPublicKeySpec(n,e));
        Signature sig=Signature.getInstance("SHA256withRSA"); sig.initVerify(key);
        sig.update((parts[0]+"."+parts[1]).getBytes(StandardCharsets.US_ASCII)); require(sig.verify(decode(parts[2])));
        JsonNode claims=json.readTree(decode(parts[1]));
        require(issuer.equals(text(claims,"iss")) && audience.equals(text(claims,"azp")) && "ID".equals(text(claims,"typ")));
        JsonNode aud=claims.get("aud"); require(aud!=null && ((aud.isTextual() && audience.equals(aud.asText())) || (aud.isArray() && aud.size()==1 && aud.get(0).isTextual() && audience.equals(aud.get(0).asText()))));
        long now=Instant.now().getEpochSecond(); require(number(claims,"exp")>now && number(claims,"iat")<=now+30);
        if(claims.has("nbf")) require(number(claims,"nbf")<=now+30);
        String sub=text(claims,"sub"); require(sub.length()<=255);
        return new Identity(issuer, sub, optionalText(claims,"preferred_username"), optionalText(claims,"email"), optionalText(claims,"given_name"), optionalText(claims,"family_name"));
    }
}
