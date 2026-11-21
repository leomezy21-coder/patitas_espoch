import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/incidencia_modelo.dart';
import 'configuracion_supabase.dart';
import 'servicio_notificaciones.dart';

class ErrorIncidencias implements Exception {
  final String mensaje;
  const ErrorIncidencias(this.mensaje);

  @override
  String toString() => mensaje;
}

abstract class ProveedorIncidencias {
  Future<IncidenciaModelo> registrar(SolicitudRegistroIncidencia solicitud);

  Future<List<IncidenciaModelo>> listar({
    EstadoIncidencia? estado,
    bool soloActivas = false,
    String? idAnimal,
  });

  Future<IncidenciaModelo> obtenerDetalle(String idIncidencia);

  Future<IncidenciaModelo> actualizarEstado({
    required String idIncidencia,
    required EstadoIncidencia estadoActual,
    required EstadoIncidencia nuevoEstado,
  });
}

abstract final class ServicioIncidencias {
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  static void notificarCambio() => cambios.value++;

  static ProveedorIncidencias _proveedor = ProveedorIncidenciasSupabase();
  static ProveedorIncidencias get proveedor => _proveedor;

  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorIncidencias proveedor) {
    _proveedor = proveedor;
  }

  @visibleForTesting
  static void restaurarProveedor() {
    _proveedor = ProveedorIncidenciasSupabase();
  }

  static String mensajeError(Object error) {
    if (error is ErrorIncidencias) return error.mensaje;
    if (error is PostgrestException) {
      switch (error.code) {
        case '42501':
          return 'Tu cuenta no tiene una sesión activa con permisos para realizar esta acción sobre incidencias.';
        case '40001':
          return 'El estado de la incidencia cambió recientemente. Recarga la información e inténtalo nuevamente.';
        case '22023':
          return error.message.isNotEmpty
              ? error.message
              : 'Revisa los datos de la incidencia antes de enviarla.';
        case 'PGRST202':
        case '42883':
          return 'El servicio de incidencias está pendiente de configuración en el servidor.';
      }
    }
    if (error is FormatException) {
      return 'El servidor devolvió una respuesta de incidencia no válida.';
    }
    return 'No se pudo completar la operación de incidencias. Comprueba tu conexión e inténtalo nuevamente.';
  }
}

typedef InvocarRpcIncidencias = Future<dynamic> Function(
  String nombre,
  Map<String, dynamic> parametros,
);

class ProveedorIncidenciasSupabase implements ProveedorIncidencias {
  final InvocarRpcIncidencias? invocar;

  ProveedorIncidenciasSupabase({this.invocar});

