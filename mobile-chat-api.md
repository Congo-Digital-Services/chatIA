# API mobile / chat LibreChat

Cette note documente les routes utiles pour un client mobile ou backend qui :

- echange un bearer OpenID contre un token natif LibreChat
- demarre un chat `openAI`
- suit correctement le flux SSE de bout en bout
- liste les conversations
- lit le detail d'une conversation
- recharge un access token LibreChat via le refresh token natif

Les routes ci-dessous sont derivees du code serveur actuel.

## 1. Vue d'ensemble du flux

Flux recommande :

1. faire le SSO OpenID
2. `POST /api/mobile/auth/exchange` immediatement apres le SSO reussi
3. Recuperer `token` et `refreshToken` natifs LibreChat
4. oublier le `access_token` et le `refresh_token` OpenID pour toutes les routes LibreChat
5. `POST /api/agents/chat/openAI`
6. Ouvrir immediatement `GET /api/agents/chat/stream/:streamId`
7. Une fois termine, lire l'historique via `GET /api/messages?conversationId=...`
8. Quand le token expire, appeler `POST /api/auth/refresh` avec le `refreshToken` natif LibreChat

## 2. Contraintes globales

### Authentification

- Les routes `/api/agents/*`, `/api/convos*`, `/api/messages*` et `/api/auth/refresh` utilisent le token natif LibreChat.
- Ce token est celui renvoye par `/api/mobile/auth/exchange`.
- Le `access_token` OpenID issu du SSO n'est pas valide pour ces routes LibreChat.
- Des que l'echange est reussi, le client ne doit plus utiliser les tokens SSO pour les appels LibreChat.

### User-Agent obligatoire sur les routes chat

Les routes `/api/agents/*` passent par un filtre anti non-browser.

Si le `User-Agent` n'est pas reconnu comme navigateur, la route renvoie :

```json
{
  "message": "Illegal request"
}
```

Utiliser par exemple :

```http
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36
```

## 3. Echange mobile -> token natif LibreChat

### Route

`POST /api/mobile/auth/exchange`

### But

Echanger un bearer OpenID valide contre :

- un `token` d'acces natif LibreChat
- un `refreshToken` natif LibreChat

Cet echange doit etre fait juste apres un SSO reussi, avant la premiere requete vers LibreChat.

### Headers d'entree

```http
Authorization: Bearer <openid_access_token>
x-mobile-auth-key: <MOBILE_AUTH_EXCHANGE_KEY>
```

### Body d'entree

Aucun body JSON requis.

### Validation appliquee

- `MOBILE_AUTH_EXCHANGE_KEY` doit etre active cote serveur
- `x-mobile-auth-key` doit correspondre a la cle serveur
- le bearer doit etre un JWT `RS256`
- l'issuer du bearer doit correspondre a l'issuer OpenID configure
- l'email doit etre present
- l'email ne doit pas etre non verifie (`email_verified !== false`)
- le domaine email doit etre autorise

### Reponse 200

```json
{
  "token": "<librechat_access_token>",
  "refreshToken": "<librechat_refresh_token>",
  "user": {
    "id": "6a354dd249b43069c8614129",
    "email": "user@example.com",
    "username": "user",
    "provider": "openid"
  }
}
```

### Schema de sortie

```json
{
  "type": "object",
  "required": ["token", "refreshToken", "user"],
  "properties": {
    "token": { "type": "string" },
    "refreshToken": { "type": "string" },
    "user": {
      "type": "object",
      "required": ["id", "email", "username", "provider"],
      "properties": {
        "id": { "type": "string" },
        "email": { "type": "string" },
        "username": { "type": "string" },
        "provider": { "type": "string", "enum": ["openid"] }
      }
    }
  }
}
```

### Erreurs possibles

