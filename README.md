# jdocker.sh

Script permettant une administration plus simplifiée des conteneurs Docker/Podman. Il est en théorie capable de gérer à la fois les différentes versions de Docker, ainsi que Podman.

- Avant d'utiliser ce script, vous devez tout d'abord modifier le fichier `jdocker.cfg` pour remplacer votre nom d'utilisateur, l'outil de conteneurisation à utiliser, et les différents répertoires.

- Un paramètre, spécifique à Podman, permet de choisir de l'utiliser en mode rootless ou non. Modifiez ce paramètre avant tout lancement, car il va modifier le comportement de l'installation. Modifiez également le port minimal à autoriser.

- Lancez le script une première fois pour installer l'auto complétion. Si vous déplacez le script, supprimez le fichier `/etc/bash_completion.d/jdocker` et relancez le.

- Pour automatiser vos backups, il y a un fichier `.jdocker.cron` dans ce répertoire. Modifiez le selon vos préférences. Faites ensuite `./jdocker.sh bk` pour le copier dans le répertoire des cron.

Pour consulter l'aide, lancez `./jdocker.sh` sans paramètre.
