import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../models/swim_session.dart';

class DashboardScreen extends StatefulWidget {
  final AppState appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isFetchingRaw = false;
  List<Map<String, dynamic>> _rawPoints = [];
  int _selectedDays = 30;
  // Keys like "<sessionId>:HR", "<sessionId>:DISTANCE" — which per-session
  // lists are showing everything instead of just the first 100 lines.
  final Set<String> _expandedLists = {};
  // The flat "todos los registros sueltos" dump below the sessions is heavy
  // to build (full JSON per point, potentially thousands of them over a
  // month) — collapsed by default so opening the screen never has to pay
  // for it, and it's rebuilt from scratch each time it's expanded.
  bool _showRawDump = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Request Health Connect permissions after the first frame so the Android
    // Activity is fully active (requestAuthorization crashes if called before
    // runApp finishes building the Activity).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.appState.requestPermissions();
      // Refresh regardless of the exact grant outcome — refreshData()
      // already shows the "sin permisos" card on its own if something
      // essential is actually missing. Gating this on `granted` meant any
      // one non-essential permission left unchecked (or a request that
      // errored, e.g. one already in flight) hid every session that WAS
      // readable, which is worse than just trying and showing what we get.
      if (mounted) {
        await _refreshAll();
      }
    });
  }

  Future<void> _loadAll() async {
    setState(() => _isFetchingRaw = true);
    // AppState.init() ya hizo refreshData() al arrancar.
    // Aquí solo pedimos los datos crudos directamente para no poner
    // appState.isLoading = true (que congela la UI en MainNavigation).
    final points = await widget.appState
        .fetchRawJsonData(days: Duration(days: _selectedDays));
    if (mounted) {
      setState(() {
        _rawPoints = points;
        _isFetchingRaw = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _isFetchingRaw = true);
    await widget.appState.refreshData();
    final points = await widget.appState
        .fetchRawJsonData(days: Duration(days: _selectedDays));
    if (mounted) {
      setState(() {
        _rawPoints = points;
        _isFetchingRaw = false;
      });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(label),
      backgroundColor: const Color(0xFF64FFDA),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // Group raw points by type
  Map<String, List<Map<String, dynamic>>> get _byType {
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (final p in _rawPoints) {
      final type = p['type'] as String? ?? 'DESCONOCIDO';
      result.putIfAbsent(type, () => []).add(p);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final sessions = widget.appState.sessions;
    final byType = _byType;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: const Text(
          "Datos de Health Connect",
          style: TextStyle(
              color: Color(0xFF64FFDA),
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        actions: [
          DropdownButton<int>(
            value: _selectedDays,
            dropdownColor: const Color(0xFF0D253F),
            underline: Container(),
            style: const TextStyle(
                color: Color(0xFF64FFDA),
                fontSize: 12,
                fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(value: 1, child: Text("24h")),
              DropdownMenuItem(value: 7, child: Text("7 días")),
              DropdownMenuItem(value: 30, child: Text("30 días")),
              DropdownMenuItem(value: 365, child: Text("1 año")),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedDays = v);
                _refreshAll();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64FFDA)),
            tooltip: "Refrescar datos de Health Connect",
            onPressed: _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all, color: Colors.white54),
            tooltip: "Copiar todo el JSON crudo",
            onPressed: _rawPoints.isEmpty
                ? null
                : () => _copy(encoder.convert(_rawPoints),
                    "¡Todo el JSON copiado (${_rawPoints.length} objetos)!"),
          ),
        ],
      ),
      body: _isFetchingRaw
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF64FFDA)),
                  SizedBox(height: 14),
                  Text(
                    "Consultando Health Connect...",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF64FFDA),
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Error banner
                  if (widget.appState.errorMessage != null) ...[
                    _errorBanner(widget.appState.errorMessage!),
                    const SizedBox(height: 12),
                  ],

                  // ── RESUMEN ──────────────────────────────────────────────
                  _sectionHeader(
                      "RESUMEN DE DATOS", Icons.analytics, Colors.white),
                  const SizedBox(height: 8),
                  _summaryCard(sessions, byType, encoder),
                  const SizedBox(height: 20),

                  // ── ENTRENAMIENTOS DETECTADOS ────────────────────────────
                  _sectionHeader(
                      "ENTRENAMIENTOS DETECTADOS (${sessions.length})",
                      Icons.fitness_center,
                      const Color(0xFF64FFDA)),
                  const SizedBox(height: 8),
                  if (sessions.isEmpty)
                    _noWorkoutsCard()
                  else
                    ...sessions.asMap().entries.map((e) =>
                        _sessionCard(e.value, e.key + 1, encoder, _rawPoints)),
                  const SizedBox(height: 20),

                  // ── DATOS SUELTOS (fuera de cualquier entrenamiento) ─────
                  _sectionHeader(
                      "DATOS SUELTOS DE HEALTH CONNECT (${_rawPoints.length} registros)",
                      Icons.data_object,
                      Colors.white70),
                  const SizedBox(height: 4),
                  const Text(
                    "Son TODOS los registros individuales de Health Connect en el rango "
                    "elegido arriba — no son entrenamientos. Incluye las mismas lecturas "
                    "que ya se muestran dentro de cada entrenamiento más lo que quedó "
                    "fuera (por eso pesa: puede haber miles). Se arma solo si lo abrís.",
                    style: TextStyle(
                        color: Colors.white38, fontSize: 10, height: 1.4),
                  ),
                  const SizedBox(height: 8),

                  if (_rawPoints.isEmpty)
                    _emptyCard(
                        "Health Connect no devolvió ningún dato.\n\nAsegúrate de que:\n1. Mi Fitness tiene permisos en Health Connect\n2. Ya hiciste al menos un entrenamiento registrado",
                        Icons.cloud_off,
                        Colors.white38)
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showRawDump = !_showRawDump),
                      icon: Icon(
                          _showRawDump
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.white70,
                          size: 16),
                      label: Text(
                          _showRawDump
                              ? "Ocultar registros sueltos"
                              : "Mostrar los ${_rawPoints.length} registros sueltos",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (_showRawDump) ...[
                      const SizedBox(height: 8),
                      ...byType.entries.map((entry) =>
                          _typeSection(entry.key, entry.value, encoder)),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  // ── WIDGETS DE SECCIÓN ───────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.amber, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _emptyCard(String msg, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  Widget _summaryCard(List<SwimSession> sessions,
      Map<String, List<Map<String, dynamic>>> byType, JsonEncoder encoder) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF64FFDA).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statBadge("ENTRENAMIENTOS", "${sessions.length}",
                  const Color(0xFF64FFDA)),
              const SizedBox(width: 8),
              _statBadge("TOTAL REGISTROS", "${_rawPoints.length}", Colors.white70),
            ],
          ),
          const SizedBox(height: 10),
          if (byType.isNotEmpty) ...[
            const Text("Registros por tipo:",
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: byType.entries.map((e) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor(e.key).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _typeColor(e.key)),
                  ),
                  child: Text(
                    "${e.key}: ${e.value.length}",
                    style: TextStyle(
                        color: _typeColor(e.key),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ],
          if (_rawPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  _copy(encoder.convert(_rawPoints), "¡JSON completo copiado!"),
              icon: const Icon(Icons.copy_all, size: 14, color: Color(0xFF64FFDA)),
              label: const Text("Copiar todo el JSON crudo",
                  style:
                      TextStyle(color: Color(0xFF64FFDA), fontSize: 11)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF64FFDA)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── TARJETA DE ENTRENAMIENTO ─────────────────────────────────────────────

  Widget _sessionCard(SwimSession s, int idx, JsonEncoder encoder,
      List<Map<String, dynamic>> allRawPoints) {
    final jsonStr = encoder.convert(s.toJson());
    final durationSec = s.duration.inSeconds;
    final durationMin = s.duration.inMinutes;

    // All raw points that fall within this session's time window
    final sessionPoints = allRawPoints.where((p) {
      final from = DateTime.tryParse(p['dateFrom'] as String? ?? '');
      if (from == null) return false;
      return !from.isBefore(s.startTime.subtract(const Duration(seconds: 5))) &&
          !from.isAfter(s.endTime.add(const Duration(seconds: 5)));
    }).toList();

    final distancePoints = sessionPoints
        .where((p) => p['type'] == 'DISTANCE_DELTA')
        .toList()
      ..sort((a, b) => (a['dateFrom'] as String).compareTo(b['dateFrom'] as String));

    final spo2Points = sessionPoints
        .where((p) => p['type'] == 'BLOOD_OXYGEN')
        .toList()
      ..sort((a, b) => (a['dateFrom'] as String).compareTo(b['dateFrom'] as String));

    final calPoints = sessionPoints
        .where((p) => p['type'] == 'ACTIVE_ENERGY_BURNED')
        .toList()
      ..sort((a, b) => (a['dateFrom'] as String).compareTo(b['dateFrom'] as String));

    final hrPoints = s.heartRateSeries;
    final speedPoints = s.speedSeries;

    return Card(
      color: const Color(0xFF0D253F),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF64FFDA), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64FFDA).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF64FFDA)),
                  ),
                  child: Text(
                    "#$idx  ${s.activityType ?? 'ENTRENAMIENTO'}",
                    style: const TextStyle(
                        color: Color(0xFF64FFDA),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      color: Color(0xFF64FFDA), size: 16),
                  onPressed: () => _copy(jsonStr, "¡JSON de sesión #$idx copiado!"),
                  tooltip: "Copiar JSON completo",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Tiempos ──
            _monoRow("INICIO  ", s.startTime.toIso8601String()),
            _monoRow("FIN     ", s.endTime.toIso8601String()),
            _monoRow("DURACIÓN",
                "$durationSec seg  ($durationMin min ${durationSec % 60} seg)"),

            const Divider(color: Colors.white10, height: 18),

            // ── Métricas resumen ──
            Row(
              children: [
                Expanded(child: _metricBox("Distancia Total",
                    "${s.distance.toStringAsFixed(2)} m")),
                Expanded(child: _metricBox("Calorías",
                    "${s.calories.toStringAsFixed(2)} kcal")),
                Expanded(child: _metricBox("Ritmo", s.paceString)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _metricBox("FC Promedio",
                    s.averageHeartRate != null
                        ? "${s.averageHeartRate!.toStringAsFixed(1)} BPM"
                        : "N/A")),
                Expanded(child: _metricBox("FC Máxima",
                    s.maxHeartRate != null
                        ? "${s.maxHeartRate!.toStringAsFixed(1)} BPM"
                        : "N/A")),
                Expanded(child: _metricBox("SpO2",
                    s.spo2 != null
                        ? "${s.spo2!.toStringAsFixed(1)}%"
                        : "N/A")),
              ],
            ),

            // ── Tramos de distancia (DISTANCE_DELTA dentro del workout) ──
            if (distancePoints.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 18),
              _expandableMonoSection(
                listKey: '${s.id}:DISTANCE',
                label: 'TRAMOS / VUELTAS — DISTANCE_DELTA',
                color: Colors.cyanAccent,
                lines: distancePoints.asMap().entries.map((e) {
                  final p = e.value;
                  final from = p['dateFrom'] as String? ?? '';
                  final to = p['dateTo'] as String? ?? '';
                  final val = (p['value'] as Map?)?['numericValue'];
                  final unit = p['unit'] as String? ?? 'm';
                  final src = p['sourceName'] as String? ?? '';
                  return "Tramo ${e.key + 1}: ${val != null ? '$val $unit' : '(sin valor)'}"
                      "  Desde: $from  Hasta: $to  Fuente: $src";
                }).toList(),
              ),
            ] else ...[
              const Divider(color: Colors.white10, height: 18),
              const Text(
                "TRAMOS / VUELTAS: 0 registros DISTANCE_DELTA en este rango.\n"
                "Mi Fitness escribió un solo total para todo el entrenamiento,\n"
                "no tramo a tramo. El detalle por largo (ExerciseLap) y por estilo\n"
                "(ExerciseSegment) SÍ existe como campo estándar de Health Connect\n"
                "y esta app ya lo lee, pero llega vacío — Mi Fitness no lo está\n"
                "escribiendo para esta sesión. No hay ningún otro tipo de dato de\n"
                "Health Connect que guarde ese detalle por largo.",
                style: TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    height: 1.4),
              ),
            ],

            // ── SpO2 dentro del workout ──
            if (spo2Points.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 18),
              _expandableMonoSection(
                listKey: '${s.id}:SPO2',
                label: 'SpO2 DURANTE ENTRENAMIENTO',
                color: Colors.blueAccent,
                lines: spo2Points.asMap().entries.map((e) {
                  final p = e.value;
                  final from = p['dateFrom'] as String? ?? '';
                  final val = (p['value'] as Map?)?['numericValue'];
                  return "${e.key + 1}. $from  →  ${val != null ? '$val %' : '(sin valor)'}";
                }).toList(),
              ),
            ],

            // ── Calorías por tramo ──
            if (calPoints.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 18),
              _expandableMonoSection(
                listKey: '${s.id}:CAL',
                label: 'CALORÍAS POR TRAMO',
                color: Colors.amberAccent,
                lines: calPoints.asMap().entries.map((e) {
                  final p = e.value;
                  final from = p['dateFrom'] as String? ?? '';
                  final to = p['dateTo'] as String? ?? '';
                  final val = (p['value'] as Map?)?['numericValue'];
                  return "${e.key + 1}. $val kcal  ($from → $to)";
                }).toList(),
              ),
            ],

            // ── Velocidad (SpeedRecord — puede tener más resolución que el
            // total agregado de distancia, si Mi Fitness la escribe) ──
            if (speedPoints.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 18),
              _expandableMonoSection(
                listKey: '${s.id}:SPEED',
                label: 'VELOCIDAD — SpeedRecord',
                color: Colors.lightGreenAccent,
                lines: speedPoints
                    .asMap()
                    .entries
                    .map((e) =>
                        "${e.key + 1}. ${e.value.time.toIso8601String()}  →  ${e.value.metersPerSecond.toStringAsFixed(3)} m/s")
                    .toList(),
              ),
            ],

            // ── FC serie completa ──
            if (hrPoints.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 18),
              _expandableMonoSection(
                listKey: '${s.id}:HR',
                label: 'FC',
                color: Colors.redAccent,
                lines: hrPoints
                    .asMap()
                    .entries
                    .map((e) =>
                        "${e.key + 1}. ${e.value.time.toIso8601String()}  →  ${e.value.bpm} BPM")
                    .toList(),
              ),
            ],

            // ── JSON completo ──
            const Divider(color: Colors.white10, height: 18),
            const Text("JSON COMPLETO DEL OBJETO SESIÓN:",
                style: TextStyle(
                    color: Colors.white30,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF06101E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                jsonStr,
                style: const TextStyle(
                    color: Color(0xFF64FFDA),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }

  static const int _collapsedPreviewCount = 100;

  /// A titled monospace block that shows every line, collapsing to the first
  /// 100 with a "ver todos" toggle only when there are more than that.
  /// Used for every raw sub-list inside a session card (FC, distancia,
  /// SpO2, calorías) so none of them get silently truncated.
  Widget _expandableMonoSection({
    required String listKey,
    required String label,
    required Color color,
    required List<String> lines,
  }) {
    final expanded = _expandedLists.contains(listKey);
    final showAll = expanded || lines.length <= _collapsedPreviewCount;
    final display = showAll ? lines : lines.take(_collapsedPreviewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _subSectionHeader("$label (${lines.length})", color),
            if (lines.length > _collapsedPreviewCount)
              TextButton.icon(
                onPressed: () => setState(() {
                  if (expanded) {
                    _expandedLists.remove(listKey);
                  } else {
                    _expandedLists.add(listKey);
                  }
                }),
                icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: color),
                label: Text(
                    expanded ? "▲ Colapsar" : "▼ Ver todos (${lines.length})",
                    style: TextStyle(color: color, fontSize: 11)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF06101E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            display.join("\n"),
            style: TextStyle(
                color: color, fontSize: 10, fontFamily: 'monospace', height: 1.4),
          ),
        ),
        if (!showAll) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expandedLists.add(listKey)),
              icon: Icon(Icons.expand_more, size: 16, color: color),
              label: Text(
                  "▼ Ver ${lines.length - _collapsedPreviewCount} más",
                  style: TextStyle(color: color, fontSize: 11)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),
        ],
      ],
    );
  }

  // ── SIN WORKOUTS ────────────────────────────────────────────────────────

  Widget _noWorkoutsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "No se encontraron registros WORKOUT",
                  style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "coswim no tiene permiso para leer 'Actividad/Ejercicio' en Health Connect.\n\n"
            "Pasos para arreglarlo:\n"
            "  1. Abre la app Google Health Connect\n"
            "  2. Ve a: Aplicaciones → coswim\n"
            "  3. Activa 'Actividad' o 'Ejercicio' en LECTURA\n"
            "  4. Regresa aquí y pulsa el botón de abajo",
            style: TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final granted =
                        await widget.appState.requestPermissions();
                    if (granted && mounted) await _refreshAll();
                  },
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text("Solicitar permisos ahora",
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64FFDA),
                    foregroundColor: const Color(0xFF0A192F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _refreshAll,
                  icon: const Icon(Icons.refresh,
                      size: 16, color: Colors.white70),
                  label: const Text("Ya lo hice, refrescar",
                      style:
                          TextStyle(fontSize: 12, color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN POR TIPO DE DATO ─────────────────────────────────────────────

  Widget _typeSection(String type, List<Map<String, dynamic>> points,
      JsonEncoder encoder) {
    final color = _typeColor(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  "$type  (${points.length} registros)",
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.copy_all, color: color, size: 16),
              tooltip: "Copiar todos los registros de $type",
              onPressed: () => _copy(
                  encoder.convert(points),
                  "¡${points.length} registros de $type copiados!"),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...points.asMap().entries.map(
              (e) => _rawPointCard(e.value, e.key + 1, type, color, encoder),
            ),
      ],
    );
  }

  Widget _rawPointCard(Map<String, dynamic> item, int idx, String type,
      Color color, JsonEncoder encoder) {
    final dateFrom = item['dateFrom'] as String? ?? '';
    final dateTo = item['dateTo'] as String? ?? '';
    final durationSec = item['durationSeconds'] as int? ?? 0;
    final sourceName = item['sourceName'] as String? ?? '';
    final sourceId = item['sourceId'] as String? ?? '';
    final unit = item['unit'] as String? ?? '';
    final recordingMethod = item['recordingMethod'] as String? ?? '';
    final platform = item['sourcePlatform'] as String? ?? '';
    final value = item['value'] as Map<String, dynamic>? ?? {};
    final jsonStr = encoder.convert(item);

    // Build a human-readable value string
    String valueStr = '';
    if (value['kind'] == 'NumericHealthValue') {
      final num = value['numericValue'];
      valueStr = "$num ${unit.isNotEmpty ? unit : ''}";
    } else if (value['kind'] == 'WorkoutHealthValue') {
      final activity = value['workoutActivityType'] ?? '';
      final dist = value['totalDistance'];
      final cal = value['totalEnergyBurned'];
      valueStr = "Actividad: $activity"
          "${dist != null ? ' | Distancia: $dist ${value['totalDistanceUnit'] ?? 'm'}' : ''}"
          "${cal != null ? ' | Energía: $cal ${value['totalEnergyBurnedUnit'] ?? 'kcal'}' : ''}";
    } else {
      valueStr = value['rawString'] ?? value.toString();
    }

    return Card(
      color: const Color(0xFF0D253F),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index + value highlight
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "#$idx",
                  style: TextStyle(
                      color: color.withOpacity(0.6),
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      valueStr,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: color.withOpacity(0.6), size: 14),
                  onPressed: () => _copy(jsonStr, "¡JSON de $type #$idx copiado!"),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Copiar este registro",
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Timestamps
            _monoRow("DESDE     ", dateFrom),
            _monoRow("HASTA     ", dateTo),
            _monoRow("DURACIÓN  ", "${durationSec}s"),

            const SizedBox(height: 6),

            // Source info
            _monoRow("FUENTE    ", sourceName.isNotEmpty ? sourceName : "(vacío)"),
            _monoRow("SOURCE ID ", sourceId.isNotEmpty ? sourceId : "(vacío)"),
            _monoRow("PLATAFORMA", platform),
            _monoRow("MÉTODO    ", recordingMethod),
            _monoRow("UNIDAD    ", unit.isNotEmpty ? unit : "(sin unidad)"),

            const SizedBox(height: 8),

            // Full JSON always visible
            const Text("JSON COMPLETO:",
                style: TextStyle(
                    color: Colors.white30,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06101E),
                borderRadius: BorderRadius.circular(5),
              ),
              child: SelectableText(
                jsonStr,
                style: const TextStyle(
                    color: Color(0xFF64FFDA),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label  ",
              style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value) {
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF172A45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'WORKOUT':
        return Colors.orangeAccent;
      case 'HEART_RATE':
        return Colors.redAccent;
      case 'DISTANCE_DELTA':
        return Colors.cyanAccent;
      case 'BLOOD_OXYGEN':
        return Colors.blueAccent;
      case 'ACTIVE_ENERGY_BURNED':
        return Colors.amberAccent;
      default:
        return Colors.white54;
    }
  }
}