- `404 { "message": "Mobile auth exchange is disabled" }`
- `403 { "message": "Invalid mobile auth key" }`
- `401 { "message": "Missing bearer token" }`
- `401 { "message": "Invalid token algorithm" }`
- `401 { "message": "Invalid issuer" }`
- `401 { "message": "Invalid bearer token" }`
- `400 { "message": "Missing email in token" }`
- `403 { "message": "Email not verified" }`
- `500 { "message": "Mobile auth exchange failed" }`

## 4. Demarrer un chat OpenAI

### Route

`POST /api/agents/chat/openAI`

### Headers d'entree

```http
Authorization: Bearer <librechat_access_token>
Content-Type: application/json
User-Agent: <browser-like user agent>
```

### Body d'entree minimal

```json
{
  "endpoint": "openAI",
  "model": "gpt-4",
  "conversationId": null,
  "parentMessageId": "00000000-0000-0000-0000-000000000000",
  "messageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
  "text": "ok"
}
```

### Schema d'entree pratique

```json
{
  "type": "object",
  "required": ["endpoint", "model", "parentMessageId", "messageId", "text"],
  "properties": {
    "endpoint": { "type": "string", "enum": ["openAI"] },
    "model": { "type": "string" },
    "conversationId": { "type": ["string", "null"] },
    "parentMessageId": { "type": "string" },
    "messageId": { "type": "string" },
    "text": { "type": "string" },
    "agent_id": { "type": "string" },
    "files": { "type": "array" },
    "isTemporary": { "type": "boolean" }
  }
}
```

### Comportement important

- si `conversationId` est `null` ou `"new"`, le serveur cree un nouvel identifiant
- `streamId === conversationId`
- la route repond tout de suite, puis la generation continue en arriere-plan

### Reponse 200

```json
{
  "streamId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
  "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
  "status": "started"
}
```

### Schema de sortie

```json
{
  "type": "object",
  "required": ["streamId", "conversationId", "status"],
  "properties": {
    "streamId": { "type": "string" },
    "conversationId": { "type": "string" },
    "status": { "type": "string", "enum": ["started"] }
  }
}
```

### Erreurs typiques

- `401` / `403` si token invalide ou expire
- `400` / erreur metier si `model` manquant
- `200` puis erreur SSE plus tard si generation demarre mais echoue ensuite
- `Illegal request` si `User-Agent` non navigateur

## 5. Suivre le flux SSE de bout en bout

### Route

`GET /api/agents/chat/stream/:streamId`

### Headers d'entree

```http
Authorization: Bearer <librechat_access_token>
Accept: text/event-stream
User-Agent: <browser-like user agent>
```

### Query params

- `resume=true` : mode reconnexion avec envoi d'un etat de reprise

### Comportement correct cote client

Le client doit :

1. appeler `POST /api/agents/chat/openAI`
2. recuperer `streamId`
3. ouvrir immediatement `GET /api/agents/chat/stream/:streamId`
4. lire les evenements SSE jusqu'a la fermeture du flux
5. persister `conversationId`
6. si deconnexion, reouvrir avec `?resume=true`

### Pourquoi ouvrir le stream immediatement

Le job SSE peut etre nettoye des qu'il est complete. Si le client attend trop longtemps avant de se connecter, il peut recevoir :

```json
{
  "error": "Stream not found",
  "message": "The generation job does not exist or has expired."
}
```

### Format de transport SSE

Evenement standard :

```text
event: message
data: {...json...}
```

Evenement d'erreur :

```text
event: error
data: {"error":"Generation failed"}
```

### Evenements utiles a gerer

#### 1. Evenements `message`

Le contenu exact depend des chunks emis pendant la generation. Les formes utiles sont :

##### a. Synchronisation de reprise

Recu surtout avec `?resume=true`.

