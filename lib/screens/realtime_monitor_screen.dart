import 'dart:async';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../services/app_state.dart';
import '../utils/rules_engine.dart';

class RealtimeMonitorScreen extends StatefulWidget {
  final AppState appState;
  /// Solo para tests; por defecto se usa `Health()` del paquete health.
  final Health? health;

  const RealtimeMonitorScreen({super.key, required this.appState, this.health});

  @override
  State<RealtimeMonitorScreen> createState() => _RealtimeMonitorScreenState();
}

class _RealtimeMonitorScreenState extends State<RealtimeMonitorScreen> {
  Timer? _timer;
  bool _isMonitoring = false;
  bool _isFetching = false;
  String? _connectionError;
  DateTime? _latestHRTime;
  DateTime? _latestSpO2Time;
  
  // Real-time variables (default to 0/null representing empty/no data state)
  int _currentHR = 0;
  double? _currentSpO2;
  double _currentSpeed = 0.0;
  double _currentCalories = 0.0;
  double _currentDistance = 0.0;
  double? _currentWaterTemp;

  // Evaluation buffer for HR (last 60 seconds)
  final List<int> _hrEvaluationBuffer = [];

  late final Health _health = widget.health ?? Health();

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    setState(() {
      _isMonitoring = true;
      _isFetching = false;
      _connectionError = null;
      _latestHRTime = null;
      _latestSpO2Time = null;
      _currentHR = 0;
      _currentSpO2 = null;
      _currentSpeed = 0.0;
      _currentCalories = 0.0;
      _currentDistance = 0.0;
      _currentWaterTemp = null;
      _hrEvaluationBuffer.clear();
    });

