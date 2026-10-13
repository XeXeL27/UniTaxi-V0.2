# syntax=docker/dockerfile:1
# Backend de UNITAXI como servicio de Docker (servicio "unitaxi" de docker-compose.yml). Se construye con
# ./despliegue/servicio.sh: compila solo Java (sin Flutter: el panel y la app ya van compilados en
# backend/src/main/resources/web). La configuracion de la maquina (application-<perfil>.properties) entra en
# el jar igual que con bootRun; el .env se lee al arrancar (despliegue/entrada.sh).

FROM eclipse-temurin:21-jdk AS compilar
# La red de la UAP no tiene IPv6: sin esto Gradle puede fallar al descargar.
ENV JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true
WORKDIR /fuente
COPY backend/gradlew backend/build.gradle backend/settings.gradle ./
COPY backend/gradle gradle
# Las dependencias quedan en la cache de Docker: la siguiente actualizacion no las vuelve a bajar.
RUN --mount=type=cache,target=/root/.gradle ./gradlew --no-daemon dependencies > /dev/null
COPY backend/src src
RUN --mount=type=cache,target=/root/.gradle ./gradlew --no-daemon bootJar -x test \
    && cp build/libs/taxiuap-0.0.1-SNAPSHOT.jar /unitaxi.jar

FROM eclipse-temurin:21-jre
ENV TZ=America/La_Paz
COPY --from=compilar /unitaxi.jar /opt/unitaxi/unitaxi.jar
COPY despliegue/entrada.sh /opt/unitaxi/entrada.sh
RUN chmod 755 /opt/unitaxi/entrada.sh
ENTRYPOINT ["/opt/unitaxi/entrada.sh"]