```json
{
  "sync": true,
  "resumeState": {
    "runSteps": [],
    "aggregatedContent": [],
    "userMessage": {
      "messageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
      "parentMessageId": "00000000-0000-0000-0000-000000000000",
      "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
      "text": "ok"
    },
    "responseMessageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f_",
    "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
    "sender": "AI",
    "titleEvent": {
      "event": "title",
      "data": {
        "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
        "title": "Bonjour"
      }
    },
    "replayEvents": []
  },
  "pendingEvents": []
}
```

##### b. Evenements intermediaires de generation

Le serveur peut emettre plusieurs messages intermediaires selon le modele, les outils, les run steps et les morceaux de contenu agreges.

Schema generique :

```json
{
  "type": "object",
  "additionalProperties": true
}
```

Le client ne doit pas supposer une seule forme intermediaire. Il doit simplement traiter les chunks recus jusqu'a l'evenement final.

##### c. Evenement final

```json
{
  "final": true,
  "conversation": {
    "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
    "endpoint": "openAI",
    "title": "New Chat",
    "createdAt": "2026-06-19T14:20:00.000Z",
    "updatedAt": "2026-06-19T14:20:03.000Z"
  },
  "title": "New Chat",
  "requestMessage": {
    "messageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
    "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
    "parentMessageId": "00000000-0000-0000-0000-000000000000",
    "text": "ok",
    "isCreatedByUser": true
  },
  "responseMessage": {
    "messageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f_",
    "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
    "parentMessageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
    "text": "",
    "content": [],
    "isCreatedByUser": false,
    "unfinished": false
  }
}
```

#### 2. Evenement `error`

```json
{
  "error": "Generation failed"
}
```

### Schema de sortie SSE

Le flux ne renvoie pas un unique JSON, mais une suite d'evenements SSE.

Evenements supportes par la route :

- `message`
- `error`

Structures observees :

- `message` de reprise : `{ "sync": true, "resumeState": ..., "pendingEvents": [...] }`
- `message` intermediaire : chunk libre, depend du moteur
- `message` final : `{ "final": true, "conversation": ..., "title": ..., "requestMessage": ..., "responseMessage": ... }`
- `error` : `{ "error": "<message>" }`

### Reconnexion

En cas de coupure reseau :

`GET /api/agents/chat/stream/:streamId?resume=true`

Le serveur peut renvoyer :

- un `resumeState`
- des `pendingEvents`

### Route utile de statut

`GET /api/agents/chat/status/:conversationId`

Reponse :

```json
{
  "active": true,
  "streamId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
  "status": "running",
  "aggregatedContent": [],
  "createdAt": 1781878800000,
  "resumeState": {
    "runSteps": [],
    "aggregatedContent": []
  }
}
```

Schema :

```json
{
  "type": "object",
  "required": ["active"],
  "properties": {
    "active": { "type": "boolean" },
    "streamId": { "type": "string" },
    "status": { "type": "string" },
    "aggregatedContent": { "type": "array" },
    "createdAt": { "type": "number" },
    "resumeState": { "type": "object" }
  }
}
```

## 6. Liste des conversations

### Route

`GET /api/convos`

### Headers d'entree

```http
Authorization: Bearer <librechat_access_token>
```

### Query params

- `cursor?: string`
- `limit?: number` par defaut `25`
- `isArchived?: boolean`
- `search?: string`
- `sortBy?: "title" | "createdAt" | "updatedAt"` par defaut `updatedAt`
- `sortDirection?: "asc" | "desc"` par defaut `desc`
- `tags?: string[]`
- `projectId?: string | "unassigned"`

### Reponse 200

```json
{
  "conversations": [
    {
      "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
      "endpoint": "openAI",
      "title": "New Chat",
      "createdAt": "2026-06-19T14:20:00.000Z",
      "updatedAt": "2026-06-19T14:20:03.000Z",
      "user": "6a354dd249b43069c8614129",
      "chatProjectId": null
    }
  ],
  "nextCursor": "..."
}
```

### Schema de sortie

