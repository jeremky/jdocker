# jdocker.sh

Script permettant une administration plus simplifiée des conteneurs Podman. Ce script n'est pour le moment pas compatible avec le mode rootless de Podman.

- Avant d'utiliser ce script, vous devez tout d'abord modifier le fichier jdocker.cfg pour remplacer votre nom d'utilisateur, et la destination des backups.

- Pour automatiser vos backups, il y a un fichier .cron dans ce répertoire. Modifiez le selon vos préférences. Faites ensuite ./jdocker.sh bk pour le copier dans le répertoire des cron.

- Podman intègre un système de mise à jour automatique. Ce script contrôle vos conteneurs via systemd pour être compatible avec cette fonctionnalité.

Pour consulter l'aide, lancez ./jdocker.sh sans paramètre.
