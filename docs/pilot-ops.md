# Pilote TeriyaScore — ops déploiement, APK, IMF, FCM, MM

## 1. API Render (stable)

1. Render → **Blueprint** → ce repo (`render.yaml`).
2. Services créés : `teriyascore-db`, `teriyascore-redis`, `teriyascore-api`, `teriyascore-worker`, `teriyascore-ml`.
3. `USE_JOB_QUEUE=1` est forcé sur API + worker (SMS / MM / FCM / relances via Redis).
4. Renseigner les secrets (dashboard, non versionnés) :

| Variable | Rôle |
|----------|------|
| `CORS_ORIGIN` | URL PWA / portail (ex. `https://….onrender.com`) |
| `TWILIO_*` | OTP SMS réel |
| `PARTNER_API_KEY` | Clé portail IMF |
| `ADMIN_API_KEY` | Admin agents |
| `FCM_SERVER_KEY` | Push Firebase Legacy |
| `ORANGE_MM_*` / `MOOV_MM_*` | Mobile Money |
| `SCORING_ML_URL` | URL service ML (optionnel) |

5. Après deploy : `GET https://<api>/ready` → postgres `ok`, redis `ok`.
6. Migrations : incluses au boot Docker / `prisma migrate deploy`.

## 2. APK signée commerçants

```powershell
powershell -File scripts/build-release-apk.ps1
```

- Sortie : `dist/apk/TeriyaScore-commercant.apk`
- Keystore local : `apps/mobile/android/upload-keystore.jks` (**gitignore**)
- Install : USB `adb install -r …` ou partage fichier + « sources inconnues »
- Pointer l’app vers l’API prod :
  `flutter build apk --release --dart-define=API_BASE=https://<api>`

## 3. Portail IMF

- URL web : `/imf/login`
- Auth : clé `X-Partner-Key` (= `PARTNER_API_KEY` ou clé IMF admin)
- Écrans : dossiers (décision / outcome), reporting (`GET /partners/stats`), commissions

## 4. FCM

1. Firebase Console → Cloud Messaging → **Server key** → `FCM_SERVER_KEY`
2. App mobile : obtenir un token FCM puis `POST /devices/push-token`
3. Les `createNotification` (décision crédit, créances) déclenchent un push

Sans `FCM_SERVER_KEY`, les notifs restent in-app + locales.

## 5. Mobile Money

Renseigner `ORANGE_MM_URL` + `ORANGE_MM_API_KEY` (optionnel OAuth : `ORANGE_MM_TOKEN_URL`, `CLIENT_ID`, `CLIENT_SECRET`) et/ou `MOOV_MM_*`.  
Sans credentials → stub (pas de débit réel).  
Transferts : `POST /mobile-money/transfer` (sync ou job `mm_transfer`).

## 6. Worker

Déjà activé sur Render (`USE_JOB_QUEUE=1`). Local :

```bash
# .env : USE_JOB_QUEUE=1 + REDIS_URL
npm run worker
```

Jobs : `sms`, `alert`, `mm_transfer`, `overdue_notify`, `fcm_push`.

## 7. USSD / KYC / audio FR

- USSD : `POST /ussd/webhook` — menu 1–6 (ventes, score, dettes, offre, statut demande, KYC)
- KYC léger : champs `pieceIdentite*`, `dateNaissance`, `adresse`, `kycStatut` via `PATCH /me`
- Audio FR : `powershell -File scripts/generate-fr-audio.ps1` (48 WAV) ou `node scripts/generate-fr-audio.mjs` (edge-tts)
