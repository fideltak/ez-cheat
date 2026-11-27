# PCAI Downstream Authenticator SPI (Keycloak 25.0.6)

検証用の実装。Java 21 / Maven 3.9。上位 Keycloak、OAuth2 Proxy は変更しない。クラスター内部を信頼し、mTLS/接続元制限は追加しないという前提。

## ビルド

```sh
java -version
mvn -version
mvn clean package
```

`target/pcai-downstream-authenticator-0.4.0.jar` を下位 Keycloak の `/opt/keycloak/providers/` に配置。通常の `kc.sh start` で起動するか、最適化起動なら配置後に `kc.sh build` を実行してから `kc.sh start --optimized`。全レプリカに同じ JAR を配置する。実行 JVM は Java 21 が必要。

## 環境変数（すべて必須、デフォルトなし）

下位 Keycloak のコンテナに設定する。以下は Kubernetes の env の例（実際の環境に合わせて変更する）。

```yaml
env:
  - name: PCAI_UPSTREAM_ISSUER
    value: "https://keycloak.example.com/realms/UPSTREAM_REALM"
  - name: PCAI_UPSTREAM_AUDIENCE
    value: "UPSTREAM_CLIENT_ID"
  - name: PCAI_UPSTREAM_JWKS_URL
    value: "https://keycloak.example.com/realms/UPSTREAM_REALM/protocol/openid-connect/certs"
  - name: PCAI_AUTO_REGISTER
    value: "true"
  - name: PCAI_SYNC_USER_ATTRIBUTES
    value: "true"
```

初回の SPI インスタンス取得時に読み込み、未設定・空値・不正な HTTPS URL は例外で拒否する。起動時の検証ではない（ビルド時にも環境変数は不要）。設定変更後は全 Pod を再起動する。管理画面からの上書きは不可。Provider ID は `pcai-downstream-authenticator` のままなので 旧版からの更新では既存 Execution を維持できる。旧 JAR は除去する。上記5項目が必須。

## 管理コンソール

1. 下位 Realm を作成（例: `DOWNSTREAM_REALM`）。User registration を OFF。管理者用 master Realm の認証フローは変更しない。
2. Realm settings → User profile に `upstream_issuer` と `upstream_subject` を追加。編集・閲覧権限は admin のみにする。単一値属性とする。ユーザー名やメールのみの照合は行わない。
3. 初回の正規 JWT でユーザーを登録し、認証を続行する。管理者は Users でユーザーを確認し、必要なグループを割り当てる。自動登録を false にすると事前登録のみ。既存ユーザーの issuer/subject は変更しない。グループによるログイン制限が必要なら別の認証フローやアプリ側で実装する。
4. Authentication → Flows → Create flow → Basic flow `PCAI Browser`。Add step → `PCAI Downstream Authenticator` → REQUIRED。Cookie や Password Form 等の代替経路を入れない。設定用の歯車は不要。接続設定は環境変数からのみ取得する。
5. Clients → harbor → Advanced → Authentication flow overrides → Browser Flow に PCAI Browser を設定。Standard flow ON、Client authentication ON、Direct access grants OFF。Harbor の正確な callback URL を登録。必要な Group Membership Mapper を ID Token に設定。
6. 許可対象の全 Client に同じフローを REQUIRED で割り当てる。Device Grant、Direct Grant、不要な Token Exchange、代替ログイン経路を無効化する。登録用 Realm のパスワードリセット、セルフ登録、不要な認証経路も無効化し、不要な required actions を割り当てない。Harbor の OIDC issuer は下位 Realm URL。Client ID/Secret は下位のもの。Group Claim Name は groups、管理者グループは下位で設定したもの。

## 登録と同期の詳細

