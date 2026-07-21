# ChatIA

Application Flutter inspiree de Conduit/OpenWebUI, avec UI mockee et base SSO Keycloak.

## Configuration d'environnement

Le projet utilise des variables compatibles Flutter via `--dart-define`.

Variables disponibles :

- `CHATIA_API_BASE_URL`
- `MOBILE_AUTH_EXCHANGE_KEY`
- `KEYCLOAK_BASE_URL`
- `KEYCLOAK_REALM`
- `KEYCLOAK_CLIENT_ID`
- `KEYCLOAK_CLIENT_SECRET`
- `KEYCLOAK_WEB_REDIRECT_ORIGIN`
- `KEYCLOAK_MOBILE_REDIRECT_SCHEME`
- `KEYCLOAK_MOBILE_REDIRECT_HOST`
- `KEYCLOAK_LOGOUT_REDIRECT_PATH`
- `KEYCLOAK_REGISTRATION_URL`
- `KEYCLOAK_FORGOT_PASSWORD_URL`

Exemple web :

```bash
flutter run -d chrome \
  --dart-define=CHATIA_API_BASE_URL=https://loba-ia.congo-digital.com \
  --dart-define=MOBILE_AUTH_EXCHANGE_KEY=change-me \
  --dart-define=KEYCLOAK_BASE_URL=https://auth.congo-digital.com \
  --dart-define=KEYCLOAK_REALM=OpenWebUI \
  --dart-define=KEYCLOAK_CLIENT_ID=librechat \
  --dart-define=KEYCLOAK_WEB_REDIRECT_ORIGIN=http://localhost:3000
```

Exemple build :

```bash
flutter build web \
  --dart-define-from-file=.env.json
```

Exemple de fichier `.env.json` :

```json
{
  "CHATIA_API_BASE_URL": "https://loba-ia.congo-digital.com",
  "MOBILE_AUTH_EXCHANGE_KEY": "change-me",
  "KEYCLOAK_BASE_URL": "https://auth.congo-digital.com",
  "KEYCLOAK_REALM": "OpenWebUI",
  "KEYCLOAK_CLIENT_ID": "librechat",
  "KEYCLOAK_CLIENT_SECRET": "",
  "KEYCLOAK_WEB_REDIRECT_ORIGIN": "http://localhost:3000",
  "KEYCLOAK_MOBILE_REDIRECT_SCHEME": "chatia",
  "KEYCLOAK_MOBILE_REDIRECT_HOST": "oauth",
  "KEYCLOAK_LOGOUT_REDIRECT_PATH": "/login",
  "KEYCLOAK_REGISTRATION_URL": "",
  "KEYCLOAK_FORGOT_PASSWORD_URL": ""
}
```

## Flux token mobile

Sur mobile, l'app ne consomme pas directement le bearer OpenID pour les routes chat.

Flux implemente :

1. login Keycloak natif via `flutter_appauth`
2. echange immediat du bearer OpenID via `POST /api/mobile/auth/exchange`
3. abandon des tokens SSO pour toutes les routes LibreChat
4. stockage local du `token` et du `refreshToken` natifs LibreChat
5. avant chaque requete protegee :
   - si le token expire dans moins de `120s`, refresh proactif
6. au redemarrage mobile :
   - si une session LibreChat native expiree est stockee localement, tentative de refresh automatique avant de renvoyer vers le SSO
7. si une requete protegee repond `401` :
   - refresh une seule fois
   - rejeu unique de la requete
8. si le refresh echoue :
   - purge de la session locale
   - l'etat auth repasse non authentifie

La logique est centralisee dans `lib/core/services/librechat_session_service.dart`.
