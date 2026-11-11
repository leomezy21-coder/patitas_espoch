const pruebita = require("node:test");
const afirmar = require("node:assert/strict");

const {
  extraerParametrosRecuperacion,
  limpiarUrlSensible,
  validarPoliticaContrasena,
  traducirErrorRecuperacionWeb,
  REQUISITOS_CONTRASENA,
  SIMBOLOS_CONTRASENA,
  ControladorRecuperacionWeb,
  inicializarPaginaRecuperacion
} = require("../web_recuperacion/recuperacion_contrasena.js");

/**
 * Crea un cliente simulado de Supabase Auth que modela el comportamiento real de
 * `verifyOtp({ token_hash, type: 'recovery' })` (token de un solo uso, sin requerir PKCE code_verifier),
 * `updateUser` y `signOut`.
 */
function crearClienteAuthSimulado({
  tokensValidos = ["hash_valido_flutter_123"],
  tokensVencidos = ["hash_vencido_999"]
} = {}) {
  const tokensDisponibles = new Set(tokensValidos);
  const tokensExpirados = new Set(tokensVencidos);
  const tokensConsumidos = new Set();

  let sesionEnMemoria = null;
  let llamadasVerifyOtp = 0;
  let llamadasUpdateUser = 0;
  let llamadasSignOut = 0;
  let ultimaContrasenaActualizada = null;

  return {
    get estadoInterno() {
      return {
        sesionEnMemoria,
        llamadasVerifyOtp,
        llamadasUpdateUser,
        llamadasSignOut,
        ultimaContrasenaActualizada
      };
    },
    async verifyOtp({ token_hash: tokenHash, type: tipo }) {
      llamadasVerifyOtp += 1;

      if (tipo !== "recovery" || !tokenHash) {
        return {
          data: { session: null, user: null },
          error: { code: "validation_failed", message: "Invalid recovery params" }
        };
      }

      if (tokensExpirados.has(tokenHash)) {
        return {
          data: { session: null, user: null },
          error: { code: "otp_expired", message: "Email link is invalid or has expired" }
        };
      }

      if (tokensConsumidos.has(tokenHash)) {
        return {
          data: { session: null, user: null },
          error: { code: "otp_expired", message: "Token has already been used or expired" }
        };
      }

      if (!tokensDisponibles.has(tokenHash)) {
        return {
          data: { session: null, user: null },
          error: { code: "otp_expired", message: "Invalid token_hash" }
        };
      }

      // El TokenHash es de un solo uso: se consume al verificarse
      tokensDisponibles.delete(tokenHash);
      tokensConsumidos.add(tokenHash);

      sesionEnMemoria = {
        access_token: "jwt_temporal_recuperacion",
        token_type: "bearer",
        user: { email: "estudiante@espoch.edu.ec" }
      };

      return {
        data: { session: sesionEnMemoria, user: sesionEnMemoria.user },
        error: null
      };
    },

    async updateUser({ password: nuevaContrasena }) {
      llamadasUpdateUser += 1;
      if (!sesionEnMemoria) {
        return {
          data: { user: null },
          error: { code: "session_not_found", message: "Auth session missing" }
        };
      }

      ultimaContrasenaActualizada = nuevaContrasena;
      return {
        data: { user: sesionEnMemoria.user },
        error: null
      };
    },

    async signOut() {
      llamadasSignOut += 1;
      sesionEnMemoria = null;
      return { error: null };
    }
  };
}

pruebita("1. Acceso directo sin enlace: rechaza la vista y no habilita el formulario", async () => {
  const clienteAuth = crearClienteAuthSimulado();
  const controlador = new ControladorRecuperacionWeb({ clienteAuth });

  const parametros = extraerParametrosRecuperacion("", "");
  afirmar.equal(parametros.tokenHash, "");
  afirmar.equal(parametros.tieneParametrosSensibles, false);

  const verificado = await controlador.verificarEnlaceInicial(parametros);
  afirmar.equal(verificado, false);
  afirmar.equal(controlador.estadoActual, "enlaceInvalido");
  afirmar.equal(controlador.sesionRecuperacionVerificada, false);
  afirmar.equal(clienteAuth.estadoInterno.llamadasVerifyOtp, 0);

  // Intentar guardar contrasena sin sesion verificada debe fallar
  const guardado = await controlador.guardarNuevaContrasena(
    "NuevaClave2026!",
    "NuevaClave2026!"
  );
  afirmar.equal(guardado, false);
  afirmar.equal(clienteAuth.estadoInterno.llamadasUpdateUser, 0);
});

