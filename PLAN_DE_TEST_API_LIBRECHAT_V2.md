# Plan de test API LibreChat V2

Version orientee architecture actuelle :

- LibreChat n'utilise plus l'auth locale comme parcours principal
- ChatIA doit s'aligner sur le meme realm SSO Keycloak
- l'objectif n'est plus seulement de tester des routes isolees, mais de verifier la continuite d'identite entre SSO, LibreChat et ChatIA

Base backend cible :

`http://localhost:3080`

Realm SSO cible :

- realm Keycloak partage entre LibreChat et ChatIA
- meme utilisateur attendu dans les deux applications

## 1. Objectifs de la V2

- verifier que ChatIA et LibreChat partagent bien la meme identite SSO
- verifier que les tokens/session emis via le realm commun permettent d'acceder aux routes protegees LibreChat
- verifier que les features exposees par `/api/config` correspondent a la strategie SSO attendue
- verifier que les routes chat, fichiers, speech et conversations restent operables avec cette auth partagee
- separer clairement :
  - les tests de federation SSO
  - les tests de session applicative LibreChat
  - les tests fonctionnels API metier

## 2. Hypotheses d'architecture a valider

Hypotheses actuelles :

- LibreChat et ChatIA pointent vers le meme realm Keycloak
- le client SSO utilise par ChatIA est compatible avec la conf OIDC attendue
- l'utilisateur connecte dans ChatIA doit etre reconnu comme le meme utilisateur cote LibreChat
- les providers sociaux ou login local LibreChat ne sont plus le parcours principal

Points a confirmer techniquement :

- LibreChat consomme-t-il un cookie de session propre apres callback SSO, ou accepte-t-il directement un bearer token exploitable par ChatIA ?
- le token porte-t-il les claims suffisants : `sub`, `email`, `preferred_username`, roles eventuels
- la deconnexion OIDC suffit-elle, ou faut-il aussi appeler une route backend LibreChat
- le refresh de session passe-t-il par cookie backend, refresh token OIDC, ou recreation de session

## 3. Pre-requis generaux

- backend LibreChat demarre sur `http://localhost:3080`
- Keycloak joignable et realm commun configure
- client OIDC LibreChat configure
- client OIDC ChatIA configure
- callback web autorise pour ChatIA
- post logout redirect autorise
- CORS/origins autorises pour l'environnement de test
- un utilisateur de test existe deja dans le realm partage

Variables a verifier cote ChatIA :

- `CHATIA_API_BASE_URL`
- `KEYCLOAK_BASE_URL`
- `KEYCLOAK_REALM`
- `KEYCLOAK_CLIENT_ID`
- `KEYCLOAK_CLIENT_SECRET` si necessaire
- `KEYCLOAK_WEB_REDIRECT_ORIGIN`
- `KEYCLOAK_MOBILE_REDIRECT_SCHEME`
- `KEYCLOAK_MOBILE_REDIRECT_HOST`
- `KEYCLOAK_LOGOUT_REDIRECT_PATH`

Headers a surveiller pour les appels API :

- `Authorization: Bearer <token>` si le backend attend un bearer
- `User-Agent` navigateur lorsque LibreChat applique le filtre anti non-browser
- `Accept: text/event-stream` pour le stream SSE

## 4. Axe A - Validation du SSO partage

### 4.1 Configuration OIDC de ChatIA

Verifier :

- issuer correct
- realm correct
- client id correct
- redirect URI correcte
- logout redirect correcte
- scopes minimum : `openid profile email`

Succes attendu :

- la redirection vers Keycloak fonctionne
- le callback revient sur ChatIA sans erreur de state ni PKCE
- la session locale ChatIA est creee

Echecs a surveiller :

- redirect URI mismatch
- state OAuth invalide
- verifier PKCE manquant
- popup bloquee si un flux popup est reintroduit
- CORS ou origin mismatch

### 4.2 Identite retournee apres login

Verifier dans ChatIA apres callback :

- presence `access_token`
- presence eventuelle `id_token`
- expiration coherente
- `userName` correctement derive des claims
- `email` coherent avec l'utilisateur attendu

Succes attendu :

- l'utilisateur affiche dans ChatIA correspond a celui du realm partage

### 4.3 Alignement utilisateur ChatIA / LibreChat

Objectif :

- prouver que le meme utilisateur SSO est reconnu cote LibreChat

Methodes de verification :

- appeler `/api/config` apres login et verifier absence d'erreur d'auth
- appeler `/api/convos` avec le token/session issue de ChatIA
- comparer l'identite visible dans LibreChat et ChatIA si l'UI LibreChat est disponible

Succes attendu :

- pas de `jwt malformed`
- pas de `jwt expired` immediat
- pas de creation d'un utilisateur divergent ou duplique

## 5. Axe B - Validation de session LibreChat

### 5.1 Route `/api/config`

Route :

- `GET /api/config`

Verifier :

- la route repond depuis ChatIA
- les flags d'auth refletent la strategie actuelle

Points a controler dans la reponse :

- si le login email est encore expose ou non
- si les providers SSO pertinents apparaissent
- si les features speech/images/chat attendues sont actives

Succes attendu :

- la config confirme le mode SSO reel de l'instance

### 5.2 Route `/api/auth/logout`

Route :

- `POST /api/auth/logout`

Objectif :

- verifier si LibreChat attend une invalidation backend en plus du logout OIDC

Tests :

- logout OIDC seul
- logout backend seul
- logout OIDC + logout backend

