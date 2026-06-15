# ChatIA

Application Flutter inspiree de Conduit/OpenWebUI, avec UI mockee et base SSO Keycloak.

## Configuration d'environnement

Le projet utilise des variables compatibles Flutter via `--dart-define`.

Variables disponibles :

- `CHATIA_API_BASE_URL`
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
  --dart-define=CHATIA_API_BASE_URL=http://localhost:3080 \
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
  "CHATIA_API_BASE_URL": "http://localhost:3080",
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