pruebita("2. Enlace vencido: muestra estado de enlace vencido y bloquea el cambio", async () => {
  const clienteAuth = crearClienteAuthSimulado();
  const controlador = new ControladorRecuperacionWeb({ clienteAuth });

  const parametros = extraerParametrosRecuperacion(
    "?token_hash=hash_vencido_999&type=recovery",
    ""
  );
  const verificado = await controlador.verificarEnlaceInicial(parametros);

  afirmar.equal(verificado, false);
  afirmar.equal(controlador.estadoActual, "enlaceInvalido");
  afirmar.equal(controlador.sesionRecuperacionVerificada, false);
  afirmar.match(controlador.mensajeEstado, /vencido o ya fue utilizado/i);
});

pruebita("3. Enlace reutilizado: el segundo intento con el mismo token_hash es rechazado", async () => {
  const clienteAuth = crearClienteAuthSimulado({
    tokensValidos: ["token_unico_espoch"]
  });

  const parametros = extraerParametrosRecuperacion(
    "?token_hash=token_unico_espoch&type=recovery",
    ""
  );

  // Primer uso: valido
  const controladorPrimero = new ControladorRecuperacionWeb({ clienteAuth });
  const primerUso = await controladorPrimero.verificarEnlaceInicial(parametros);
  afirmar.equal(primerUso, true);
  afirmar.equal(controladorPrimero.estadoActual, "formularioActivo");

  // Segundo uso del mismo enlace (recarga o reapertura): rechazado por ser de un solo uso
  const controladorSegundo = new ControladorRecuperacionWeb({ clienteAuth });
  const segundoUso = await controladorSegundo.verificarEnlaceInicial(parametros);
  afirmar.equal(segundoUso, false);
  afirmar.equal(controladorSegundo.estadoActual, "enlaceInvalido");
  afirmar.equal(controladorSegundo.sesionRecuperacionVerificada, false);
  afirmar.match(controladorSegundo.mensajeEstado, /vencido o ya fue utilizado/i);
});

pruebita("4. Recuperacion iniciada en Flutter y completada en otro navegador sin verificador PKCE", async () => {
  const clienteAuth = crearClienteAuthSimulado({
    tokensValidos: ["hash_generado_desde_flutter"]
  });
  const controlador = new ControladorRecuperacionWeb({ clienteAuth });

  // Simula ventana del navegador con URL que contiene token_hash sensible
  let urlReemplazada = null;
  const ventanaSimulada = {
    location: {
      pathname: "/web_recuperacion/index.html",
      search: "?token_hash=hash_generado_desde_flutter&type=recovery",
      hash: ""
    },
    document: { title: "Patitas ESPOCH" },
    history: {
      replaceState(_estado, _titulo, nuevaRuta) {
        urlReemplazada = nuevaRuta;
      }
    }
  };

  const parametros = extraerParametrosRecuperacion(
    ventanaSimulada.location.search,
    ventanaSimulada.location.hash
  );
  afirmar.equal(parametros.tieneParametrosSensibles, true);

  limpiarUrlSensible(ventanaSimulada);
  afirmar.equal(urlReemplazada, "/web_recuperacion/index.html");

  const verificado = await controlador.verificarEnlaceInicial(parametros);
  afirmar.equal(verificado, true);
  afirmar.equal(controlador.estadoActual, "formularioActivo");
  afirmar.equal(controlador.sesionRecuperacionVerificada, true);

  // Comprueba validaciones de politica de contrasena antes de enviar
  const intentoCorto = await controlador.guardarNuevaContrasena("12345", "12345");
  afirmar.equal(intentoCorto, false);
  afirmar.match(controlador.mensajeErrorFormulario, /al menos 8 caracteres/i);

  const intentoDesigual = await controlador.guardarNuevaContrasena(
    "ClaveSegura2026!",
    "OtraClave2026!"
  );
  afirmar.equal(intentoDesigual, false);
  afirmar.match(controlador.mensajeErrorFormulario, /no coinciden/i);

  // Actualizacion exitosa y cierre de sesion temporal en el navegador
  const actualizado = await controlador.guardarNuevaContrasena(
    "ClaveSegura2026!",
    "ClaveSegura2026!"
  );
  afirmar.equal(actualizado, true);
  afirmar.equal(controlador.estadoActual, "exito");
  afirmar.equal(controlador.sesionRecuperacionVerificada, false);
  afirmar.equal(
    clienteAuth.estadoInterno.ultimaContrasenaActualizada,
    "ClaveSegura2026!"
  );
  afirmar.equal(clienteAuth.estadoInterno.llamadasSignOut, 1);
  afirmar.equal(clienteAuth.estadoInterno.sesionEnMemoria, null);
});

