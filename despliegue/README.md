# UNITAXI como servicio de Docker (servidor)

El backend (API, panel en `/admin` y app web en `/app`) corre en el contenedor `unitaxi-backend`, en el puerto
**5557** de la maquina. Arranca solo al prender el servidor y se reinicia si se cae. Atiende al proxy con
certificado de **https://uni-taxi.uap.edu.bo** y directo en **http://virtual.uap.edu.bo:5557/app/**.

- No compila Flutter: el panel y la app ya van compilados en `backend/src/main/resources/web` (se actualizan
  con `./compilar-web.sh` antes de subir). En el servidor solo se compila Java, dentro de Docker.
- La base de datos que ya corre (`taxiuap-db` de `docker-compose.yml`) no se toca.
- Usa la misma configuracion que `./iniciar.sh`: el `.env` de la raiz y el `application-<perfil>.properties` de
  la maquina, la carpeta de archivos (Documentos Unitaxi) y los logs en `logs/`.

## Primera vez

```bash
cd <carpeta del repositorio>
git status                      # si hay archivos modificados, revisarlos antes
git pull
# detener el ./iniciar.sh que este corriendo (Ctrl+C en su terminal); el puerto 5557 debe quedar libre
./despliegue/servicio.sh iniciar
```

## Despues

```bash
./despliegue/servicio.sh actualizar   # git pull + compilar Java + reiniciar (guarda cambios locales con git stash)
./despliegue/servicio.sh reiniciar    # despues de cambiar el .env
./despliegue/servicio.sh estado
./despliegue/servicio.sh logs         # tambien logs/taxiuap.log y logs/taxiuap-errores.log
./despliegue/servicio.sh detener
```

El usuario necesita permiso para Docker (grupo `docker`) o usar `sudo`; el contenedor corre igual con el usuario
duenio del repositorio.

## Hora de Bolivia

El backend ya trabaja con la hora de Bolivia aunque la maquina este en UTC (el contenedor lleva
`TZ=America/La_Paz` y Java `-Duser.timezone=America/La_Paz`; la conexion a la BD usa esa zona). Para que tambien
la maquina (comando `date`, cron, logs del sistema) muestre la hora de Bolivia, una sola vez:

```bash
sudo timedatectl set-timezone America/La_Paz
timedatectl            # debe decir "Time zone: America/La_Paz (-04, -0400)"
```

No hace falta reiniciar el servicio. Si la BD externa tambien debe mostrar esa hora en sus consultas sueltas:
`ALTER DATABASE taxiuap SET timezone TO 'America/La_Paz';` (como superusuario de PostgreSQL).
