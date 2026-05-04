# !/bin/bash

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
  echo -e "${RED}[!] Error: Este script debe ejecutarse con sudo.${NC}"
  exit 1
fi

# 2. Detectar Sistema Operativo
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}[!] No se pudo detectar la distribución.${NC}"
    exit 1
fi

echo -e "${GREEN}[*] Sistema detectado: $DISTRO${NC}"

# 3. Instalación de dependencias según la Distro
case $DISTRO in
    arch)
        echo "--- Instalando Plymouth (Arch) ---"
        pacman -Sy --noconfirm plymouth
        ;;
    linuxmint|ubuntu|debian)
        echo "--- Instalando Plymouth (Mint/Ubuntu) ---"
        apt update -y
        apt install -y plymouth plymouth-themes
        ;;
    *)
        echo -e "${RED}[!] Distribución no soportada.${NC}"
        exit 1
        ;;
esac

# 4. Copiar carpeta del tema
echo "--- Copiando archivos del tema ---"
TARGET_DIR="/usr/share/plymouth/themes/logo-personalizado"
mkdir -p "$TARGET_DIR"
cp -rf Logo-Personalizado-Plymouth/* "$TARGET_DIR/"

# 5. Aplicar el tema
echo "--- Aplicando el tema en Plymouth ---"
plymouth-set-default-theme -R logo-personalizado

# 6. Configuración específica de arranque
if [ "$DISTRO" == "arch" ]; then
    echo "--- Configurando mkinitcpio (Arch) ---"
    sed -i 's/^MODULES=(/MODULES=(hv_fb /' /etc/mkinitcpio.conf
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sed -i 's/HOOKS=(base udev/HOOKS=(base udev plymouth/' /etc/mkinitcpio.conf
    fi
    mkinitcpio -p linux
else
    echo "--- Actualizando initramfs (Mint/Ubuntu) ---"
    update-initramfs -u
fi

# 7. Configurar GRUB (Silent Boot)
echo "--- Configurando GRUB ---"
GRUB_PARAMS="quiet splash loglevel=3 rd.systemd.show_status=auto rd.udev.log_priority=3 vt.global_cursor_default=0"
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"/" /etc/default/grub

if [ "$DISTRO" == "arch" ]; then
    grub-mkconfig -o /boot/grub/grub.cfg
else
    update-grub
fi

# 8. Finalización
echo -e "\n${GREEN}[✔] ¡Personalización completada con éxito!${NC}"
echo -en "${CYAN}¿Deseas reiniciar ahora? (s/n): ${NC}"
read -r respuesta

if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    reboot
else
    echo "Saliendo..."
fi