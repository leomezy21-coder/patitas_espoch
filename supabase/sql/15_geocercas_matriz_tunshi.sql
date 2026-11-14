-- PATITAS ESPOCH — RF-10/RF-11: Matriz + área delimitada de Tunshi.
-- Aplicar UNA VEZ como postgres en patitas-espoch. Requiere SQL 02,04,07,09,12.
-- Conserva fechas, autores, coordenadas, fotos y animales de los reportes.
-- Alcance adicional Tunshi aprobado por el usuario; no representa toda la sede.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
LOCK TABLE public.zonas, public.animales, public.avistamientos IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
 IF to_regclass('privado.geocercas_rf11') IS NOT NULL THEN
  RAISE EXCEPTION 'RF-11 ya instalado. No repetir esta migracion.';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM public.zonas WHERE id_zona='7a43d9a5-6861-4b12-833d-35023f502fae'::uuid AND activa AND tipo='campus') THEN
  RAISE EXCEPTION 'Falta el perimetro Matriz del SQL 07. Revisar antes de continuar.';
 END IF;
END $$;
CREATE TABLE privado.geocercas_rf11 (
 id_zona uuid PRIMARY KEY REFERENCES public.zonas(id_zona),
 sede text NOT NULL CHECK(sede IN ('matriz','tunshi')),
 codigo text NOT NULL,
 nivel text NOT NULL CHECK(nivel IN ('campus','sector')),
 color text NOT NULL,
 tipo_fuente text NOT NULL,
 UNIQUE(sede,codigo)
);
REVOKE ALL ON privado.geocercas_rf11 FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE public.animales
 ADD COLUMN zona_habitual_asignada_en timestamptz,
 ADD COLUMN zona_habitual_asignada_por uuid REFERENCES public.perfiles_usuario(id_usuario);
ALTER TABLE public.avistamientos
 ADD COLUMN id_campus_detectado uuid REFERENCES public.zonas(id_zona),
 ADD COLUMN id_zona_habitual_referencia uuid REFERENCES public.zonas(id_zona);
