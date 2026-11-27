import { timingSafeEqual } from 'node:crypto';
import { createClient } from 'npm:@supabase/supabase-js@2';

interface AvisoReclamado {
  id_sincronizacion: string;
  id_incidencia: string;
}

interface ResultadoTelegram {
  idMensaje: number | null;
  error: string | null;
}

const codificador = new TextEncoder();

function autorizar(solicitud: Request): boolean {
  const esperado = Deno.env.get('PATITAS_TELEGRAM_CRON_SECRET') ?? '';
  const recibido = solicitud.headers.get('x-patitas-telegram-secret') ?? '';
  if (esperado.length < 32) return false;

  const claveEsperada = codificador.encode(esperado);
  const claveRecibida = codificador.encode(recibido);
  return claveEsperada.length === claveRecibida.length &&
    timingSafeEqual(claveRecibida, claveEsperada);
}

async function enviarAviso(
  token: string, idGrupo: string, idIncidencia: string,
): Promise<ResultadoTelegram> {
  try {
    const respuesta = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: idGrupo,
        text: `Patitas ESPOCH | Prueba I04\nIncidencia reportada: ${idIncidencia}`,
        reply_markup: {
          inline_keyboard: [[{ text: 'En atención', callback_data: `i04:a:${idIncidencia}` }]],
        },
      }),
      signal: AbortSignal.timeout(8000),
    });
    if (!respuesta.ok) {
      return { idMensaje: null, error: `telegram_http_${respuesta.status}` };
    }

    const datos = await respuesta.json();
    const idMensaje: unknown = datos?.result?.message_id;
    if (datos?.ok === true && typeof idMensaje === 'number' &&
        Number.isSafeInteger(idMensaje) && idMensaje > 0) {
      return { idMensaje, error: null };
    }
    return { idMensaje: null, error: 'telegram_respuesta_inesperada' };
  } catch {
    // Si no se conoce el resultado del proveedor, el piloto no reenvía el aviso.
    return { idMensaje: null, error: 'telegram_resultado_desconocido' };
  }
}

Deno.serve(async (solicitud) => {
  if (solicitud.method !== 'POST') {
    return Response.json({ error: 'Usa POST.' }, { status: 405 });
  }
  if (!autorizar(solicitud)) {
    return Response.json({ error: 'Acceso restringido.' }, { status: 403 });
  }

  const token = Deno.env.get('TELEGRAM_BOT_TOKEN');
  const idGrupo = Deno.env.get('TELEGRAM_CHAT_ID');
  const idReportante = Deno.env.get('TELEGRAM_REPORTANTE_PRUEBA_ID');
  const url = Deno.env.get('SUPABASE_URL');
  const claveServicio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!token || !idGrupo || !idReportante || !url || !claveServicio) {
    return Response.json({ error: 'Falta configurar el piloto I04.' }, { status: 500 });
  }

  const cliente = createClient(url, claveServicio, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error: errorReclamo } = await cliente
    .rpc('reclamar_aviso_telegram_piloto', { p_id_reportante: idReportante });
  if (errorReclamo) {
    return Response.json({ error: 'No se pudo reclamar un aviso.' }, { status: 500 });
  }
  const aviso: AvisoReclamado | undefined = data?.[0];
  if (!aviso) return Response.json({ enviados: 0 });

  const resultado = await enviarAviso(token, idGrupo, aviso.id_incidencia);
  const { data: registrado, error: errorRegistro } = await cliente
    .rpc('finalizar_aviso_telegram_piloto', {
      p_id_sincronizacion: aviso.id_sincronizacion,
      p_id_mensaje: resultado.idMensaje,
      p_error: resultado.error,
    });
  if (errorRegistro || registrado !== true) {
    return Response.json({ error: 'No se pudo cerrar el registro del aviso.' }, { status: 500 });
  }
  if (resultado.idMensaje === null) {
    return Response.json({ enviados: 0, error: resultado.error }, { status: 502 });
  }
  return Response.json({ enviados: 1, id_incidencia: aviso.id_incidencia });
});
