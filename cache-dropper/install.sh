#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Cache Dropper Installer
# Hecho por Novation Hosting
# ===============================

# ===== SEGURIDAD =====
if [[ "${EUID}" -ne 0 ]]; then
  echo "❌ Este instalador debe ejecutarse como root"
  exit 1
fi

# ===== CONFIG =====
AUTHOR="Novation Hosting"
VERSION="1.0.0"
SERVICE="clear-cache"
SCRIPT_PATH="/usr/local/bin/clear_cache.sh"
SERVICE_PATH="/etc/systemd/system/${SERVICE}.service"
TIMER_PATH="/etc/systemd/system/${SERVICE}.timer"
TOTAL_STEPS=6
CURRENT_STEP=0
# ==================

# ===== DETECTAR OS =====
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  OS_ID="$ID"
else
  echo "❌ No se pudo detectar el sistema operativo"
  exit 1
fi

SUPPORTED_OS=("ubuntu" "debian" "proxmox" "rocky" "almalinux" "centos" "rhel")

if [[ ! " ${SUPPORTED_OS[*]} " =~ " ${OS_ID} " ]]; then
  echo "❌ Sistema operativo no soportado: ${OS_ID}"
  echo "✔ Soportados: ${SUPPORTED_OS[*]}"
  exit 1
fi

# ===== PROGRESS BAR =====
progress_bar () {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s-" $(seq 1 $empty)
    printf "] %d%%" "$percent"
}

clear
echo "======================================"
echo "📦 Cache Dropper v${VERSION}"
echo "🚀 Hecho por ${AUTHOR}"
echo "🖥️ Sistema detectado: ${PRETTY_NAME}"
echo "======================================"
sleep 1

# ===== DETECTAR INSTALACIÓN PREVIA =====
if [[ -f "$SCRIPT_PATH" && -f "$TIMER_PATH" ]] && systemctl is-active --quiet ${SERVICE}.timer; then
    echo "⚠️ Cache Dropper ya está instalado y activo"
    echo "ℹ️ No se realizará ninguna acción"
    exit 0
fi

# ===== INSTALACIÓN =====
echo "🔧 Creando script de limpieza..."
progress_bar
cat << 'EOF' > "$SCRIPT_PATH"
#!/usr/bin/env bash
sync
echo 3 > /proc/sys/vm/drop_caches
EOF
chmod +x "$SCRIPT_PATH"
sleep 1

echo -e "\n🧩 Creando servicio systemd..."
progress_bar
cat << EOF > "$SERVICE_PATH"
[Unit]
Description=Clear Linux PageCache, dentries and inodes

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH}
EOF
sleep 1

echo -e "\n⏱️ Creando timer systemd..."
progress_bar
cat << EOF > "$TIMER_PATH"
[Unit]
Description=Run clear-cache.service every 20 seconds

[Timer]
OnBootSec=20s
OnUnitActiveSec=20s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF
sleep 1

echo -e "\n🔄 Recargando systemd..."
progress_bar
systemctl daemon-reexec
systemctl daemon-reload
sleep 1

echo -e "\n✅ Activando servicio..."
progress_bar
systemctl enable --now ${SERVICE}.timer
sleep 1

echo -e "\n\n🎉 Instalación completada correctamente"
echo "💼 Script desarrollado por ${AUTHOR}"
echo "📊 Estado del timer:"
systemctl list-timers ${SERVICE}.timer
