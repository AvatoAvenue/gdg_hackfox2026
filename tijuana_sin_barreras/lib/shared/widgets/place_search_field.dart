import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/place_models.dart';
import '../../core/services/maps_service.dart';

/// Campo de búsqueda con autocompletado estilo Google Maps.
///
/// Muestra sugerencias en un overlay flotante mientras el usuario escribe
/// (con debounce), sesgadas a Tijuana. Al elegir una, resuelve sus
/// coordenadas vía Place Details y las entrega en [onSelected], listas
/// para alimentar a Routes API. Funciona en web y Android (Places API New).
class PlaceSearchField extends StatefulWidget {
  final MapsService mapsService;
  final String hintText;
  final IconData icon;

  /// Se llama cuando el usuario elige un lugar y se resuelven sus coordenadas.
  final ValueChanged<PlaceResult> onSelected;

  /// Se llama cuando el usuario limpia o cambia el texto (invalida la selección).
  final VoidCallback? onCleared;

  /// Texto crudo escrito por el usuario (para fallback de búsqueda por texto).
  final ValueChanged<String>? onTextChanged;

  /// Controller externo opcional (p. ej. para rellenar desde chips de demo).
  final TextEditingController? controller;

  /// Color del icono prefijo.
  final Color? iconColor;

  const PlaceSearchField({
    super.key,
    required this.mapsService,
    required this.hintText,
    required this.icon,
    required this.onSelected,
    this.onCleared,
    this.onTextChanged,
    this.controller,
    this.iconColor,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  OverlayEntry? _overlay;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  String? _sessionToken;
  bool _hasSelection = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    // Solo desechar el controller si lo creamos nosotros.
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Pequeño retraso para permitir el tap sobre una sugerencia.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    } else if (_suggestions.isNotEmpty) {
      _showOverlay();
    }
  }

  void _onChanged(String value) {
    widget.onTextChanged?.call(value);
    if (_hasSelection) {
      _hasSelection = false;
      widget.onCleared?.call();
    }
    _debounce?.cancel();

    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      _removeOverlay();
      return;
    }

    _sessionToken ??= widget.mapsService.newSessionToken();
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(value));
  }

  Future<void> _fetch(String value) async {
    setState(() => _loading = true);
    try {
      final results = await widget.mapsService.autocompletePlaces(
        value,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
      if (_focusNode.hasFocus) _showOverlay();
    } catch (_) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    _controller.text = suggestion.mainText;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _suggestions = []);
    _removeOverlay();
    _focusNode.unfocus();

    try {
      final result = await widget.mapsService.getPlaceDetails(
        suggestion.placeId,
        sessionToken: _sessionToken,
      );
      _sessionToken = null; // cierra la sesión de facturación
      if (result != null && mounted) {
        _hasSelection = true;
        widget.onSelected(result);
      }
    } catch (_) {
      // Si falla details, el fallback searchText del screen lo cubre.
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _hasSelection = false;
    });
    _removeOverlay();
    widget.onCleared?.call();
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder:
                        (_, i) => _buildSuggestionTile(_suggestions[i]),
                  ),
                ),
              ),
            ),
          ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildSuggestionTile(PlaceSuggestion s) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.location_on_outlined, color: AppColors.muted),
      title: Text(
        s.mainText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle:
          s.secondaryText.isNotEmpty
              ? Text(
                s.secondaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              )
              : null,
      onTap: () => _select(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          hintText: widget.hintText,
          prefixIcon: Icon(widget.icon, color: widget.iconColor),
          suffixIcon:
              _loading
                  ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : (_controller.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clear,
                      )
                      : null),
        ),
      ),
    );
  }
}