```json
{
  "type": "object",
  "required": ["conversations", "nextCursor"],
  "properties": {
    "conversations": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["conversationId", "createdAt", "updatedAt"],
        "properties": {
          "conversationId": { "type": "string" },
          "endpoint": { "type": ["string", "null"] },
          "title": { "type": ["string", "null"] },
          "createdAt": { "type": "string" },
          "updatedAt": { "type": "string" },
          "user": { "type": "string" },
          "chatProjectId": { "type": ["string", "null"] }
        }
      }
    },
    "nextCursor": { "type": ["string", "null"] }
  }
}
```

## 7. Detail d'une conversation

### Route

`GET /api/convos/:conversationId`

### Headers d'entree

```http
Authorization: Bearer <librechat_access_token>
```

### Reponse 200

La route renvoie un objet `TConversation` complet.

Exemple :

```json
{
  "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
  "endpoint": "openAI",
  "title": "New Chat",
  "user": "6a354dd249b43069c8614129",
  "messages": [
    "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
    "031c8a62-63f4-4638-a73b-dce59e3e6b5f_"
  ],
  "model": "gpt-4",
  "createdAt": "2026-06-19T14:20:00.000Z",
  "updatedAt": "2026-06-19T14:20:03.000Z",
  "chatProjectId": null,
  "isArchived": false
}
```

### Schema de sortie principal

```json
{
  "type": "object",
  "required": ["conversationId", "createdAt", "updatedAt"],
  "properties": {
    "conversationId": { "type": ["string", "null"] },
    "endpoint": { "type": ["string", "null"] },
    "endpointType": { "type": ["string", "null"] },
    "isArchived": { "type": "boolean" },
    "title": { "type": ["string", "null"] },
    "user": { "type": "string" },
    "messages": { "type": "array", "items": { "type": "string" } },
    "modelLabel": { "type": ["string", "null"] },
    "userLabel": { "type": "string" },
    "model": { "type": ["string", "null"] },
    "promptPrefix": { "type": ["string", "null"] },
    "temperature": { "type": ["number", "null"] },
    "topP": { "type": "number" },
    "topK": { "type": "number" },
    "top_p": { "type": "number" },
    "frequency_penalty": { "type": "number" },
    "presence_penalty": { "type": "number" },
    "parentMessageId": { "type": "string" },
    "maxOutputTokens": { "type": ["number", "string", "null"] },
    "maxContextTokens": { "type": ["number", "string"] },
    "max_tokens": { "type": ["number", "string"] },
    "promptCache": { "type": "boolean" },
    "system": { "type": "string" },
    "thinking": { "type": "boolean" },
    "thinkingBudget": { "type": ["number", "string"] },
    "thinkingLevel": { "type": "string" },
    "stream": { "type": "boolean" },
    "artifacts": { "type": "string" },
    "context": { "type": ["string", "null"] },
    "examples": { "type": "array" },
    "tags": { "type": "array", "items": { "type": "string" } },
    "chatProjectId": { "type": ["string", "null"] },
    "createdAt": { "type": "string" },
    "updatedAt": { "type": "string" },
    "resendFiles": { "type": "boolean" },
    "file_ids": { "type": "array", "items": { "type": "string" } },
    "imageDetail": { "type": "string" },
    "reasoning_effort": { "type": ["string", "null"] },
    "reasoning_summary": { "type": ["string", "null"] },
    "verbosity": { "type": ["string", "null"] },
    "useResponsesApi": { "type": "boolean" },
    "effort": { "type": ["string", "null"] },
    "thinkingDisplay": { "type": ["string", "null"] },
    "web_search": { "type": "boolean" },
    "disableStreaming": { "type": "boolean" },
    "assistant_id": { "type": "string" },
    "agent_id": { "type": "string" },
    "region": { "type": "string" },
    "maxTokens": { "type": ["number", "string"] },
    "instructions": { "type": "string" },
    "additional_instructions": { "type": "string" },
    "append_current_datetime": { "type": "boolean" },
    "stop": { "type": "array", "items": { "type": "string" } },
    "greeting": { "type": "string" },
    "spec": { "type": ["string", "null"] },
    "iconURL": { "type": ["string", "null"] },
    "expiredAt": { "type": ["string", "null"] },
    "isTemporary": { "type": "boolean" },
    "fileTokenLimit": { "type": ["number", "string"] },
    "chatGptLabel": { "type": ["string", "null"] }
  }
}
```