Succes attendu :

- comportement clairement compris et documente

Conclusion attendue :

- determiner le chemin de logout officiel a implementer dans ChatIA

### 5.3 Route `/api/auth/refresh`

Route :

- `POST /api/auth/refresh`

Objectif :

- verifier si cette route reste utile dans l'architecture SSO actuelle

Tests :

- appel avec session active
- appel apres expiration courte du token si possible
- appel sans cookie/session backend

Succes attendu :

- clarifier si la route doit etre integree, ignoree, ou remplacee par une logique OIDC

## 6. Axe C - Validation chat OpenAI

### 6.1 Demarrage de generation

Route :

- `POST /api/agents/chat/openAI`

Body minimal :

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

Verifier :

- route accessible avec l'identite SSO partagee
- `streamId` retourne
- `conversationId` retourne si cree

Echecs a surveiller :

- `missing_model`
- `jwt malformed`
- `jwt expired`
- `no_user_key`

### 6.2 Flux SSE

Route :

- `GET /api/agents/chat/stream/:streamId`

Verifier :

- connexion SSE et non HTTP classique
- `Accept: text/event-stream`
- lecture des chunks
- gestion du `[DONE]`

Succes attendu :

- le transport SSE fonctionne depuis ChatIA

Note :

- la generation metier complete peut rester bloquee si la cle OpenAI serveur n'est pas configuree

## 7. Axe D - Conversations et messages

### 7.1 Conversations

Route :

- `GET /api/convos?sortBy=updatedAt&sortDirection=desc&pageSize=10`

Verifier :

- la reponse vide est correctement prise en compte
- ChatIA n'affiche pas a tort uniquement des mocks quand l'API retourne vide
- les conversations reelles remplacent ou completent proprement l'etat local

Succes attendu :

- la source de verite backend est respectee

### 7.2 Messages conversation

Routes :

- `GET /api/messages/:conversationId`
- `POST /api/messages/:conversationId`
- `GET /api/messages/:conversationId/:messageId`
- `PUT /api/messages/:conversationId/:messageId`
- `DELETE /api/messages/:conversationId/:messageId`

Verifier :

- lecture d'une conversation existante
- creation d'un message sur conversation persistante
- lecture unitaire
- modification
- suppression

Succes attendu :

- couverture CRUD minimale des messages

## 8. Axe E - Fichiers et images

### 8.1 Upload image

Route :

- `POST /api/files/images`

Champs attendus :

- `file`
- `endpoint`
- `file_id`
- `width`
- `height`

Verifier :

- upload fonctionne avec utilisateur SSO
- erreurs explicites si `file_id` ou dimensions manquent
- URL/fichier exploitable cote ChatIA

### 8.2 Upload fichier generique

Route :

- `POST /api/files`

Champs attendus :

- `file`
- `endpoint`
- `file_id`
- `message_file=true`

Verifier :

- le flag `message_file=true` reste obligatoire dans le parcours ChatIA
- pas de bascule involontaire vers un flux agent

## 9. Axe F - Speech

### 9.1 STT

Route :

- `POST /api/files/speech/stt`

Verifier :

- champ `audio` correctement envoye
- transcription exploitable dans ChatIA
- comportement si provider STT non configure

### 9.2 TTS

Routes :

- `GET /api/files/speech/tts/voices`
- `POST /api/files/speech/tts`
- `POST /api/files/speech/tts/manual`

Verifier :

- etat reel de la configuration TTS
- route voices accessible
- comportement documente si `speech.tts` absent

## 10. Matrice de conformite ChatIA vs cible

Verifier explicitement dans ChatIA :

- login SSO fonctionnel
- restauration de session fonctionnelle
- logout conforme au comportement officiel LibreChat
- chargement de `/api/config`
- chargement de `/api/convos`
- chargement de `/api/messages/:conversationId`
- envoi chat OpenAI + stream SSE
- upload image
- upload fichier generique
- STT

Ecarts deja probables a verifier :

- conservation de conversations mock si `/api/convos` est vide
- absence de CRUD complet messages
- absence possible d'appel backend `/api/auth/logout`
- absence de strategie explicite pour `/api/auth/refresh`

## 11. Priorites de test

Priorite 1 :

- SSO Keycloak ChatIA
- identite partagee avec LibreChat
- `/api/config`
- `/api/convos`
- `/api/agents/chat/openAI`
- `/api/agents/chat/stream/:streamId`

Priorite 2 :

- `/api/auth/logout`
- `/api/auth/refresh`
- `/api/files/images`
- `/api/files`
- `/api/files/speech/stt`

Priorite 3 :

- CRUD messages complet
- TTS complet
- scenarios mobile lorsque le flux deep link sera implemente

## 12. Criteres de sortie

La V2 est consideree validee si :

- le meme utilisateur SSO est confirme dans ChatIA et LibreChat
- les routes protegees LibreChat sont accessibles avec le mecanisme de session retenu
- le flux chat SSE fonctionne
- les uploads principaux fonctionnent
- les ecarts restants sont explicitement documentes comme :
  - limitation backend
  - limitation de configuration
  - dette client ChatIA

## 13. Livrables attendus

- captures ou logs du login SSO
- exemple de token/claims anonymise si necessaire
- resultats `/api/config`
- resultats `/api/convos`
- resultats chat + stream SSE
- resultats upload image/fichier/STT
- liste finale des ecarts entre comportement LibreChat et implementation ChatIA
