import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/gemini_service.dart';

class ReportBarrierScreen extends StatefulWidget {
  const ReportBarrierScreen({super.key});

  @override
  State<ReportBarrierScreen> createState() => _ReportBarrierScreenState();
}

class _ReportBarrierScreenState extends State<ReportBarrierScreen> {
  final _descController = TextEditingController();
  String _selectedType = AppConstants.barrierTypes.first;
  Uint8List? _photoBytes;
  bool _submitting = false;
  bool _analyzing = false;
  BarrierPhotoValidation? _validation;
  bool _validationFailed = false;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _position = pos);
    } catch (_) {}
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _validation = null;
      _validationFailed = false;
    });
    await _validatePhoto();
  }

  /// Pide a Gemini que confirme si la foto corresponde al tipo seleccionado.
  Future<void> _validatePhoto() async {
    if (_photoBytes == null) return;
    setState(() {
      _analyzing = true;
      _validationFailed = false;
    });
    try {
      final result = await context
          .read<GeminiService>()
          .validateBarrierPhoto(_photoBytes!, _selectedType);
      if (mounted) {
        setState(() {
          _validation = result;
          // result == null => la API no respondió correctamente.
          _validationFailed = result == null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _validationFailed = true);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _onTypeSelected(String type) {
    if (type == _selectedType) return;
    setState(() {
      _selectedType = type;
      // Si ya hay foto, revalidamos contra el nuevo tipo seleccionado.
      if (_photoBytes != null) {
        _validation = null;
        _validationFailed = false;
      }
    });
    if (_photoBytes != null) _validatePhoto();
  }

  Future<void> _submit() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esperando ubicación GPS...')),
      );
      return;
    }

    // Si Gemini detectó que la foto no corresponde al tipo seleccionado,
    // pedimos confirmación antes de enviar.
    if (_validation != null && !_validation!.matches) {
      final proceed = await _confirmMismatch();
      if (proceed != true || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      final firebase = context.read<FirebaseService>();
      String? photoBase64;

      if (_photoBytes != null) {
        // La foto se guarda como base64 dentro del documento de Firestore
        // (evitamos Firebase Storage, que requiere plan de pago). Un documento
        // de Firestore admite máx. 1 MB, así que rechazamos fotos muy pesadas.
        const maxBytes = 900 * 1024; // ~900 KB de bytes crudos
        if (_photoBytes!.lengthInBytes > maxBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La foto es demasiado grande. Toma otra con menor resolución.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
          setState(() => _submitting = false);
          return;
        }
        photoBase64 = base64Encode(_photoBytes!);
      }

      final description = _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : _selectedType;

      await firebase.submitBarrierReport(
        lat: _position!.latitude,
        lng: _position!.longitude,
        type: _selectedType,
        description: description,
        photoBase64: photoBase64,
        geminiAnalysis: _validation?.analysis,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barrera reportada. ¡Gracias por ayudar!'),
            backgroundColor: AppColors.secondary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Barrera'),
        backgroundColor: AppColors.danger,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationBadge(),
            const SizedBox(height: 24),
            _buildLabel('Tipo de barrera'),
            const SizedBox(height: 10),
            _buildTypeChips(),
            const SizedBox(height: 24),
            _buildLabel('Foto (opcional · mejora el análisis IA)'),
            const SizedBox(height: 10),
            _buildPhotoSection(),
            if (_analyzing) ...[
              const SizedBox(height: 10),
              _buildAnalyzingIndicator(),
            ],
            if (_validation != null) ...[
              const SizedBox(height: 16),
              _buildMatchBadge(_validation!),
              if (_validation!.analysis != null) ...[
                const SizedBox(height: 12),
                _buildGeminiResult(_validation!.analysis!),
              ],
            ],
            if (_validationFailed) ...[
              const SizedBox(height: 16),
              _buildValidationError(),
            ],
            const SizedBox(height: 24),
            _buildLabel('Descripción adicional'),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe la barrera con más detalle...',
                filled: true,
                fillColor: Color(0xFFF8F9FA),
              ),
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15));
  }

  Widget _buildLocationBadge() {
    final hasLocation = _position != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (hasLocation ? AppColors.secondary : AppColors.warning).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.location_on : Icons.location_searching,
            color: hasLocation ? AppColors.secondary : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasLocation
                  ? '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                  : 'Obteniendo tu ubicación...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasLocation ? AppColors.secondary : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.barrierTypes.map((type) {
        final selected = _selectedType == type;
        return FilterChip(
          label: Text(type),
          selected: selected,
          onSelected: (_) => _onTypeSelected(type),
          selectedColor: AppColors.danger.withOpacity(0.15),
          checkmarkColor: AppColors.danger,
          labelStyle: TextStyle(
            color: selected ? AppColors.danger : AppColors.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        if (_photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _photoBytes!,
              height: 280,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          )
        else
          Container(
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: const Center(
              child: Icon(Icons.add_photo_alternate_outlined, size: 42, color: AppColors.muted),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Cámara'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyzingIndicator() {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
        SizedBox(width: 8),
        Text(
          'Gemini AI verificando la foto...',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  /// Badge que indica si la foto coincide o no con el tipo seleccionado.
  Widget _buildMatchBadge(BarrierPhotoValidation v) {
    final color = v.matches ? AppColors.secondary : AppColors.warning;
    final title = v.matches
        ? 'La foto coincide con "$_selectedType"'
        : 'La foto no parece ser "$_selectedType"';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                v.matches ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${v.confidence}%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (v.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(v.message, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
          if (!v.matches && v.detectedType.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: AppConstants.barrierTypes.contains(v.detectedType)
                    ? () => _onTypeSelected(v.detectedType)
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text('Gemini detectó: "${v.detectedType}"'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Aviso cuando no se pudo contactar a Gemini (p. ej. API key inválida o
  /// sin conexión). No bloquea el envío, pero deja claro que no hubo verificación.
  Widget _buildValidationError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.muted.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No se pudo verificar la foto con Gemini. Revisa tu conexión o la '
              'configuración de la API. El reporte se puede enviar sin verificar.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: _analyzing ? null : _validatePhoto,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmMismatch() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('La foto no coincide'),
        content: Text(
          'Gemini detectó que la foto parece mostrar '
          '"${_validation!.detectedType}" en vez de "$_selectedType".\n\n'
          '¿Quieres enviar el reporte de todos modos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Revisar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar igual'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiResult(String analysis) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'Análisis de Gemini AI',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(analysis, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _submitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.danger.withOpacity(0.5),
      ),
      icon: _submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.send_rounded),
      label: Text(_submitting ? 'Enviando...' : 'Reportar barrera'),
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }
}
