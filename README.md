# MotoScan

## Détection des motos

La caméra et la galerie utilisent le détecteur YOLO FastAPI du dépôt
[Object_detection_fastAPI_docker](https://github.com/enesagu/Object_detection_fastAPI_docker).
L’image n’est acceptée dans l’application que si le détecteur y trouve une moto.

Démarre le service depuis ce dossier avec Docker Desktop ouvert :

```powershell
docker compose up --build -d
```

Le premier démarrage construit le conteneur et peut prendre quelques minutes. Pour
l’arrêter : `docker compose down`.

Par défaut, l’application Android vise le service du PC via `10.0.2.2:8000`
(adresse hôte utilisée par l’émulateur Android). Pour utiliser un téléphone
physique, remplace `127.0.0.1:8000:8000` par `8000:8000` dans
`docker-compose.yml`, autorise le port 8000 dans le pare-feu, ajoute l’adresse IP
locale du PC dans `android/app/src/main/res/xml/network_security_config.xml`, puis
lance l’application avec `--dart-define=MOTO_DETECTION_URL=http://IP_DU_PC:8000`.
