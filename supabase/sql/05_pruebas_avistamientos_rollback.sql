-- =============================================================================
-- PRUEBAS DE INTEGRACION POSTGRESQL PARA AVISTAMIENTOS (RF-08, RF-09 y RF-12)
-- Ejecutar en SQL Editor despues de aplicar el script 04.
-- Crea tres usuarios tecnicos temporales SIN contrasena e inicia transaccion.
-- No utiliza ni modifica cuentas reales y finaliza siempre con ROLLBACK.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  g uuid := gen_random_uuid();
  p uuid := gen_random_uuid();
  a uuid := gen_random_uuid();
  an uuid := gen_random_uuid();
  av uuid := gen_random_uuid();
  ts timestamptz := now() - interval '2 minutes';
BEGIN
  PERFORM set_config('patitas_test.general', g::text, true);
  PERFORM set_config('patitas_test.personal', p::text, true);
  PERFORM set_config('patitas_test.admin', a::text, true);
  PERFORM set_config('patitas_test.animal', an::text, true);
  PERFORM set_config('patitas_test.avistamiento', av::text, true);

  INSERT INTO auth.users(id, email)
  VALUES
    (g, g::text || '@espoch.edu.ec'),
    (p, p::text || '@espoch.edu.ec'),
    (a, a::text || '@espoch.edu.ec');

  UPDATE public.perfiles_usuario SET id_rol = 2 WHERE id_usuario = p;
  UPDATE public.perfiles_usuario SET id_rol = 3 WHERE id_usuario = a;

  -- 1. Registrar animal base como usuario general
  PERFORM public.registrar_animal_con_foto(
    g,
    an,
    'Canela Campus',
    'Perro',
    'Mestizo',
    'Hembra',
    'Collar azul de referencia visual',
    'https://res.cloudinary.com/prueba/image/upload/ficha.png',
    'patitas_espoch/animales/' || g::text || '/' || an::text
  );

  -- El registro principal existe incluso si todavia no se ha enviado la foto a Cloudinary.
  PERFORM public.preparar_avistamiento(g, av, an, -1.65440, -78.67990, 8.5, ts,
    'Avistada descansando junto a la entrada principal de la FIE.');
  IF NOT EXISTS (SELECT 1 FROM public.avistamientos WHERE id_avistamiento = av)
     OR EXISTS (SELECT 1 FROM public.fotografias WHERE id_avistamiento = av) THEN
    RAISE EXCEPTION 'No se conserva correctamente el reporte anterior al efecto externo.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.avistamientos WHERE id_avistamiento = av
      AND (dentro_campus IS NOT NULL OR fuera_zona_habitual IS NOT NULL)) THEN
    RAISE EXCEPTION 'Se invento una validacion espacial.';
  END IF;
  BEGIN
    PERFORM public.preparar_avistamiento(g, av, an, 0.0, -78.67990, 8.5, ts, 'Cambio de contenido');
    RAISE EXCEPTION 'Permitio cambiar el contenido de un UUID existente.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  IF has_function_privilege('authenticated',
    'public.preparar_avistamiento(uuid,uuid,uuid,double precision,double precision,numeric,timestamptz,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'El alta privilegiada quedo accesible al cliente.';
  END IF;

  -- 2. Registrar avistamiento con foto y comprobar idempotencia ante reintento
  PERFORM public.registrar_avistamiento_con_foto(
    g,
    av,
    an,
    -1.65440,
    -78.67990,
    8.5,
    ts,
    'Avistada descansando junto a la entrada principal de la FIE.',
    'https://res.cloudinary.com/prueba/image/upload/avistamiento.png',
    'patitas_espoch/avistamientos/' || g::text || '/' || av::text
  );

  PERFORM public.registrar_avistamiento_con_foto(
    g,
    av,
    an,
    -1.65440,
    -78.67990,
    8.5,
    ts,
    'Avistada descansando junto a la entrada principal de la FIE.',
    'https://res.cloudinary.com/prueba/image/upload/avistamiento.png',
    'patitas_espoch/avistamientos/' || g::text || '/' || av::text
  );

  IF (SELECT count(*) FROM public.avistamientos WHERE id_avistamiento = av) <> 1 THEN
    RAISE EXCEPTION 'El reintento duplico el avistamiento.';
  END IF;

  IF (SELECT count(*) FROM public.fotografias WHERE id_avistamiento = av) <> 1 THEN
    RAISE EXCEPTION 'El reintento duplico la fotografia del avistamiento.';
  END IF;

  -- La fotografia principal de la ficha no debe ser reemplazada por la del avistamiento
  IF privado.ficha_animal_json(an)->>'url_fotografia' <> 'https://res.cloudinary.com/prueba/image/upload/ficha.png' THEN
    RAISE EXCEPTION 'La foto del avistamiento altero la foto principal de la ficha.';
  END IF;

  -- La ficha del animal debe reflejar el ultimo avistamiento registrado
  IF coalesce(privado.ficha_animal_json(an)->>'ultimo_avistamiento', '') = '' THEN
    RAISE EXCEPTION 'La ficha del animal no actualizo ultimo_avistamiento.';
  END IF;

  -- 3. Verificar que authenticated no puede ejecutar el alta privilegiada ni insertar directo
  IF has_function_privilege(
    'authenticated',
    'public.registrar_avistamiento_con_foto(uuid,uuid,uuid,double precision,double precision,numeric,timestamptz,text,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'registrar_avistamiento_con_foto quedó expuesta a authenticated.';
  END IF;

  IF has_table_privilege('authenticated', 'public.avistamientos', 'INSERT') THEN
    RAISE EXCEPTION 'INSERT directo en public.avistamientos quedó permitido a authenticated.';
  END IF;

  IF has_function_privilege('anon', 'public.listar_avistamientos_recientes(uuid,integer)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.obtener_avistamiento(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Las consultas quedaron expuestas a usuarios anonimos.';
  END IF;
  IF has_function_privilege('authenticated', 'privado.insertar_fila_avistamiento(uuid,uuid,uuid,double precision,double precision,numeric,text,timestamptz)', 'EXECUTE') THEN
    RAISE EXCEPTION 'El cliente puede invocar la escritura privada.';
  END IF;

  -- 4. Verificar rechazo de coordenadas fuera de rango y de otro usuario con mismo UUID
  BEGIN
    PERFORM public.registrar_avistamiento_con_foto(
      p,
      av,
      an,
      -1.65440,
      -78.67990,
      8.5,
      ts,
      'Intento con UUID ajeno',
      'https://res.cloudinary.com/prueba/image/upload/avistamiento2.png',
      'patitas_espoch/avistamientos/' || p::text || '/' || av::text
    );
    RAISE EXCEPTION 'Permitio reutilizar UUID de avistamiento de otro usuario.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.registrar_avistamiento_con_foto(
      g,
      gen_random_uuid(),
      an,
      -95.0,
      -78.67990,
      8.5,
      ts,
      'Coordenada invalida',
      'https://res.cloudinary.com/prueba/image/upload/avistamiento3.png',
      'patitas_espoch/avistamientos/' || g::text || '/' || gen_random_uuid()::text
    );
    RAISE EXCEPTION 'Permitio latitud fuera de rango.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;

-- 5. Verificar consulta desde los tres roles activos (general, personal, admin)
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test.general'), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_detalle jsonb;
  v_lista jsonb;
BEGIN
  v_detalle := public.obtener_avistamiento(current_setting('patitas_test.avistamiento')::uuid);
  IF v_detalle->>'nombre_animal' <> 'Canela Campus'
     OR abs((v_detalle->>'latitud')::double precision - (-1.65440)) > 0.00001
     OR abs((v_detalle->>'longitud')::double precision - (-78.67990)) > 0.00001
     OR v_detalle->>'url_fotografia' <> 'https://res.cloudinary.com/prueba/image/upload/avistamiento.png'
  THEN
    RAISE EXCEPTION 'El detalle del avistamiento no coincide con los datos guardados.';
  END IF;

  v_lista := public.listar_avistamientos_recientes(current_setting('patitas_test.animal')::uuid, 10);
  IF jsonb_array_length(v_lista) <> 1 THEN
    RAISE EXCEPTION 'listar_avistamientos_recientes no devolvio el avistamiento esperado.';
  END IF;
END $$;

RESET ROLE;

SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test.personal'), true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF public.obtener_avistamiento(current_setting('patitas_test.avistamiento')::uuid)->>'id_animal'
     <> current_setting('patitas_test.animal')
  THEN
    RAISE EXCEPTION 'Personal autorizado no pudo consultar el avistamiento.';
  END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test.admin'), true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF public.obtener_avistamiento(current_setting('patitas_test.avistamiento')::uuid)->>'id_animal'
     <> current_setting('patitas_test.animal')
  THEN
    RAISE EXCEPTION 'Administrador no pudo consultar el avistamiento.';
  END IF;
END $$;
RESET ROLE;

-- 6. Verificar bloqueo de cuenta inactiva al listar u obtener avistamientos
DO $$
BEGIN
  UPDATE public.perfiles_usuario
  SET activo = false
  WHERE id_usuario = current_setting('patitas_test.general')::uuid;
END $$;

SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test.general'), true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  BEGIN
    PERFORM public.listar_avistamientos_recientes();
    RAISE EXCEPTION 'Cuenta inactiva pudo listar avistamientos.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'Pruebas de registro y consulta de avistamientos completadas; se revierte toda fila de prueba.';
END $$;
RESET ROLE;

ROLLBACK;

