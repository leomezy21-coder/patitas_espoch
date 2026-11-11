import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../modelos/animal_modelo.dart';
import '../modelos/avistamiento_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_avistamientos.dart';
import '../servicios/servicio_ubicacion_campus.dart';
import '../tema/tema_patitas.dart';

class PantallaRegistroAvistamiento extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final AvistamientoModelo? avistamientoPendiente;
  final Future<Uint8List?> Function(ImageSource origen)? seleccionarFotografia;
  const PantallaRegistroAvistamiento({super.key, required this.perfil,
    this.seleccionarFotografia, this.avistamientoPendiente});
  @override
  State<PantallaRegistroAvistamiento> createState() => _EstadoRegistroAvistamiento();
}

class _EstadoRegistroAvistamiento extends State<PantallaRegistroAvistamiento> {
  final _observaciones = TextEditingController();
  final _selector = ImagePicker();
  List<AnimalModelo> _animales = [];
  String? _idAnimal;
  Uint8List? _foto;
  DateTime _fecha = DateTime.now();
  UbicacionUsuarioCampus? _ubicacion;
  String? _error;
  bool _cargando = true;
  bool _ocupado = false;
  SolicitudAvistamiento? _solicitud;
  bool get _bloqueado => _ocupado || _solicitud != null;
  bool get _datosFijos => _bloqueado || widget.avistamientoPendiente != null;

