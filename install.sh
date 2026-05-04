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

# 3. Comprobación de imagen existente
LOCAL_LOGO="Logo-Personalizado-Plymouth/logo.png"
if [ -f "$LOCAL_LOGO" ]; then
    echo -e "${YELLOW}[?] Se ha detectado una imagen 'logo.png' en la carpeta.${NC}"
    read -p "¿Deseas usar esta imagen o prefieres mantener la que ya esté instalada en el sistema? (u: usar local / m: mantener sistema): " opt_img
    if [[ "$opt_img" != "u" && "$opt_img" != "U" ]]; then
        echo -e "${CYAN}[*] Se mantendrá la imagen actual del sistema.${NC}"
        SKIP_COPY_IMG=true
    fi
fi

# 4. Instalación de dependencias
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

# 5. Copiar carpeta del tema
TARGET_DIR="/usr/share/plymouth/themes/logo-personalizado"
echo -e "${CYAN}[*] Configurando archivos en $TARGET_DIR...${NC}"
mkdir -p "$TARGET_DIR"

if [ "$SKIP_COPY_IMG" = true ]; then
    # Copiar todo menos el logo
    cp -rf Logo-Personalizado-Plymouth/logo-personalizado.plymouth "$TARGET_DIR/"
    cp -rf Logo-Personalizado-Plymouth/logo-personalizado.script "$TARGET_DIR/"
    cp -rf Logo-Personalizado-Plymouth/progress_*.png "$TARGET_DIR/"
else
    cp -rf Logo-Personalizado-Plymouth/* "$TARGET_DIR/"
fi

chmod -R 755 "$TARGET_DIR"

# 6. Aplicar el tema
echo -e "${CYAN}[*] Aplicando tema LobeOS...${NC}"
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R logo-personalizado
else
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$TARGET_DIR/logo-personalizado.plymouth" 100
    update-alternatives --set default.plymouth "$TARGET_DIR/logo-personalizado.plymouth"
fi

# 7. Configuración de arranque y Drivers
echo -e "${CYAN}[*] Optimizando GRUB y drivers de video...${NC}"
GRUB_PARAMS="quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_priority=3 vt.global_cursor_default=0"
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"/" /etc/default/grub

# Forzar resolución para evitar el logo de Lenovo/Mint
sed -i 's/^#GRUB_GFXMODE=.*/GRUB_GFXMODE=1024x768x32/' /etc/default/grub
if ! grep -q "GRUB_GFXPAYLOAD_LINUX=keep" /etc/default/grub; then
    echo "GRUB_GFXPAYLOAD_LINUX=keep" >> /etc/default/grub
fi

if [ "$DISTRO" == "arch" ]; then
    sed -i 's/^MODULES=(/MODULES=(i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm fbcon /' /etc/mkinitcpio.conf
    mkinitcpio -p linux
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "FRAMEBUFFER=y" > /etc/initramfs-tools/conf.d/splash
    for module in i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm fbcon; do
        if ! grep -q "$module" /etc/initramfs-tools/modules; then
            echo "$module" >> /etc/initramfs-tools/modules
        fi
    done
    update-initramfs -u
    update-grub
fi

# 8. Previsualización
echo -e "\n${GREEN}[✔] Instalación completada.${NC}"
read -p "¿Deseas previsualizar el tema ahora mismo sin reiniciar? (s/n): " previsualizar
if [[ "$previsualizar" =~ ^[Ss]$ ]]; then
    echo -e "${CYAN}[*] Iniciando previsualización (durará 8 segundos)...${NC}"
    # Ejecutar demonio, mostrar splash, simular carga y cerrar
    plymouthd
    plymouth --show-splash
    for i in {1..8}; do
        plymouth --update=test$i
        sleep 1
    done
    plymouth quit
fi

# 9. Reinicio
echo -en "${YELLOW}¿Deseas reiniciar el equipo ahora? (s/n): ${NC}"
read -r respuesta
[[ "$respuesta" =~ ^[Ss]$ ]] && reboot