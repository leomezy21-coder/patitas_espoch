(function (globalScope) {
  "use strict";

  const LONGITUD_MINIMA_CONTRASENA = 8;
  const LONGITUD_MAXIMA_BYTES_CONTRASENA = 72;
  const SIMBOLOS_CONTRASENA = "!@#$%^&*()_+-=[]{};'\\:\"|<>?,./`~";
  const REQUISITOS_CONTRASENA = "Mínimo 8 caracteres: incluye mayúscula, minúscula, número y símbolo (por ejemplo, @, # o !).";

  /**
   * Extrae de forma segura los parametros del enlace de recuperacion desde
   * query string (`?token_hash=...&type=recovery`) o fragmento (`#...`),
   * sin registrar el enlace completo ni los tokens en consola.
   */
  function extraerParametrosRecuperacion(searchString, hashString) {
    const consulta = new URLSearchParams(searchString || "");
    const fragmentoLimpio = (hashString || "").replace(/^#/, "");
    const fragmento = new URLSearchParams(fragmentoLimpio);

    function obtenerParametro(clave) {
      return consulta.get(clave) || fragmento.get(clave) || "";
    }

    return {
      tokenHash: obtenerParametro("token_hash").trim(),
      tipo: obtenerParametro("type").trim().toLowerCase(),
      codigoError: obtenerParametro("error_code").trim().toLowerCase(),
      error: obtenerParametro("error").trim().toLowerCase(),
      descripcionError: obtenerParametro("error_description").trim(),
      tieneParametrosSensibles:
        consulta.has("token_hash") ||
        consulta.has("type") ||
        consulta.has("code") ||
        consulta.has("error") ||
        consulta.has("error_code") ||
        consulta.has("error_description") ||
        fragmento.has("access_token") ||
        fragmento.has("refresh_token") ||
        fragmento.has("token_hash") ||
        fragmento.has("error")
    };
  }

  /**
   * Elimina de la barra de direcciones del navegador los parametros sensibles
   * del enlace una vez leidos en memoria.
   */
  function limpiarUrlSensible(objetoVentana) {
    if (
      !objetoVentana ||
      !objetoVentana.history ||
      typeof objetoVentana.history.replaceState !== "function" ||
      !objetoVentana.location
    ) {
      return;
    }

    const rutaLimpia = objetoVentana.location.pathname || "/";
    const titulo =
      objetoVentana.document && objetoVentana.document.title
        ? objetoVentana.document.title
        : "Patitas ESPOCH";
    objetoVentana.history.replaceState(null, titulo, rutaLimpia);
  }

  /**
   * Valida la nueva contrasena y su confirmacion conforme a la politica del proyecto.
   */
  function validarPoliticaContrasena(nuevaContrasena, confirmarContrasena) {
    const clave = typeof nuevaContrasena === "string" ? nuevaContrasena : "";
    const confirmacion =
      typeof confirmarContrasena === "string" ? confirmarContrasena : "";

    if (clave.length === 0) {
      return {
        esValida: false,
        mensaje: "Ingresa tu nueva contraseña institucional."
      };
    }

    if (Array.from(clave).length < LONGITUD_MINIMA_CONTRASENA) {
      return {
        esValida: false,
        mensaje:
          "La nueva contraseña debe tener al menos " +
          LONGITUD_MINIMA_CONTRASENA +
          " caracteres."
      };
    }

    if (new TextEncoder().encode(clave).length > LONGITUD_MAXIMA_BYTES_CONTRASENA) {
      return { esValida: false, mensaje: "La contraseña es demasiado larga; usa una más corta" };
    }
    if (!/[A-Z]/.test(clave)) {
      return { esValida: false, mensaje: "Incluye una mayúscula (A-Z)" };
    }
    if (!/[a-z]/.test(clave)) {
      return { esValida: false, mensaje: "Incluye una minúscula (a-z)" };
    }
    if (!/[0-9]/.test(clave)) {
      return { esValida: false, mensaje: "Incluye un número (0-9)" };
    }
    if (!Array.from(clave).some((caracter) => SIMBOLOS_CONTRASENA.includes(caracter))) {
      return { esValida: false, mensaje: "Incluye un símbolo, por ejemplo @, # o !" };
    }

    if (confirmacion.length === 0) {
      return {
        esValida: false,
        mensaje: "Confirma tu nueva contraseña."
      };
    }

    if (clave !== confirmacion) {
      return {
        esValida: false,
        mensaje: "Las contraseñas ingresadas no coinciden."
      };
    }

    return {
      esValida: true,
      mensaje: ""
    };
  }

  /**
   * Traduce los errores de Supabase Auth a mensajes comprensibles en espanol
   * sin exponer tokens ni detalles internos.
   */
  function traducirErrorRecuperacionWeb(error) {
    if (!error) {
      return "No se pudo completar la operación. Solicita un nuevo enlace desde la aplicación.";
    }

    const mensaje = String(error.message || error.descripcionError || "").toLowerCase();
    const codigo = String(error.code || error.codigoError || "").toLowerCase();

    if (
      codigo === "weak_password" ||
      mensaje.includes("password should be at least") ||
      mensaje.includes("password should contain")
    ) {
      return REQUISITOS_CONTRASENA;
    }
    if (mensaje.includes("password cannot be longer")) {
      return "La contraseña es demasiado larga; usa una más corta";
    }

    if (
      codigo === "otp_expired" ||
      codigo === "flow_state_expired" ||
      codigo === "flow_state_not_found" ||
      codigo === "bad_code_verifier" ||
      mensaje.includes("expired") ||
      mensaje.includes("invalid") ||
      mensaje.includes("already used") ||
      mensaje.includes("token has expired")
    ) {
      return (
        "Este enlace de recuperación ha vencido o ya fue utilizado. " +
        "Por seguridad cada enlace es de un solo uso; solicita uno nuevo desde la aplicación móvil Patitas ESPOCH."
      );
    }

    if (
      codigo === "same_password" ||
      mensaje.includes("different from the old password") ||
      mensaje.includes("same_password")
    ) {
      return "La nueva contraseña debe ser diferente a tu contraseña anterior.";
    }

    if (
      codigo === "over_email_send_rate_limit" ||
      mensaje.includes("rate limit") ||
      mensaje.includes("too many requests")
    ) {
      return "Se realizaron demasiados intentos en poco tiempo. Espera unos minutos antes de volver a intentarlo.";
    }

    if (
      mensaje.includes("fetch") ||
      mensaje.includes("network") ||
      mensaje.includes("failed to fetch")
    ) {
      return "Error de conexión: comprueba tu acceso a Internet e inténtalo nuevamente.";
    }

    return "No fue posible procesar el restablecimiento de contraseña. Solicita un nuevo enlace desde la aplicación.";
  }

  /**
   * Controlador de estado y flujo para la pagina web de recuperacion de contrasena.
   * Separa la logica de negocio para permitir pruebas automatizadas deterministas.
   */
  class ControladorRecuperacionWeb {
    constructor(opciones) {
      this.clienteAuth = opciones ? opciones.clienteAuth : null;
      this.alCambiarEstado =
        opciones && typeof opciones.alCambiarEstado === "function"
          ? opciones.alCambiarEstado
          : function () {};

      this.estadoActual = "cargando";
      this.mensajeEstado = "Verificando la validez del enlace de recuperación...";
      this.mensajeErrorFormulario = "";
      this.sesionRecuperacionVerificada = false;
      this.procesandoEnvio = false;
    }

    _notificarCambio() {
      this.alCambiarEstado({
        estadoActual: this.estadoActual,
        mensajeEstado: this.mensajeEstado,
        mensajeErrorFormulario: this.mensajeErrorFormulario,
        sesionRecuperacionVerificada: this.sesionRecuperacionVerificada,
        procesandoEnvio: this.procesandoEnvio
      });
    }

    /**
     * Verifica el enlace de recuperacion mediante `verifyOtp({ token_hash, type: 'recovery' })`.
     */
    async verificarEnlaceInicial(parametros) {
      this.estadoActual = "cargando";
      this.mensajeEstado = "Verificando la validez del enlace de recuperación...";
      this.mensajeErrorFormulario = "";
      this.sesionRecuperacionVerificada = false;
      this._notificarCambio();

      if (!this.clienteAuth) {
        this.estadoActual = "enlaceInvalido";
        this.mensajeEstado =
          "La página de recuperación aún no tiene configurada la URL y clave pública de Supabase (configuracion_web.js).";
        this._notificarCambio();
        return false;
      }

      if (parametros && (parametros.error || parametros.codigoError)) {
        this.estadoActual = "enlaceInvalido";
        this.mensajeEstado = traducirErrorRecuperacionWeb(parametros);
        this._notificarCambio();
        return false;
      }

      if (
        !parametros ||
        !parametros.tokenHash ||
        parametros.tipo !== "recovery"
      ) {
        this.estadoActual = "enlaceInvalido";
        this.mensajeEstado =
          "Acceso inválido o enlace incompleto. Para restablecer tu contraseña, solicita un enlace desde la aplicación móvil Patitas ESPOCH y ábrelo desde tu correo institucional.";
        this._notificarCambio();
        return false;
      }

      try {
        const respuesta = await this.clienteAuth.verifyOtp({
          token_hash: parametros.tokenHash,
          type: "recovery"
        });

        if (respuesta && respuesta.error) {
          this.estadoActual = "enlaceInvalido";
          this.mensajeEstado = traducirErrorRecuperacionWeb(respuesta.error);
          this._notificarCambio();
          return false;
        }

        const sesion = respuesta && respuesta.data ? respuesta.data.session : null;
        if (!sesion || !sesion.access_token) {
          this.estadoActual = "enlaceInvalido";
          this.mensajeEstado =
            "No se pudo establecer una sesión válida de recuperación. Solicita un nuevo enlace desde la aplicación.";
          this._notificarCambio();
          return false;
        }

        this.sesionRecuperacionVerificada = true;
        this.estadoActual = "formularioActivo";
        this.mensajeEstado = "";
        this._notificarCambio();
        return true;
      } catch (errorCapturado) {
        this.estadoActual = "enlaceInvalido";
        this.mensajeEstado = traducirErrorRecuperacionWeb(errorCapturado);
        this._notificarCambio();
        return false;
      }
    }

    /**
     * Valida y actualiza la contrasena en Supabase Auth si existe una sesion de recuperacion valida,
     * bloqueando envios duplicados y cerrando la sesion temporal al finalizar.
     */
    async guardarNuevaContrasena(nuevaContrasena, confirmarContrasena) {
      if (this.procesandoEnvio) {
        return false;
      }

      if (
        !this.sesionRecuperacionVerificada ||
        this.estadoActual !== "formularioActivo"
      ) {
        this.estadoActual = "enlaceInvalido";
        this.mensajeEstado =
          "La sesión de recuperación no es válida o ya expiró. Solicita un nuevo enlace desde la aplicación.";
        this._notificarCambio();
        return false;
      }

      const validacion = validarPoliticaContrasena(
        nuevaContrasena,
        confirmarContrasena
      );
      if (!validacion.esValida) {
        this.mensajeErrorFormulario = validacion.mensaje;
        this._notificarCambio();
        return false;
      }

      this.procesandoEnvio = true;
      this.mensajeErrorFormulario = "";
      this._notificarCambio();

      try {
        const respuesta = await this.clienteAuth.updateUser({
          password: nuevaContrasena
        });

        if (respuesta && respuesta.error) {
          this.procesandoEnvio = false;
          this.mensajeErrorFormulario = traducirErrorRecuperacionWeb(
            respuesta.error
          );
          this._notificarCambio();
          return false;
        }

        try {
          await this.clienteAuth.signOut({ scope: "local" });
        } catch (_) {
          // La sesion en memoria queda descartada igualmente al cerrar el flujo.
        }

        this.sesionRecuperacionVerificada = false;
        this.procesandoEnvio = false;
        this.estadoActual = "exito";
        this.mensajeEstado =
          "Tu contraseña institucional se actualizó correctamente. Ya puedes cerrar esta página, regresar a la aplicación móvil Patitas ESPOCH e iniciar sesión con tu nueva clave.";
        this._notificarCambio();
        return true;
      } catch (errorCapturado) {
        this.procesandoEnvio = false;
        this.mensajeErrorFormulario =
          traducirErrorRecuperacionWeb(errorCapturado);
        this._notificarCambio();
        return false;
      }
    }
  }

  /**
   * Conecta el controlador con los elementos del DOM cuando se ejecuta en el navegador.
   */
  function inicializarPaginaRecuperacion(objetoVentana) {
    const doc = objetoVentana.document;
    if (!doc) return;

    const bloqueCargando = doc.getElementById("bloque-cargando");
    const textoCargando = doc.getElementById("texto-cargando");
    const bloqueEnlaceInvalido = doc.getElementById("bloque-enlace-invalido");
    const textoEnlaceInvalido = doc.getElementById("texto-enlace-invalido");
    const bloqueFormulario = doc.getElementById("bloque-formulario");
    const formularioRecuperacion = doc.getElementById("formulario-recuperacion");
    const inputNuevaContrasena = doc.getElementById("input-nueva-contrasena");
    const inputConfirmarContrasena = doc.getElementById(
      "input-confirmar-contrasena"
    );
    const botonVisibilidadNueva = doc.getElementById("boton-visibilidad-nueva");
    const botonVisibilidadConfirmacion = doc.getElementById(
      "boton-visibilidad-confirmacion"
    );
    const cajaErrorFormulario = doc.getElementById("caja-error-formulario");
    const botonGuardarContrasena = doc.getElementById(
      "boton-guardar-contrasena"
    );
    const bloqueExito = doc.getElementById("bloque-exito");
    const textoExito = doc.getElementById("texto-exito");

    const parametros = extraerParametrosRecuperacion(
      objetoVentana.location.search,
      objetoVentana.location.hash
    );

    if (parametros.tieneParametrosSensibles) {
      limpiarUrlSensible(objetoVentana);
    }

    const configuracion = objetoVentana.CONFIGURACION_SUPABASE_PATITAS || {};
    const urlSupabase = String(configuracion.urlSupabase || "").trim();
    const clavePublicaSupabase = String(
      configuracion.clavePublicaSupabase || ""
    ).trim();

    let clienteAuth = null;
    if (
      urlSupabase.length > 0 &&
      clavePublicaSupabase.length > 0 &&
      objetoVentana.supabase &&
      typeof objetoVentana.supabase.createClient === "function"
    ) {
      const clienteSupabase = objetoVentana.supabase.createClient(
        urlSupabase,
        clavePublicaSupabase,
        {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUrl: false
          }
        }
      );
      clienteAuth = clienteSupabase.auth;
    }

    function renderizarEstado(estado) {
      bloqueCargando.classList.toggle(
        "oculto",
        estado.estadoActual !== "cargando"
      );
      bloqueEnlaceInvalido.classList.toggle(
        "oculto",
        estado.estadoActual !== "enlaceInvalido"
      );
      bloqueFormulario.classList.toggle(
        "oculto",
        estado.estadoActual !== "formularioActivo"
      );
      bloqueExito.classList.toggle("oculto", estado.estadoActual !== "exito");

      if (estado.estadoActual === "cargando" && textoCargando) {
        textoCargando.textContent = estado.mensajeEstado;
      }

      if (estado.estadoActual === "enlaceInvalido" && textoEnlaceInvalido) {
        textoEnlaceInvalido.textContent = estado.mensajeEstado;
      }

      if (estado.estadoActual === "exito" && textoExito) {
        textoExito.textContent = estado.mensajeEstado;
      }

      if (cajaErrorFormulario) {
        if (estado.mensajeErrorFormulario) {
          cajaErrorFormulario.textContent = estado.mensajeErrorFormulario;
          cajaErrorFormulario.classList.remove("oculto");
        } else {
          cajaErrorFormulario.textContent = "";
          cajaErrorFormulario.classList.add("oculto");
        }
      }

      const deshabilitarControles =
        estado.procesandoEnvio || estado.estadoActual !== "formularioActivo";
      if (inputNuevaContrasena) {
        inputNuevaContrasena.disabled = deshabilitarControles;
      }
      if (inputConfirmarContrasena) {
        inputConfirmarContrasena.disabled = deshabilitarControles;
      }
      if (botonVisibilidadNueva) {
        botonVisibilidadNueva.disabled = deshabilitarControles;
      }
      if (botonVisibilidadConfirmacion) {
        botonVisibilidadConfirmacion.disabled = deshabilitarControles;
      }
      if (botonGuardarContrasena) {
        botonGuardarContrasena.disabled = deshabilitarControles;
        botonGuardarContrasena.textContent = estado.procesandoEnvio
          ? "Guardando nueva contraseña..."
          : "Guardar nueva contraseña";
      }
    }

    const controlador = new ControladorRecuperacionWeb({
      clienteAuth: clienteAuth,
      alCambiarEstado: renderizarEstado
    });

    function configurarBotonVisibilidad(boton, campoInput) {
      if (!boton || !campoInput) return;
      boton.addEventListener("click", function () {
        const ocultoActualmente = campoInput.type === "password";
        campoInput.type = ocultoActualmente ? "text" : "password";
        boton.textContent = ocultoActualmente ? "Ocultar" : "Mostrar";
        boton.setAttribute(
          "aria-label",
          ocultoActualmente ? "Ocultar contraseña" : "Mostrar contraseña"
        );
      });
    }

    configurarBotonVisibilidad(botonVisibilidadNueva, inputNuevaContrasena);
    configurarBotonVisibilidad(
      botonVisibilidadConfirmacion,
      inputConfirmarContrasena
    );

    if (formularioRecuperacion) {
      formularioRecuperacion.addEventListener("submit", function (evento) {
        evento.preventDefault();
        controlador.guardarNuevaContrasena(
          inputNuevaContrasena ? inputNuevaContrasena.value : "",
          inputConfirmarContrasena ? inputConfirmarContrasena.value : ""
        );
      });
    }

    controlador.verificarEnlaceInicial(parametros);
  }

  const exportaciones = {
    LONGITUD_MINIMA_CONTRASENA: LONGITUD_MINIMA_CONTRASENA,
    REQUISITOS_CONTRASENA: REQUISITOS_CONTRASENA,
    SIMBOLOS_CONTRASENA: SIMBOLOS_CONTRASENA,
    extraerParametrosRecuperacion: extraerParametrosRecuperacion,
    limpiarUrlSensible: limpiarUrlSensible,
    validarPoliticaContrasena: validarPoliticaContrasena,
    traducirErrorRecuperacionWeb: traducirErrorRecuperacionWeb,
    ControladorRecuperacionWeb: ControladorRecuperacionWeb,
    inicializarPaginaRecuperacion: inicializarPaginaRecuperacion
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = exportaciones;
  }

  if (globalScope && typeof globalScope.addEventListener === "function" && globalScope.document) {
    globalScope.PatitasRecuperacionWeb = exportaciones;
    if (globalScope.document.readyState === "loading") {
      globalScope.document.addEventListener("DOMContentLoaded", function () {
        inicializarPaginaRecuperacion(globalScope);
      });
    } else {
      inicializarPaginaRecuperacion(globalScope);
    }
  }
})(typeof window !== "undefined" ? window : globalThis);