pruebita("5. Bloqueo de envios duplicados durante la actualizacion de contrasena", async () => {
  let resolverActualizacion;
  const clienteAuthLento = {
    async verifyOtp() {
      return {
        data: { session: { access_token: "jwt_valido" } },
        error: null
      };
    },
    updateUser: () =>
      new Promise((resolve) => {
        resolverActualizacion = resolve;
      }),
    async signOut() {
      return { error: null };
    }
  };

  const controlador = new ControladorRecuperacionWeb({
    clienteAuth: clienteAuthLento
  });

  await controlador.verificarEnlaceInicial({
    tokenHash: "token_lento",
    tipo: "recovery"
  });

  const primeraPromesa = controlador.guardarNuevaContrasena(
    "ClaveUnica2026!",
    "ClaveUnica2026!"
  );
  afirmar.equal(controlador.procesandoEnvio, true);

  // Un segundo clic inmediato debe ser rechazado mientras procesandoEnvio es true
  const segundoIntentoDuplicado = await controlador.guardarNuevaContrasena(
    "ClaveUnica2026!",
    "ClaveUnica2026!"
  );
  afirmar.equal(segundoIntentoDuplicado, false);

  resolverActualizacion({ data: { user: { id: "1" } }, error: null });
  const resultadoPrimero = await primeraPromesa;
  afirmar.equal(resultadoPrimero, true);
  afirmar.equal(controlador.procesandoEnvio, false);
  afirmar.equal(controlador.estadoActual, "exito");
});

pruebita("6. Funcion validarPoliticaContrasena verifica casos borde", () => {
  afirmar.equal(validarPoliticaContrasena("", "").esValida, false);
  afirmar.equal(validarPoliticaContrasena("1234567", "1234567").esValida, false);
  afirmar.equal(
    validarPoliticaContrasena("12345678", "87654321").esValida,
    false
  );
  const casos = [
    [null, false],
    ["12345678", false],
    ["abcdefg1!", false],
    ["ABCDEFG1!", false],
    ["Abcdefgh!", false],
    ["Abcdefg1", false],
    ["Abcdef1 ", false],
    ["Abcdef1é", false],
    ["Abcdef1🙂", false],
    ["Ab1!🙂🙂🙂", false],
    ["Abcdef1!", true],
    ["  Abcd1!", true],
    ["Ab1!🙂🙂🙂🙂", true],
    ["Ab1!" + "x".repeat(68), true],
    ["Ab1!" + "x".repeat(69), false],
    ["Ab1!" + "é".repeat(35), false]
  ];
  for (const [clave, esValida] of casos) {
    afirmar.equal(validarPoliticaContrasena(clave, clave).esValida, esValida);
  }
  for (const simbolo of SIMBOLOS_CONTRASENA) {
    const clave = "Abcdef1" + simbolo;
    afirmar.equal(validarPoliticaContrasena(clave, clave).esValida, true);
  }
  afirmar.equal(validarPoliticaContrasena("Abcdef1!", "").esValida, false);
  afirmar.equal(validarPoliticaContrasena("Abcdef1! ", "Abcdef1!").esValida, false);
});

