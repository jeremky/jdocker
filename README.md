# jdocker

> jdocker a été entièrement revu : le script s'installe désormais comme un vrai binaire via make install, en respectant les conventions Linux standard (`~/.local/bin`, `~/.config`)

Ce script permet une l'installation et une administration plus simplifiée des conteneurs Podman en mode rootless sur un système Debian.
Les fichiers de déploiement sont centralisés dans le répertoire de votre choix, ce qui permet de les déployer facilement, sans avoir besoin d'être dans le dossier où se trouve le fichier `compose.yml`.

## Configuration

Avant d'installer ce script, vous devez tout d'abord adapter le fichier `jdocker.config` selon vos préférences :

- `autobackup` : Sauvegarde automatique des volumes externes lors d'une mise à jour
- `autoclean` : Suppression automatique des images après mise à jour
- `backupdays` : la durée de rétention pour des sauvegardes
- Les différents répertoires où sont stockées les données (les fichiers `compose.yml`, les backups, les volumes...)

Ce fichier de config sera modifiable à posteriori à l'emplacement suivant : `$HOME/.config/jdocker/jdocker.config`

```txt
# jdocker config
autobackup=false
autoclean=true
backupdays=7

composedir=$HOME/compose
volumesdir=$HOME/volumes
backupsdir=$HOME/backups
imagesdir=$HOME/images
```

> le dossier `composedir` doit contenir un sous dossier pour chaque application, avec un fichier `compose.yml` et un fichier `.env`

## Installation

L'installation va automatiquement déployer `podman`, `podman-compose`, et effectuer la configuration pour autoriser votre utilisateur à exploiter correctement Podman.

### Utilisateur actuel

Si votre utilisateur dispose des droits sudo :

```bash
make install
```

### Utilisateur sans sudo

Dans le cas contraire, il faut exécuter en tant que `root` et préciser pour quel utilisateur installer l'application :

```bash
sudo make install PODMAN_USER=<user>
```

Comme indiqué à la fin de l'installation, pensez à activer les services liés à Podman. Contrairement à l'installation classique, l'activation de ces services n'est pas automatique :

```bash
systemctl --user enable --now podman-restart.service podman.socket
```

### Port

Par défaut, un utilisateur standard ne peut pas utiliser un port inférieur à 1024. l'installation va permettre de modifier ce paramètre pour l'utilisation des ports à partir de 80. Si vous désirez changer cette valeur :

```bash
sudo make install PODMAN_USER=<user> BASEPORT=<port>
```

## Utilisation

Une fois installé, `jdocker` est utilisable directement depuis votre terminal.

Pour consulter l'aide, lancez `jdocker` sans paramètre :

```txt
Commandes disponibles :
  ls  | list            Lister les conteneurs actifs
  n   | networks        Lister les réseaux virtuels
  v   | volumes         Lister les volumes virtuels
  i   | images          Lister les images
  l   | logs            Consulter les logs pour un conteneur spécifié
  lo  | load            Charger une ou plusieurs images locales spécifiées
  it  | install         Installer un conteneur avec compose
  rm  | remove          Supprimer un conteneur avec compose
  r   | restart         Redémarrer un conteneur
  pr  | purge           Purger les images et les réseaux non utilisés
  pra | purgeall        Purger également les volumes non utilisés
  at  | attach          S'attacher au prompt ouvert pour un conteneur spécifié
  p   | pull            Récupérer la dernière version de l'image d'un conteneur spécifié
  up  | upgrade         Télécharger la dernière image et mettre à jour un conteneur spécifié
  ps  | lsa             Afficher les informations détaillées des conteneurs
  s   | stats           Afficher les statistiques en temps réel des conteneurs
  sh  | bash            Se connecter au bash d'un conteneur spécifié
  bk  | backup          Sauvegarder un conteneur spécifié
  u   | unshare         Basculer l'ID via la commande podman unshare
  h   | help            Afficher cette aide
```

## Sauvegarde

`jdocker` propose un système de sauvegarde des volumes externalisés.
Pour automatiser vos sauvegardes, adaptez le fichier `/etc/cron.d/jdocker` selon vos préférences :

```txt
# jdocker cron
jdocksh=$PODMAN_HOME/.local/bin/jdocker

# app1
0 0 * * *  $PODMAN_USER $jdocksh bk app1 >/dev/null 2>&1

# app2
0 1 * * *  $PODMAN_USER $jdocksh bk app2 >/dev/null 2>&1
```
