import { manejarIdentificacion } from './manejador.mjs';

Deno.serve((peticion: Request) => manejarIdentificacion(peticion, {
  url: Deno.env.get('SUPABASE_URL'),
  anon: Deno.env.get('SUPABASE_ANON_KEY'),
  servicio: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  nube: Deno.env.get('CLOUDINARY_CLOUD_NAME'),
  claveGemini: Deno.env.get('GEMINI_API_KEY'),
  modelo: Deno.env.get('GEMINI_MODEL'),
  solicitar: fetch,
}));