## 8. Lire les messages d'une conversation avec pagination

### Route recommandee

`GET /api/messages?conversationId=:conversationId`

### Headers d'entree

```http
Authorization: Bearer <librechat_access_token>
```

### Query params

- `conversationId: string` requis
- `cursor?: string | null`
- `pageSize?: number` par defaut `25`
- `sortBy?: "endpoint" | "createdAt" | "updatedAt"`
- `sortDirection?: "asc" | "desc"`

### Reponse 200

```json
{
  "messages": [
    {
      "messageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
      "endpoint": "openAI",
      "conversationId": "1a87a2ea-e215-454c-b68b-7623bfb3408c",
      "parentMessageId": "00000000-0000-0000-0000-000000000000",
      "model": "gpt-4",
      "title": "New Chat",
      "sender": "user",
      "text": "ok",
      "isCreatedByUser": true,
      "createdAt": "2026-06-19T14:20:00.000Z",
      "updatedAt": "2026-06-19T14:20:00.000Z",
      "error": false,
      "unfinished": false
    }
  ],
  "nextCursor": "..."
}
```

### Schema de sortie

```json
{
  "type": "object",
  "required": ["messages", "nextCursor"],
  "properties": {
    "messages": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [
          "messageId",
          "conversationId",
          "parentMessageId",
          "text",
          "isCreatedByUser"
        ],
        "properties": {
          "messageId": { "type": "string" },
          "endpoint": { "type": "string" },
          "clientId": { "type": ["string", "null"] },
          "conversationId": { "type": ["string", "null"] },
          "parentMessageId": { "type": ["string", "null"] },
          "responseMessageId": { "type": ["string", "null"] },
          "overrideParentMessageId": { "type": ["string", "null"] },
          "bg": { "type": ["string", "null"] },
          "model": { "type": ["string", "null"] },
          "title": { "type": ["string", "null"] },
          "sender": { "type": "string" },
          "text": { "type": "string" },
          "generation": { "type": ["string", "null"] },
          "isCreatedByUser": { "type": "boolean" },
          "isTemporary": { "type": "boolean" },
          "expiredAt": { "type": ["string", "null"] },
          "error": { "type": "boolean" },
          "clientTimestamp": { "type": "string" },
          "createdAt": { "type": "string" },
          "updatedAt": { "type": "string" },
          "current": { "type": "boolean" },
          "unfinished": { "type": "boolean" },
          "searchResult": { "type": "boolean" },
          "finish_reason": { "type": "string" },
          "thread_id": { "type": "string" },
          "iconURL": { "type": ["string", "null"] },
          "feedback": { "type": "object" },
          "metadata": { "type": "object" },
          "contextMeta": { "type": "object" },
          "content": { "type": "array" },
          "files": { "type": "array" },
          "attachments": { "type": "array" }
        }
      }
    },
    "nextCursor": { "type": ["string", "null"] }
  }
}
```

### Route non paginee

`GET /api/messages/:conversationId`

Cette variante renvoie directement un tableau de messages, sans enveloppe `{ messages, nextCursor }`.

## 9. Refresh du token natif LibreChat

### Route

`POST /api/auth/refresh`

### But

Rafraichir un access token LibreChat natif a partir du `refreshToken` natif LibreChat.

### Headers / cookies d'entree

Pour un token natif LibreChat :

