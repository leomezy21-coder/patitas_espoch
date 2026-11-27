import { timingSafeEqual } from 'node:crypto';
import { createClient } from 'npm:@supabase/supabase-js@2';

interface ActualizacionTelegram {
  callback_query?: {
    id?: unknown;
    from?: { id?: unknown };
    message?: { message_id?: unknown; chat?: { id?: unknown } };
    data?: unknown;
  };
}

const codificador = new TextEncoder();
const formatoAccion = /^i04:([ar]):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/;

function autorizarWebhook(peticion: Request): boolean {
  const secreto = Deno.env.get('TELEGRAM_WEBHOOK_SECRET') ?? '';
  if (secreto.length < 32) return false;

  const esperado = codificador.encode(secreto);
  const recibido = codificador.encode(
    peticion.headers.get('x-telegram-bot-api-secret-token') ?? '',
  );
  return esperado.length === recibido.length && timingSafeEqual(esperado, recibido);
}

function esIdPositivo(valor: unknown): valor is number {
  return typeof valor === 'number' && Number.isSafeInteger(valor) && valor > 0;
}

async function llamarTelegram(
  token: string,
  operacion: 'answerCallbackQuery' | 'editMessageReplyMarkup',
  parametros: Record<string, unknown>,
): Promise<boolean> {
  try {
    const respuesta = await fetch(`https://api.telegram.org/bot${token}/${operacion}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(parametros),
      signal: AbortSignal.timeout(5000),
    });
    const datos = await respuesta.json();
    if (respuesta.ok && datos?.ok === true) return true;

    // Una entrega repetida puede encontrar el teclado ya actualizado.
    return operacion === 'editMessageReplyMarkup' && respuesta.status === 400 &&
      typeof datos?.description === 'string' && datos.description.includes('message is not modified');
  } catch {
    return false;
  }
}

Deno.serve(async (peticion) => {
  if (peticion.method !== 'POST') {
    return Response.json({ error: 'Usa POST.' }, { status: 405 });
  }
  if (!autorizarWebhook(peticion)) {
    return Response.json({ error: 'Acceso restringido.' }, { status: 403 });
  }

  const token = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const idGrupo = Deno.env.get('TELEGRAM_CHAT_ID');
  const url = Deno.env.get('SUPABASE_URL');
  const claveServicio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!token || !idGrupo || !url || !claveServicio) {
    return Response.json({ error: 'Falta configurar el webhook I04.' }, { status: 500 });
  }

  let actualizacion: ActualizacionTelegram | null;
  try {
    actualizacion = await peticion.json();
  } catch {
    return Response.json({ error: 'Solicitud inválida.' }, { status: 400 });
  }
  const consulta = actualizacion?.callback_query;
  const idConsulta = consulta?.id;
  if (typeof idConsulta !== 'string' || idConsulta.length === 0) {
    return Response.json({ recibido: true });
  }

  const accion = typeof consulta?.data === 'string' ? formatoAccion.exec(consulta.data) : null;
  const idMensaje = consulta?.message?.message_id;
  const idTelegram = consulta?.from?.id;
  if (!accion || !esIdPositivo(idMensaje) || !esIdPositivo(idTelegram) ||
      String(consulta?.message?.chat?.id) !== idGrupo) {
    await llamarTelegram(token, 'answerCallbackQuery', {
      callback_query_id: idConsulta, text: 'Esta acción no está disponible.', show_alert: true,
    });
    return Response.json({ recibido: true });
  }

  const pasarAAtencion = accion[1] === 'a';
  const idIncidencia = accion[2];
  const cliente = createClient(url, claveServicio, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: estado, error } = await cliente.rpc('actualizar_incidencia_desde_telegram', {
    p_id_incidencia: idIncidencia,
    p_id_mensaje: idMensaje,
    p_telegram_user_id: idTelegram,
    p_estado_esperado: pasarAAtencion ? 'reportada' : 'en_atencion',
    p_nuevo_estado: pasarAAtencion ? 'en_atencion' : 'resuelta',
  });
  if (error) {
    const rechazo = ['42501', '22023', '40001'].includes(error.code);
    await llamarTelegram(token, 'answerCallbackQuery', {
      callback_query_id: idConsulta,
      text: rechazo ? 'Acción no disponible para tu cuenta o para esta incidencia.' :
        'No se pudo confirmar el cambio. Comprueba el estado en Patitas ESPOCH.',
      show_alert: true,
    });
    return Response.json({ recibido: true }, { status: rechazo ? 200 : 502 });
  }
  if (estado !== 'en_atencion' && estado !== 'resuelta') {
    return Response.json({ error: 'Estado inesperado.' }, { status: 502 });
  }

  const respondido = llamarTelegram(token, 'answerCallbackQuery', {
    callback_query_id: idConsulta,
    text: estado === 'resuelta' ? 'Estado actual: Resuelta.' : 'Estado actual: En atención.',
  });
  const tecladoActualizado = llamarTelegram(token, 'editMessageReplyMarkup', {
    chat_id: idGrupo,
    message_id: idMensaje,
    reply_markup: {
      inline_keyboard: estado === 'en_atencion'
        ? [[{ text: 'Resolver', callback_data: `i04:r:${idIncidencia}` }]]
        : [],
    },
  });
  const [, actualizado] = await Promise.all([respondido, tecladoActualizado]);
  return Response.json({ recibido: true, estado }, { status: actualizado ? 200 : 502 });
});
