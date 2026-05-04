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

# 1. Validar ROOT
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Error: Debes ejecutar este script con sudo.${NC}"
    exit 1
fi

# 2. Detectar Distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}[!] No se pudo detectar la distro.${NC}"
    exit 1
fi

# 3. Instalación de dependencias
echo -e "${CYAN}[*] Instalando paquetes necesarios...${NC}"
case $DISTRO in
    arch)
        pacman -Sy --noconfirm plymouth
        ;;
    linuxmint|ubuntu|debian)
        apt update -y
        apt install -y plymouth plymouth-themes
        ;;
    *)
        echo -e "${RED}[!] Distro no soportada.${NC}"
        exit 1
        ;;
esac

# 4. Copiar carpeta del tema
echo -e "${CYAN}[*] Copiando archivos del tema LobeOS...${NC}"
TARGET_DIR="/usr/share/plymouth/themes/logo-personalizado"
mkdir -p "$TARGET_DIR"
cp -rf Logo-Personalizado-Plymouth/* "$TARGET_DIR/"

# 5. Aplicar el tema y Configurar Framebuffer
echo -e "${CYAN}[*] Configurando tema predeterminado...${NC}"
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R logo-personalizado
else
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$TARGET_DIR/logo-personalizado.plymouth" 100
    update-alternatives --set default.plymouth "$TARGET_DIR/logo-personalizado.plymouth"
fi

# Forzar Framebuffer en Debian/Mint/Ubuntu para asegurar visualización temprana
if [ "$DISTRO" != "arch" ]; then
    echo "FRAMEBUFFER=y" > /etc/initramfs-tools/conf.d/splash
fi

# 6. Configuración de arranque (Silent Boot y Early KMS)
echo -e "${CYAN}[*] Configurando GRUB y Drivers de video...${NC}"
GRUB_PARAMS="quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_priority=3 vt.global_cursor_default=0"
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"/" /etc/default/grub

if [ "$DISTRO" == "arch" ]; then
    # Configuración Arch: MKINITCPIO
    sed -i 's/^MODULES=(/MODULES=(i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm hv_fb virtio_gpu /' /etc/mkinitcpio.conf
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sed -i 's/HOOKS=(base udev/HOOKS=(base udev plymouth/' /etc/mkinitcpio.conf
    fi
    mkinitcpio -p linux
    grub-mkconfig -o /boot/grub/grub.cfg
else
    # Configuración Mint/Ubuntu: INITRAMFS
    echo "--- Optimizando drivers para Hardware Físico y VM ---"
    for module in i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm fbcon hv_fb virtio_gpu; do
        if ! grep -q "$module" /etc/initramfs-tools/modules; then
            echo "$module" >> /etc/initramfs-tools/modules
        fi
    done
    update-initramfs -u
    update-grub
fi

# 7. Finalización
echo -e "\n${GREEN}[✔] ¡LobeOS Personalizado con éxito!${NC}"
echo -e "${CYAN}[i] Se han configurado los drivers i915, AMD y NVIDIA para carga temprana.${NC}"
echo -en "${CYAN}¿Deseas reiniciar ahora para ver los cambios? (s/n): ${NC}"
read -r respuesta
[[ "$respuesta" =~ ^[Ss]$ ]] && reboot