CREATE INDEX geocercas_rf11_geometria_idx ON public.zonas USING gist(geometria) WHERE activa;
CREATE INDEX avistamientos_campus_rf11_idx ON public.avistamientos(id_campus_detectado);
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM public.zonas WHERE id_zona='7a43d9a5-6861-4b12-833d-35023f502fae'::uuid AND extensions.ST_Equals(geometria,extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.6744588,-1.6531517],[-78.6735518,-1.6539162],[-78.67316,-1.6547581],[-78.6722581,-1.6561709],[-78.6729233,-1.6569445],[-78.6734196,-1.6575203],[-78.6734806,-1.6575956],[-78.6747524,-1.6589757],[-78.673978,-1.6596536],[-78.674519,-1.6601696],[-78.6747784,-1.6599936],[-78.6748019,-1.6599568],[-78.6748626,-1.6598616],[-78.6750767,-1.6595854],[-78.6753234,-1.6597454],[-78.6753385,-1.6597851],[-78.6751893,-1.6601024],[-78.6751635,-1.6604336],[-78.6751635,-1.6608659],[-78.6751857,-1.6612346],[-78.6758293,-1.6610539],[-78.6759562,-1.6615837],[-78.6766631,-1.6613631],[-78.6771924,-1.6611979],[-78.6772675,-1.6611211],[-78.6772662,-1.6610836],[-78.677306,-1.6610823],[-78.6773792,-1.6610799],[-78.6774146,-1.6610834],[-78.6774135,-1.6611344],[-78.6774658,-1.661153],[-78.6813109,-1.6600571],[-78.6813496,-1.6599992],[-78.6806723,-1.6596593],[-78.6804116,-1.6594536],[-78.6803223,-1.6593794],[-78.6803318,-1.6592925],[-78.6803905,-1.6589106],[-78.6803499,-1.6586001],[-78.6801823,-1.6580439],[-78.6798979,-1.6571627],[-78.6797616,-1.656728],[-78.6797469,-1.6566821],[-78.6798662,-1.6565914],[-78.6809055,-1.6558011],[-78.6821034,-1.6549759],[-78.6822357,-1.654973],[-78.683138,-1.6548081],[-78.6834013,-1.6547687],[-78.6839593,-1.6545797],[-78.6844421,-1.6543362],[-78.6850927,-1.6538917],[-78.6840291,-1.6530969],[-78.6840628,-1.6530872],[-78.6841944,-1.652953],[-78.6854026,-1.6519],[-78.6854362,-1.6518703],[-78.6854591,-1.65185],[-78.6860584,-1.6513296],[-78.6867068,-1.6518704],[-78.6876942,-1.6511068],[-78.6865867,-1.6496888],[-78.6866181,-1.6496507],[-78.686722,-1.6495516],[-78.6881582,-1.6480946],[-78.6880686,-1.6480391],[-78.6878453,-1.647957],[-78.6876384,-1.6478923],[-78.6867255,-1.6476991],[-78.6844751,-1.6472272],[-78.6835114,-1.6477972],[-78.6822871,-1.6487111],[-78.6821589,-1.6488119],[-78.6815541,-1.649159],[-78.6808341,-1.6496023],[-78.6801779,-1.6500765],[-78.6797878,-1.6503361],[-78.6789283,-1.6508767],[-78.6780318,-1.6514174],[-78.6766901,-1.6521983],[-78.676872,-1.6524568],[-78.6754715,-1.6546226],[-78.6744588,-1.6531517]]]}$geo$),4326))) THEN RAISE EXCEPTION 'El limite Matriz cambio respecto al HTML. No se reemplaza.'; END IF; END $$;
INSERT INTO privado.geocercas_rf11 VALUES('7a43d9a5-6861-4b12-833d-35023f502fae','matriz','CAMPUS','campus','#17835b','geocerca_campus');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('e7bd231d-172f-5603-b557-5b76665b08fc','Tunshi — área delimitada','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: perimetro','campus',NULL,extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62875342369081,-1.7455743786992552],[-78.62420439720154,-1.7470218194704301],[-78.62436532974245,-1.7477293318011338],[-78.62426877021791,-1.7483465036765755],[-78.62429559230806,-1.748544936347435],[-78.62436801195146,-1.7486709315592137],[-78.62452894449235,-1.7488451553036413],[-78.62465500831605,-1.7489148770971743],[-78.62478375434877,-1.748979202290989],[-78.62496078014375,-1.749067684850182],[-78.62503051757814,-1.7492086749036693],[-78.62513780593873,-1.7493373133792562],[-78.62522900104524,-1.7495314560805453],[-78.62534165382387,-1.7496803492709074],[-78.62542748451234,-1.7499805056246631],[-78.62555623054506,-1.7506558572448911],[-78.62555623054506,-1.751513446253331],[-78.625545501709,-1.7521459178955383],[-78.6255669593811,-1.752821268735347],[-78.62558841705322,-1.7530542522891113],[-78.6256366968155,-1.7536789322169455],[-78.62576007843019,-1.7539914959426297],[-78.62589687108995,-1.7542580030577957],[-78.62613558769227,-1.7546762216014926],[-78.62623214721681,-1.7546601358935339],[-78.62649232149126,-1.7546065366821146],[-78.62665325403215,-1.7548102602451512],[-78.62676590681077,-1.7549470125266522],[-78.62692952156068,-1.7549228621704782],[-78.62725138664247,-1.754602527062842],[-78.6274901032448,-1.7543250654957712],[-78.62759739160538,-1.7541293569937106],[-78.62770199775697,-1.7539175528487578],[-78.6277797818184,-1.7537995790497136],[-78.62784147262575,-1.7536377409923707],[-78.62792730331422,-1.7534662234166343],[-78.62805604934694,-1.7532901920472217],[-78.62831354141237,-1.7530052698540397],[-78.62858176231386,-1.7527191816038263],[-78.62861394882204,-1.7526407948637044],[-78.62868636846544,-1.7524885937745691],[-78.62891972064972,-1.7523223844994704],[-78.62864613533021,-1.752373303812524],[-78.6284101009369,-1.7523599079566676],[-78.62820088863373,-1.7523116646439174],[-78.62835645675659,-1.75222808045073],[-78.62868636846544,-1.7520918263455263],[-78.6289304494858,-1.7520301633883681],[-78.6291825771332,-1.751960412977311],[-78.62950176000595,-1.7519014537596256],[-78.62964659929277,-1.751853198545418],[-78.62994968891144,-1.7517942195082332],[-78.63035738468172,-1.7516119145293287],[-78.62946152687074,-1.7503759945337372],[-78.62926036119462,-1.7498853624087574],[-78.62904846668245,-1.7494992885393448],[-78.62899214029312,-1.748917541213017],[-78.62897604703905,-1.7487111083067521],[-78.62887412309648,-1.748279474712055],[-78.62885802984239,-1.7478612448326958],[-78.62893313169481,-1.7474993457692587],[-78.6289143562317,-1.7473398197129515],[-78.62886607646944,-1.7471481001370932],[-78.62896263599397,-1.7469014664714888],[-78.62913161516191,-1.7467111141657843],[-78.62925767898561,-1.74657870779462],[-78.62930327653886,-1.7465019911366628],[-78.62915307283403,-1.746263392349854],[-78.628968000412,-1.7459336298663426],[-78.62883120775224,-1.745673576358347],[-78.62875342369081,-1.7455743786992552]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('e7bd231d-172f-5603-b557-5b76665b08fc','tunshi','tunshi_1794325846812_c53ffd','campus','#17835b','perimetro');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('2e032aef-1f0f-513b-ae24-f3296a3c959a','Facultad de Informática y Electrónica','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.67548877551,-1.656917346939],[-78.678537878788,-1.657298484848],[-78.679205970149,-1.656759701493],[-78.678733333333,-1.652033333333],[-78.67808519577,-1.65138519577],[-78.6780318,-1.6514174],[-78.6766901,-1.6521983],[-78.676872,-1.6524568],[-78.6754715,-1.6546226],[-78.6744588,-1.6531517],[-78.673692540922,-1.653797571075],[-78.67548877551,-1.656917346939]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('2e032aef-1f0f-513b-ae24-f3296a3c959a','matriz','S1','sector','#3984D4','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('b83405e7-0af3-53fb-b483-17a854ceed9d','Facultad de Mecánica','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.678537878788,-1.657298484848],[-78.67548877551,-1.656917346939],[-78.675035170885,-1.659638974693],[-78.6750767,-1.6595854],[-78.6753234,-1.6597454],[-78.6753385,-1.6597851],[-78.6751893,-1.6601024],[-78.6751635,-1.6604336],[-78.6751635,-1.6608659],[-78.6751857,-1.6612346],[-78.6758293,-1.6610539],[-78.6759562,-1.6615837],[-78.6766631,-1.6613631],[-78.6771924,-1.6611979],[-78.6772675,-1.6611211],[-78.6772662,-1.6610836],[-78.677306,-1.6610823],[-78.6773792,-1.6610799],[-78.6774146,-1.6610834],[-78.6774135,-1.6611344],[-78.6774658,-1.661153],[-78.677582570232,-1.661119719072],[-78.678537878788,-1.657298484848]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('b83405e7-0af3-53fb-b483-17a854ceed9d','matriz','S2','sector','#E88B38','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('02eb641d-08ff-5080-8939-2ae1e5136f44','Complejo Deportivo','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.679205970149,-1.656759701493],[-78.678537878788,-1.657298484848],[-78.677582570232,-1.661119719072],[-78.6813109,-1.6600571],[-78.6813496,-1.6599992],[-78.6806723,-1.6596593],[-78.6804116,-1.6594536],[-78.6803223,-1.6593794],[-78.6803318,-1.6592925],[-78.6803905,-1.6589106],[-78.6803499,-1.6586001],[-78.6801823,-1.6580439],[-78.6798979,-1.6571627],[-78.679859338588,-1.657039716538],[-78.679205970149,-1.656759701493]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('02eb641d-08ff-5080-8939-2ae1e5136f44','matriz','S3','sector','#DF527C','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('c0081ae1-8ae5-5fd5-94ac-9f98398b748e','Área Este','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.67548877551,-1.656917346939],[-78.673692540922,-1.653797571075],[-78.6735518,-1.6539162],[-78.67316,-1.6547581],[-78.6722581,-1.6561709],[-78.6729233,-1.6569445],[-78.6734196,-1.6575203],[-78.6734806,-1.6575956],[-78.6747524,-1.6589757],[-78.673978,-1.6596536],[-78.674519,-1.6601696],[-78.6747784,-1.6599936],[-78.6748019,-1.6599568],[-78.6748626,-1.6598616],[-78.675035170885,-1.659638974693],[-78.67548877551,-1.656917346939]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('c0081ae1-8ae5-5fd5-94ac-9f98398b748e','matriz','S4','sector','#16A89A','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('48bb58d4-6f70-5a93-88e7-6938e1d99e4b','Área Académica Central','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.679205970149,-1.656759701493],[-78.679859338588,-1.657039716538],[-78.6797616,-1.656728],[-78.6797469,-1.6566821],[-78.6798662,-1.6565914],[-78.6809055,-1.6558011],[-78.6821034,-1.6549759],[-78.6822357,-1.654973],[-78.683138,-1.6548081],[-78.6834013,-1.6547687],[-78.6839593,-1.6545797],[-78.684379513337,-1.65436776556],[-78.683607303371,-1.653466853933],[-78.678733333333,-1.652033333333],[-78.679205970149,-1.656759701493]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('48bb58d4-6f70-5a93-88e7-6938e1d99e4b','matriz','S5','sector','#D8A623','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('7b1490a8-9f3b-5df5-9fb1-71e9a78bba98','Áreas Verdes y Zona Posterior','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.678733333333,-1.652033333333],[-78.683607303371,-1.653466853933],[-78.685217753428,-1.647382931493],[-78.6844751,-1.6472272],[-78.6835114,-1.6477972],[-78.6822871,-1.6487111],[-78.6821589,-1.6488119],[-78.6815541,-1.649159],[-78.6808341,-1.6496023],[-78.6801779,-1.6500765],[-78.6797878,-1.6503361],[-78.6789283,-1.6508767],[-78.67808519577,-1.65138519577],[-78.678733333333,-1.652033333333]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('7b1490a8-9f3b-5df5-9fb1-71e9a78bba98','matriz','S6','sector','#68A64B','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('13e1fbc3-9a0a-52a1-a0f8-ef240a4e869d','Área Occidental','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: geocerca_sector','sector','7a43d9a5-6861-4b12-833d-35023f502fae',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.683607303371,-1.653466853933],[-78.684379513337,-1.65436776556],[-78.6844421,-1.6543362],[-78.6850927,-1.6538917],[-78.6840291,-1.6530969],[-78.6840628,-1.6530872],[-78.6841944,-1.652953],[-78.6854026,-1.6519],[-78.6854362,-1.6518703],[-78.6854591,-1.65185],[-78.6860584,-1.6513296],[-78.6867068,-1.6518704],[-78.6876942,-1.6511068],[-78.6865867,-1.6496888],[-78.6866181,-1.6496507],[-78.686722,-1.6495516],[-78.6881582,-1.6480946],[-78.6880686,-1.6480391],[-78.6878453,-1.647957],[-78.6876384,-1.6478923],[-78.6867255,-1.6476991],[-78.685217753428,-1.647382931493],[-78.683607303371,-1.653466853933]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('13e1fbc3-9a0a-52a1-a0f8-ef240a4e869d','matriz','S7','sector','#9A65C9','geocerca_sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('ef895454-1b80-5f5d-ba78-80c1db5ba0a0','ESPOCH-FCP-Tunshi-Placteos','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: sector','sector','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62706899642946,-1.7520732707018398],[-78.62682223320009,-1.7529790983949156],[-78.6256527900696,-1.7530166178757325],[-78.62560451030733,-1.7528290204642192],[-78.62559378147127,-1.7520837904161042],[-78.62558841705322,-1.7516306782467599],[-78.62591564655305,-1.751660556163806],[-78.62703144550325,-1.7520462213763808],[-78.62706899642946,-1.7520732707018398]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('ef895454-1b80-5f5d-ba78-80c1db5ba0a0','tunshi','tunshi_1794359182490_0rsh7o','sector','#17835b','sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('19cd2a8e-227d-50ad-a336-e58e9a4935a2','ESPOCH-Tunshi-FRN.Recursos-Renovables 2','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: jardin','jardin','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62815260887147,-1.750903616963184],[-78.62854152917863,-1.7521159222439757],[-78.62826257944108,-1.7522446140234709],[-78.62797021865846,-1.7522794614814714],[-78.62714409828187,-1.7520140459519082],[-78.62594783306123,-1.7516065902685531],[-78.62557768821716,-1.7515521686012139],[-78.62558573484422,-1.7508558848686975],[-78.62810969352724,-1.7508880504050035],[-78.62815260887147,-1.750903616963184]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('19cd2a8e-227d-50ad-a336-e58e9a4935a2','tunshi','tunshi_1794360225803_z4nd8t','sector','#17835b','jardin');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('75b2fc40-19b2-5d81-b120-bf533698d259','ESPOCH-Admin Estación 2','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: jardin','jardin','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62876683473588,-1.7456306918297795],[-78.62927913665773,-1.7464966401095476],[-78.62893581390382,-1.7468780719980146],[-78.62884730100633,-1.7471615148555217],[-78.62890899181366,-1.7474805542679266],[-78.62884998321535,-1.7478535814287177],[-78.62886607646944,-1.7484349486149593],[-78.62725943326951,-1.74857438034021],[-78.62719774246217,-1.747569025008064],[-78.6282303929329,-1.7458129914448441],[-78.62821698188783,-1.7457647331016704],[-78.62874001264574,-1.7456011962687885],[-78.62876683473588,-1.7456306918297795]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('75b2fc40-19b2-5d81-b120-bf533698d259','tunshi','tunshi_1794361657697_z8bvwf','sector','#17835b','jardin');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('3ddd164b-7bb7-53db-adc0-0bb8d05a9875','ESPOCH-FCP-Tunshi-Placteos 2','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: jardin','jardin','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62759202718736,-1.754099838777883],[-78.62746059894563,-1.7543277097878398],[-78.62717628479005,-1.7546360231841862],[-78.62691611051561,-1.7548906332920646],[-78.62678200006486,-1.7549121601642872],[-78.62651109695436,-1.7545824160456545],[-78.6261570453644,-1.7546494259593903],[-78.6258164048195,-1.7540514399537563],[-78.6256527900696,-1.7536682004795272],[-78.62560719251634,-1.7530328809518267],[-78.6268249154091,-1.7530033220957364],[-78.62675517797472,-1.753241921015963],[-78.62756520509721,-1.7540676663611086],[-78.62759202718736,-1.754099838777883]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('3ddd164b-7bb7-53db-adc0-0bb8d05a9875','tunshi','tunshi_1794358969101_3egpz5','sector','#17835b','jardin');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('eca2ec20-526c-5b88-8f5e-b753b6134955','ESPOCH-FCP-Tunshi-Placteos 1','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: jardin','jardin','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62818747758867,-1.7522962241365259],[-78.62795144319534,-1.752329066079284],[-78.62708911299707,-1.752054294956573],[-78.62676858901979,-1.753236565549455],[-78.6276000738144,-1.7540622945486997],[-78.62777173519136,-1.7537752701500895],[-78.62791657447816,-1.7534456873321682],[-78.62828135490419,-1.7530176403043083],[-78.62856298685075,-1.75271748443705],[-78.6286622285843,-1.7524778580671188],[-78.62888485193254,-1.7523357684659555],[-78.62867027521135,-1.7523798090288503],[-78.62841546535493,-1.752373301335508],[-78.62819820642473,-1.7523149853700455],[-78.62818881869316,-1.7523056106981496],[-78.62818747758867,-1.7522962241365259]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('eca2ec20-526c-5b88-8f5e-b753b6134955','tunshi','tunshi_1794358848090_1o2ues','sector','#17835b','jardin');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('8a5dd321-4ae6-5761-b96d-dd440044226a','ESPOCH-Tunshi-FRN.Recursos-Renovables 1','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: jardin','jardin','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62994968891144,-1.7517673405972756],[-78.62985312938692,-1.7517914464078983],[-78.62943470478059,-1.7518853422668845],[-78.6285549402237,-1.752099402541392],[-78.6281740665436,-1.7508934043920446],[-78.6281740665436,-1.7497969115939171],[-78.62907528877258,-1.7495851168671723],[-78.62943470478059,-1.7503733066406149],[-78.63033056259157,-1.7516020635242433],[-78.62998455762865,-1.7517494615885452],[-78.62994968891144,-1.7517673405972756]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('8a5dd321-4ae6-5761-b96d-dd440044226a','tunshi','tunshi_1794360144851_0h4fwo','sector','#17835b','jardin');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('1d144a79-f279-5056-94ff-488055771803','ESPOCH-Tunshi-FRN.Recursos-Renovables','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: sector','sector','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62816601991655,-1.7497955686377427],[-78.62816333770753,-1.7508746446304475],[-78.62556964159013,-1.750831755266699],[-78.62557768821716,-1.7506357461853512],[-78.62540066242218,-1.7498237172134958],[-78.62816601991655,-1.7497741130447784],[-78.62816601991655,-1.7497955686377427]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('1d144a79-f279-5056-94ff-488055771803','tunshi','tunshi_1794360054103_356mfw','sector','#17835b','sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('ffca23f2-e1bd-5923-9c53-c2a57744c1c9','ESPOCH-FCP-TUNSHI-EST-EXPERIMENTAL','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: sector','sector','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62902432680131,-1.7494668673511604],[-78.62906455993652,-1.749563657308578],[-78.62828135490419,-1.749762379166143],[-78.62775027751924,-1.7497730990362885],[-78.62540066242218,-1.749796901685866],[-78.62536311149599,-1.749673572646044],[-78.62524509429932,-1.749526104071224],[-78.62514317035676,-1.7493113935338005],[-78.62504661083221,-1.7491963292802253],[-78.62497419118881,-1.7490435443262604],[-78.62696439027788,-1.7488532011550326],[-78.62697780132295,-1.748609243719355],[-78.62720578908922,-1.7485851111160196],[-78.6288955807686,-1.7484537401067368],[-78.62902432680131,-1.7494668673511604]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('ffca23f2-e1bd-5923-9c53-c2a57744c1c9','tunshi','tunshi_1794356136744_w5ium2','sector','#17835b','sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('1b65476d-9e1f-5ad2-9234-14dff1eccabd','ESPOCH-Admin Estación','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: sector','sector','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62431168556215,-1.7485314879514233],[-78.62430095672609,-1.7484537579412773],[-78.62430095672609,-1.748303733151861],[-78.62438678741456,-1.7476843053574171],[-78.62720847129823,-1.747515404786893],[-78.62718164920808,-1.7475770619476558],[-78.62724736332895,-1.748566334487661],[-78.62697377800943,-1.7485985040264533],[-78.62695768475533,-1.748839798338367],[-78.6249527335167,-1.74903684291864],[-78.62453967332841,-1.7488290705364398],[-78.6243760585785,-1.7486501793445177],[-78.62432241439821,-1.7485644203303914],[-78.62431168556215,-1.7485314879514233]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('1b65476d-9e1f-5ad2-9234-14dff1eccabd','tunshi','tunshi_1794356325962_m3qo77','sector','#17835b','sector');
INSERT INTO public.zonas(id_zona,nombre,descripcion,tipo,id_zona_padre,geometria,activa) VALUES ('62f6c7d5-a269-50ad-a7dd-897f076926b3','ESPOCH-Admin Estación 1','RF11 20261113; trazado aceptado del HTML; referencia no certificada. Tipo original: jardin','jardin','e7bd231d-172f-5603-b557-5b76665b08fc',extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.62820625305177,-1.7458156892525951],[-78.62722992897035,-1.7474985650129293],[-78.62436532974245,-1.7476708955967355],[-78.62423658370973,-1.7470408844393266],[-78.62819015979767,-1.7457754738015991],[-78.62820625305177,-1.7458156892525951]]]}$geo$),4326),true);
INSERT INTO privado.geocercas_rf11 VALUES('62f6c7d5-a269-50ad-a7dd-897f076926b3','tunshi','tunshi_1794361524348_ltxsfb','sector','#17835b','jardin');