  @override
  void initState() {
    super.initState();
    final pendiente = widget.avistamientoPendiente;
    if (pendiente != null) {
      _idAnimal = pendiente.idAnimal;
      _fecha = pendiente.fecha.toLocal();
      _observaciones.text = pendiente.observaciones;
      _ubicacion = UbicacionUsuarioCampus(latitud: pendiente.latitud,
        longitud: pendiente.longitud, precisionMetros: pendiente.precisionMetros,
        fechaCaptura: pendiente.fecha);
    }
    _cargarAnimales();
  }
  @override
  void dispose() {
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _cargarAnimales() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final lista = await ServicioAnimales.proveedor.listar();
      if (mounted) setState(() => _animales = lista.where((animal) => !animal.esDemostracion).toList());
    } catch (error) {
      if (mounted) setState(() => _error = ServicioAnimales.mensajeError(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarFoto(ImageSource origen) async {
    if (_bloqueado) return;
    setState(() => _ocupado = true);
    try {
      Uint8List? foto;
      if (widget.seleccionarFotografia != null) {
        foto = await widget.seleccionarFotografia!(origen);
      } else {
        final archivo = await _selector.pickImage(source: origen,
          maxWidth: 1600, maxHeight: 1600, imageQuality: 80, requestFullMetadata: false);
        if (archivo != null) {
          if (await archivo.length() > 5 * 1024 * 1024) {
            throw const ErrorAvistamientos('Selecciona una foto de hasta 5 MB.');
          }
          foto = await archivo.readAsBytes();
        }
      }
      if (foto != null) {
        if (foto.isEmpty || foto.length > 5 * 1024 * 1024) {
          throw const ErrorAvistamientos('Selecciona una foto de hasta 5 MB.');
        }
        final esJpg = foto.length >= 3 && foto[0] == 255 && foto[1] == 216 && foto[2] == 255;
        final esPng = foto.length >= 8 && listEquals(foto.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final esWebp = foto.length >= 12 && String.fromCharCodes(foto.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(foto.sublist(8, 12)) == 'WEBP';
        if (!esJpg && !esPng && !esWebp) {
          throw const ErrorAvistamientos('Usa una foto JPG, PNG o WebP de hasta 5 MB.');
        }
        if (mounted) setState(() { _foto = foto; _error = null; });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo abrir la foto. Revisa los permisos y selecciona un JPG, PNG o WebP de hasta 5 MB.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _obtenerUbicacion() async {
    if (_bloqueado) return;
    setState(() { _ocupado = true; _error = null; });
    final resultado = await ServicioUbicacionCampus.solicitarUbicacionActual();
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (resultado.exito) {
        _ubicacion = resultado.ubicacion;
      } else {
        _error = resultado.mensajeError;
      }
    });
  }

  Future<void> _cambiarFecha() async {
    if (_bloqueado) return;
    final ahora = DateTime.now();
    final dia = await showDatePicker(context: context, initialDate: _fecha,
      firstDate: DateTime(2000), lastDate: ahora);
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fecha));
    if (hora == null || !mounted) return;
    final fecha = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    setState(() {
      if (fecha.isAfter(DateTime.now())) {
        _error = 'La fecha y hora no pueden estar en el futuro.';
      } else {
        _fecha = fecha;
        _error = null;
      }
    });
  }

  Future<void> _guardar() async {
    if (_ocupado || _cargando) return;
    final pendiente = widget.avistamientoPendiente;
    if (pendiente != null && pendiente.idUsuario != widget.perfil.idUsuario) {
      setState(() => _error = 'Solo puedes completar tus propios reportes.');
      return;
    }
    if (!widget.perfil.activo || _idAnimal == null || _foto == null || _ubicacion == null) {
      setState(() => _error = 'Selecciona el animal, una foto y la ubicación del avistamiento.');
      return;
    }
    if (_observaciones.text.runes.length > 2000 || _fecha.isAfter(DateTime.now())) {
      setState(() => _error = 'Revisa las observaciones y la fecha del avistamiento.');
      return;
    }
    setState(() { _ocupado = true; _error = null; });
    if (_solicitud == null) {
      final nombreAnimal = pendiente?.nombreAnimal ?? _animales.firstWhere((animal) => animal.id == _idAnimal).nombre;
      final confirmado = await showDialog<bool>(context: context, builder: (contexto) => AlertDialog(
        title: const Text('Confirmar avistamiento'),
        scrollable: true,
        content: Text('$nombreAnimal\n${MaterialLocalizations.of(context).formatFullDate(_fecha)} '
          '${TimeOfDay.fromDateTime(_fecha).format(context)}\n${_ubicacion!.resumenCoordenadas}\n\n'
          '${pendiente == null ? 'Confirma que viste a este animal en ese lugar y momento. La ubicación corresponde a tu teléfono al capturarla.' : 'Se conservan el lugar y la fecha del reporte guardado; solo se adjuntará esta fotografía.'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Corregir')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Confirmar y guardar')),
        ],
      ));
      if (!mounted) return;
      if (confirmado != true) { setState(() => _ocupado = false); return; }
      final precision = _ubicacion!.precisionMetros;
      _solicitud = SolicitudAvistamiento(
        id: pendiente?.id ?? ServicioAnimales.nuevoIdentificador(), idAnimal: _idAnimal!,
        latitud: _ubicacion!.latitud, longitud: _ubicacion!.longitud,
        precisionMetros: precision != null && precision.isFinite && precision >= 0 ? precision : null,
        fecha: _fecha, observaciones: _observaciones.text, fotografia: _foto!,
      );
    }
    try {
      await ServicioAvistamientos.proveedor.registrar(_solicitud!);
      ServicioAvistamientos.notificarCambio();
      ServicioAnimales.notificarCambio();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = ServicioAvistamientos.mensajeError(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,
      appBar: AppBar(title: const Text('Reportar avistamiento')),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Registra dónde y cuándo viste al animal.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Solo campus matriz ESPOCH. Los reportes son observaciones de la comunidad; los animales no llevan GPS.'),
          const SizedBox(height: 20),
          if (_cargando) const Center(child: CircularProgressIndicator())
          else if (_animales.isEmpty) ...[
            const Text('No hay animales disponibles para reportar. Puedes revisar el catálogo o reintentar la consulta.'),
            TextButton(onPressed: _cargarAnimales, child: const Text('Reintentar catálogo')),
          ] else if (widget.avistamientoPendiente != null)
            Text('Completar foto de ${widget.avistamientoPendiente!.nombreAnimal}. Los datos del reporte guardado se conservan.')
          else DropdownButtonFormField<String>(
            key: const Key('avistamiento_animal'),
            initialValue: _idAnimal, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Animal que viste'),
            items: _animales.map((animal) => DropdownMenuItem(value: animal.id,
              child: Text('${animal.nombre} · ${animal.identificador}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _datosFijos ? null : (valor) => setState(() => _idAnimal = valor),
          ),
          const SizedBox(height: 16),
          if (_foto != null) ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.memory(_foto!, height: 180, fit: BoxFit.contain,
              errorBuilder: (_, error, traza) => const Text('No se pudo mostrar la foto. Selecciona otra imagen válida.'))),
          Wrap(spacing: 12, children: [
            OutlinedButton.icon(key: const Key('avistamiento_galeria'),
              onPressed: _bloqueado ? null : () => _seleccionarFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined), label: const Text('Galería')),
            OutlinedButton.icon(onPressed: _bloqueado ? null : () => _seleccionarFoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined), label: const Text('Tomar foto')),
          ]),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event),
            title: const Text('Fecha y hora del avistamiento'),
            subtitle: Text('${MaterialLocalizations.of(context).formatFullDate(_fecha)} · ${TimeOfDay.fromDateTime(_fecha).format(context)}'),
            onTap: _datosFijos ? null : _cambiarFecha,
            trailing: const Icon(Icons.edit_outlined)),
          OutlinedButton.icon(key: const Key('avistamiento_ubicacion'),
            onPressed: _datosFijos ? null : _obtenerUbicacion,
            icon: const Icon(Icons.my_location),
            label: Text(_ubicacion == null ? 'Capturar ubicación del teléfono' : 'Actualizar ubicación del teléfono')),
          if (_ubicacion != null) Text('${_ubicacion!.resumenCoordenadas}\n${_ubicacion!.resumenPrecision}'),
          TextButton(onPressed: _bloqueado ? null : ServicioUbicacionCampus.abrirAjustesAplicacion,
            child: const Text('Ajustes de permisos')),
          const SizedBox(height: 8),
          TextField(key: const Key('avistamiento_observaciones'), controller: _observaciones,
            enabled: !_datosFijos, maxLines: 3, maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Observaciones (opcional)')),
          if (_solicitud != null) const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('El envío conserva los datos originales para reintentar sin duplicados. No cierres este formulario hasta confirmar el resultado.')),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, key: const Key('avistamiento_error'), style: const TextStyle(color: Color(0xFF9B2C20)))),
          FilledButton(key: const Key('avistamiento_guardar'),
            onPressed: _ocupado || _cargando ? null : _guardar,
            child: Text(_ocupado ? 'Procesando…' : _solicitud == null ? 'Revisar avistamiento' : 'Reintentar guardado')),
        ]),
      )),
    ),
  );
}
