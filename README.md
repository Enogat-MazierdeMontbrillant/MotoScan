# MotoScan

## Déploiement gratuit sur Netlify

L’application web exécute YOLO dans le navigateur : aucun conteneur Docker ni serveur de détection n’est nécessaire. Le modèle ONNX (environ 13 Mo) et ONNX Runtime sont téléchargés depuis des CDN publics lors de la première détection. La photo utilisée pour vérifier la présence d’une moto reste dans le navigateur ; elle n’est envoyée à Gemini que si l’utilisateur demande ensuite l’identification.

1. Dans Netlify, importe le dépôt GitHub `Enogat-MazierdeMontbrillant/MotoScan`. La configuration de compilation est déjà dans `netlify.toml`.
2. Dans les variables d’environnement Netlify, ajoute `GEMINI_API_KEY` et `NINJAS_API_KEY`, avec le scope **Functions**. Les clés restent côté serveur dans les fonctions Netlify et ne sont pas incluses dans le code JavaScript public.
3. Lance le déploiement. Netlify compile Flutter Web et publie aussi les fonctions qui relaient les requêtes vers Gemini et API Ninjas.

L’hébergement Netlify et l’inférence dans le navigateur ne requièrent pas de serveur Docker payant, sous réserve des limites de l’offre gratuite. Gemini et API Ninjas nécessitent leurs propres clés et restent soumis aux quotas et conditions de leurs fournisseurs.

Les fonctions Netlify sont appelables depuis l’URL publique du site : les clés ne sont pas visibles dans le navigateur, mais les visiteurs peuvent consommer les quotas des API. Vérifie les limites de tes clés avant de partager le site.

En mode debug avec Android Studio/Edge, l’application appelle les API directement et utilise les clés locales fournies à Flutter. La compilation Netlify active les fonctions serveur, pour ne pas inclure les clés dans le site publié.

## Application mobile Android

Android continue d’utiliser le service YOLO FastAPI du dépôt
[Object_detection_fastAPI_docker](https://github.com/enesagu/Object_detection_fastAPI_docker).
Démarre-le avec Docker Desktop :

```powershell
docker compose up --build -d
```

Arrête-le avec `docker compose down`. L’émulateur Android accède au service du PC via `10.0.2.2:8000`. Pour un téléphone physique, configure l’adresse IP locale du PC dans `MOTO_DETECTION_URL`, publie le port 8000 sur le réseau local et autorise-le dans le pare-feu.
