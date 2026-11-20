
import { withSupabase } from "npm:@supabase/server@1";

export default {
  fetch: withSupabase({ auth: "user" }, async (req) => {
    if (req.method !== "POST") {
      return Response.json(
        { error: "Método no permitido" },
        { status: 405 }
      );
    }

    try {
      const { origen, destino } = await req.json();

      const esValido = (p: any) =>
        p &&
        typeof p.lat === "number" &&
        typeof p.lon === "number" &&
        Number.isFinite(p.lat) &&
        Number.isFinite(p.lon) &&
        Math.abs(p.lat) <= 90 &&
        Math.abs(p.lon) <= 180;

      if (!esValido(origen) || !esValido(destino)) {
        return Response.json(
          { error: "Coordenadas inválidas" },
          { status: 400 }
        );
      }

      const apiKey = Deno.env.get("ORS_API_KEY");

      if (!apiKey) {
        throw new Error("ORS_API_KEY no configurada");
      }

      const respuesta = await fetch(
        "https://api.openrouteservice.org/v2/directions/foot-walking/geojson",
        {
          method: "POST",
          headers: {
            Authorization: apiKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            coordinates: [
              [origen.lon, origen.lat],
              [destino.lon, destino.lat],
            ],
          }),
        }
      );

      if (!respuesta.ok) {
        console.error(
          "OpenRouteService respondió:",
          respuesta.status
        );

        return Response.json(
          { error: "No se pudo calcular la ruta" },
          { status: 502 }
        );
      }

      const datos = await respuesta.json();
      const ruta = datos.features?.[0];

      if (!ruta || ruta.geometry?.type !== "LineString") {
        return Response.json(
          { error: "No existe una ruta disponible" },
          { status: 404 }
        );
      }

      const puntos = ruta.geometry.coordinates.map(
        ([lon, lat]: number[]) => [lat, lon]
      );

      return Response.json({
        success: true,
        puntos: puntos,
        distanciaMetros: ruta.properties.summary.distance,
        duracionSegundos: ruta.properties.summary.duration,
      });

    } catch (error) {
      console.error("Error al calcular la ruta:", error);

      return Response.json(
        { error: "Error interno del servicio" },
        { status: 500 }
      );
    }
  }),
};
