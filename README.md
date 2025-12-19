<div align="center">
  <img src="https://cdn.simpleicons.org/mikrotik/666666" width="80" alt="MikroTik Logo">
  <h1>🚀 Dockerized MikroTik RouterOS (CHR)</h1>
  <p><b>La solución definitiva para ejecutar MikroTik CHR con rendimiento nativo KVM en Docker.</b></p>

  <p>
    <a href="https://hub.docker.com/r/dayron95/routeros-kvm"> <img src="https://img.shields.io/badge/Docker_Hub-Ir_al_Repositorio-2496ed?style=for-the-badge&logo=docker&logoColor=white" />
    <img src="https://img.shields.io/github/stars/Dayron1195/routeros-kvm?style=for-the-badge&logo=github&color=fafafa&labelColor=333" />
    <img src="https://img.shields.io/badge/KVM-Accelerated-orange?style=for-the-badge&logo=linux" />
  </p>
</div>
      
<div align="center"> <a href="https://github.com/Dayron1195/routeros-kvm/wiki"><img src="https://cdn.simpleicons.org/wikipedia/666666" width="80"></a>
</div>

### 📖 Descripción
Este contenedor permite ejecutar **MikroTik RouterOS (CHR)** de manera ligera y segura. Está diseñado para administradores de red que necesitan instancias de MikroTik rápidas para laboratorios, VPNs o routing interno, eliminando la complejidad de configurar QEMU manualmente.



### ✨ Características Principales
* **⚡ Aceleración KVM:** Rendimiento casi nativo detectando automáticamente `/dev/kvm`.
* **🔌 Gestión Inteligente:** Mapeo dinámico de puertos mediante variables de entorno.
* **💾 Auto-Resize:** El disco virtual se expande al tamaño definido en `DISK_SIZE`.
* **🤖 Auto-Configuración:** Inyecta tus scripts `.rsc` personalizados al arrancar.
* **📂 Persistencia:** Configuración segura mediante volúmenes externos.

---

### 📋 Requisitos
* **Sistema:** Linux con soporte KVM (o WSL2 configurado).
* **Virtualización:** VT-x o AMD-V habilitado en BIOS.
* **Herramientas:** Docker y Docker Compose.

---

---

### ⚡ Inicio Rápido
```bash
git clone [https://github.com/dayron95/mikrotik-docker.git](https://github.com/dayron95/mikrotik-docker.git)
cd mikrotik-docker
docker-compose up -d --build
```
<table align="center"> <tr> <td align="center"><b>Servicio</b></td> <td align="center"><b>Puerto Host</b></td> <td align="center"><b>Usuario/Pass</b></td> </tr> <tr> <td>Winbox</td> <td align="center"><code>8291</code></td> <td rowspan="3" align="center">admin / (vacio)</td> </tr> <tr> <td>WebFig (HTTP)</td> <td align="center"><code>80</code></td> </tr> <tr> <td>SSH</td> <td align="center"><code>22</code></td> </tr> </table>

----

### 🛠️ Configuración (Variables de Entorno)
<p>Personaliza tu instancia editando las variables en el archivo <code>docker-compose.yml</code>:</p>

<table width="100%">
  <thead>
    <tr style="background-color: #24292e; color: white;">
      <th align="left" width="30%">Variable</th>
      <th align="center" width="20%">Por Defecto</th>
      <th align="left" width="50%">Descripción</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>ROUTEROS_VERSION</code></td>
      <td align="center"><code>7.12.1</code></td>
      <td>Versión oficial de MikroTik a descargar desde sus servidores.</td>
    </tr>
    <tr>
      <td><code>ROUTEROS_RAM</code></td>
      <td align="center"><code>512</code></td>
      <td>Cantidad de memoria RAM asignada al sistema (en MB).</td>
    </tr>
    <tr>
      <td><code>DISK_SIZE</code></td>
      <td align="center"><code>1G</code></td>
      <td>Tamaño del disco virtual. Se expande automáticamente (ej: <code>2G</code>, <code>10G</code>).</td>
    </tr>
    <tr>
      <td><code>EXTRA_PORTS</code></td>
      <td align="center"><code>-</code></td>
      <td>Puertos adicionales en formato <code>Host:Guest:Proto</code> (ej: <code>1194:1194:udp</code>).</td>
    </tr>
  </tbody>
</table>

---

----

🎮 Operaciones Comunes
<summary>💻 <b>Acceder a la Consola (CLI)</b></summary> Usa el comando directo para entrar al router sin necesidad de SSH externo:

```bash
docker exec -it mikrotik-pro terminal
```

----

<summary>🤖 <b>Script de Auto-Arranque (ZTP)</b></summary>

Coloca tu archivo en ./config/autorun.rsc.

El contenedor lo ejecutará en el primer arranque.

Se creará un archivo .applied para evitar duplicidad.

----

🚨 Solución de Problemas
¿Lento? Revisa permisos de KVM: sudo chmod 666 /dev/kvm.

¿No conecta? Asegúrate de que ether1 esté en modo DHCP interno; no cambies su IP manualmente.

Puertos Extra: Recuerda declarar los puertos tanto en EXTRA_PORTS como en la sección ports: de Docker.

----

<div align="center"> <p><b>Desarrollado por <a href="https://www.google.com/search?q=https://github.com/dayron95">dayron95</a></b></p> <sub><img src="https://merch.mikrotik.com/cdn/shop/files/512.png?v=1657867177&width=250" width="20" alt="MikroTik Logo">MikroTik y RouterOS son marcas registradas de MikroTikls SIA.</sub> </div>