-- Validar los trazados antes de habilitar cualquier escritura.
DO $$ BEGIN
 IF (SELECT count(*) FROM privado.geocercas_rf11)<>19 THEN RAISE EXCEPTION 'Semilla incompleta'; END IF;
 IF EXISTS(SELECT 1 FROM public.zonas z JOIN privado.geocercas_rf11 g USING(id_zona)
 WHERE z.geometria IS NULL OR NOT extensions.ST_IsValid(z.geometria)
 OR extensions.ST_IsEmpty(z.geometria) OR extensions.ST_SRID(z.geometria)<>4326
 OR extensions.GeometryType(z.geometria)<>'POLYGON') THEN RAISE EXCEPTION 'Geometria invalida'; END IF;
 -- Tolerancia de 1e-12 grados cuadrados solo para diferencias de coma flotante.
 IF EXISTS(SELECT 1 FROM public.zonas z JOIN privado.geocercas_rf11 g USING(id_zona)
 JOIN public.zonas padre ON padre.id_zona=z.id_zona_padre WHERE g.nivel='sector'
 AND extensions.ST_Area(extensions.ST_Difference(z.geometria,padre.geometria))>1e-12)
 THEN RAISE EXCEPTION 'Un sector sale de su perimetro'; END IF;
 IF EXISTS(SELECT 1 FROM public.zonas a JOIN privado.geocercas_rf11 ga ON ga.id_zona=a.id_zona
 JOIN privado.geocercas_rf11 gb ON gb.sede=ga.sede AND gb.nivel='sector' AND gb.id_zona>ga.id_zona
 JOIN public.zonas b ON b.id_zona=gb.id_zona WHERE ga.nivel='sector'
 AND extensions.ST_Area(extensions.ST_Intersection(a.geometria,b.geometria))>1e-12)
 THEN RAISE EXCEPTION 'Sectores con solapamiento interior'; END IF;
