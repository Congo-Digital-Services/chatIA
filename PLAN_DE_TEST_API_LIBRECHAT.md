# Plan de test API LibreChat

Base URL locale :

`http://localhost:3080`

Compte de test utilisé :

- email : `sylviangassaki20@gmail.com`
- rôle : `ADMIN`

## 1. Pré-requis généraux

- Le backend doit répondre sur `http://localhost:3080`
- Pour les routes protégées, il faut un token JWT via `POST /api/auth/login`
- Certaines routes exigent un vrai `User-Agent` de navigateur, sinon retour `Illegal request`
- Plusieurs routes fonctionnent techniquement mais bloquent ensuite sur la configuration provider

Header `User-Agent` sûr à réutiliser :

`Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36`

## 2. Routes d’authentification

### 2.1 Routes locales

- `POST /api/auth/login`
  - rôle : connexion email/mot de passe
  - body :
    ```json
    {
      "email": "sylviangassaki20@gmail.com",
      "password": "Mauricette20@"
    }
    ```
  - statut : testée, fonctionne
  - réponse : renvoie `token` + `user`
  - contrainte : dans Postman, body obligatoire en `raw JSON`, sinon `{"message":"Missing credentials"}`

- `POST /api/auth/register`
  - rôle : création de compte
  - body type :
    ```json
    {
      "name": "Test User",
      "username": "testuser",
      "email": "test@example.com",
      "password": "Test123456!"
    }
    ```
  - statut : testée
  - contrainte rencontrée : rate limit actif
  - erreur observée :
    ```json
    {"message":"Too many accounts created, please try again after 60 minutes"}
    ```
  - contournement utilisé : `npm run create-user`

- `POST /api/auth/logout`
  - rôle : déconnexion
  - statut : non testée
  - contrainte probable : nécessite auth active

- `POST /api/auth/refresh`
  - rôle : renouveler le token
  - statut : non testée
  - contrainte : utilise surtout le cookie `refreshToken`

### 2.2 SSO / OAuth

Routes repérées :

- `GET /oauth/google`
- `GET /oauth/google/callback`
- `GET /oauth/github`
- `GET /oauth/github/callback`
- `GET /oauth/discord`
- `GET /oauth/discord/callback`
- `GET /oauth/facebook`
- `GET /oauth/facebook/callback`
- `GET /oauth/openid`
- `GET /oauth/openid/callback`
- `GET /oauth/apple`
- `POST /oauth/apple/callback`
- `GET /oauth/saml`
- `POST /oauth/saml/callback`

Statut :

- non testées
- repérées dans le code
- non activées actuellement sur l’instance locale selon `/api/config`

## 3. Routes de configuration

- `GET /api/config`
  - rôle : vérifier les features activées
  - statut : testée, fonctionne
  - usage : très utile avant de tester auth, SSO, speech, social login
  - constats vus :
    - `emailLoginEnabled: true`
    - `registrationEnabled: true`
    - providers SSO à `false`

## 4. Routes de chat

### 4.1 Démarrage de chat provider

- `POST /api/agents/chat/openAI`
  - rôle : démarrer une génération via provider OpenAI
  - body minimal testé :
    ```json
    {
      "endpoint": "openAI",
      "model": "gpt-4o-mini",
      "conversationId": null,
      "parentMessageId": "00000000-0000-0000-0000-000000000000",
      "messageId": "11111111-1111-4111-8111-111111111111",
      "text": "Bonjour"
    }
    ```
  - statut : testée, route fonctionne
  - réponse observée :
    ```json
    {
      "streamId": "...",
      "conversationId": "...",
      "status": "started"
    }
    ```
  - contraintes rencontrées :
    - utiliser `/api/agents/chat/openAI`, pas `/api/agents/chat` pour un provider OpenAI
    - si pas de `model` : erreur `missing_model`
    - si token invalide : `jwt malformed` ou `jwt expired`

- `POST /api/agents/chat`
  - rôle : chat avec un agent LibreChat
  - statut : partiellement repérée, non test fonctionnel complet
  - contrainte : nécessite un `agent_id`

### 4.2 Stream de chat

