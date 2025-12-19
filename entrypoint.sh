#!/bin/bash
# MikroTik RouterOS (CHR) Docker Runner
# Mejorado para robustez y flexibilidad de puertos

set -u

# --- CONFIGURACIÓN POR DEFECTO ---
VERSION=$(echo "${ROUTEROS_VERSION:-7.12.1}" | tr -d '\r')
DISK_SIZE=$(echo "${DISK_SIZE:-512M}" | tr -d '\r')
USER=$(echo "${ROUTEROS_USER:-admin}" | tr -d '\r')
PASS=$(echo "${ROUTEROS_PASSWORD:-}" | tr -d '\r')
RAM=$(echo "${ROUTEROS_RAM:-256}" | tr -d '\r')
CPUS=$(echo "${ROUTEROS_CPU:-1}" | tr -d '\r')

IMG_DIR="/routeros"
IMG_NAME="chr-$VERSION.img"
ZIP_NAME="chr-$VERSION.img.zip"
CURRENT_IMG="$IMG_DIR/$IMG_NAME"

echo "🤖 MikroTik Docker Init - Version: $VERSION"

# --- 1. VALIDACIÓN DE DEPENDENCIAS ---
for cmd in qemu-system-x86_64 wget unzip sshpass nc; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ ERROR: El comando '$cmd' no está instalado."
        exit 1
    fi
done

# --- 2. DESCARGA Y PREPARACIÓN DEL DISCO ---
mkdir -p $IMG_DIR

if [ ! -f "$CURRENT_IMG" ]; then
    URL="https://download.mikrotik.com/routeros/$VERSION/$ZIP_NAME"
    echo "⬇️ Descargando imagen desde: $URL"
    
    if wget --no-check-certificate -q --show-progress -O "$IMG_DIR/$ZIP_NAME" "$URL"; then
        unzip -q "$IMG_DIR/$ZIP_NAME" -d "$IMG_DIR"
        rm "$IMG_DIR/$ZIP_NAME"
        
        # Buscar el archivo .img extraído y renombrarlo al estándar
        EXTRACTED=$(find "$IMG_DIR" -maxdepth 1 -name "*.img" ! -name "$IMG_NAME" | head -n 1)
        if [ ! -z "$EXTRACTED" ]; then
            mv "$EXTRACTED" "$CURRENT_IMG"
        fi
    else
        echo "❌ ERROR: Falló la descarga. Revisa la versión o conexión."
        sleep 60 && exit 1
    fi
fi

# Redimensionar disco si es necesario
if [ ! -z "$DISK_SIZE" ]; then
    echo "💿 Ajustando tamaño de disco a $DISK_SIZE..."
    qemu-img resize -f raw "$CURRENT_IMG" "$DISK_SIZE" > /dev/null
fi

# --- 3. CONFIGURACIÓN DE RED (PORT FORWARDING) ---
# Usamos un array para construir las reglas de forma limpia
declare -a FWD_RULES

# Puertos base obligatorios (Host:Guest)
# 2222->22 (SSH), 8291 (Winbox), 8728 (API), 80 (Web), 443 (SSL)
FWD_RULES+=("tcp::2222-:22" "tcp::8291-:8291" "tcp::8728-:8728" "tcp::8080-:80" "tcp::4433-:443")

# Puertos opcionales por variables específicas
[ ! -z "${PORT_API_SSL:-}" ] && F_SSL=$(echo "$PORT_API_SSL" | tr -d '\r') && FWD_RULES+=("tcp::${F_SSL}-:8729")
[ ! -z "${PORT_WIREGUARD:-}" ] && F_WG=$(echo "$PORT_WIREGUARD" | tr -d '\r') && FWD_RULES+=("udp::${F_WG}-:${F_WG}")

# Puertos EXTRA personalizados (Formato: "80:80,443:443:tcp,1194:1194:udp")
if [ ! -z "${EXTRA_PORTS:-}" ]; then
    CLEAN_EXTRA=$(echo "$EXTRA_PORTS" | tr -d '\r ')
    IFS=',' read -ra ADDS <<< "$CLEAN_EXTRA"
    for i in "${ADDS[@]}"; do
        IFS=':' read -ra P_DATA <<< "$i"
        
        H_PORT="${P_DATA[0]}"
        G_PORT="${P_DATA[1]:-$H_PORT}" # Si no hay guest port, usa el mismo que host
        PROTO="${P_DATA[2]:-tcp}"      # Default tcp
        
        FWD_RULES+=("${PROTO}::${H_PORT}-:${G_PORT}")
        echo "🔌 + Custom Port: $H_PORT -> $G_PORT ($PROTO)"
    done
