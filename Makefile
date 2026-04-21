PREFIX ?= /usr/local
LIBEXECDIR ?= $(PREFIX)/libexec

GUEST_USER ?= guest-user
GUEST_HOME ?= /home/$(GUEST_USER)
GUEST_HOME_SIZE ?= 1024M
GUEST_SHELL ?= /sbin/nologin

SCRIPT_SRC := guest-user-home-setup.sh
SCRIPT_DST := $(LIBEXECDIR)/guest-user-home-setup.sh

.PHONY: all install install-user install-script

all:
	@echo "Available targets:"
	@echo "  make install"
	@echo
	@echo "Variables you can override:"
	@echo "  GUEST_USER=$(GUEST_USER)"
	@echo "  GUEST_HOME=$(GUEST_HOME)"
	@echo "  GUEST_HOME_SIZE=$(GUEST_HOME_SIZE)"
	@echo "  GUEST_SHELL=$(GUEST_SHELL)"

install: install-user install-script
	@echo
	@echo "Done."
	@echo "Guest user: $(GUEST_USER)"
	@echo "Guest home: $(GUEST_HOME)"
	@echo "Tmpfs size: $(GUEST_HOME_SIZE)"
	@echo
	@echo "Manual PAM/authselect changes are still required."

install-user:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "install-user must be run as root."; \
		exit 1; \
	fi
	@if getent passwd "$(GUEST_USER)" >/dev/null; then \
		echo "User $(GUEST_USER) already exists; leaving it alone."; \
	else \
		echo "Creating user $(GUEST_USER)..."; \
		useradd -M -d "$(GUEST_HOME)" -s "$(GUEST_SHELL)" -c "Guest User" "$(GUEST_USER)"; \
		echo "Set password for $(GUEST_USER):"; \
		passwd "$(GUEST_USER)"; \
	fi

install-script:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "install-script must be run as root."; \
		exit 1; \
	fi
	@if [ ! -f "$(SCRIPT_SRC)" ]; then \
		echo "Missing $(SCRIPT_SRC) in current directory."; \
		exit 1; \
	fi
	@echo "Installing $(SCRIPT_SRC) to $(SCRIPT_DST)..."
	@install -d -m 0755 "$(LIBEXECDIR)"
	@install -m 0755 "$(SCRIPT_SRC)" "$(SCRIPT_DST)"
	@echo "Rewriting configuration variables in $(SCRIPT_DST)..."
	@sed -i \
		-e 's|^GUEST_USER=.*|GUEST_USER="$(GUEST_USER)"|' \
		-e 's|^GUEST_HOME_SIZE=.*|GUEST_HOME_SIZE="$(GUEST_HOME_SIZE)"|' \
		"$(SCRIPT_DST)"