- `GET /api/agents/chat/stream/:streamId`
  - rôle : lire le flux SSE du chat
  - statut : testée, route fonctionne
  - précision : il s’agit d’un flux `SSE` temps réel, pas de `SSR`
  - contraintes :
    - nécessite un token frais
    - nécessite `Accept: text/event-stream`
  - erreurs observées pendant les tests :
    - `jwt malformed`
    - `jwt expired`
    - `{"type":"missing_model","info":"openAI"}`
    - `{"type":"no_user_key"}`
  - conclusion :
    - le transport temps réel SSE est validé
    - les événements sont bien remontés par la route
    - la génération complète et le suivi réel de la réponse du modèle restent bloqués tant qu’une vraie clé OpenAI n’est pas configurée

Conclusion chat OpenAI :

- la route fonctionne
- le stream fonctionne
- le blocage final actuel est la config provider
- cause actuelle : `.env` contient `OPENAI_API_KEY=user_provided`, donc aucune vraie clé OpenAI serveur

## 5. Routes de conversations et messages

- `GET /api/convos?sortBy=updatedAt&sortDirection=desc&pageSize=10`
  - rôle : lister les conversations
  - statut : testée, fonctionne
  - réponse observée :
    ```json
    {"conversations":[],"nextCursor":null}
    ```
  - conclusion : aucune conversation persistée pour l’utilisateur de test

- `GET /api/messages/:conversationId`
  - rôle : lire les messages d’une conversation
  - statut : testée, fonctionne
  - réponse observée :
    ```json
    {"error":"Conversation not found"}
    ```
  - conclusion : la route est bonne, mais l’ID testé n’était pas une conversation persistée

- `POST /api/messages/:conversationId`
  - rôle : sauvegarder un message dans une conversation existante
  - statut : non testée jusqu’au bout
  - contrainte : nécessite un `conversationId` réellement existant en base
  - body type :
    ```json
    {
      "messageId": "22222222-2222-4222-8222-222222222222",
      "parentMessageId": "00000000-0000-0000-0000-000000000000",
      "sender": "User",
      "text": "Message de test",
      "isCreatedByUser": true,
      "error": false
    }
    ```

- `GET /api/messages/:conversationId/:messageId`
  - rôle : lire un message précis
  - statut : non testée

- `PUT /api/messages/:conversationId/:messageId`
  - rôle : modifier un message
  - statut : non testée

- `DELETE /api/messages/:conversationId/:messageId`
  - rôle : supprimer un message
  - statut : non testée

## 6. Routes image / fichiers

- `POST /api/files/images`
  - rôle : upload d’image
  - statut : testée, fonctionne
  - type : `multipart/form-data`
  - champs requis observés :
    - `file`
    - `endpoint`
    - `file_id`
    - `width`
    - `height`
  - contrainte : route protégée + `User-Agent` navigateur recommandé
  - exemple :
    ```bash
    curl -X POST http://localhost:3080/api/files/images \
      -H "Authorization: Bearer <TOKEN>" \
      -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36" \
      -F "file=@/chemin/vers/image.png" \
      -F "endpoint=openAI" \
      -F "file_id=33333333-3333-4333-8333-333333333333" \
      -F "width=1024" \
      -F "height=1024"
    ```
  - erreurs observées pendant les essais :
    - `Error processing file` avec cause réelle dans les logs : `No file_id provided`
    - `Error processing file` avec cause réelle dans les logs : `No width provided`
  - réponse finale observée en succès :
    ```json
    {
      "message": "File uploaded and processed successfully",
      "file_id": "9fcbdf97-375c-4f13-90e6-2915cbb5bb50",
      "temp_file_id": "33333333-3333-4333-8333-333333333333",
      "filepath": "/images/6a26ab8ce71cd202eed332d4/9fcbdf97-375c-4f13-90e6-2915cbb5bb50__WhatsApp_Image_2026-04-17_at_07.17.25-crop.png",
      "type": "image/png",
      "source": "local",
      "width": 662,
      "height": 299
    }
    ```