END $$;

-- Una coordenada sobre un borde pertenece al poligono (ST_Covers).
-- En un limite compartido se elige el sector por codigo+UUID, orden estable.
CREATE FUNCTION privado.clasificar_geocercas_rf11(p extensions.geometry)
RETURNS TABLE(id_campus uuid,id_sector uuid,dentro boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 id_campus:=NULL; id_sector:=NULL; dentro:=NULL;
 IF p IS NULL OR extensions.ST_IsEmpty(p) OR extensions.ST_SRID(p)<>4326
 OR extensions.GeometryType(p)<>'POINT' OR NOT extensions.ST_IsValid(p)
 OR extensions.ST_X(p) NOT BETWEEN -180 AND 180 OR extensions.ST_Y(p) NOT BETWEEN -90 AND 90
 OR extensions.ST_X(p)::text IN ('NaN','Infinity','-Infinity')
 OR extensions.ST_Y(p)::text IN ('NaN','Infinity','-Infinity') THEN RETURN NEXT; RETURN; END IF;
 IF (SELECT count(*) FROM public.zonas z JOIN privado.geocercas_rf11 g USING(id_zona)
 WHERE g.nivel='campus' AND z.activa)<>2 THEN RETURN NEXT; RETURN; END IF;
 SELECT z.id_zona INTO id_campus FROM public.zonas z JOIN privado.geocercas_rf11 g USING(id_zona)
 WHERE z.activa AND g.nivel='campus' AND extensions.ST_Covers(z.geometria,p)
 ORDER BY g.sede,z.id_zona LIMIT 1;
 dentro:=id_campus IS NOT NULL;
 IF dentro THEN
  SELECT z.id_zona INTO id_sector FROM public.zonas z JOIN privado.geocercas_rf11 g USING(id_zona)
  WHERE z.activa AND g.nivel='sector' AND z.id_zona_padre=id_campus
  AND extensions.ST_Covers(z.geometria,p) ORDER BY g.codigo,z.id_zona LIMIT 1;
 END IF;
 RETURN NEXT;
END $$;

-- Mantener el helper RF-10, ahora referido a las DOS areas aprobadas.
CREATE OR REPLACE FUNCTION privado.ubicacion_dentro_campus(p_ubicacion extensions.geometry)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
 SELECT dentro FROM privado.clasificar_geocercas_rf11(p_ubicacion);
$$;
CREATE OR REPLACE FUNCTION privado.validar_campus_avistamiento()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v record; v_habitual uuid; v_asignada timestamptz; v_geom extensions.geometry;
BEGIN
 SELECT * INTO v FROM privado.clasificar_geocercas_rf11(NEW.ubicacion);
 NEW.id_campus_detectado:=v.id_campus;
 NEW.id_zona_detectada:=v.id_sector;
 NEW.dentro_campus:=v.dentro;
 -- Guardar una referencia temporal, no comparar reportes anteriores con asignaciones futuras.
 IF TG_OP='INSERT' THEN
  SELECT id_zona_habitual,zona_habitual_asignada_en INTO v_habitual,v_asignada
   FROM public.animales WHERE id_animal=NEW.id_animal FOR SHARE;
  IF v_asignada IS NULL OR v_asignada>NEW.fecha_avistamiento THEN v_habitual:=NULL; END IF;
  NEW.id_zona_habitual_referencia:=v_habitual;
 ELSIF NEW.id_animal IS DISTINCT FROM OLD.id_animal THEN
  -- RF-13 puede corregir la identidad: no reutilizar la zona del animal anterior.
  -- Sin historial temporal del nuevo animal no se inventa una comparacion pasada.
  NEW.id_zona_habitual_referencia:=NULL;
 ELSE
  NEW.id_zona_habitual_referencia:=OLD.id_zona_habitual_referencia;
 END IF;
 NEW.fuera_zona_habitual:=NULL;
 SELECT z.geometria INTO v_geom FROM public.zonas z
 JOIN privado.geocercas_rf11 g USING(id_zona)
 WHERE z.id_zona=NEW.id_zona_habitual_referencia AND z.activa AND g.nivel='sector';
 IF v_geom IS NOT NULL AND v.dentro IS NOT NULL THEN
  NEW.fuera_zona_habitual:=NOT extensions.ST_Covers(v_geom,NEW.ubicacion);
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER validar_campus_al_guardar_avistamiento ON public.avistamientos;
CREATE TRIGGER validar_campus_al_guardar_avistamiento
 BEFORE INSERT OR UPDATE OF ubicacion,id_animal,fecha_avistamiento,dentro_campus,
 id_zona_detectada,id_campus_detectado,fuera_zona_habitual,id_zona_habitual_referencia
 ON public.avistamientos FOR EACH ROW EXECUTE FUNCTION privado.validar_campus_avistamiento();
-- Clasificacion de coordenadas historicas; habitual_referencia permanece NULL.
UPDATE public.avistamientos SET ubicacion=ubicacion;

CREATE FUNCTION privado.listar_geocercas_rf11()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v jsonb;
BEGIN
 -- Solo lectura: no usar el helper FOR SHARE dentro de una funcion STABLE.
 IF NOT EXISTS(SELECT 1 FROM public.perfiles_usuario WHERE id_usuario=auth.uid()
 AND activo AND id_rol IN (1,2,3)) THEN RAISE insufficient_privilege; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id_zona',z.id_zona,'nombre',z.nombre,
 'id_zona_padre',z.id_zona_padre,'sede',g.sede,'codigo',g.codigo,'nivel',g.nivel,'color',g.color,
 'geometria',extensions.ST_AsGeoJSON(z.geometria,15)::jsonb) ORDER BY g.sede,g.nivel,g.codigo),'[]'::jsonb)
 INTO v FROM public.zonas z JOIN privado.geocercas_rf11 g USING(id_zona) WHERE z.activa;
 RETURN v;