```http
Cookie: refreshToken=<librechat_refresh_token>; token_provider=librechat
```

Remarque :

- la route lit le `refreshToken` depuis les cookies
- pour ton cas d'usage, c'est bien le `refreshToken` renvoye par `/api/mobile/auth/exchange`

### Body d'entree

Aucun body JSON requis.

### Reponse 200

```json
{
  "token": "<new_librechat_access_token>",
  "user": {
    "_id": "6a354dd249b43069c8614129",
    "email": "user@example.com",
    "username": "user",
    "provider": "openid"
  }
}
```

### Schema de sortie

```json
{
  "type": "object",
  "required": ["token", "user"],
  "properties": {
    "token": { "type": "string" },
    "user": { "type": "object" }
  }
}
```

### Erreurs possibles

- `200 "Refresh token not provided"`
- `401 "Refresh token expired or not found for this user"`
- `403 "Invalid refresh token"`
- `403 "No session found"` quand `?retry=true` est utilise et que la session n'existe plus

## 10. Politique de duree des tokens natifs

Configuration actuelle du depot :

- `SESSION_EXPIRY=1000 * 60 * 15`
- `REFRESH_TOKEN_EXPIRY=(1000 * 60 * 60 * 24) * 7`

Donc, par defaut ici :

- access token LibreChat : `15 minutes`
- refresh token LibreChat : `7 jours`

## 11. Exemples cURL

### 11.1 Exchange

```bash
curl --location --request POST 'http://HOST/api/mobile/auth/exchange' \
  --header 'Authorization: Bearer <openid_access_token>' \
  --header 'x-mobile-auth-key: <mobile_exchange_key>'
```

### 11.2 Demarrer le chat

```bash
curl --location 'http://HOST/api/agents/chat/openAI' \
  --header 'Authorization: Bearer <librechat_access_token>' \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36' \
  --data '{
    "endpoint": "openAI",
    "model": "gpt-4",
    "conversationId": null,
    "parentMessageId": "00000000-0000-0000-0000-000000000000",
    "messageId": "031c8a62-63f4-4638-a73b-dce59e3e6b5f",
    "text": "ok"
  }'
```

### 11.3 Ouvrir le flux SSE

```bash
curl --no-buffer \
  --location 'http://HOST/api/agents/chat/stream/<streamId>' \
  --header 'Accept: text/event-stream' \
  --header 'Authorization: Bearer <librechat_access_token>' \
  --header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
```

### 11.4 Reprendre un stream

```bash
curl --no-buffer \
  --location 'http://HOST/api/agents/chat/stream/<streamId>?resume=true' \
  --header 'Accept: text/event-stream' \
  --header 'Authorization: Bearer <librechat_access_token>' \
  --header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
```

### 11.5 Lister les conversations

```bash
curl --location 'http://HOST/api/convos?limit=50&sortBy=updatedAt&sortDirection=desc' \
  --header 'Authorization: Bearer <librechat_access_token>'
```

### 11.6 Lire une conversation

```bash
curl --location 'http://HOST/api/convos/<conversationId>' \
  --header 'Authorization: Bearer <librechat_access_token>'
```

### 11.7 Lire les messages avec pagination

```bash
curl --location 'http://HOST/api/messages?conversationId=<conversationId>&pageSize=20&sortBy=createdAt&sortDirection=asc' \
  --header 'Authorization: Bearer <librechat_access_token>'
```

### 11.8 Page suivante des messages

```bash
curl --location 'http://HOST/api/messages?conversationId=<conversationId>&pageSize=20&sortBy=createdAt&sortDirection=asc&cursor=<nextCursor>' \
  --header 'Authorization: Bearer <librechat_access_token>'
```

### 11.9 Refresh du token natif LibreChat

```bash
curl --location --request POST 'http://HOST/api/auth/refresh' \
  --header 'Cookie: refreshToken=<librechat_refresh_token>; token_provider=librechat'
```