- SPI は Client ID やグループ所属で認証を制限しない。初期グループ・ロール・required action は付与しない。権限は下位 Keycloak と各サービスで管理する。グループ未所属でも SPI の認証は成功する。
- `PCAI_AUTO_REGISTER=true` の場合のみ登録を行う。登録は通常の認証トランザクション内で行い、そのまま認証を続行する。後続の認証処理やトランザクションの失敗により登録が永続化されない場合がある。既存アカウントへのユーザー名・メールによる自動紐付けはしない。同名・同一メールの衝突時は拒否する。新規 username は ASCII の英数字と `._@-` のみ（3〜255文字）。
- `PCAI_SYNC_USER_ATTRIBUTES=true` は既存ユーザーの email / given_name / family_name を、存在する Claim のみ更新する。username は初回作成時のみ、グループ・ロールは同期しない。メール検証済みフラグは引き継がない。属性同期でメールが変わると未検証に戻す。登録時にはフラグにかかわらず基本属性を設定する。
- 上位トークンに必要な氏名・メール Claim がない場合は管理者が補う。User Profile の必須項目や Verify Email 等により追加画面が発生する場合があるため、実際の OIDC フローを確認する。ユーザー自身による識別属性の編集は禁止する。
- グループの割り当てやアクセス制限は SPI の対象外。Harbor 等ではグループ未所属でもログインできる場合がある。ログイン自体を制限する場合は別途認可を設定し、権限剥奪時には下位 KC とアプリのセッションを失効させる。

## TLS / Gateway

`gateway-auth-policy.yaml` はテンプレート。適用前に `DOWNSTREAM_HOST`、`DOWNSTREAM_REALM`、`GATEWAY_NAMESPACE`、`OAUTH_PROVIDER`、`GATEWAY_SELECTOR_KEY`、`GATEWAY_SELECTOR_VALUE` を対象環境に合わせて置換する。コンテキストパスがある場合は paths にも反映する。VirtualService と Service は下位 Keycloak の Helm 設定に合わせる。既存 OAuth2 Proxy から Authorization ヘッダーに ID Token が渡ることを対象環境で確認する。Token/Discovery/JWKS API には CUSTOM policy を適用しない。管理画面の master Realm にも適用しない。

JWKS URL は HTTPS を使用する。接続先の TLS 証明書を発行した CA が Java の truststore から信頼されていることが必要。Java HttpClient は JVM の TLS 設定を利用する。証明書検証を無効にしない。必要なら専用 truststore を作成して JVM に指定する。

## 検証項目

- 正規 ID Token かつ登録済み・有効なユーザー → 成功
- 初回登録（自動登録 ON）→ Users に保存され認証成功。グループの有無にかかわらず SPI は認証を許可する。未登録（自動登録 OFF）、無効、属性重複、署名不正、期限切れ、issuer/audience/azp/type 不一致 → 拒否
- 同名・同一メールの別ユーザーや並行登録 → 自動紐付けなし。登録の永続化と重複防止を実機確認する。
- JWT 欠落、JWKS 取得不能（キャッシュ期限後）→ 拒否
- 未認証ブラウザのリダイレクト後に OIDC state が維持されること
- Harbor の token API、グループ claim、ログアウトとセッション失効
- 鍵ローテーション時は最大60秒のキャッシュ期間があり、新しい kid は更新まで拒否する。

## 制約

上位 ID Token の audience は既存認証仲介用の Client ID であり、下位 KC に直接発行されたものではない。これは標準 OIDC brokering ではなく、既存認証仲介への独自の信頼設定。クラスター内からの直接通信を許容するため、正規 ID Token の再利用を防止しない。既存 OAuth2 Proxy が bearer token による認証を許可する場合も含め、Gateway だけで replay を防げない。署名検証は上位セッションの即時失効確認ではない。本番利用にはこのリスクの承認、信頼境界、セッション管理、HPE サポート可否の確認が必要。

署名アルゴリズムは RS256 のみ（対象環境の JWT ヘッダー alg を確認すること）。対象環境での Maven コンパイル・実機試験を実施すること。JAR バイナリは同梱していない。

参考: https://www.keycloak.org/docs/25.0.6/server_development/index.html
