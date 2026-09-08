# PROMPT MAESTRO — App de Monitoreo de Natación (Flutter + Health Connect + Redmi Watch 4)

Este documento sirve como instrucción completa (prompt) para construir la aplicación de principio a fin: qué datos extraer, cómo mostrarlos, qué gráficos generar, y bajo qué límites clínicos/deportivos evaluar cada métrica. Todo lo que no tiene fuente citada está marcado explícitamente como estimación general, no como dato clínico verificado.

---

## 1. Objetivo de la aplicación

Aplicación móvil en **Flutter** que se conecta a **Health Connect** (Android) para leer los datos sincronizados desde el **Redmi Watch 4** (vía Mi Fitness), y presenta al usuario un dashboard de sus sesiones de natación con:
- Métricas crudas (lo que el reloj mide)
- Evaluación contra rangos de referencia deportivos/clínicos (con fuente)
- Gráficos históricos de progreso

---

## 2. Datos a extraer de Health Connect (confirmado con el dispositivo real)

Según lo verificado directamente en la pantalla de permisos de Mi Fitness → Health Connect, estos son los tipos de dato realmente disponibles:

| Tipo de dato | HealthDataType en Flutter (`health` package) | Disponible en Redmi Watch 4 |
|---|---|---|
| Calorías activas quemadas | `ACTIVE_ENERGY_BURNED` | ✅ Confirmado |
| Distancia | `DISTANCE_DELTA` | ✅ Confirmado |
| Elevación ganada | `ELEVATION_GAINED` | ✅ Confirmado (poco relevante para natación en piscina) |
| Ejercicio / sesión de entrenamiento | `WORKOUT` | ✅ Confirmado (aquí debería venir el tipo "natación" y duración) |
| Ruta de ejercicio | `WORKOUT_ROUTE` | ✅ Confirmado (relevante solo en aguas abiertas con GPS) |
| Frecuencia cardíaca | `HEART_RATE` | ✅ Confirmado |
| Saturación de oxígeno (SpO2) | `BLOOD_OXYGEN` | ✅ Confirmado (ojo: medido en reposo, no fiable dentro del agua — ver sección 5) |
| Sueño | `SLEEP_ASLEEP` / `SLEEP_SESSION` | ✅ Confirmado (no relevante para la sesión de nado en sí) |
| Velocidad | `SPEED` | ✅ Confirmado |
| Pasos | `STEPS` | ✅ Confirmado (no relevante para natación) |

**NO disponibles / no confirmados en Health Connect (limitación real del dispositivo, documentada en conversación previa):**
- Temperatura del agua ❌
- SWOLF (eficiencia de nado) ❌ — puede estar dentro de Mi Fitness pero no mapeado a Health Connect
- Estilo de nado detectado (libre/espalda/pecho/mariposa) ❌ — mismo caso, verificar manualmente
- Temperatura corporal / de piel ❌ — no apareció en la lista de permisos otorgados

**Acción técnica:** la app debe manejar con gracia (mensaje "dato no disponible desde tu dispositivo") cualquier campo que no venga en la respuesta de `getHealthDataFromTypes()`, en vez de fallar o mostrar campos vacíos sin explicación.

---

## 3. Pantallas y gráficos a implementar

### Pantalla 1 — Dashboard principal (resumen de la última sesión)
- Card con: distancia total, duración, calorías, FC promedio, FC máxima
- Indicador visual (semáforo verde/amarillo/rojo) de si la FC estuvo dentro de zona segura según edad (ver sección 4)

### Pantalla 2 — Historial de sesiones
- Lista de sesiones de natación ordenadas por fecha (filtradas del tipo `WORKOUT` donde el tipo de ejercicio sea natación)
- Cada ítem: fecha, distancia, duración, ritmo promedio

### Pantalla 3 — Gráficos de progreso (usar `fl_chart` o `syncfusion_flutter_charts` en Flutter)
1. **Gráfico de línea — Distancia nadada por sesión a lo largo del tiempo** (eje X: fecha, eje Y: metros)
2. **Gráfico de línea — Frecuencia cardíaca durante una sesión específica** (eje X: tiempo transcurrido, eje Y: BPM), con **bandas de color de fondo** marcando las zonas de FC (ver sección 4) para que el usuario vea visualmente en qué zona estuvo
3. **Gráfico de barras — Calorías quemadas por semana**
4. **Gráfico de dispersión o línea — SpO2 en reposo pre/post sesión** (con nota clara de que no es medición continua durante el nado)
5. **Gráfico de velocidad/ritmo por sesión** (metros/minuto), con línea de referencia según el nivel del usuario (ver sección 6)