  Future<dynamic> _rpc(String nombre, Map<String, dynamic> parametros) async {
    if (invocar != null) return invocar!(nombre, parametros);
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorIncidencias(
        'El servicio de incidencias no está conectado al servidor.',
      );
    }
    final cliente = Supabase.instance.client;
    if (cliente.auth.currentSession == null) {
      throw const ErrorIncidencias(
        'Debes iniciar sesión institucional activa para acceder a las incidencias.',
      );
    }
    return cliente.rpc(nombre, params: parametros);
  }

  @override
  Future<IncidenciaModelo> registrar(
    SolicitudRegistroIncidencia solicitud,
  ) async {
    final idLimpio = solicitud.idIncidencia.trim();
    final idAnimalLimpio = solicitud.idAnimal.trim();
    final descripcionLimpia = solicitud.descripcion.trim();
    final longitudDescripcion = descripcionLimpia.runes.length;

    if (idLimpio.isEmpty || idAnimalLimpio.isEmpty) {
      throw const ErrorIncidencias(
        'Selecciona el animal relacionado con la incidencia.',
      );
    }
    if (longitudDescripcion < 5 || longitudDescripcion > 2000) {
      throw const ErrorIncidencias(
        'Describe la incidencia usando entre 5 y 2000 caracteres.',
      );
    }
    if (!solicitud.coordenadasValidas) {
      throw const ErrorIncidencias(
        'Las coordenadas adjuntas no son válidas.',
      );
    }

    try {
      final datos = await _rpc('registrar_incidencia', solicitud.parametrosRpc);
      if (datos is! Map) throw const FormatException();
      final incidencia = IncidenciaModelo.desdeMapa(
        Map<String, dynamic>.from(datos),
      );
      if (incidencia.id != idLimpio ||
          incidencia.idAnimal != idAnimalLimpio ||
          incidencia.estado != EstadoIncidencia.reportada) {
        throw const FormatException();
      }
      await ServicioNotificaciones.notificarEventoIncidencia(
        idIncidencia: incidencia.id,
        evento: 'registro',
        estadoClave: incidencia.estado.codigoBd,
      );
      return incidencia;
    } catch (error) {
      throw ErrorIncidencias(ServicioIncidencias.mensajeError(error));
    }
  }

  @override
  Future<List<IncidenciaModelo>> listar({
    EstadoIncidencia? estado,
    bool soloActivas = false,
    String? idAnimal,
  }) async {
    final animalLimpio = idAnimal?.trim();
    final filtroEstado = soloActivas ? 'activas' : estado?.codigoBd;

    try {
      final respuesta = await _rpc(
        'listar_incidencias',
        <String, dynamic>{
          'p_estado': filtroEstado,
          'p_id_animal':
              (animalLimpio == null || animalLimpio.isEmpty) ? null : animalLimpio,
          'p_limite': 50,
        },
      );
      if (respuesta is! List) throw const FormatException();
      final resultado = <IncidenciaModelo>[];
      for (final item in respuesta) {
        if (item is! Map) throw const FormatException();
        resultado.add(
          IncidenciaModelo.desdeMapa(Map<String, dynamic>.from(item)),
        );
      }
      return List<IncidenciaModelo>.unmodifiable(resultado);
    } catch (error) {
      throw ErrorIncidencias(ServicioIncidencias.mensajeError(error));
    }
  }

  @override
  Future<IncidenciaModelo> obtenerDetalle(String idIncidencia) async {
    final idLimpio = idIncidencia.trim();
    if (idLimpio.isEmpty) {
      throw const ErrorIncidencias(
        'Identificador de incidencia obligatorio.',
      );
    }

    try {
      final datos = await _rpc(
        'obtener_detalle_incidencia',
        <String, dynamic>{'p_id_incidencia': idLimpio},
      );
      if (datos is! Map) throw const FormatException();
      final incidencia = IncidenciaModelo.desdeMapa(
        Map<String, dynamic>.from(datos),
      );
      if (incidencia.id != idLimpio) throw const FormatException();
      return incidencia;
    } catch (error) {
      throw ErrorIncidencias(ServicioIncidencias.mensajeError(error));
    }
  }

  @override
  Future<IncidenciaModelo> actualizarEstado({
    required String idIncidencia,
    required EstadoIncidencia estadoActual,
    required EstadoIncidencia nuevoEstado,
  }) async {
    final idLimpio = idIncidencia.trim();
    if (idLimpio.isEmpty) {
      throw const ErrorIncidencias(
        'Identificador de incidencia obligatorio.',
      );
    }

    if (estadoActual.siguienteEstado != nuevoEstado) {
      throw const ErrorIncidencias(
        'Transición de estado no permitida: solo se permite avanzar de Reportada a En atención y de En atención a Resuelta.',
      );
    }

    try {
      final datos = await _rpc(
        'actualizar_estado_incidencia',
        <String, dynamic>{
          'p_id_incidencia': idLimpio,
          'p_estado_esperado': estadoActual.codigoBd,
          'p_nuevo_estado': nuevoEstado.codigoBd,
        },
      );
      if (datos is! Map) throw const FormatException();
      final incidencia = IncidenciaModelo.desdeMapa(
        Map<String, dynamic>.from(datos),
      );
      if (incidencia.id != idLimpio || incidencia.estado != nuevoEstado) {
        throw const FormatException();
      }
      await ServicioNotificaciones.notificarEventoIncidencia(
        idIncidencia: incidencia.id,
        evento: 'cambio_estado',
        estadoClave: incidencia.estado.codigoBd,
      );
      return incidencia;
    } catch (error) {
      throw ErrorIncidencias(ServicioIncidencias.mensajeError(error));
    }
  }
}