END $$;
CREATE FUNCTION public.listar_geocercas()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO '' AS $$
 SELECT privado.listar_geocercas_rf11();
$$;

CREATE FUNCTION privado.asignar_zona_habitual_rf11(p_id_animal uuid,p_id_zona uuid,p_zona_esperada uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_anterior uuid;
BEGIN
 PERFORM privado.exigir_rol_animal(auth.uid(),ARRAY[3]::smallint[]);
 SELECT id_zona_habitual INTO v_anterior FROM public.animales
 WHERE id_animal=p_id_animal AND activo FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Animal no disponible' USING ERRCODE='22023'; END IF;
 IF v_anterior IS DISTINCT FROM p_zona_esperada THEN
  RAISE EXCEPTION 'La zona cambio. Actualiza la ficha.' USING ERRCODE='40001'; END IF;
 IF p_id_zona IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.zonas z
 JOIN privado.geocercas_rf11 g USING(id_zona) JOIN public.zonas padre ON padre.id_zona=z.id_zona_padre
 WHERE z.id_zona=p_id_zona AND z.activa AND padre.activa AND g.nivel='sector') THEN
  RAISE EXCEPTION 'Selecciona un sector activo' USING ERRCODE='22023'; END IF;
 IF v_anterior IS DISTINCT FROM p_id_zona THEN
  UPDATE public.animales SET id_zona_habitual=p_id_zona,zona_habitual_asignada_en=clock_timestamp(),
  zona_habitual_asignada_por=auth.uid() WHERE id_animal=p_id_animal;
 END IF;
 RETURN privado.ficha_animal_json(p_id_animal);
