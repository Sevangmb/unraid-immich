# Immich — Unraid Community Applications Template

Alternative auto-hébergée à Google Photos — gestion et sauvegarde de photos/vidéos.  
Ce template déploie **Immich + PostgreSQL (pgvecto.rs) + Redis + Machine Learning** dans un **container unique** directement depuis Docker Hub, avec accélération GPU NVIDIA.

## Ports

| Port | Protocole | Usage |
|------|-----------|-------|
| 2283 | TCP | Interface web + API mobile |

## Premier démarrage

1. Dans Community Applications, recherche **Immich**.
2. Installe le plugin **Unraid NVIDIA** si ce n'est pas déjà fait (pour le GPU).
3. Définis le mot de passe de la base de données et les chemins de données.
4. Clique **Apply** — PostgreSQL s'initialise, les extensions s'installent, Immich démarre.
5. Ouvre `http://TON_IP_UNRAID:2283` et crée ton compte admin.

## Données persistées sur le host

```
/mnt/user/appdata/immich/
├── postgres/       ← base de données PostgreSQL
└── model-cache/    ← modèles Machine Learning (téléchargés au premier usage)

/mnt/user/photos/   ← tes photos et vidéos
```

## GPU NVIDIA

L'image embarque `onnxruntime-gpu` (via l'image officielle `immich-machine-learning:release-cuda`).  
Avec le plugin NVIDIA installé sur Unraid et `NVIDIA_VISIBLE_DEVICES=all`, le Machine Learning (reconnaissance faciale, recherche CLIP) tourne sur GPU automatiquement.

## Mise à jour de l'image

Chaque `git push` sur `main` rebuild et publie automatiquement l'image sur Docker Hub via GitHub Actions.  
Sur Unraid, clique **Check for Updates** dans le Docker Manager.

## Soumettre au store Community Applications

1. Fork [Squidly271/AppFeed](https://github.com/Squidly271/AppFeed).
2. Ajoute `immich.xml` dans le dossier templates.
3. Ouvre une Pull Request — l'équipe CA review et merge.

## Liens

- [Immich](https://immich.app)
- [Docker Hub — sevanitito/immich-unraid](https://hub.docker.com/r/sevanitito/immich-unraid)
- [GitHub — Sevangmb/unraid-immich](https://github.com/Sevangmb/unraid-immich)
- [Unraid CA submission guide](https://forums.unraid.net/topic/38582-plug-in-community-applications/)