- `POST /api/files`
  - rôle : upload fichier générique
  - statut : testée, fonctionne
  - type : `multipart/form-data`
  - champs requis observés pour un test simple :
    - `file`
    - `endpoint`
    - `file_id`
    - `message_file=true`
  - contrainte importante :
    - sans `message_file=true`, la route bascule vers le flux agent et peut réclamer un `agent_id` ou un `tool_resource`
  - exemple validé :
    ```bash
    curl -X POST http://localhost:3080/api/files \
      -H "Authorization: Bearer <TOKEN>" \
      -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36" \
      -F "file=@/Users/macbook/Downloads/f6f5a158-a221-4260-8055-70fa57a03691.pdf" \
      -F "endpoint=openAI" \
      -F "file_id=44444444-4444-4444-8444-444444444444" \
      -F "message_file=true"
    ```
  - réponse finale observée en succès :
    ```json
    {
      "message": "Agent file uploaded and processed successfully",
      "file_id": "1eae1789-1b4d-43e3-b268-6b0640a34648",
      "temp_file_id": "44444444-4444-4444-8444-444444444444",
      "filepath": "/uploads/6a26ab8ce71cd202eed332d4/1eae1789-1b4d-43e3-b268-6b0640a34648__f6f5a158-a221-4260-8055-70fa57a03691.pdf",
      "type": "application/pdf",
      "source": "local"
    }
    ```

## 7. Routes voix / speech

- `GET /api/files/speech/tts/voices`
  - rôle : lister les voix TTS disponibles
  - statut : testée, route fonctionne
  - erreur observée :
    ```json
    {"error":"Failed to get voices: Configuration or TTS schema is missing"}
    ```
  - conclusion : la route est bonne, mais `speech.tts` n’est pas configuré

- `POST /api/files/speech/stt`
  - rôle : speech-to-text
  - statut : non testée
  - type : `multipart/form-data`
  - champ fichier attendu : `audio`
  - contrainte probable : nécessite config `speech.stt`

- `POST /api/files/speech/tts`
  - rôle : streaming TTS
  - statut : non testée
  - contrainte probable : nécessite config `speech.tts`

- `POST /api/files/speech/tts/manual`
  - rôle : TTS manuel
  - statut : non testée

## 8. Problèmes et contraintes déjà rencontrés

- `ECONNREFUSED 127.0.0.1:3080`
  - cause : backend non démarré

- `cross-env: command not found`
  - cause : dépendances non installées / environnement incomplet

- MongoDB et MeiliSearch indisponibles
  - cause : services non lancés
  - solution retenue : Docker + publication des ports

- `Illegal request`
  - cause : filtre `User-Agent` anti non-browser
  - solution : envoyer un `User-Agent` de navigateur complet

- bannissement temporaire du compte
  - cause : système de violations local trop agressif pendant les essais
  - solution locale appliquée :
    - `BAN_VIOLATIONS=false`
    - `NON_BROWSER_VIOLATION_SCORE=1`

- `no_user_key`
  - cause : `OPENAI_API_KEY=user_provided` dans `.env`
  - effet : la route chat passe mais la génération réelle échoue sans clé

- `Configuration or TTS schema is missing`
  - cause : aucune config `speech.tts`

## 9. Ce qui est déjà validé

- backend local opérationnel
- auth locale opérationnelle
- création utilisateur possible en CLI
- route `/api/config` OK
- route `/api/convos` OK
- route `/api/messages/:conversationId` OK côté validation/retour d’erreur
- route `/api/agents/chat/openAI` OK
- route `/api/agents/chat/stream/:streamId` OK
- flux SSE temps réel du chat validé côté route
- route `/api/files/speech/tts/voices` OK
- route `/api/files/images` OK
- route `/api/files` OK

## 10. Ce qu’il reste à tester

Priorité haute :

- `POST /api/auth/logout`
- `POST /api/auth/refresh`
- `POST /api/files/speech/stt`

Priorité moyenne :

- `POST /api/messages/:conversationId`
- `GET /api/messages/:conversationId/:messageId`
- `PUT /api/messages/:conversationId/:messageId`
- `DELETE /api/messages/:conversationId/:messageId`

Priorité ultérieure :

- routes SSO/OAuth, après activation provider
- routes TTS complètes, après config `speech.tts`
- chat provider complet, après vraie clé OpenAI

## 11. Résumé rapide

- Les routes principales d’auth fonctionnent
- Les routes chat fonctionnent techniquement, mais le provider OpenAI bloque faute de clé
- Les routes messages répondent correctement, mais il n’y a pas encore de conversation persistée
- La route voices fonctionne techniquement, mais TTS n’est pas configuré
- La prochaine meilleure cible de test est `POST /api/files/images` ou `POST /api/files/speech/stt`
