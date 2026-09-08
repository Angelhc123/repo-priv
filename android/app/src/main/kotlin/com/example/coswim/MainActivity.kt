package com.example.coswim

import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.coswim/health_direct"
    private val PERMISSION_REQUEST_CODE = 47821

    // Permissions actually needed to show a workout (same scopes
    // health_service.dart asks for via the `health` package's _dataTypes).
    // "granted" for the app's purposes means these are all granted.
    private val essentialPermissions = setOf(
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
    )

    // Offered in the system dialog as a bonus, but NOT required for
    // "granted" — Speed is a nice-to-have (see getExerciseSessions' speed
    // block, which already tolerates it being denied). Gating the whole
    // "did permissions work" result on this too meant a user who left
    // Speed unchecked would never get their sessions refreshed at all,
    // even though everything that actually matters was granted fine.
    private val requestedPermissions = essentialPermissions +
        HealthPermission.getReadPermission(SpeedRecord::class)

    // FlutterActivity extends plain android.app.Activity (not ComponentActivity),
    // so the registerForActivityResult() API isn't available here. The contract
    // still works standalone via createIntent()/parseResult() + the classic
    // startActivityForResult()/onActivityResult() pair below.
    private val permissionContract = PermissionController.createRequestPermissionResultContract()
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getExerciseSessions" -> {
                        val startMs = call.argument<Long>("startMs") ?: 0L
                        val endMs = call.argument<Long>("endMs")
                            ?: System.currentTimeMillis()

                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val client =
                                    HealthConnectClient.getOrCreate(this@MainActivity)
                                val timeRange = TimeRangeFilter.between(
                                    Instant.ofEpochMilli(startMs),
                                    Instant.ofEpochMilli(endMs)
                                )

                                // --- Exercise sessions ---
                                val sessionsReq = ReadRecordsRequest(
                                    recordType = ExerciseSessionRecord::class,
                                    timeRangeFilter = timeRange
                                )
                                val sessionsResp = client.readRecords(sessionsReq)

                                val jsonArray = JSONArray()
                                for (rec in sessionsResp.records) {
                                    val obj = JSONObject()
                                    obj.put("id", rec.metadata.id)
                                    obj.put("startMs", rec.startTime.toEpochMilli())
                                    obj.put("endMs", rec.endTime.toEpochMilli())
                                    obj.put("exerciseType", rec.exerciseType)
                                    obj.put("title", rec.title ?: "")
                                    obj.put("notes", rec.notes ?: "")
                                    obj.put(
                                        "sourceApp",
                                        rec.metadata.dataOrigin.packageName
                                    )

                                    // Laps (vueltas en piscina)
                                    val lapsArr = JSONArray()
                                    for (lap in rec.laps) {
                                        val lapObj = JSONObject()
                                        lapObj.put(
                                            "startMs",
                                            lap.startTime.toEpochMilli()
                                        )
                                        lapObj.put(
                                            "endMs",
                                            lap.endTime.toEpochMilli()
                                        )
                                        lapObj.put(
                                            "lengthMeters",
                                            lap.length?.inMeters ?: 0.0
                                        )
                                        lapsArr.put(lapObj)
                                    }
                                    obj.put("laps", lapsArr)

                                    // Segments (estilo de nado por tramo)
                                    val segsArr = JSONArray()
                                    for (seg in rec.segments) {
                                        val segObj = JSONObject()
                                        segObj.put(
                                            "startMs",
                                            seg.startTime.toEpochMilli()
                                        )
                                        segObj.put(
                                            "endMs",
                                            seg.endTime.toEpochMilli()
                                        )
                                        segObj.put("segmentType", seg.segmentType)
                                        segObj.put("repetitions", seg.repetitions)
                                        segsArr.put(segObj)
                                    }
                                    obj.put("segments", segsArr)

                                    // HR within session window
                                    val hrRange = TimeRangeFilter.between(
                                        rec.startTime,
                                        rec.endTime
                                    )
                                    try {
                                        val hrResp = client.readRecords(
                                            ReadRecordsRequest(
                                                HeartRateRecord::class,
                                                hrRange
                                            )
                                        )
                                        val hrArr = JSONArray()
                                        for (hr in hrResp.records) {
                                            for (sample in hr.samples) {
                                                val hrObj = JSONObject()
                                                hrObj.put(
                                                    "timeMs",
                                                    sample.time.toEpochMilli()
                                                )
                                                hrObj.put("bpm", sample.beatsPerMinute)
                                                hrArr.put(hrObj)
                                            }
                                        }
                                        obj.put("heartRate", hrArr)
                                    } catch (_: Exception) {
                                        obj.put("heartRate", JSONArray())
                                    }

                                    // Distance within session window
                                    try {
                                        val distResp = client.readRecords(
                                            ReadRecordsRequest(
                                                DistanceRecord::class,
                                                hrRange
                                            )
                                        )
                                        var totalDist = 0.0
                                        val distArr = JSONArray()
                                        for (d in distResp.records) {
                                            totalDist += d.distance.inMeters
                                            val dObj = JSONObject()
                                            dObj.put(
                                                "startMs",
                                                d.startTime.toEpochMilli()
                                            )
                                            dObj.put(
                                                "endMs",
                                                d.endTime.toEpochMilli()
                                            )
                                            dObj.put(
                                                "meters",
                                                d.distance.inMeters
                                            )
                                            distArr.put(dObj)
                                        }
                                        obj.put("totalDistanceMeters", totalDist)
                                        obj.put("distanceSegments", distArr)
                                    } catch (_: Exception) {
                                        obj.put("totalDistanceMeters", 0.0)
                                        obj.put("distanceSegments", JSONArray())
                                    }

                                    // Calories within session window
                                    try {
                                        val calResp = client.readRecords(
                                            ReadRecordsRequest(
                                                ActiveCaloriesBurnedRecord::class,
                                                hrRange
                                            )
                                        )
                                        var totalCal = 0.0
                                        for (c in calResp.records) {
                                            totalCal += c.energy.inKilocalories
                                        }
                                        obj.put("totalCaloriesKcal", totalCal)
                                    } catch (_: Exception) {
                                        obj.put("totalCaloriesKcal", 0.0)
                                    }

                                    // Speed samples within session window — HC has no
                                    // record type for per-length swim splits (confirmed:
                                    // ExerciseLap/ExerciseSegment above are the only ones
                                    // that could carry it, and Mi Fitness leaves them
                                    // empty). Speed is a genuine time series though, so
                                    // it may show more granularity than the single
                                    // aggregated DistanceRecord above, if Mi Fitness
                                    // writes it at all.
                                    try {
                                        val speedResp = client.readRecords(
                                            ReadRecordsRequest(
                                                SpeedRecord::class,
                                                hrRange
                                            )
                                        )
                                        val speedArr = JSONArray()
                                        for (sp in speedResp.records) {
                                            for (sample in sp.samples) {
                                                val sampleObj = JSONObject()
                                                sampleObj.put(
                                                    "timeMs",
                                                    sample.time.toEpochMilli()
                                                )
                                                sampleObj.put(
                                                    "metersPerSecond",
                                                    sample.speed.inMetersPerSecond
                                                )
                                                speedArr.put(sampleObj)
                                            }
                                        }
                                        obj.put("speed", speedArr)
                                    } catch (_: Exception) {
                                        obj.put("speed", JSONArray())
                                    }

                                    jsonArray.put(obj)
                                }

                                withContext(Dispatchers.Main) {
                                    result.success(jsonArray.toString())
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "HC_ERROR",
                                        e.message,
                                        e.stackTraceToString()
                                    )
                                }
                            }
                        }
                    }

                    // Requests Health Connect read permissions directly via the
                    // platform SDK. Bypasses `health` package's requestAuthorization(),
                    // which throws "Unsupported operation: Google Health Connect is
                    // not available" on some devices even though HC works fine.
                    "requestHealthPermissions" -> {
                        if (pendingPermissionResult != null) {
                            // Already showing the system permission screen from an
                            // earlier call (e.g. the automatic request on screen open
                            // overlapping with a manual button tap) — launching a
                            // second one on top of it is what caused the "opens
                            // something weird, can't quite see it" glitch. Just make
                            // this call wait for the one already in flight instead.
                            result.error(
                                "HC_PERMISSION_BUSY",
                                "A permission request is already in progress",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                val client =
                                    HealthConnectClient.getOrCreate(this@MainActivity)
                                val granted =
                                    client.permissionController.getGrantedPermissions()
                                if (granted.containsAll(essentialPermissions)) {
                                    result.success(true)
                                } else {
                                    pendingPermissionResult = result
                                    val intent = permissionContract.createIntent(
                                        this@MainActivity,
                                        requestedPermissions
                                    )
                                    startActivityForResult(intent, PERMISSION_REQUEST_CODE)
                                }
                            } catch (e: Exception) {
                                pendingPermissionResult = null
                                result.error(
                                    "HC_PERMISSION_ERROR",
                                    e.message,
                                    e.stackTraceToString()
                                )
                            }
                        }
                    }

                    // Raw Health Connect records for the dashboard's "datos sueltos"
                    // dump — reads via the platform SDK directly, same as
                    // getExerciseSessions above, instead of going through the
                    // health Flutter package's configure()/getHealthDataFromTypes.
                    // That package path can throw "Health Connect not available"
                    // on this device even though HC works fine (same class of
                    // bug as requestAuthorization below), which was leaving the
                    // whole dashboard empty — not just the workouts section.
                    "getRawHealthPoints" -> {
                        val startMs = call.argument<Long>("startMs") ?: 0L
                        val endMs = call.argument<Long>("endMs")
                            ?: System.currentTimeMillis()

                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val client =
                                    HealthConnectClient.getOrCreate(this@MainActivity)
                                val timeRange = TimeRangeFilter.between(
                                    Instant.ofEpochMilli(startMs),
                                    Instant.ofEpochMilli(endMs)
                                )
                                val out = JSONArray()

                                fun addPoint(
                                    type: String,
                                    from: Instant,
                                    to: Instant,
                                    unit: String,
                                    numericValue: Double,
                                    sourceApp: String,
                                    recordId: String,
                                    recordingMethod: Int
                                ) {
                                    val o = JSONObject()
                                    o.put("type", type)
                                    o.put("dateFrom", from.toString())
                                    o.put("dateFromEpochMs", from.toEpochMilli())
                                    o.put("dateTo", to.toString())
                                    o.put("dateToEpochMs", to.toEpochMilli())
                                    o.put(
                                        "durationSeconds",
                                        to.epochSecond - from.epochSecond
                                    )
                                    o.put("unit", unit)
                                    o.put("sourceId", recordId)
                                    o.put("sourceName", sourceApp)
                                    o.put("sourcePlatform", "GOOGLE_HEALTH_CONNECT")
                                    o.put(
                                        "recordingMethod",
                                        recordingMethodName(recordingMethod)
                                    )
                                    val v = JSONObject()
                                    v.put("kind", "NumericHealthValue")
                                    v.put("numericValue", numericValue)
                                    o.put("value", v)
                                    out.put(o)
                                }

                                // Heart rate — one row per sample
                                try {
                                    val resp = client.readRecords(
                                        ReadRecordsRequest(HeartRateRecord::class, timeRange)
                                    )
                                    for (rec in resp.records) {
                                        for (s in rec.samples) {
                                            addPoint(
                                                "HEART_RATE", s.time, s.time,
                                                "BEATS_PER_MINUTE",
                                                s.beatsPerMinute.toDouble(),
                                                rec.metadata.dataOrigin.packageName,
                                                rec.metadata.id,
                                                rec.metadata.recordingMethod
                                            )
                                        }
                                    }
                                } catch (_: Exception) {
                                }

                                // Distance
                                try {
                                    val resp = client.readRecords(
                                        ReadRecordsRequest(DistanceRecord::class, timeRange)
                                    )
                                    for (rec in resp.records) {
                                        addPoint(
                                            "DISTANCE_DELTA", rec.startTime, rec.endTime,
                                            "METER", rec.distance.inMeters,
                                            rec.metadata.dataOrigin.packageName,
                                            rec.metadata.id,
                                            rec.metadata.recordingMethod
                                        )
                                    }
                                } catch (_: Exception) {
                                }

                                // Active calories
                                try {
                                    val resp = client.readRecords(
                                        ReadRecordsRequest(
                                            ActiveCaloriesBurnedRecord::class,
                                            timeRange
                                        )
                                    )
                                    for (rec in resp.records) {
                                        addPoint(
                                            "ACTIVE_ENERGY_BURNED", rec.startTime,
                                            rec.endTime, "KILOCALORIE",
                                            rec.energy.inKilocalories,
                                            rec.metadata.dataOrigin.packageName,
                                            rec.metadata.id,
                                            rec.metadata.recordingMethod
                                        )
                                    }
                                } catch (_: Exception) {
                                }

                                // Blood oxygen (SpO2) — instantaneous record
                                try {
                                    val resp = client.readRecords(
                                        ReadRecordsRequest(
                                            OxygenSaturationRecord::class,
                                            timeRange
                                        )
                                    )
                                    for (rec in resp.records) {
                                        addPoint(
                                            "BLOOD_OXYGEN", rec.time, rec.time,
                                            "PERCENT", rec.percentage.value,
                                            rec.metadata.dataOrigin.packageName,
                                            rec.metadata.id,
                                            rec.metadata.recordingMethod
                                        )
                                    }
                                } catch (_: Exception) {
                                }

                                // Speed — one row per sample
                                try {
                                    val resp = client.readRecords(
                                        ReadRecordsRequest(SpeedRecord::class, timeRange)
                                    )
                                    for (rec in resp.records) {
                                        for (s in rec.samples) {
                                            addPoint(
                                                "SPEED", s.time, s.time,
                                                "METERS_PER_SECOND",
                                                s.speed.inMetersPerSecond,
                                                rec.metadata.dataOrigin.packageName,
                                                rec.metadata.id,
                                                rec.metadata.recordingMethod
                                            )
                                        }
                                    }
                                } catch (_: Exception) {
                                }

                                // Exercise sessions — the REAL workouts, raw. No
                                // clustering, no synthesizing from loose samples:
                                // only what Health Connect actually has recorded
                                // as an ExerciseSessionRecord.
                                try {
                                    val resp = client.readRecords(
                                        ReadRecordsRequest(
                                            ExerciseSessionRecord::class,
                                            timeRange
                                        )
                                    )
                                    for (rec in resp.records) {
                                        val o = JSONObject()
                                        o.put("type", "WORKOUT")
                                        o.put("dateFrom", rec.startTime.toString())
                                        o.put(
                                            "dateFromEpochMs",
                                            rec.startTime.toEpochMilli()
                                        )
                                        o.put("dateTo", rec.endTime.toString())
                                        o.put(
                                            "dateToEpochMs",
                                            rec.endTime.toEpochMilli()
                                        )
                                        o.put(
                                            "durationSeconds",
                                            rec.endTime.epochSecond -
                                                rec.startTime.epochSecond
                                        )
                                        o.put("unit", "")
                                        o.put("sourceId", rec.metadata.id)
                                        o.put(
                                            "sourceName",
                                            rec.metadata.dataOrigin.packageName
                                        )
                                        o.put(
                                            "sourcePlatform",
                                            "GOOGLE_HEALTH_CONNECT"
                                        )
                                        o.put(
                                            "recordingMethod",
                                            recordingMethodName(
                                                rec.metadata.recordingMethod
                                            )
                                        )
                                        val v = JSONObject()
                                        v.put("kind", "WorkoutHealthValue")
                                        v.put(
                                            "workoutActivityType",
                                            exerciseTypeNameRaw(rec.exerciseType)
                                        )
                                        o.put("value", v)
                                        out.put(o)
                                    }
                                } catch (_: Exception) {
                                }

                                withContext(Dispatchers.Main) {
                                    result.success(out.toString())
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "HC_RAW_ERROR",
                                        e.message,
                                        e.stackTraceToString()
                                    )
                                }
                            }
                        }
                    }

                    "hasHealthPermissions" -> {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val client =
                                    HealthConnectClient.getOrCreate(this@MainActivity)
                                val granted =
                                    client.permissionController.getGrantedPermissions()
                                withContext(Dispatchers.Main) {
                                    result.success(granted.containsAll(essentialPermissions))
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "HC_STATUS_ERROR",
                                        e.message,
                                        e.stackTraceToString()
                                    )
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun recordingMethodName(v: Int): String = when (v) {
        1 -> "ACTIVELY_RECORDED"
        2 -> "AUTOMATICALLY_RECORDED"
        3 -> "MANUAL_ENTRY"
        else -> "UNKNOWN"
    }

    // Mirrors _exerciseTypeName in health_service.dart so raw dump entries
    // and parsed-session entries read the same activity name.
    private fun exerciseTypeNameRaw(type: Int): String {
        val names = mapOf(
            40 to "RUNNING", 41 to "RUNNING_TREADMILL",
            56 to "SWIMMING_OPEN_WATER", 57 to "SWIMMING_POOL",
            4 to "BIKING", 5 to "BIKING_STATIONARY",
            61 to "WALKING", 53 to "STRENGTH_TRAINING",
            65 to "YOGA", 21 to "HIIT", 11 to "ELLIPTICAL",
            1 to "BADMINTON", 3 to "BASKETBALL", 48 to "SOCCER",
            59 to "TENNIS", 60 to "VOLLEYBALL", 63 to "WEIGHTLIFTING",
            0 to "ENTRENAMIENTO"
        )
        return names[type] ?: "TIPO_$type"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val grantedNow = permissionContract.parseResult(resultCode, data)
            val pending = pendingPermissionResult
            pendingPermissionResult = null
            pending?.success(grantedNow.containsAll(essentialPermissions))
        }
    }
}