### Pantalla 4 — Configuración de perfil
- Edad (necesaria para calcular FC máxima teórica — fórmula en sección 4)
- Nivel autodeclarado: principiante / intermedio / avanzado / competitivo (para ajustar los rangos de referencia de ritmo, sección 6)

---

## 4. Límites de frecuencia cardíaca (con fuente)

**Fórmula estándar de FC máxima teórica:**
```
FC máxima = 220 − edad
```
> Fuente: i-Natación — "La intensidad del entrenamiento", http://www.i-natacion.com/articulos/fisiologia/intensidad_entreno.html
> Fuente: Alto Rendimiento — "Zonas de entrenamiento según las pulsaciones cardiacas", https://altorendimiento.com/zonas-de-entrenamiento-segun-las-pulsaciones-cardiacas/

**Zonas de entrenamiento (% de la FC máxima calculada):**

| Zona | % de FC máx. | Nombre | Efecto |
|---|---|---|---|
| Zona 1 | 50-60% | Recuperación / calentamiento | Regeneración activa |
| Zona 2 | 60-70% | Resistencia básica | Desarrollo de capacidad aeróbica |
| Zona 3 | 70-80% | Aeróbico moderado | Mejora cardiovascular |
| Zona 4 | 80-90% | Umbral anaeróbico | Solo recomendado para deportistas entrenados |
| Zona 5 | >90% | Máximo esfuerzo | Uso muy limitado en el tiempo |

> Fuente: gouforit.com — "Análisis de zonas de frecuencia cardíaca en natación", https://gouforit.com/como-maximizar-entrenamiento-monitor-ritmo-cardiaco-pulsera-fitness/
> Fuente específica de natación: i-Natación recomienda que durante el entrenamiento la FC no debe superar el rango de 60% a 80% de la FC máxima en la mayoría de sesiones (zona aeróbica segura para entrenamiento regular).

**Regla de alerta a implementar en la app:** si la FC durante la sesión supera el 90% de la FC máxima teórica del usuario de forma sostenida (más de X segundos — a definir por el equipo, ej. 60 seg), mostrar una advertencia visual (no un diagnóstico médico, solo un aviso de "estás en zona de esfuerzo máximo").

---

## 5. Límites de saturación de oxígeno (SpO2) — con fuente clínica

| Rango SpO2 | Interpretación | Fuente |
|---|---|---|
| 95% - 100% | Normal (persona sana) | ComparaSalud — "Saturación de Oxígeno: Valores Normales", https://www.comparasalud.com/blog/saturacion-oxigeno-valores-normales.html — y confirmado por la OMS/American Thoracic Society según fisiotorax.es |
| 91% - 94% | Hipoxemia leve — requiere evaluación médica | Misma fuente (ComparaSalud) |
| Menor a 90% | Emergencia — requiere atención inmediata | fisiotorax.es — "¿Con qué saturación de oxígeno hay que ir a urgencias?", https://fisiotorax.es/blog/saturacion-oxigeno-urgencias/ |

**Advertencia técnica importante para el diseño de la app (documentar en el informe del curso):** el propio sensor del reloj **no es de grado médico** y su medición de SpO2 solo es confiable **en reposo**, no durante el nado activo (agua + movimiento interfieren con el sensor óptico). La app debe mostrar el dato con una nota clara: *"Medición en reposo, no representa el nivel de oxigenación durante el nado."* — nunca presentar esto como una medición médica válida en tiempo real dentro del agua.

---

## 6. Límites de temperatura del agua — con fuente oficial (World Aquatics / FINA)

| Contexto | Rango oficial | Fuente |
|---|---|---|
| Piscina de competición estándar | 25°C - 28°C | Fluidra — "Temperatura del agua según la piscina", https://www.fluidra.com/es/soluciones-comerciales/inspiracion/blog/control-de-temperatura-del-agua/ (cita el reglamento de World Aquatics/FINA) |
| Waterpolo | 26°C - 28°C (±1°C tolerancia) | Deporteka — Glosario de Waterpolo, https://deporteka.com/waterpolo/glosario/piscina-waterpolo/ |
| Natación sincronizada | 27°C (óptimo) | Fluidra (misma fuente que competición estándar) |
| Aguas abiertas | Por debajo de 18°C: uso obligatorio de traje térmico | World Aquatics — Open Water Swimming Rules 2025, https://cdn.rfen.es/sectionFiles/1743674623_5843.pdf |