pruebita("7. Integracion DOM: mostrar/ocultar contrasena, limpieza de URL y actualizacion completa", async () => {
  function crearElementoSimulado(id, tipoInicial = "") {
    const clases = new Set(["oculto"]);
    const oyentes = {};
    const atributos = {};
    return {
      id,
      type: tipoInicial,
      value: "",
      textContent: "",
      disabled: false,
      classList: {
        add(c) {
          clases.add(c);
        },
        remove(c) {
          clases.delete(c);
        },
        toggle(c, forzar) {
          if (forzar) clases.add(c);
          else clases.delete(c);
        },
        contains(c) {
          return clases.has(c);
        }
      },
      addEventListener(evento, fn) {
        oyentes[evento] = fn;
      },
      setAttribute(nombre, valor) {
        atributos[nombre] = valor;
      },
      disparar(evento, arg = {}) {
        if (oyentes[evento]) oyentes[evento](arg);
      }
    };
  }

  const elementos = {
    "bloque-cargando": crearElementoSimulado("bloque-cargando"),
    "texto-cargando": crearElementoSimulado("texto-cargando"),
    "bloque-enlace-invalido": crearElementoSimulado("bloque-enlace-invalido"),
    "texto-enlace-invalido": crearElementoSimulado("texto-enlace-invalido"),
    "bloque-formulario": crearElementoSimulado("bloque-formulario"),
    "formulario-recuperacion": crearElementoSimulado("formulario-recuperacion"),
    "input-nueva-contrasena": crearElementoSimulado("input-nueva-contrasena", "password"),
    "input-confirmar-contrasena": crearElementoSimulado("input-confirmar-contrasena", "password"),
    "boton-visibilidad-nueva": crearElementoSimulado("boton-visibilidad-nueva"),
    "boton-visibilidad-confirmacion": crearElementoSimulado("boton-visibilidad-confirmacion"),
    "caja-error-formulario": crearElementoSimulado("caja-error-formulario"),
    "boton-guardar-contrasena": crearElementoSimulado("boton-guardar-contrasena"),
    "bloque-exito": crearElementoSimulado("bloque-exito"),
    "texto-exito": crearElementoSimulado("texto-exito")
  };

  const clienteAuth = crearClienteAuthSimulado({
    tokensValidos: ["token_dom_123"]
  });

  let rutaLimpiada = null;
  const ventanaSimulada = {
    location: {
      pathname: "/restablecer",
      search: "?token_hash=token_dom_123&type=recovery",
      hash: ""
    },
    history: {
      replaceState(_estado, _titulo, ruta) {
        rutaLimpiada = ruta;
      }
    },
    document: {
      title: "Patitas ESPOCH",
      readyState: "complete",
      getElementById(id) {
        return elementos[id] || null;
      }
    },
    CONFIGURACION_SUPABASE_PATITAS: {
      urlSupabase: "https://ejemplo.supabase.co",
      clavePublicaSupabase: "clave_publica_ejemplo"
    },
    supabase: {
      createClient() {
        return { auth: clienteAuth };
      }
    }
  };

  inicializarPaginaRecuperacion(ventanaSimulada);

  // Espera al microtask de verificarEnlaceInicial
  await new Promise((r) => setTimeout(r, 15));

  afirmar.equal(rutaLimpiada, "/restablecer");
  afirmar.equal(elementos["bloque-formulario"].classList.contains("oculto"), false);
  afirmar.equal(elementos["bloque-cargando"].classList.contains("oculto"), true);

  // Prueba alternar mostrar/ocultar contrasena
  elementos["boton-visibilidad-nueva"].disparar("click");
  afirmar.equal(elementos["input-nueva-contrasena"].type, "text");
  afirmar.equal(elementos["boton-visibilidad-nueva"].textContent, "Ocultar");

  elementos["boton-visibilidad-nueva"].disparar("click");
  afirmar.equal(elementos["input-nueva-contrasena"].type, "password");
  afirmar.equal(elementos["boton-visibilidad-nueva"].textContent, "Mostrar");

  // Envia el formulario con contrasena valida
  elementos["input-nueva-contrasena"].value = "ClaveInstitucional2026!";
  elementos["input-confirmar-contrasena"].value = "ClaveInstitucional2026!";
  elementos["formulario-recuperacion"].disparar("submit", {
    preventDefault() {}
  });

  await new Promise((r) => setTimeout(r, 15));

  afirmar.equal(elementos["bloque-exito"].classList.contains("oculto"), false);
  afirmar.equal(elementos["bloque-formulario"].classList.contains("oculto"), true);
  afirmar.equal(clienteAuth.estadoInterno.llamadasSignOut, 1);
});