fi

# Unir todas las reglas con ',hostfwd='
FWD_STRING=""
for rule in "${FWD_RULES[@]}"; do
    FWD_STRING="${FWD_STRING},hostfwd=${rule}"
done

NET_ARGS="-netdev user,id=net0${FWD_STRING} -device virtio-net-pci,netdev=net0"

# --- 4. PREPARACIÓN DE QEMU ---
QEMU_ARGS="-nographic -serial mon:stdio -m $RAM -smp $CPUS -device i6300esb,id=watchdog0 -action watchdog=reset"

if [ -e /dev/kvm ]; then
    echo "🚀 KVM Detectado: Aceleración por Hardware ACTIVADA"
    QEMU_ARGS="$QEMU_ARGS -enable-kvm -machine q35,accel=kvm"
else
    echo "⚠️ KVM no encontrado: Usando emulación por software (Lento)"
    QEMU_ARGS="$QEMU_ARGS -machine q35"
fi

# --- 5. HILO DE AUTO-CONFIGURACIÓN (BACKGROUND) ---
(
    echo "⏳ (Auto-Config) Esperando a que RouterOS inicie..."
    MAX_RETRIES=30
    COUNT=0
    
    # Esperar a que el puerto SSH responda internamente
    until nc -z 127.0.0.1 2222 &>/dev/null; do
        sleep 3
        COUNT=$((COUNT+1))
        [ $COUNT -ge $MAX_RETRIES ] && echo "❌ (Auto-Config) Timeout SSH. No se pudo auto-configurar." && exit 0
    done

    # Aplicar script si existe y no ha sido aplicado antes
    if [ -f "/routeros/config/autorun.rsc" ] && [ ! -f "/routeros/config/.applied" ]; then
        echo "📜 (Auto-Config) Aplicando configuración inicial 'autorun.rsc'..."
        sleep 5
        # Intentar aplicar vía SSH
        sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -p 2222 "$USER@127.0.0.1" < /routeros/config/autorun.rsc
        if [ $? -eq 0 ]; then
            touch /routeros/config/.applied
            echo "✅ (Auto-Config) Configuración aplicada con éxito."
        fi
    fi
) &

# --- 6. LANZAMIENTO ---
echo "🔥 Iniciando QEMU..."
echo "ℹ️  Acceso Winbox por puerto: 8291"
echo "ℹ️  Acceso SSH por puerto: 2222"

exec qemu-system-x86_64 $QEMU_ARGS -drive file="$CURRENT_IMG",format=raw,if=virtio $NET_ARGSù


# Mejoras clave introducidas:
# Manejo de Puertos Dinámico: Ahora usa un array (FWD_RULES). Esto evita el error de tener una coma al principio o al final de la cadena de puertos que hace que QEMU falle al arrancar.
# Lógica EXTRA_PORTS mejorada:
# Soporta PuertoHost:PuertoGuest:Protocolo.
# Si omites el protocolo, usa tcp.
# Si omites el puerto guest (ej. EXTRA_PORTS="1194:1194:udp"), lo mapea correctamente.
# Detección de Imagen: Al descomprimir el ZIP de MikroTik, a veces el archivo se llama chr-7.12.1.img y otras solo chr.img. He añadido un find para localizarlo automáticamente y renombrarlo.
# Validación de Binarios: El script comprueba si tienes sshpass, nc y qemu antes de empezar para no fallar a mitad del proceso.
# Limpieza de variables: Se añade limpieza de \r a todas las variables críticas (RAM, CPU, etc.) para evitar fallos si el archivo .env se creó en Windows.
# Uso de exec: Al final, exec reemplaza el proceso del script por el de QEMU. Esto permite que Docker capture correctamente las señales de apagado (SIGTERM) y que la consola sea interactiva de inmediato.
# Cómo usar la variable EXTRA_PORTS ahora:
# Puedes pasarla así en tu docker-compose.yml o docker run:
# EXTRA_PORTS="500:500:udp,4500:4500:udp,1194:1194:tcp"
# EXTRA_PORTS="8081:80" (Mapea el 8081 del host al 80 del router).