END $$;
CREATE FUNCTION public.asignar_zona_habitual(p_id_animal uuid,p_id_zona uuid,p_zona_esperada uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO '' AS $$
 SELECT privado.asignar_zona_habitual_rf11(p_id_animal,p_id_zona,p_zona_esperada);
$$;
CREATE OR REPLACE FUNCTION privado.ficha_animal_json(p_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
  SELECT jsonb_build_object(
    'id_animal',a.id_animal,'identificador',a.identificador,'nombre',a.nombre,
    'especie',a.especie,'raza',a.raza,'sexo',a.sexo,
    'caracteristicas_fisicas',a.caracteristicas_fisicas,'observaciones',a.observaciones,
    'id_zona_habitual',a.id_zona_habitual,'zona_habitual_asignada_en',a.zona_habitual_asignada_en,'zona_habitual',z.nombre,'registrado_por',a.registrado_por,'activo',a.activo,
    'revision_administrativa',a.revision_administrativa,
    'observacion_revision',a.observacion_revision,'revisado_por',a.revisado_por,'fecha_revision',a.fecha_revision,
    'estado_vacunacion',a.estado_vacunacion,'observacion_vacunacion',a.observacion_vacunacion,
    'vacunacion_validada_por',a.vacunacion_validada_por,'fecha_validacion_vacunacion',a.fecha_validacion_vacunacion,
    'estado_comportamiento',coalesce(c.estado_validacion,'pendiente'),
    'comportamiento',c.descripcion,'recomendaciones',c.recomendaciones,
    'comportamiento_validado_por',c.actualizado_por,'fecha_validacion_comportamiento',c.fecha_actualizacion,
    'estado_general',privado.calcular_estado_animal(a.revision_administrativa,a.estado_vacunacion,coalesce(c.estado_validacion,'pendiente')),
    'url_fotografia',(SELECT f.url_fotografia FROM public.fotografias f WHERE f.id_animal=a.id_animal AND f.id_avistamiento IS NULL ORDER BY f.fecha_subida DESC,f.id_fotografia LIMIT 1),
    'ultimo_avistamiento',(SELECT v.fecha_avistamiento::text FROM public.avistamientos v WHERE v.id_animal=a.id_animal ORDER BY v.fecha_avistamiento DESC LIMIT 1),
    'vacunaciones',coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id_vacunacion',v.id_vacunacion,'nombre',vc.nombre,'fecha_aplicacion',v.fecha_aplicacion,
      'observaciones',v.observaciones,'registrado_por',v.registrado_por,
      'actualizado_por',v.actualizado_por,'fecha_actualizacion',v.fecha_actualizacion
    ) ORDER BY v.fecha_aplicacion DESC,v.id_vacunacion)
    FROM public.vacunaciones v JOIN public.vacunas vc ON vc.id_vacuna=v.id_vacuna WHERE v.id_animal=a.id_animal),'[]'::jsonb)
  ) FROM public.animales a
  LEFT JOIN public.zonas z ON z.id_zona=a.id_zona_habitual
  LEFT JOIN public.comportamientos c ON c.id_animal=a.id_animal
  WHERE a.id_animal=p_id;
