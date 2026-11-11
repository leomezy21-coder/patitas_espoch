import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_reportes_animales.dart';

class PantallaRegistroAnimal extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final Future<Uint8List?> Function()? seleccionarFotografia;
  const PantallaRegistroAnimal({
    super.key,
    required this.perfil,
    this.seleccionarFotografia,
  });
  @override
  State<PantallaRegistroAnimal> createState() => _EstadoRegistroAnimal();
}

class _EstadoRegistroAnimal extends State<PantallaRegistroAnimal> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _raza = TextEditingController();
  final _descripcion = TextEditingController();
  final _selector = ImagePicker();
  String? _especie;
  String? _sexo;
  Uint8List? _foto;
  bool _guardando = false;
  bool _registroConfirmado = false;
  bool _seleccionando = false;
  String? _error;
  SolicitudRegistroAnimal? _solicitud;

  @override
  void initState() {
    super.initState();
    _recuperarFoto();
  }

  Future<void> _recuperarFoto() async {
    if (widget.seleccionarFotografia != null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final perdida = await _selector.retrieveLostData();
      if (perdida.files?.isNotEmpty ?? false) {
        final archivo = perdida.files!.first;
        if (await archivo.length() <= 5 * 1024 * 1024) {
          final bytes = await archivo.readAsBytes();
          if (mounted) setState(() => _foto = bytes);
        }
      }
    } catch (_) {
      /* El selector puede no tener una operacion anterior. */
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _raza.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    if (_guardando || _seleccionando || _solicitud != null) return;
    setState(() => _seleccionando = true);
    try {
      Uint8List? bytes;
      if (widget.seleccionarFotografia != null) {
        bytes = await widget.seleccionarFotografia!();
      } else {
        final archivo = await _selector.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        if (archivo != null) {
          if (await archivo.length() > 5 * 1024 * 1024) {
            throw const ErrorAnimales('Selecciona una foto de hasta 5 MB.');
          }
          bytes = await archivo.readAsBytes();
        }
      }
      if (bytes != null) {
        if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          throw const ErrorAnimales('Selecciona una foto de hasta 5 MB.');
        }
        if (mounted) {
          setState(() {
            _foto = bytes;
            _error = null;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo seleccionar la foto. Usa una imagen JPG, PNG o WebP de hasta 5 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _seleccionando = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando || _seleccionando || _registroConfirmado) return;
    FocusScope.of(context).unfocus();
    if (!(_formulario.currentState?.validate() ?? false)) return;
    if (_foto == null) {
      setState(() => _error = 'Selecciona la fotografía del animal.');
      return;
    }
    _solicitud ??= SolicitudRegistroAnimal(
      idAnimal: ServicioAnimales.nuevoIdentificador(),
      nombre: _nombre.text,
      especie: _especie!,
      raza: _raza.text,
      sexo: _sexo!,
      descripcion: _descripcion.text,
      fotografia: _foto!,
    );
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ServicioAnimales.proveedor.registrar(_solicitud!);
      ServicioAnimales.notificarCambio();
      if (!mounted) return;
      // La operacion termino; el modal conserva el bloqueo de nuevos envios.
      setState(() {
        _guardando = false;
        _registroConfirmado = true;
      });
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Registro guardado',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        transitionBuilder: (context, animacion, secundaria, hijo) =>
            FadeTransition(
              opacity: animacion,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animacion),
                child: hijo,
              ),
            ),
        pageBuilder: (contexto, animacion, secundaria) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: TemaPatitas.colorSuperficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            scrollable: true,
            title: const Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: TemaPatitas.colorVerdeEsmeralda,
                  size: 54,
                ),
                SizedBox(height: 12),
                Text(
                  '¡Animal registrado con éxito!',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'La información de tu animal se ha guardado correctamente.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0C2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.schedule, color: Color(0xFF8B600C)),
                      SizedBox(height: 6),
                      Text(
                        'Pendiente de revisión',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tu registro está pendiente de revisión por el personal administrativo.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Una vez revisado, podrás consultar su estado actualizado en la aplicación.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: TemaPatitas.colorVerdeEsmeralda,
                ),
                onPressed: () => Navigator.of(contexto).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _guardando = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PantallaReportesAnimales(
            perfil: widget.perfil,
            soloPropios: true,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = ServicioAnimales.mensajeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_guardando && _solicitud == null;
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        appBar: AppBar(title: const Text('Registrar animal')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Agregar otro animalito',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: TemaPatitas.colorMarronOscuro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Comparte sus datos básicos. La revisión y las evaluaciones se realizarán después.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const ValueKey('animal_nombre'),
                        controller: _nombre,
                        enabled: editable,
                        maxLength: 100,
                        decoration: decoracionCampoAutenticacion(
                          etiqueta: 'Nombre del animal',
                          iconoPrefijo: Icons.pets,
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Ingresa el nombre del animal'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('animal_especie'),
                        initialValue: _especie,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de animal',
                        ),
                        items: const ['Perro', 'Gato']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: editable
                            ? (v) => setState(() => _especie = v)
                            : null,
                        validator: (v) =>
                            v == null ? 'Selecciona el tipo de animal' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _raza,
                        enabled: editable,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Raza (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('animal_sexo'),
                        initialValue: _sexo,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: const ['Macho', 'Hembra', 'No identificado']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: editable
                            ? (v) => setState(() => _sexo = v)
                            : null,
                        validator: (v) =>
                            v == null ? 'Selecciona el sexo' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descripcion,
                        enabled: editable,
                        maxLength: 2000,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_foto != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              _foto!,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, traza) =>
                                  const Text('Fotografía seleccionada'),
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        key: const ValueKey('seleccionar_foto_animal'),
                        onPressed: editable && !_seleccionando
                            ? _seleccionarFoto
                            : null,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _seleccionando
                              ? 'Abriendo fotografías…'
                              : _foto == null
                              ? 'Seleccionar fotografía'
                              : 'Cambiar fotografía',
                        ),
                      ),
                      const Text(
                        'Fotografía obligatoria · JPG, PNG o WebP · Hasta 5 MB',
                        style: TextStyle(fontSize: 12),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (_solicitud != null &&
                          !_guardando &&
                          !_registroConfirmado)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Reintenta el guardado para confirmar este registro. Conservamos tus datos y la fotografía.',
                          ),
                        ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const ValueKey('guardar_animal'),
                        style: estiloBotonPrimarioNaranja(),
                        onPressed:
                            _guardando || _seleccionando || _registroConfirmado
                            ? null
                            : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _registroConfirmado
                                    ? 'Registro guardado'
                                    : _solicitud == null
                                    ? 'Guardar'
                                    : 'Reintentar guardado',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
