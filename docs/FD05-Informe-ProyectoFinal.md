<center>

![./media/media/image1.png](./media/logo-upt.png)

**UNIVERSIDAD PRIVADA DE TACNA**

**FACULTAD DE INGENIERIA**

**Escuela Profesional de Ingeniería de Sistemas**

**Informe Final**

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

> Informe Final del Proyecto

> Versión *1.0*

|CONTROL DE VERSIONES||||||
| :-: | :- | :- | :- | :- | :- |
|Versión|Hecha por|Revisada por|Aprobada por|Fecha|Motivo|
|1\.0|Equipo CoSwim|Patricio Cuadros|Patricio Cuadros|09/10/2026|Versión original|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

# **INDICE GENERAL**

[1. Antecedentes](#_Toc1)

[2. Planteamiento del Problema](#_Toc2)

[3. Objetivos](#_Toc3)

[4. Desarrollo de la Solución](#_Toc4)

[5. Cronograma](#_Toc5)

[6. Presupuesto](#_Toc6)

[7. Conclusiones](#_Toc7)

[8. Recomendaciones](#_Toc8)

[9. Bibliografía](#_Toc9)

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

**<u>Informe Final del Proyecto</u>**

1. <span id="_Toc1" class="anchor"></span>**Antecedentes**

    &nbsp;&nbsp;&nbsp;&nbsp;Los relojes deportivos de gama media (como el Redmi Watch 4 usado como
    referencia) sincronizan sus datos de natación hacia Health Connect a través de la app
    del fabricante (Mi Fitness), pero esa app solo ofrece una lectura genérica: promedios
    de sesión, sin índices de eficiencia propios ni comparación histórica. Este proyecto
    surge para cubrir ese vacío construyendo una capa de analítica independiente del
    fabricante del reloj.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

2. <span id="_Toc2" class="anchor"></span>**Planteamiento del Problema**

    &nbsp;&nbsp;&nbsp;&nbsp;Un nadador que entrena con un wearable de gama media no tiene forma de ver
    su índice de eficiencia real, sus splits por 100 m ni su tendencia de mejora entre
    sesiones, porque la app del fabricante no calcula esas métricas y los datos quedan
    aislados en el dispositivo. Adicionalmente, durante el desarrollo se confirmaron
    problemas reales de interoperabilidad entre Mi Fitness y Health Connect (permisos de
    Android mal declarados para `SPEED` y `BLOOD_OXYGEN`), que bloqueaban silenciosamente
    la lectura de todos los demás tipos de dato.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

3. <span id="_Toc3" class="anchor"></span>**Objetivos**

    &nbsp;&nbsp;&nbsp;&nbsp;**Objetivo general:** desarrollar una aplicación móvil que lea, almacene y
    analice sesiones de natación sincronizadas desde Health Connect, con métricas de
    rendimiento que la app del fabricante del reloj no calcula de forma nativa.

    &nbsp;&nbsp;&nbsp;&nbsp;**Objetivos específicos:**

    - Integrar la lectura confiable de Health Connect, aislando fallas por tipo de dato.
    - Diseñar un backend propio con autenticación Google y sincronización de historial.
    - Calcular métricas de analítica deportiva propias a partir de series disponibles.
    - Incorporar un pipeline de CI con análisis de calidad y seguridad.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

4. <span id="_Toc4" class="anchor"></span>**Desarrollo de la Solución**

    &nbsp;&nbsp;&nbsp;&nbsp;La solución final es un sistema cliente-servidor: una app Flutter
    (Android) que lee Health Connect y se autentica con Google, y un backend propio en
    Node.js/Express con base de datos PostgreSQL desplegado en Railway. La app nunca
    accede directo a la base de datos. Sobre los datos leídos se calculan métricas
    propias: índice de eficiencia, splits de 100 m (desde la serie de velocidad), zonas
    de frecuencia cardiaca, carga de entrenamiento estilo TRIMP y recuperación de FC
    post-esfuerzo. El detalle completo de la arquitectura, requerimientos y factibilidad
    se documenta en los anexos (FD01 a FD04).

    &nbsp;&nbsp;&nbsp;&nbsp;La metodología de implementación siguió el orden natural de dependencias:
    primero la lectura confiable de Health Connect, luego el modelo de dominio y las
    métricas propias, luego el backend y la sincronización, y por último la capa de
    calidad y seguridad continua (SonarCloud, Snyk, Semgrep vía GitHub Actions).

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

5. <span id="_Toc5" class="anchor"></span>**Cronograma**

    &nbsp;&nbsp;&nbsp;&nbsp;El desarrollo se ejecutó en 8 semanas, según el detalle del Informe de
    Factibilidad (FD01, Figura 1): relevamiento y diseño (2 semanas), integración con
    Health Connect (3 semanas), backend y sincronización (2.5 semanas) y analítica/calidad
    (2.5 semanas, en paralelo con el cierre de la etapa anterior).

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

6. <span id="_Toc6" class="anchor"></span>**Presupuesto**

    |Rubro|Costo (S/)|
    | :- | :-: |
    |Costos generales|270.00|
    |Costos operativos (estimado máximo, mensual)|40.00|
    |Costos de personal (valorizado)|3675.00|
    |**Total estimado del proyecto**|**3985.00**|

    &nbsp;&nbsp;&nbsp;&nbsp;El detalle de cada rubro se encuentra en el Informe de Factibilidad
    (FD01, sección 4.2). El costo operativo recurrente (infraestructura) es de S/ 0.00 a
    S/ 40.00 mensuales, sostenible sin financiamiento externo.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

7. <span id="_Toc7" class="anchor"></span>**Conclusiones**

- El proyecto cumplió su objetivo general: CoSwim lee, almacena y analiza sesiones de
  natación con métricas que la app del fabricante del wearable no ofrece.
- Las limitaciones de interoperabilidad encontradas (permisos de Health Connect mal
  declarados, ausencia de `SpeedRecord` en ciertos modos) son del ecosistema de
  terceros y ya están mitigadas en el código actual.
- La arquitectura con backend propio y autenticación por Google cumple los objetivos
  de seguridad planteados sin requerir infraestructura dedicada del usuario.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

8. <span id="_Toc8" class="anchor"></span>**Recomendaciones**

- Definir una licencia de código abierto antes de cualquier distribución pública.
- Evaluar un sistema de migraciones versionado si el esquema de base de datos crece.
- Evaluar soporte para iOS/HealthKit si el proyecto escala más allá del alcance actual.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

9. <span id="_Toc9" class="anchor"></span>**Bibliografía**

Edwards, S. (1993). *The heart rate monitor book*. Polar Electro Oy.

Google. (s. f.). *Health Connect developer guide*. Android Developers. Recuperado el 9
de octubre de 2026, de https://developer.android.com/health-and-fitness/guides/health-connect

Railway. (s. f.). *Railway documentation*. Recuperado el 9 de octubre de 2026, de
https://docs.railway.com/