**Nota de seguridad adicional (respaldada por literatura científica, no solo reglamento deportivo):** un estudio publicado en Revista de Educação Física identifica la **temperatura elevada del agua** como uno de los factores de riesgo asociados a eventos fatales en natación de aguas abiertas, junto con arritmias y pánico — recomienda evitar tanto temperaturas muy bajas como muy altas.
> Fuente: DOAJ — "Deaths in Open Water Swimming, Why?", https://doaj.org/article/86de76d84f754c8d901df3c8c8f09744

**Para la app (dato no disponible desde el hardware, pero útil documentarlo):** si en el futuro se agrega un sensor de temperatura del agua (ej. upgrade a un reloj con esa función, o input manual del usuario), la app debería evaluar contra el rango 25°C-28°C como "óptimo/normal", y marcar como alerta cualquier valor fuera de 18°C-31°C aproximado, citando el respaldo de la literatura de seguridad en natación.

---

## 7. Ritmo/velocidad de nado — referencia general (⚠️ sin fuente clínica puntual, usar con cautela)

A diferencia de las secciones anteriores, **no encontré una fuente médica/deportiva oficial con tablas numéricas específicas de ritmo por nivel** (esto varía mucho según estilo de nado, edad, federación). Lo que se presenta aquí es una categorización general de uso común en la comunidad de natación, **no un estándar clínico verificado** — debe presentarse en la app como "referencia orientativa", no como límite médico:

| Nivel autodeclarado | Ritmo aproximado (estilo libre, 100m) | Nota |
|---|---|---|
| Principiante | Más de 2:30 min/100m | Sin fuente oficial — estimación de uso común |
| Intermedio | 1:45 - 2:30 min/100m | Sin fuente oficial — estimación de uso común |
| Avanzado | 1:15 - 1:45 min/100m | Sin fuente oficial — estimación de uso común |
| Competitivo | Menos de 1:15 min/100m | Sin fuente oficial — estimación de uso común |

**Recomendación para el curso:** si tu profesor exige fuente verificable para TODOS los límites de la app, esta tabla de ritmo debería quedar fuera del "motor de reglas validado" y presentarse solo como referencia visual sin alertas automáticas — a diferencia de FC, SpO2 y temperatura del agua, que sí tienen respaldo oficial citable.

---

## 8. Resumen de reglas a programar (motor de evaluación)

```
SI fc_actual > (220 - edad_usuario) * 0.90 durante > 60 segundos:
    mostrar_alerta("Zona de esfuerzo máximo sostenido")

SI spo2_reposo < 90:
    mostrar_alerta_urgente("SpO2 bajo — consulta médica recomendada")
SINO SI spo2_reposo >= 91 AND spo2_reposo <= 94:
    mostrar_aviso("SpO2 levemente bajo")
SINO:
    mostrar_normal("SpO2 dentro de rango normal")

SI temperatura_agua (si disponible) < 18 OR > 31:
    mostrar_alerta("Temperatura de agua fuera de rango seguro de referencia")
SINO SI temperatura_agua >= 25 AND <= 28:
    mostrar_normal("Temperatura óptima de competición")
```

Este motor de reglas es el equivalente al "motor de detección de columnas" que se documentó para la idea de inventario — mismo patrón: reglas testeables una por una con casos de entrada/salida esperados, ideal para pruebas unitarias en el curso de Calidad y Pruebas de Software.

---

## 9. Objetivos medibles sugeridos para el curso (si se usa esta app como proyecto)

1. Precisión de mapeo de datos desde Health Connect: 100% de los campos disponibles (tabla sección 2) correctamente parseados en 50 sincronizaciones de prueba.
2. Cobertura de pruebas unitarias del motor de reglas (sección 8) ≥85%, con casos de prueba en cada límite exacto (ej. FC = exactamente 90% de FC máx., SpO2 = exactamente 90%, 91%, 94%, 95%).
3. Manejo de datos ausentes: 100% de los campos no disponibles (SWOLF, estilo, temp. agua) deben mostrar el mensaje de "no disponible" sin causar error, verificado en 20 pruebas con datos incompletos simulados.
4. Tiempo de renderizado de los 5 gráficos de la sección 3 con un historial de 100 sesiones: <3 segundos.

---

## Nota final sobre honestidad de fuentes

Todas las secciones 4, 5 y 6 tienen respaldo verificable de fuentes deportivas/médicas reales, citadas con link. La sección 7 (ritmo de nado) está marcada explícitamente como sin fuente oficial — inclúyela en tu documento del curso con esa misma salvedad si tu profesor pide rigor en las fuentes.