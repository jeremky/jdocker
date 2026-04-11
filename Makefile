PODMAN_USER ?= $(shell whoami)
PODMAN_HOME ?= $(shell eval echo ~$(PODMAN_USER))

BINDIR = $(PODMAN_HOME)/.local/bin
CONFDIR = $(PODMAN_HOME)/.config/jdocker
COMPDIR = $(PODMAN_HOME)/.local/share/bash-completion/completions

BASEPORT ?= 80

.PHONY: install uninstall

install:
	@if ! which podman > /dev/null 2>&1; then \
		sudo apt install -y podman podman-compose && \
		sudo sysctl net.ipv4.ip_unprivileged_port_start=$(BASEPORT) && \
		echo "net.ipv4.ip_unprivileged_port_start=$(BASEPORT)" | sudo tee /etc/sysctl.d/10-podman.conf > /dev/null && \
		sudo loginctl enable-linger $(PODMAN_USER) && \
		if [ "$(PODMAN_USER)" = "$(shell whoami)" ]; then \
			systemctl --user enable --now podman-restart.service podman.socket; \
		else \
			echo && \
			echo "Pour activer les services Podman, lancer la commande suivante en tant que $(PODMAN_USER) :" && \
			echo "  systemctl --user enable --now podman-restart.service podman.socket" && \
			echo; \
		fi; \
	else \
		echo "Podman est déjà installé"; \
	fi

	@if [ ! -f /etc/cron.d/jdocker ]; then \
		export PODMAN_USER=$(PODMAN_USER) PODMAN_HOME=$(PODMAN_HOME) && \
		envsubst '$$PODMAN_USER $$PODMAN_HOME' < jdocker.cron | sudo tee /etc/cron.d/jdocker > /dev/null; \
	fi

	@if [ ! -f $(CONFDIR)/jdocker.config ]; then \
		sudo install -m 644 -D jdocker.config $(CONFDIR)/jdocker.config; \
	fi

	@if [ ! -f $(COMPDIR)/jdocker ]; then \
		sudo install -m 644 -D .jdocker.comp $(COMPDIR)/jdocker; \
	fi

	@sudo install -m 755 -D jdocker.sh $(BINDIR)/jdocker

	@sudo chown -R $(PODMAN_USER): $(PODMAN_HOME)/.config $(PODMAN_HOME)/.local
	@sudo -u $(PODMAN_USER) bash -c '. $(CONFDIR)/jdocker.config && \
			mkdir -p $$composedir $$volumesdir $$backupsdir $$imagesdir'
	@echo "Installation de jdocker effectuée. Redémarrez la session bash"

uninstall:
	@sudo rm -f /etc/sysctl.d/10-podman.conf
	@sudo rm -f /etc/cron.d/jdocker
	@sudo rm -f $(BINDIR)/jdocker
	@sudo rm -f $(COMPDIR)/jdocker
	@sudo rm -fr $(CONFDIR)
	@echo "Suppression de jdocker effectuée"
