import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';

class RawJsonScreen extends StatefulWidget {
  final AppState appState;

  const RawJsonScreen({super.key, required this.appState});

  @override
  State<RawJsonScreen> createState() => _RawJsonScreenState();
}

class _RawJsonScreenState extends State<RawJsonScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _rawPoints = [];
  String _selectedFilter = 'ALL';
  int _selectedDays = 30;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRawData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRawData() async {
    setState(() {
      _isLoading = true;
    });

    final data = await widget.appState.fetchRawJsonData(days: Duration(days: _selectedDays));

    if (mounted) {
      setState(() {
        _rawPoints = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPoints {
    return _rawPoints.where((item) {
      final type = item['type'] as String? ?? '';
      
      // Type filter
      if (_selectedFilter != 'ALL') {
        if (_selectedFilter == 'WORKOUT' && type != 'WORKOUT') return false;
        if (_selectedFilter == 'HEART_RATE' && type != 'HEART_RATE') return false;
        if (_selectedFilter == 'DISTANCE_DELTA' && type != 'DISTANCE_DELTA') return false;
        if (_selectedFilter == 'SPEED' && type != 'SPEED') return false;
        if (_selectedFilter == 'BLOOD_OXYGEN' && type != 'BLOOD_OXYGEN') return false;
        if (_selectedFilter == 'ACTIVE_ENERGY_BURNED' && type != 'ACTIVE_ENERGY_BURNED') return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final jsonStr = json.encode(item).toLowerCase();
        if (!jsonStr.contains(_searchQuery.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF64FFDA),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPoints;
    const encoder = JsonEncoder.withIndent('  ');

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.data_object, color: Color(0xFF64FFDA)),
            SizedBox(width: 8),
            Text(
              "Inspector JSON Crudo",
              style: TextStyle(
                color: Color(0xFF64FFDA),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: "Refrescar datos crudos",
            onPressed: _loadRawData,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all, color: Color(0xFF64FFDA)),
            tooltip: "Copiar todo el JSON al portapapeles",
            onPressed: filtered.isEmpty
                ? null
                : () {
                    final fullJsonStr = encoder.convert(filtered);
                    _copyToClipboard(fullJsonStr, "¡Todos los objetos JSON copiados al portapapeles!");
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF64FFDA)),
                  SizedBox(height: 16),
                  Text("Consultando registros crudos en Health Connect...", style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner explaining raw data
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D253F),
                      border: Border.all(color: const Color(0xFF64FFDA).withOpacity(0.4), width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, color: Color(0xFF64FFDA), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Datos Sin Procesar de Health Connect",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Esta pantalla muestra la estructura JSON exacta y sin filtros tal como la entrega Google Health Connect (escrita por Mi Fitness / Redmi Watch 4).\nAquís verás si existen registros de segundos exactos, metros parciales o si Mi Fitness solo reporta resúmenes globales.",
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                final fullJsonStr = encoder.convert(filtered);
                                _copyToClipboard(fullJsonStr, "¡JSON completo copiado!");
                              },
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text("Copiar JSON Completo", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF64FFDA),
                                foregroundColor: const Color(0xFF0A192F),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _loadRawData,
                              icon: const Icon(Icons.refresh, size: 14, color: Colors.white),
                              label: const Text("Refrescar", style: TextStyle(color: Colors.white, fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Range Selector & Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Buscar en JSON...",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF0D253F),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF64FFDA)),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: _selectedDays,
                        dropdownColor: const Color(0xFF0D253F),
                        style: const TextStyle(color: Color(0xFF64FFDA), fontSize: 12, fontWeight: FontWeight.bold),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text("Últimas 24h")),
                          DropdownMenuItem(value: 7, child: Text("Últimos 7 días")),
                          DropdownMenuItem(value: 30, child: Text("Últimos 30 días")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedDays = val;
                            });
                            _loadRawData();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("TODOS", 'ALL'),
                        _buildFilterChip("WORKOUT", 'WORKOUT'),
                        _buildFilterChip("HEART_RATE", 'HEART_RATE'),
                        _buildFilterChip("DISTANCE", 'DISTANCE_DELTA'),
                        _buildFilterChip("SPEED", 'SPEED'),
                        _buildFilterChip("SPO2", 'BLOOD_OXYGEN'),
                        _buildFilterChip("CALORIES", 'ACTIVE_ENERGY_BURNED'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Results count summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Resultados: ${filtered.length} objetos crudos",
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Total en DB: ${_rawPoints.length}",
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // List of Raw JSON Cards
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D253F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, color: Colors.white38, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            "No se encontraron objetos crudos en Health Connect",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedFilter != 'ALL'
                                ? "Intenta cambiar el filtro '$_selectedFilter' o ampliar el rango de días."
                                : "Verifica si Mi Fitness tiene permiso de escritura en la app Google Health Connect.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildRawItemCard(item, index, encoder);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF64FFDA),
        backgroundColor: const Color(0xFF0D253F),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF0A192F) : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedFilter = filterKey;
            });
          }
        },
      ),
    );
  }

  Widget _buildRawItemCard(Map<String, dynamic> item, int index, JsonEncoder encoder) {
    final type = item['type'] as String? ?? 'DESCONOCIDO';
    final dateFrom = item['dateFrom'] as String? ?? '';
    final dateTo = item['dateTo'] as String? ?? '';
    final durationSec = item['durationSeconds'] as int? ?? 0;
    final jsonString = encoder.convert(item);

    Color badgeColor = Colors.grey;
    if (type == 'WORKOUT') badgeColor = Colors.orangeAccent;
    if (type == 'HEART_RATE') badgeColor = Colors.redAccent;
    if (type == 'DISTANCE_DELTA') badgeColor = Colors.cyanAccent;
    if (type == 'SPEED') badgeColor = Colors.greenAccent;
    if (type == 'BLOOD_OXYGEN') badgeColor = Colors.blueAccent;
    if (type == 'ACTIVE_ENERGY_BURNED') badgeColor = Colors.amberAccent;

    return Card(
      color: const Color(0xFF0D253F),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: ExpansionTile(
        key: Key("raw_card_${index}_$type"),
        initiallyExpanded: index == 0 || type == 'WORKOUT',
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            "#${index + 1}",
            style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor, width: 1),
              ),
              child: Text(
                type,
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Duración: ${durationSec}s",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "Desde: $dateFrom\nHasta: $dateTo",
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "JSON Crudo Objeto HealthConnect:",
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Color(0xFF64FFDA), size: 18),
                tooltip: "Copiar este JSON",
                onPressed: () {
                  _copyToClipboard(jsonString, "¡JSON de $type copiado!");
                },
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF06101E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white10),
            ),
            child: SelectableText(
              jsonString,
              style: const TextStyle(
                color: Color(0xFF64FFDA),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
