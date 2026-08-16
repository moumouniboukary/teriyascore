# Tests E2E device (Maestro)

```bash
# Installer Maestro : https://maestro.mobile.dev
# Lancer l'app sur device/émulateur, puis :
cd apps/mobile
maestro test e2e/
```

| Flux | Fichier |
|------|---------|
| Smoke splash / login | `e2e/smoke.yaml` |

Les OTP en mode test utilisent `devCode` renvoyé par l'API (sans Twilio).
L'inscription commerçant n'existe pas dans TeriyaScore : le compte agent est provisionné par DigiCoop.