pruebita("8. Una clave sin cada requisito no llega a updateUser y permite corregir el formulario", async () => {
  const clienteAuth = crearClienteAuthSimulado();
  const controlador = new ControladorRecuperacionWeb({ clienteAuth });
  await controlador.verificarEnlaceInicial({ tokenHash: "hash_valido_flutter_123", tipo: "recovery" });
  for (const clave of ["12345678", "abcdefg1!", "ABCDEFG1!", "Abcdefgh!", "Abcdefg1"]) {
    afirmar.equal(await controlador.guardarNuevaContrasena(clave, clave), false);
    afirmar.equal(controlador.estadoActual, "formularioActivo");
    afirmar.equal(controlador.sesionRecuperacionVerificada, true);
    afirmar.equal(controlador.procesandoEnvio, false);
  }
  afirmar.equal(clienteAuth.estadoInterno.llamadasUpdateUser, 0);
  const claveConEspacios = "  Abcd1!";
  afirmar.equal(await controlador.guardarNuevaContrasena(claveConEspacios, claveConEspacios), true);
  afirmar.equal(clienteAuth.estadoInterno.ultimaContrasenaActualizada, claveConEspacios);
  afirmar.equal(clienteAuth.estadoInterno.llamadasSignOut, 1);
});

pruebita("9. El rechazo weak_password del servidor conserva el formulario y no se confunde con enlace vencido", async () => {
  let intentos = 0;
  let cierres = 0;
  const controlador = new ControladorRecuperacionWeb({ clienteAuth: {
    async verifyOtp() { return { data: { session: { access_token: "sesion_simulada" } }, error: null }; },
    async updateUser() {
      intentos++;
      return intentos === 1
        ? { error: { code: "weak_password", message: "Invalid password: detalle interno" } }
        : { error: null };
    },
    async signOut() { cierres++; return { error: null }; }
  } });
  await controlador.verificarEnlaceInicial({ tokenHash: "hash_simulado", tipo: "recovery" });
  afirmar.equal(await controlador.guardarNuevaContrasena("Abcdef1!", "Abcdef1!"), false);
  afirmar.equal(controlador.mensajeErrorFormulario, REQUISITOS_CONTRASENA);
  afirmar.equal(controlador.estadoActual, "formularioActivo");
  afirmar.equal(controlador.sesionRecuperacionVerificada, true);
  afirmar.equal(controlador.procesandoEnvio, false);
  afirmar.equal(cierres, 0);
  afirmar.equal(await controlador.guardarNuevaContrasena("OtraClave1!", "OtraClave1!"), true);
  afirmar.equal(intentos, 2);
  afirmar.equal(cierres, 1);
  afirmar.equal(traducirErrorRecuperacionWeb({ code: "same_password" }), "La nueva contraseña debe ser diferente a tu contraseña anterior.");
});

pruebita("10. HTML muestra los mismos requisitos y los vincula con el campo de nueva contrasena", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const html = fs.readFileSync(path.join(__dirname, "../web_recuperacion/index.html"), "utf8");
  afirmar.ok(html.includes(REQUISITOS_CONTRASENA));
  afirmar.match(html, /id="requisitos-contrasena"/);
  afirmar.match(html, /aria-describedby="requisitos-contrasena"/);
  afirmar.match(html, /minlength="8"/);
});

