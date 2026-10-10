<center>

![./media/media/image1.png](./media/logo-upt.png)

**UNIVERSIDAD PRIVADA DE TACNA**

**FACULTAD DE INGENIERIA**

**Escuela Profesional de Ingeniería de Sistemas**

**Propuesta del Proyecto CoSwim**

Curso: *{Nombre de Asignatura}*

Docente: *Patricio Cuadros*

Integrantes:

***{Apellidos y nombres del estudiante (código universitario)}***

**Tacna – Perú**

***2026***

</center>
<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

> Sistema *CoSwim*

> Propuesta del Proyecto

> Versión *1.0*

|CONTROL DE VERSIONES||||||
| :-: | :- | :- | :- | :- | :- |
|Versión|Hecha por|Revisada por|Aprobada por|Fecha|Motivo|
|1\.0|Equipo CoSwim|Patricio Cuadros|Patricio Cuadros|09/10/2026|Versión original|

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

# **INDICE GENERAL**

[1. Resumen Ejecutivo](#_Toc1)

[2. Planteamiento del Problema y Justificación](#_Toc2)

[3. Objetivo General y Específicos](#_Toc3)

[4. Beneficios](#_Toc4)

[5. Alcance y Restricciones](#_Toc5)

[6. Cronograma](#_Toc6)

[7. Presupuesto](#_Toc7)

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

**<u>Propuesta del Proyecto</u>**

1. <span id="_Toc1" class="anchor"></span>**Resumen Ejecutivo**

    &nbsp;&nbsp;&nbsp;&nbsp;Se propone desarrollar **CoSwim**, una aplicación móvil que lee sesiones
    de natación desde Health Connect (sincronizadas por el reloj del usuario) y agrega
    analítica deportiva propia que la app del fabricante del wearable no ofrece: índice
    de eficiencia, splits de 100 m, zonas de frecuencia cardiaca, carga de entrenamiento
    y recuperación. El sistema incluye un backend propio con autenticación por Google
    para respaldar el historial del usuario en la nube.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

2. <span id="_Toc2" class="anchor"></span>**Planteamiento del Problema y Justificación**

    &nbsp;&nbsp;&nbsp;&nbsp;Los wearables de gama media sincronizan datos de natación hacia Health
    Connect, pero sus apps oficiales solo muestran promedios de sesión, sin analítica
    comparativa ni índices propios. Se justifica el desarrollo de una capa de software
    independiente del fabricante porque: (1) el problema es real y verificado con
    hardware físico, no hipotético; (2) la tecnología necesaria (Health Connect, Flutter,
    Node.js) es gratuita y madura; y (3) el costo de infraestructura recurrente es casi
    nulo (capas gratuitas de Railway y GitHub Actions).

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

3. <span id="_Toc3" class="anchor"></span>**Objetivo General y Específicos**

    &nbsp;&nbsp;&nbsp;&nbsp;**Objetivo general:** desarrollar una aplicación móvil que lea, almacene y
    analice sesiones de natación sincronizadas desde Health Connect.

    - Integrar la lectura confiable de Health Connect, tipo por tipo.
    - Implementar un backend propio con autenticación Google y sincronización.
    - Calcular métricas de analítica deportiva propias sobre datos ya disponibles.
    - Incorporar un pipeline de calidad y seguridad continuo.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

4. <span id="_Toc4" class="anchor"></span>**Beneficios**

    - Analítica deportiva que normalmente está reservada a relojes de gama alta o apps
      de pago, usando wearables de gama media ya extendidos.
    - Historial centralizado en la nube, accesible desde cualquier sesión autenticada
      con la misma cuenta de Google.
    - Costo de infraestructura recurrente cercano a cero.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

5. <span id="_Toc5" class="anchor"></span>**Alcance y Restricciones**

    &nbsp;&nbsp;&nbsp;&nbsp;El alcance cubre la app Flutter (Android) y el backend (API REST +
    PostgreSQL). Restricciones: la app solo funciona en Android con Health Connect
    disponible (sin vista iOS en este alcance); las métricas dependen de lo que el
    fabricante del wearable efectivamente escriba en Health Connect.

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

6. <span id="_Toc6" class="anchor"></span>**Cronograma**

    &nbsp;&nbsp;&nbsp;&nbsp;Duración estimada: 8 semanas, en cuatro etapas (relevamiento y diseño,
    integración con Health Connect, backend y sincronización, analítica y calidad). El
    detalle semana a semana se encuentra en el Informe de Factibilidad (FD01, Figura 1).

<div style="page-break-after: always; visibility: hidden">\pagebreak</div>

7. <span id="_Toc7" class="anchor"></span>**Presupuesto**

    |Rubro|Costo (S/)|
    | :- | :-: |
    |Costos generales|270.00|
    |Costos operativos (estimado máximo, mensual)|40.00|
    |Costos de personal (valorizado)|3675.00|
    |**Total estimado del proyecto**|**3985.00**|
