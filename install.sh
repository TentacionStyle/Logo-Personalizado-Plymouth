#!/bin/bash

# Definir el color Cian (ANSI)
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color

echo -e "${CYAN}"
cat << 'EOF'
  _____            _             _              _____ _         _     
 |_   _|__ _ __  _| |_ __ _  ___(_) ___  _ __ /  ___| |_ _   _| | ___ 
   | |/ _ \ '_ \| __/ _` |/ __| |/ _ \| '_ \ \___ \ __| | | | | |/ _ \
   | |  __/ | | | || (_| | (__| | (_) | | | |____) | |_| |_| | |  __/ 
   |_|\___|_| |_|\__\__,_|\___|_|\___/|_| |_|_____/ \__|\__, |_|\___| 
                                                        |___/         
EOF
echo -e "${NC}"

# 1. Validar que se ejecuta como ROOT
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Error: Ejecutar con sudo.${NC}"
    exit 1
fi

# 2. Detectar Sistema Operativo
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    exit 1
fi

# 3. Instalación de dependencias
case $DISTRO in
    arch)
        pacman -Sy --noconfirm plymouth
        ;;
    linuxmint|ubuntu|debian)
        apt update -y
        apt install -y plymouth plymouth-themes
        ;;
    *)
        exit 1
        ;;
esac

# 4. Copiar carpeta del tema
TARGET_DIR="/usr/share/plymouth/themes/logo-personalizado"
mkdir -p "$TARGET_DIR"
cp -rf Logo-Personalizado-Plymouth/* "$TARGET_DIR/"

# 5. Aplicar el tema
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R logo-personalizado
else
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/logo-personalizado/logo-personalizado.plymouth 100
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/logo-personalizado/logo-personalizado.plymouth
    update-initramfs -u
fi

# 6. Configuración de arranque (Silent Boot y Drivers)
GRUB_PARAMS="quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_priority=3 vt.global_cursor_default=0"
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"/" /etc/default/grub

if [ "$DISTRO" == "arch" ]; then
    sed -i 's/^MODULES=(/MODULES=(hv_fb /' /etc/mkinitcpio.conf
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sed -i 's/HOOKS=(base udev/HOOKS=(base udev plymouth/' /etc/mkinitcpio.conf
    fi
    mkinitcpio -p linux
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "--- Optimizando drivers de video ---"
    for module in i915 amdgpu nvidia nvidia_drm fbcon; do
        if ! grep -q "$module" /etc/initramfs-tools/modules; then
            echo "$module" >> /etc/initramfs-tools/modules
        fi
    done
    update-initramfs -u
    update-grub
fi

# 7. Finalización
echo -e "\n${GREEN}[✔] ¡LobeOS Personalizado con éxito!${NC}"
echo -en "${CYAN}¿Deseas reiniciar para ver los cambios? (s/n): ${NC}"
read -r respuesta
[[ "$respuesta" =~ ^[Ss]$ ]] && reboot