    // Health Connect es una DB que Mi Fitness actualiza cuando sincroniza el reloj.
    // Sondear cada 30 s es suficiente — cada segundo es inútil si la app solo
    // escribe cada varios minutos.
    _fetchLatestData(); // primera lectura inmediata
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchLatestData();
    });
  }

  void _stopMonitoring() {
    _timer?.cancel();
    setState(() {
      _isMonitoring = false;
    });
  }

  Future<void> _fetchLatestData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      int hrVal = _currentHR;
      double? spo2Val = _currentSpO2;
      double speedVal = _currentSpeed;
      double calVal = _currentCalories;
      double distVal = _currentDistance;
      double? tempVal = _currentWaterTemp;

        try {
          final now = DateTime.now();
          final twelveHoursAgo = now.subtract(const Duration(hours: 12));
          final queryEndTime = now.add(const Duration(minutes: 15));
          
          await _health.configure();

          // Fetch datatypes individually to prevent combined query failures in Health Connect API
          List<HealthDataPoint> hrPoints = [];
          try {
            hrPoints = await _health.getHealthDataFromTypes(
              types: [HealthDataType.HEART_RATE],
              startTime: twelveHoursAgo,
              endTime: queryEndTime,
            );
          } catch (_) {}

          List<HealthDataPoint> spo2Points = [];
          try {
            spo2Points = await _health.getHealthDataFromTypes(
              types: [HealthDataType.BLOOD_OXYGEN],
              startTime: twelveHoursAgo,
              endTime: queryEndTime,
            );
          } catch (_) {}

          List<HealthDataPoint> calPoints = [];
          try {
            calPoints = await _health.getHealthDataFromTypes(
              types: [HealthDataType.ACTIVE_ENERGY_BURNED],
              startTime: twelveHoursAgo,
              endTime: queryEndTime,
            );
          } catch (_) {}

          List<HealthDataPoint> distPoints = [];
          try {
            distPoints = await _health.getHealthDataFromTypes(
              types: [HealthDataType.DISTANCE_DELTA],
              startTime: twelveHoursAgo,
              endTime: queryEndTime,
            );
          } catch (_) {}

          DateTime? latestHRT;
          int fetchedHR = 0;
          if (hrPoints.isNotEmpty) {
            hrPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));
            final val = hrPoints.first.value;
            if (val is NumericHealthValue) fetchedHR = val.numericValue.toInt();
            latestHRT = hrPoints.first.dateTo;
          }

          DateTime? latestSpO2T;
          double? fetchedSpO2;
          if (spo2Points.isNotEmpty) {
            spo2Points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
            final val = spo2Points.first.value;
            if (val is NumericHealthValue) fetchedSpO2 = val.numericValue.toDouble();
            latestSpO2T = spo2Points.first.dateTo;
          }

          double fetchedCalories = 0.0;
          if (calPoints.isNotEmpty) {
            double sum = 0.0;
            for (var p in calPoints) {
              final val = p.value;
              if (val is NumericHealthValue) sum += val.numericValue.toDouble();
            }
            fetchedCalories = sum;
          }

          double fetchedDistance = 0.0;
          if (distPoints.isNotEmpty) {
            double sum = 0.0;
            for (var p in distPoints) {
              final val = p.value;
              if (val is NumericHealthValue) sum += val.numericValue.toDouble();
            }
            fetchedDistance = sum;
          }
          
          hrVal = fetchedHR;
          spo2Val = fetchedSpO2;
          speedVal = 0.0;
          calVal = fetchedCalories;
          distVal = fetchedDistance;
          tempVal = null;
          _connectionError = null;
          _latestHRTime = latestHRT;
          _latestSpO2Time = latestSpO2T;
        } catch (e) {
          final errorStr = e.toString();
          if (errorStr.contains("Health Connect is not available") || 
              errorStr.contains("Unsupported operation") || 
              errorStr.contains("SdkStatus") || 
              errorStr.contains("not available")) {
            _connectionError = "Health Connect no está instalado o no es compatible con este dispositivo. Instala la app Google Health Connect para ver datos en tiempo real.";
          } else {
            _connectionError = "Error de conexión: $e";
          }
          hrVal = 0;
          spo2Val = null;
          speedVal = 0.0;
          calVal = 0.0;
          distVal = 0.0;
          tempVal = null;
          _latestHRTime = null;
          _latestSpO2Time = null;
        }

      if (mounted) {
        setState(() {
          _currentHR = hrVal;
          _currentSpO2 = spo2Val;
          _currentSpeed = speedVal;
          _currentCalories = calVal;
          _currentDistance = distVal;
          _currentWaterTemp = tempVal;

          if (_currentHR > 0) {
            _hrEvaluationBuffer.add(_currentHR);
            if (_hrEvaluationBuffer.length > 60) {
              _hrEvaluationBuffer.removeAt(0);
            }
          }
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.appState.profile;
    
    // Evaluate metrics
    final hrZone = RulesEngine.getHeartRateZone(_currentHR, profile.age);
    final hrColor = RulesEngine.getZoneColor(hrZone);
    final hrName = RulesEngine.getZoneName(hrZone);
    final hrDesc = RulesEngine.getZoneDescription(hrZone);
    final hasHRAlert = RulesEngine.checkMaxHeartRateAlert(_hrEvaluationBuffer, profile.age);
    
    final spo2Eval = RulesEngine.evaluateSpO2(_currentSpO2);
    final tempEval = RulesEngine.evaluateWaterTemperature(_currentWaterTemp);

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: const Text(
          "Monitor Live",
          style: TextStyle(
            color: Color(0xFF64FFDA),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active controller status card
            _buildControlPanelCard(),
            const SizedBox(height: 16),

            if (_isMonitoring && _connectionError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  border: Border.all(color: Colors.amber, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Advertencia de Conexión:\n$_connectionError",
                        style: const TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (!_isMonitoring)
              _buildStoppedState()
            else ...[
              // Aviso sobre modelo de sincronización de Health Connect
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  border: Border.all(color: Colors.blue.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Health Connect NO es un stream en vivo. Muestra los últimos datos que Mi Fitness escribió en la base de datos al sincronizar con el reloj. Si el reloj sincronizó hace 2 horas, los datos tienen 2 horas de antigüedad.\n\nPara datos más frescos: abre Mi Fitness y fuerza una sincronización manual con el reloj.",
                        style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // HR Card
              _buildHeartRateCard(hrName, hrColor, hrDesc, hasHRAlert, profile.age),
              const SizedBox(height: 14),

              // SpO2 Card
              _buildSpO2Card(spo2Eval),
              const SizedBox(height: 14),

              // Water Temp Card
              _buildWaterTempCard(tempEval),
              const SizedBox(height: 14),

              // Speed / Pace Card
              _buildSpeedCard(profile.level),
              const SizedBox(height: 14),

              // Calories Card
              _buildCaloriesCard(),
              const SizedBox(height: 14),

              // Distance Card
              _buildDistanceCard(),
              const SizedBox(height: 20),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanelCard() {
    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isMonitoring ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMonitoring ? "ESTADO: ACTIVO" : "ESTADO: DETENIDO",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Text(
                      "Muestreo en tiempo real (1s)",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    )
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _toggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? Colors.redAccent : const Color(0xFF64FFDA),
                foregroundColor: const Color(0xFF0A192F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _isMonitoring ? "Detener" : "Iniciar",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStoppedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.sensors_off, size: 70, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            "Esperando Inicio...",
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Haz clic en 'Iniciar' arriba para iniciar la simulación o lectura de Health Connect en tiempo real cada 1 segundo.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- Heart Rate Card ---
  Widget _buildHeartRateCard(String zoneName, Color zoneColor, String zoneDesc, bool alertActive, int age) {
    final maxHR = RulesEngine.getMaxHeartRate(age);
    final secondsAbove90 = _hrEvaluationBuffer.where((val) => val > (maxHR * 0.90)).length;
    final hrZone = RulesEngine.getHeartRateZone(_currentHR, age);
    final isHRDataAvailable = _currentHR > 0;

    String syncTimeMessage = "";
    if (isHRDataAvailable && _latestHRTime != null) {
      final diff = DateTime.now().difference(_latestHRTime!);
      if (diff.inSeconds < 60) {
        syncTimeMessage = "Sincronizado: En Vivo";
      } else if (diff.inMinutes < 60) {
        syncTimeMessage = "Sincronizado hace ${diff.inMinutes} min";
      } else {
        syncTimeMessage = "Sincronizado hace ${diff.inHours} horas";
      }
    }

    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Frecuencia Cardíaca (BPM)",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHRDataAvailable ? zoneColor.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isHRDataAvailable ? zoneColor : Colors.grey, width: 1),
                  ),
                  child: Text(
                    isHRDataAvailable ? "Zona $hrZone" : "Sin Datos",
                    style: TextStyle(color: isHRDataAvailable ? zoneColor : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PulsingHeart(color: isHRDataAvailable ? zoneColor : Colors.grey, isPulseActive: isHRDataAvailable),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isHRDataAvailable ? "$_currentHR" : "--",
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Text("BPM", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    Text(
                      isHRDataAvailable ? zoneName : "Sin lecturas recientes",
                      style: TextStyle(color: isHRDataAvailable ? zoneColor : Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (syncTimeMessage.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        syncTimeMessage,
                        style: const TextStyle(color: Color(0xFF64FFDA), fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isHRDataAvailable ? zoneDesc : "El monitor está encendido, pero no se reciben pulsaciones de Health Connect.",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              "Máximo teórico: $maxHR BPM (90% = ${(maxHR * 0.9).round()} BPM)",
              style: const TextStyle(color: Colors.white30, fontSize: 10),
            ),

            if (isHRDataAvailable && alertActive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "¡ALERTA DE ESFUERZO MÁXIMO SOSTENIDO!\nHas superado el 90% de tu FC máxima por más de 60 segundos.",
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            ] else if (isHRDataAvailable && _currentHR > (maxHR * 0.90)) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: secondsAbove90 / 60,
                color: Colors.orange,
                backgroundColor: Colors.white10,
              ),
              const SizedBox(height: 4),
              Text(
                "Superando 90% de FC Máx: $secondsAbove90 / 60s acumulando para alarma.",
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
              )
            ]
          ],
        ),
      ),
    );
  }

  // --- SpO2 Card ---
  Widget _buildSpO2Card(EvaluationResult eval) {
    String spo2SyncMessage = "";
    if (_currentSpO2 != null && _latestSpO2Time != null) {
      final diff = DateTime.now().difference(_latestSpO2Time!);
      if (diff.inSeconds < 60) {
        spo2SyncMessage = "Sincronizado: En Vivo";
      } else if (diff.inMinutes < 60) {
        spo2SyncMessage = "Sincronizado hace ${diff.inMinutes} min";
      } else {
        spo2SyncMessage = "Sincronizado hace ${diff.inHours} horas";
      }
    }

    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bloodtype, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Saturación de Oxígeno (SpO2)",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: eval.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: eval.color, width: 1),
                  ),
                  child: Text(
                    eval.title,
                    style: TextStyle(color: eval.color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _currentSpO2 != null ? _currentSpO2!.toStringAsFixed(1) : "N/A",
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const Text("%", style: TextStyle(color: Colors.white38, fontSize: 14)),
              ],
            ),
            if (spo2SyncMessage.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                spo2SyncMessage,
                style: const TextStyle(color: Color(0xFF64FFDA), fontSize: 10, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(
              eval.description,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white38, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Medición en reposo, no representa el nivel de oxigenación durante el nado.",
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Water Temp Card ---
  Widget _buildWaterTempCard(EvaluationResult eval) {
    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.thermostat, color: Colors.lightBlueAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Temperatura del Agua",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: eval.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: eval.color, width: 1),
                  ),
                  child: Text(
                    _currentWaterTemp != null ? "${_currentWaterTemp!.toStringAsFixed(1)}°C" : "N/A",
                    style: TextStyle(color: eval.color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              eval.description,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (_currentWaterTemp == null) ...[
              const SizedBox(height: 8),
              const Text(
                "Dato no disponible desde tu dispositivo (limitación del Redmi Watch 4 en Health Connect).",
                style: TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- Speed Card ---
  Widget _buildSpeedCard(String userLevel) {
    // Convert m/min to a readable pace min/100m
    String formattedPace = "--:--";
    if (_currentSpeed > 0) {
      final double secondsPer100m = 6000 / _currentSpeed;
      final int min = (secondsPer100m / 60).floor();
      final int sec = (secondsPer100m % 60).round();
      formattedPace = "$min:${sec.toString().padLeft(2, '0')} min/100m";
    }

    // Reference speed in m/min
    double refSpeed = 40.0;
    switch (userLevel.toLowerCase()) {
      case 'beginner':
        refSpeed = 40.0;
        break;
      case 'intermediate':
        refSpeed = 48.0;
        break;
      case 'advanced':
        refSpeed = 68.0;
        break;
      case 'competitive':
        refSpeed = 85.0;
        break;
    }

    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, color: Color(0xFF64FFDA), size: 20),
                SizedBox(width: 8),
                Text(
                  "Velocidad y Ritmo",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_currentSpeed.toStringAsFixed(1)} m/min",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text("Velocidad lineal", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedPace,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text("Ritmo equivalente", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Referencia para tu nivel: $refSpeed m/min.",
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // --- Calories Card ---
  Widget _buildCaloriesCard() {
    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  "Calorías Consumidas",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${_currentCalories.toStringAsFixed(1)} kcal",
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Total acumulado en el entrenamiento activo.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // --- Distance Card ---
  Widget _buildDistanceCard() {
    return Card(
      color: const Color(0xFF0D253F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pool, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  "Distancia Recorrida",
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${_currentDistance.toStringAsFixed(1)} metros",
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Lectura acumulada de metros nadados.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingHeart extends StatefulWidget {
  final Color color;
  final bool isPulseActive;

  const _PulsingHeart({required this.color, this.isPulseActive = true});

  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    if (widget.isPulseActive) {
      _controller.repeat(reverse: true);
    }
    _animation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_PulsingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulseActive != oldWidget.isPulseActive) {
      if (widget.isPulseActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPulseActive) {
      return ScaleTransition(
        scale: _animation,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.favorite, color: widget.color, size: 28),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.favorite_border, color: widget.color, size: 28),
    );
  }
}
