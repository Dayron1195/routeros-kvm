FROM alpine:latest

# --- 1. LABELS (INFORMACIÓN DEL PROYECTO) ---
LABEL org.opencontainers.image.authors="dayron95 <https://github.com/dayron95>"
LABEL org.opencontainers.image.title="MikroTik RouterOS CHR (KVM)"
LABEL org.opencontainers.image.description="Contenedor Docker para MikroTik CHR con aceleración KVM, auto-resize, puertos dinámicos y acceso por terminal."
LABEL org.opencontainers.image.version="7.20.6"

# --- 2. ENVIRONMENT VARIABLES ---
# Valores por defecto para el script de inicio
ENV ROUTEROS_VERSION="7.20.6" \
    ROUTEROS_RAM="512" \
    ROUTEROS_CPU="2" \
    DISK_SIZE="1G" \
    ROUTEROS_USER="admin" \
    ROUTEROS_PASSWORD="" \
    PORT_WIREGUARD="13231" \
    PORT_API_SSL="8729" \
    EXTRA_PORTS=""

# --- 3. WORKING DIRECTORY --
WORKDIR /routeros

# --- 4. INSTALACIÓN DE DEPENDENCIAS ---
RUN apk add --no-cache \
    bash \
    qemu-system-x86_64 \
    qemu-img \
    qemu-modules \
    wget \
    unzip \
    libcap \
    dos2unix \
    openssh-client \
    sshpass \
    netcat-openbsd \
    ca-certificates \
    && \
    # Script auxiliar para entrar a la consola del router rápidamente
    # Uso: 'docker exec -it <nombre> terminal'
    echo '#!/bin/bash' > /usr/local/bin/terminal && \
    echo 'USER=${ROUTEROS_USER:-admin}' >> /usr/local/bin/terminal && \
    echo 'PASS=${ROUTEROS_PASSWORD:-}' >> /usr/local/bin/terminal && \
    echo 'exec sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p 2222 "$USER"@127.0.0.1' >> /usr/local/bin/terminal && \
    chmod +x /usr/local/bin/terminal && \
    # Limpieza de archivos pesados no necesarios para CHR
    rm -rf /usr/share/qemu/u-boot* /usr/share/qemu/skiboot* /usr/share/qemu/openbios* \
           /usr/share/icons /usr/share/doc /usr/share/man

# --- 5. COPIAR ENTRYPOINT ---
# Copiamos el script mejorado que procesa los puertos
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# --- 6. EXPOSE PORTS ---
# Estos son los puertos que el script de entrypoint mapea hacia afuera del QEMU:
# SSH: 2222 | Winbox: 8291 | API: 8728 | HTTP: 8080 | HTTPS: 4433 | WG: 13231
EXPOSE 2222 8291 8728 8080 4433 13231/udp

# --- 7. HEALTHCHECK ---
# Verifica que el puerto SSH interno (mapeado al 2222) esté respondiendo
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD nc -z 127.0.0.1 2222 || exit 1

# --- 8. ENTRYPOINT ---
ENTRYPOINT ["/entrypoint.sh"]

# Notas Importantes para tu despliegue:
# Mapeo de SSH: Como el script redirige el tráfico del contenedor en el puerto 2222 hacia el puerto 22 interno de MikroTik, cuando hagas un docker run, debes mapearlo así:
# -p 22:2222 (Si quieres usar el puerto 22 estándar en tu host).
# Mapeo de Web: El script usa el puerto 8080 del contenedor para la Web.
# -p 80:8080 (Mapea el 80 de tu host al 8080 del contenedor).
# Terminal Directa: Gracias al comando que incluí en el Dockerfile, puedes entrar a configurar el router sin usar SSH externo ejecutando:
# code
# Bash
# docker exec -it nombre_contenedor terminal
# Aceleración KVM: No olvides que para que funcione rápido, debes ejecutar el contenedor con el dispositivo de red y privilegios:
# code
# Bash
# docker run -d \
#   --name mikrotik \
#   --device /dev/kvm \
#   --cap-add NET_ADMIN \
#   -p 8291:8291 -p 22:2222 \
#   -v ./config:/routeros/config \
#   dayron95/mikrotik-docker:7.20.6