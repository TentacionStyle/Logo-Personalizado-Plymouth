# 🚀 Custom Plymouth Boot Theme (Con detección de Distro)

Este repositorio contiene un tema de arranque personalizado para Plymouth, diseñado para ofrecer una experiencia de inicio limpia, profesional y sin distracciones (Silent Boot). Está optimizado para funcionar en **varias distibuciones**, detectando automáticamente la distribución y configurando los parámetros necesarios.

---

## 📸 Previsualización
El script configura un inicio silencioso con tu logo personalizado centrado en una pantalla negra, eliminando todos los mensajes de texto del kernel ([ OK ], mensajes de carga, etc.).

---

## 🛠️ Instalación Rápida (Recomendado)

Puedes instalar este tema automáticamente ejecutando el siguiente comando en tu terminal. El script detectará tu sistema operativo, instalará las dependencias necesarias, aplicará el tema y configurará el GRUB por ti.

```bash
curl -sSL [https://raw.githubusercontent.com/TentacionStyle/Logo-Personalizado-Plymouth/main/install.sh](https://raw.githubusercontent.com/TentacionStyle/Logo-Personalizado-Plymouth/main/install.sh) | sudo bash