$$;

CREATE OR REPLACE FUNCTION privado.avistamiento_json(p_id_avistamiento uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT jsonb_build_object(
    'id_avistamiento', v.id_avistamiento,
    'id_animal', v.id_animal,
    'nombre_animal', a.nombre,
    'identificador_animal', a.identificador,
    'especie_animal', a.especie,
    'estado_general_animal', privado.calcular_estado_animal(
      a.revision_administrativa,
      a.estado_vacunacion,
      coalesce(c.estado_validacion, 'pendiente')
    ),
    'id_usuario', CASE WHEN v.id_usuario = auth.uid() THEN v.id_usuario ELSE NULL END,
    'latitud', privado.latitud_avistamiento(v.id_avistamiento),
    'longitud', privado.longitud_avistamiento(v.id_avistamiento),
    'precision_gps_m', v.precision_gps_m,
    'dentro_campus', v.dentro_campus,
    'fuera_zona_habitual', v.fuera_zona_habitual,
    'zona_detectada', z.nombre,
    'sede_detectada', sede.nombre,
    'zona_habitual_referencia', habitual.nombre,
    'id_zona_habitual_referencia',v.id_zona_habitual_referencia,
    'observaciones', v.observaciones,
    'fecha_avistamiento', v.fecha_avistamiento,
    'url_fotografia', (
      SELECT f.url_fotografia
      FROM public.fotografias f
      WHERE f.id_avistamiento = v.id_avistamiento
      ORDER BY f.fecha_subida DESC, f.id_fotografia
      LIMIT 1
    )
  )
  FROM public.avistamientos v
  JOIN public.animales a ON a.id_animal = v.id_animal
  LEFT JOIN public.comportamientos c ON c.id_animal = a.id_animal
  LEFT JOIN public.zonas z ON z.id_zona = v.id_zona_detectada
  LEFT JOIN public.zonas sede ON sede.id_zona=v.id_campus_detectado
  LEFT JOIN public.zonas habitual ON habitual.id_zona=v.id_zona_habitual_referencia
  WHERE v.id_avistamiento = p_id_avistamiento;
$$;


REVOKE ALL ON FUNCTION privado.clasificar_geocercas_rf11(extensions.geometry),
 privado.ubicacion_dentro_campus(extensions.geometry),privado.validar_campus_avistamiento(),
 privado.listar_geocercas_rf11(),privado.asignar_zona_habitual_rf11(uuid,uuid,uuid),
 public.listar_geocercas(),public.asignar_zona_habitual(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;
GRANT USAGE ON SCHEMA privado TO authenticated;
GRANT EXECUTE ON FUNCTION privado.listar_geocercas_rf11(),privado.asignar_zona_habitual_rf11(uuid,uuid,uuid),
 public.listar_geocercas(),public.asignar_zona_habitual(uuid,uuid,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
