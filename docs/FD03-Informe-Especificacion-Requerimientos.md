<center>

![./media/media/image1.png](./media/logo-upt.png)

**UNIVERSIDAD PRIVADA DE TACNA**

**FACULTAD DE INGENIERIA**

**Escuela Profesional de Ingeniería de Sistemas**

**Proyecto CoSwim**

Curso: *{Nombre de Asignatura}*

Docente: *Patricio Cuadros*

Integrantes:

***{Apellidos y nombres del estudiante (código universitario)}***

**Tacna – Perú**

***2026***

</center>
<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

> Sistema *CoSwim*

> Documento de Especificación de Requerimientos de Software (SRS)

> Versión *1.0*

|CONTROL DE VERSIONES||||||
| :-: | :- | :- | :- | :- | :- |
|Versión|Hecha por|Revisada por|Aprobada por|Fecha|Motivo|
|1\.0|Equipo CoSwim|Patricio Cuadros|Patricio Cuadros|09/10/2026|Versión original|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

# **INDICE GENERAL**

[1. Introducción](#_Toc1)

[2. Requerimientos Funcionales](#_Toc2)

[3. Requerimientos No Funcionales](#_Toc3)

[4. Reglas de Negocio](#_Toc4)

[5. Perfiles de Usuario](#_Toc5)

[6. Casos de Uso Principales](#_Toc6)

[7. Conclusiones](#_Toc7)

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

**<u>Especificación de Requerimientos de Software</u>**

1. <span id="_Toc1" class="anchor"></span>**Introducción**

    &nbsp;&nbsp;&nbsp;&nbsp;Este documento especifica los requerimientos funcionales y no funcionales de
    **CoSwim**, aplicación móvil que lee sesiones de natación desde Health Connect y las
    analiza con métricas propias (índice de eficiencia, splits de 100 m, zonas de frecuencia
    cardiaca), respaldadas en un backend propio con autenticación por Google. El alcance
    cubre la app Flutter (Android) y la API REST (Node.js/Express + PostgreSQL) descritas
    en el Documento de Visión (FD02).

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

2. <span id="_Toc2" class="anchor"></span>**Requerimientos Funcionales**

    |Código|Requerimiento|Prioridad|
    | :- | :- | :-: |
    |RF-01|El sistema debe permitir autenticarse con una cuenta de Google, sin contraseña propia.|Alta|
    |RF-02|El sistema debe leer de Health Connect los tipos: frecuencia cardiaca, SpO2, calorías activas, distancia y sesiones de ejercicio (`WORKOUT`), solicitando cada tipo por separado.|Alta|
    |RF-03|El sistema debe listar el historial de sesiones de natación del usuario autenticado, ordenado por fecha descendente.|Alta|
    |RF-04|El sistema debe mostrar el detalle de una sesión: estadísticas, índice de eficiencia, gráfico de FC, gráfico de SpO2 y splits de 100 m.|Alta|
    |RF-05|El sistema debe calcular splits de 100 m a partir de la serie de velocidad únicamente cuando esta serie exista.|Media|
    |RF-06|El sistema debe sincronizar las sesiones locales con el backend (subir nuevas/actualizar existentes por `external_id`).|Alta|
    |RF-07|El sistema debe mostrar tendencias históricas (índice de eficiencia en el tiempo) y récords personales (mejor 100 m, mayor distancia, mejor índice).|Media|
    |RF-08|El sistema debe permitir al usuario solicitar permisos de Health Connect de forma explícita desde un botón, independiente del flujo automático de lectura.|Media|
    |RF-09|El sistema debe exponer una vista de datos crudos de Health Connect con fines de depuración.|Baja|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

3. <span id="_Toc3" class="anchor"></span>**Requerimientos No Funcionales**

    |Código|Requerimiento|Categoría|
    | :- | :- | :- |
    |RNF-01|Ningún endpoint de la API (salvo `/auth/google`) debe responder sin un JWT válido.|Seguridad|
    |RNF-02|Las credenciales de la base de datos no deben estar presentes en el cliente móvil en ningún momento.|Seguridad|
    |RNF-03|La falla de lectura de un tipo de dato de Health Connect no debe impedir la lectura de los demás tipos.|Confiabilidad|
    |RNF-04|El esquema de base de datos debe poder evolucionar (nuevas columnas) sin romper despliegues ya existentes.|Mantenibilidad|
    |RNF-05|Cambiar de pestaña en la app no debe reiniciar el estado de carga de las otras pantallas (`IndexedStack`).|Usabilidad|
    |RNF-06|El código debe pasar el pipeline de CI (análisis estático con SonarCloud, Snyk y Semgrep) sin hallazgos críticos sin resolver.|Calidad|
    |RNF-07|El backend debe operar dentro de capas gratuitas o de bajo costo (Railway) para el volumen actual de uso.|Costo|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

4. <span id="_Toc4" class="anchor"></span>**Reglas de Negocio**

    |Código|Regla|
    | :- | :- |
    |RN-01|Una sesión de natación se identifica de forma única por (`user_id`, `external_id`); volver a sincronizar la misma sesión actualiza en vez de duplicar.|
    |RN-02|No se calculan splits de 100 m si la serie de velocidad de la sesión está vacía.|
    |RN-03|Las métricas de FC (zonas, carga de entrenamiento, recuperación) solo se muestran si la sesión tiene 2 o más muestras de frecuencia cardiaca.|
    |RN-04|`HealthDataType.SPEED` no se solicita en el flujo de autorización de Health Connect (permiso Android inválido conocido).|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

5. <span id="_Toc5" class="anchor"></span>**Perfiles de Usuario**

    &nbsp;&nbsp;&nbsp;&nbsp;**Nadador.** Único perfil de usuario final: autentica con Google, autoriza el
    acceso a sus datos de Health Connect y consulta su historial y progreso. No existe
    perfil de administrador en el alcance actual: la gestión de datos es por usuario, sin
    panel de administración ni roles diferenciados.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

6. <span id="_Toc6" class="anchor"></span>**Casos de Uso Principales**

    |Caso de uso|Actor|Descripción breve|
    | :- | :- | :- |
    |Iniciar sesión con Google|Nadador|El usuario se autentica con su cuenta de Google y recibe un JWT propio de CoSwim.|
    |Sincronizar sesiones|Nadador|La app lee Health Connect, arma las sesiones y las sube al backend vía `/sessions/sync`.|
    |Ver historial de entrenamientos|Nadador|El usuario navega la lista de sesiones y abre el detalle de una de ellas.|
    |Ver progreso|Nadador|El usuario revisa tendencias históricas y récords personales en la pestaña "Progreso".|
    |Solicitar permisos de Health Connect|Nadador|El usuario autoriza manualmente los tipos de dato que la app necesita leer.|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

7. <span id="_Toc7" class="anchor"></span>**Conclusiones**

- Los requerimientos funcionales priorizan la lectura confiable de Health Connect y la
  sincronización con el backend, por ser la base de la que dependen todas las demás
  funcionalidades.
- Los requerimientos no funcionales de seguridad (JWT obligatorio, sin credenciales de
  BD en el cliente) ya están implementados y verificados por el pipeline de CI.
- No se identificaron requerimientos pendientes que bloqueen el funcionamiento actual
  del sistema.
