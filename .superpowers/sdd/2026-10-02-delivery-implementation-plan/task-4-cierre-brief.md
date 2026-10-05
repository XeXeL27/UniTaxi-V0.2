# Brief de cierre de Task 4 DELIVERY

## Objetivo

Cerrar los dos hallazgos importantes de Task 4 sin cambiar el comportamiento de producción salvo que
una prueba real demuestre un defecto. El alcance es únicamente la cobertura de integración y permisos
de `EntregaService`.

## Requisitos obligatorios

1. Crear una prueba `@SpringBootTest` con el perfil `appu` que use el `EntregaService` real, el
   `DatosEntregaRepository` real y PostgreSQL de Docker. No se permite mockear `EntregaService`,
   `ViajeService` ni `DatosEntregaRepository` en esta prueba.
2. Recorrer un camino legal completo de `ENCOMIENDA` mediante el servicio real: pedido en
   `EN_CAMINO_RECOGIDA` -> validar código de recogida -> `EN_MANO` -> confirmar pago -> validar código
   de entrega -> `ENTREGADO`; verificar además que el viaje termina `COMPLETADO`.
3. La aserción principal debe leer el registro desde una transacción/contexto posterior, no confiar en
   la misma instancia administrada por el servicio. Debe demostrar que `estado_entrega=ENTREGADO`, el
   pago quedó confirmado y el viaje quedó `COMPLETADO` persistidos en PostgreSQL.
4. Cubrir la autorización con entidades reales y el servicio real: un conductor distinto al asignado
   debe ser rechazado, un pasajero distinto al dueño del viaje debe ser rechazado al confirmar una
   compra, y el conductor asignado debe poder ejecutar su acción válida.
5. Los códigos de recogida y entrega son valores aleatorios independientes de exactamente 6 dígitos.
   No deben derivarse del teléfono, CI, id de viaje, id de persona ni ningún otro identificador.
   Las pruebas deben usar códigos explícitos de 6 dígitos para validar el contrato, sin inferir ninguna
   relación con teléfonos.
   (Corrección 2026-10-05: el brief decía 8 dígitos; el contrato vigente es de 6 dígitos, commit
   `4b9b463`.)
6. Seguir TDD: escribir las pruebas primero y observarlas fallar por la cobertura ausente o por una
   configuración incorrecta; luego ajustar únicamente lo mínimo necesario.
7. Si el test real descubre que la producción no persiste correctamente, arreglar producción con una
   prueba roja previa. No tocar la comparación de teléfonos diferida ni iniciar Task 5.

## Autoverificación obligatoria

Después de obtener GREEN, retirar temporalmente `clearAutomatically` o hacer incondicional una
actualización condicional relevante, ejecutar la prueba nueva y demostrar que falla; restaurar el cambio
inmediatamente y volver a ejecutar la prueba en verde. No dejar la producción alterada.

## Verificación

Ejecutar como mínimo:

```bash
cd backend
SPRING_PROFILES_ACTIVE=appu ./gradlew test --tests '*EntregaService*' --console=plain
SPRING_PROFILES_ACTIVE=appu ./gradlew test --console=plain
```

Registrar en `task-4-report.md` los comandos y resultados reales. El reporte debe indicar archivos,
pruebas RED/GREEN, resultado de la autoverificación y cualquier concern.

## Restricciones

- No modificar cambios locales ajenos en `README.md`, `application.properties` ni otros archivos.
- No crear SQL, Flyway ni Liquibase.
- No modificar el bug diferido de normalización de teléfonos.
- Un commit por este cierre, con mensaje en español o el estilo existente del módulo.
