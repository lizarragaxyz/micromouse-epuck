% REFEREE  Arbitro automatico del proyecto Micromouse (Supervisor).
%
% Mide el TIEMPO DE SIMULACION (no el del reloj de la computadora), de modo
% que el resultado no depende de la velocidad del equipo donde se corre.
%
%   - Una corrida inicia cuando el centro del e-puck SALE de la celda de inicio.
%   - Una corrida termina cuando el centro del e-puck ENTRA a la meta (2x2).
%   - Para iniciar otra corrida el robot debe regresar (solo) a la celda de inicio.
%   - Si durante una corrida regresa al inicio sin llegar a la meta, la corrida
%     se anula y se puede intentar de nuevo.
%
%   Puntaje de cada corrida:  P = t_corrida + t_salida / FACTOR_PENALIZACION
%   donde t_salida es el instante (desde t = 0) en que inicio esa corrida.
%   El puntaje final del robot es el MENOR P de sus corridas completas.
%
%   Si el robot no completa ninguna corrida, su puntaje es
%       P = TIEMPO_LIMITE + PESO_DISTANCIA * d + t_d / FACTOR_PENALIZACION
%   donde d es la distancia (en celdas, por los pasillos del laberinto) de
%   la celda mas cercana a la meta que visito, y t_d el instante en que llego
%   a ella por primera vez. Una corrida completa siempre da P <= TIEMPO_LIMITE,
%   asi que cualquier robot que llega a la meta queda arriba de los que no.
%   Tambien se registra el numero de celdas distintas visitadas (informativo).
%
%   El concurso del robot termina cuando ocurre lo primero de:
%     - se alcanza TIEMPO_LIMITE,
%     - el robot no cambia de celda en TIEMPO_ATORADO segundos,
%     - el robot se queda en la celda de inicio TIEMPO_ESTACIONADO segundos
%       despues de haber completado al menos una corrida.
%
% Los resultados se agregan a results/resultados.csv y el detalle de cada
% corrida se guarda en results/<equipo>_<laberinto>_<fecha>.txt
%
% Si el mundo trae el e-puck con controller "<none>", el arbitro espera a que
% se asigne un controlador en el arbol de nodos y el tiempo empieza a contar
% en ese momento (el robot se regresa al inicio y su controlador se reinicia).
%
% NO MODIFICAR (archivo oficial del concurso).

TIEMPO_LIMITE       = 600;   % [s] 10 minutos de simulacion
FACTOR_PENALIZACION = 30;
TIEMPO_ATORADO      = 60;    % [s]
TIEMPO_ESTACIONADO  = 30;    % [s]
PESO_DISTANCIA      = 30;    % [s por celda] puntaje si no llega a la meta

TIME_STEP = wb_robot_get_basic_time_step();

% ---- datos del laberinto (customData del arbitro, definido en el mundo oficial) ----
datos = wb_robot_get_custom_data();
N  = str2double(regexp(datos, 'N=(\d+)', 'tokens', 'once'));
C  = str2double(regexp(datos, 'CELDA=([\d.]+)', 'tokens', 'once'));
lab = regexp(datos, 'LABERINTO=([^|\s]+)', 'tokens', 'once');
lab = lab{1};
g  = N/2;
% Datos opcionales del concurso (campos separados por '|'): FASE, TURNO,
% EQUIPO_N, INTEGRANTES. Solo se usan para mostrarlos en pantalla.
campo = @(k) regexp(datos, [k '=([^|]*)'], 'tokens', 'once');
t = campo('EQUIPO_N');    equipoN     = ''; if ~isempty(t), equipoN     = strtrim(t{1}); end
t = campo('INTEGRANTES'); integrantes = ''; if ~isempty(t), integrantes = strtrim(t{1}); end
t = campo('FASE');        fase        = ''; if ~isempty(t), fase        = strtrim(t{1}); end
t = campo('TURNO');       turno       = ''; if ~isempty(t), turno       = strtrim(t{1}); end

mouse  = wb_supervisor_node_get_from_def('MOUSE');
campoCtrl = wb_supervisor_node_get_field(mouse, 'controller');
D = distancias_meta(N);       % D(x+1,y+1): celdas por recorrer hasta la meta

% ---- espera a que se asigne el controlador del e-puck ----
% Si el mundo trae controller "<none>", el equipo asigna el suyo en el arbol
% de nodos; entonces el robot se regresa al inicio, se reinicia su
% controlador y el tiempo del concurso empieza a contar en ese momento.
equipo = wb_supervisor_field_get_sf_string(campoCtrl);
t0 = 0;
if isempty(equipo) || strcmp(equipo, '<none>')
    fTras = wb_supervisor_node_get_field(mouse, 'translation');
    fRot  = wb_supervisor_node_get_field(mouse, 'rotation');
    pos0  = wb_supervisor_field_get_sf_vec3f(fTras);
    rot0  = wb_supervisor_field_get_sf_rotation(fRot);
    wb_supervisor_set_label(2, 'Asigne su controlador: MOUSE -> controller', ...
                            0.01, 0.01, 0.12, [1 0.85 0], 0, 'Arial');
    while wb_robot_step(TIME_STEP) ~= -1
        equipo = wb_supervisor_field_get_sf_string(campoCtrl);
        if ~isempty(equipo) && ~strcmp(equipo, '<none>'), break; end
    end
    t0 = wb_robot_get_time();
    wb_supervisor_field_set_sf_vec3f(fTras, pos0);
    wb_supervisor_field_set_sf_rotation(fRot, rot0);
    wb_supervisor_node_reset_physics(mouse);
    wb_supervisor_node_restart_controller(mouse);
end

% Sin datos del equipo en el mundo: se buscan en equipos.txt (si existe).
if isempty(equipoN)
    [equipoN, integrantes] = buscar_equipo(fullfile('..', '..', 'equipos.txt'), equipo);
end

% ---- encabezado en pantalla: equipo, controlador, integrantes, fase ----
if isempty(equipoN)
    txtTitulo = sprintf('Controlador: %s', equipo);
else
    txtTitulo = sprintf('EQUIPO %s  |  controlador: %s', equipoN, equipo);
end
txtInfo = sprintf('Laberinto: %s', lab);
if ~isempty(fase),  txtInfo = sprintf('Fase: %s   Turno: %s   %s', fase, turno, txtInfo); end
if ~isempty(integrantes), txtInfo = sprintf('Integrantes: %s\n%s', integrantes, txtInfo); end
wb_supervisor_set_label(2, txtTitulo, 0.01, 0.01, 0.12, [1 0.85 0], 0, 'Arial');
wb_supervisor_set_label(3, txtInfo,   0.01, 0.075, 0.07, [1 1 1], 0, 'Arial');

estado      = 'EN_INICIO';    % EN_INICIO | CORRIENDO | REGRESANDO
corridas    = zeros(0, 4);    % [t_salida, t_llegada, t_corrida, puntaje]
anuladas    = 0;
tSalida     = 0;
celdaPrev   = [0 0];
tCambio     = 0;              % ultimo instante en que cambio de celda
tLlegoInicio = 0;             % instante en que volvio a la celda de inicio
motivo      = 'interrumpido';  % si Webots se detiene, recarga o cierra antes del fin
tEtiqueta   = -inf;
visitadas   = false(N, N);    % celdas distintas visitadas (informativo)
dMin        = D(1, 1);        % menor distancia a la meta alcanzada
tD          = 0;              % instante en que la alcanzo

fprintf('[arbitro] Equipo "%s" en laberinto "%s" (%dx%d)\n', equipo, lab, N, N);

while wb_robot_step(TIME_STEP) ~= -1
    t   = wb_robot_get_time() - t0;      % tiempo del concurso
    pos = wb_supervisor_node_get_position(mouse);
    celda = floor(pos(1:2) / C);
    enInicio = all(celda == [0 0]);
    enMeta   = any(celda(1) == [g-1 g]) && any(celda(2) == [g-1 g]);
    if all(celda >= 0) && all(celda < N)
        visitadas(celda(1)+1, celda(2)+1) = true;
        if D(celda(1)+1, celda(2)+1) < dMin
            dMin = D(celda(1)+1, celda(2)+1);
            tD = t;
        end
    end

    if any(celda ~= celdaPrev)
        celdaPrev = celda;
        tCambio = t;
    end

    switch estado
        case 'EN_INICIO'
            if ~enInicio
                estado  = 'CORRIENDO';
                tSalida = t;
                fprintf('[arbitro] t=%7.3f s  sale del inicio (corrida %d)\n', t, size(corridas,1) + 1);
            end
        case 'CORRIENDO'
            if enMeta
                tc = t - tSalida;
                P  = tc + tSalida / FACTOR_PENALIZACION;
                corridas(end+1, :) = [tSalida, t, tc, P]; %#ok<SAGROW>
                estado = 'REGRESANDO';
                fprintf('[arbitro] t=%7.3f s  LLEGA A LA META: corrida %d = %.3f s, puntaje %.3f\n', ...
                        t, size(corridas,1), tc, P);
            elseif enInicio
                anuladas = anuladas + 1;
                estado = 'EN_INICIO';
                tLlegoInicio = t;
                fprintf('[arbitro] t=%7.3f s  regreso al inicio sin llegar: corrida anulada\n', t);
            end
        case 'REGRESANDO'
            if enInicio
                estado = 'EN_INICIO';
                tLlegoInicio = t;
                fprintf('[arbitro] t=%7.3f s  de vuelta en el inicio\n', t);
            end
    end

    % ---- marcador en pantalla ----
    if t - tEtiqueta >= 0.25
        tEtiqueta = t;
        if isempty(corridas)
            txtMejor = sprintf('-- (sin llegar: %.3f)', TIEMPO_LIMITE + PESO_DISTANCIA*dMin + tD/FACTOR_PENALIZACION);
        else
            [~, k] = min(corridas(:,4));
            txtMejor = sprintf('%.3f s (puntaje %.3f)', corridas(k,3), corridas(k,4));
        end
        if strcmp(estado, 'CORRIENDO')   % puntaje que tendria si llegara a la meta ahora
            txtActual = sprintf('%.2f s (puntaje %.3f)', t - tSalida, (t - tSalida) + tSalida/FACTOR_PENALIZACION);
        else,                           txtActual = '--';
        end
        txt = sprintf(['Tiempo: %.2f / %d s   Estado: %s\n' ...
                       'Corrida actual: %s\n' ...
                       'Completas: %d   Anuladas: %d   Celdas: %d   Dist. meta: %d\nMejor: %s'], ...
                      t, TIEMPO_LIMITE, estado, txtActual, ...
                      size(corridas,1), anuladas, nnz(visitadas), dMin, txtMejor);
        wb_supervisor_set_label(0, txt, 0.01, 0.17, 0.07, [1 1 1], 0, 'Arial');
    end

    % ---- fin del concurso ----
    if t >= TIEMPO_LIMITE
        motivo = 'tiempo limite'; break
    end
    if t - tCambio >= TIEMPO_ATORADO
        motivo = 'robot atorado'; break
    end
    if strcmp(estado, 'EN_INICIO') && ~isempty(corridas) && t - tLlegoInicio >= TIEMPO_ESTACIONADO
        motivo = 'robot estacionado en el inicio'; break
    end
end

% ---- resultados ----
t = min(wb_robot_get_time() - t0, TIEMPO_LIMITE);
if isempty(corridas)
    mejorT = NaN;
    mejorP = TIEMPO_LIMITE + PESO_DISTANCIA*dMin + tD/FACTOR_PENALIZACION;
else
    [mejorP, k] = min(corridas(:,4));
    mejorT = corridas(k,3);
end
fprintf('[arbitro] FIN (%s) en t=%.3f s. Completas: %d  Mejor tiempo: %.3f s  Puntaje: %.3f  Celdas: %d  Dist. meta: %d\n', ...
        motivo, t, size(corridas,1), mejorT, mejorP, nnz(visitadas), dMin);

dirRes = fullfile('..', '..', 'results');
if ~exist(dirRes, 'dir'), mkdir(dirRes); end
fecha = datestr(now, 'yyyy-mm-dd_HHMMSS'); %#ok<TNOW1,DATST>

resumen = fullfile(dirRes, 'resultados.csv');
encabezado = 'fecha,equipo,laberinto,completas,anuladas,celdas_visitadas,mejor_tiempo_s,mejor_puntaje,fin,t_fin_s,distancia_min,t_distancia_s';
if isfile(resumen)            % archivo de una version anterior del arbitro: se aparta
    fid = fopen(resumen, 'r'); l1 = fgetl(fid); fclose(fid);
    if ~ischar(l1) || ~strcmp(strtrim(l1), encabezado)
        movefile(resumen, fullfile(dirRes, ['resultados_anterior_' fecha '.csv']));
    end
end
nuevo = ~exist(resumen, 'file');
fid = fopen(resumen, 'a');
if nuevo
    fprintf(fid, '%s\n', encabezado);
end
fprintf(fid, '%s,%s,%s,%d,%d,%d,%.3f,%.3f,%s,%.3f,%d,%.3f\n', fecha, equipo, lab, size(corridas,1), ...
        anuladas, nnz(visitadas), mejorT, mejorP, motivo, t, dMin, tD);
fclose(fid);

fid = fopen(fullfile(dirRes, sprintf('%s_%s_%s.txt', equipo, lab, fecha)), 'w');
fprintf(fid, 'Equipo: %s\nLaberinto: %s (%dx%d)\nFin: %s en t = %.3f s\n\n', equipo, lab, N, N, motivo, t);
fprintf(fid, '%8s %10s %10s %10s %10s\n', 'corrida', 't_salida', 't_llegada', 't_corrida', 'puntaje');
for i = 1:size(corridas,1)
    fprintf(fid, '%8d %10.3f %10.3f %10.3f %10.3f\n', i, corridas(i,:));
end
fprintf(fid, '\nMejor tiempo: %.3f s   Puntaje final: %.3f\n', mejorT, mejorP);
fprintf(fid, 'Celdas distintas visitadas: %d de %d\n', nnz(visitadas), N*N);
if isempty(corridas)
    fprintf(fid, 'Sin corridas completas: distancia minima a la meta %d celdas (t = %.3f s)\n', dMin, tD);
    fprintf(fid, 'Puntaje = %d + %d*%d + %.3f/%d = %.3f\n', TIEMPO_LIMITE, PESO_DISTANCIA, dMin, ...
            tD, FACTOR_PENALIZACION, mejorP);
end
fclose(fid);

wb_supervisor_set_label(1, sprintf('FIN: %s', motivo), 0.01, 0.38, 0.08, [1 0.85 0], 0, 'Arial');

% Detiene la simulacion (no cierra Webots). Para torneos automaticos sin
% interfaz, definir la variable de entorno MICROMOUSE_SALIR=1 y Webots se cierra.
if strcmp(getenv('MICROMOUSE_SALIR'), '1')
    wb_supervisor_simulation_quit(0);
else
    wb_supervisor_simulation_set_mode(WB_SUPERVISOR_SIMULATION_MODE_PAUSE);
end
wb_robot_step(TIME_STEP);

% =====================================================================
function D = distancias_meta(N)
% Distancia en celdas (por los pasillos) de cada celda a la meta 2x2.
% Las paredes se leen del grupo DEF LABERINTO del mundo: cada MazeWall se
% llama pared_h_<x>_<j> (linea y = j, columna x) o pared_v_<i>_<y>
% (linea x = i, fila y). D(x+1, y+1) corresponde a la celda (x, y).
    H = false(N, N+1);        % H(x+1, j+1): pared sobre la linea y = j
    V = false(N+1, N);        % V(i+1, y+1): pared sobre la linea x = i
    grupo = wb_supervisor_node_get_from_def('LABERINTO');
    if isempty(grupo) || isequal(grupo, 0)
        warning('arbitro:laberinto', 'No se encontro DEF LABERINTO: se usa la distancia sin paredes.');
    else
        hijos = wb_supervisor_node_get_field(grupo, 'children');
        for k = 0:wb_supervisor_field_get_count(hijos) - 1
            nodo = wb_supervisor_field_get_mf_node(hijos, k);
            fn = wb_supervisor_node_get_field(nodo, 'name');
            if isempty(fn) || isequal(fn, 0), continue; end
            v = sscanf(wb_supervisor_field_get_sf_string(fn), 'pared_%c_%d_%d');
            if numel(v) ~= 3, continue; end
            if v(1) == 'h', H(v(2)+1, v(3)+1) = true; elseif v(1) == 'v', V(v(2)+1, v(3)+1) = true; end
        end
    end
    D = inf(N, N);
    g = N/2;
    cola = [g-1 g-1; g-1 g; g g-1; g g];
    for k = 1:4, D(cola(k,1)+1, cola(k,2)+1) = 0; end
    while ~isempty(cola)
        x = cola(1,1); y = cola(1,2); cola(1,:) = [];
        d = D(x+1, y+1) + 1;
        % vecino (a, b) y si hay pared entre las dos celdas
        vec = [x y+1 H(x+1, y+2);  x y-1 H(x+1, y+1);
               x+1 y V(x+2, y+1);  x-1 y V(x+1, y+1)];
        for m = 1:4
            a = vec(m,1); b = vec(m,2);
            if vec(m,3) || a < 0 || b < 0 || a >= N || b >= N, continue; end
            if D(a+1, b+1) > d
                D(a+1, b+1) = d;
                cola(end+1, :) = [a b]; %#ok<AGROW>
            end
        end
    end
end

function [id, integrantes] = buscar_equipo(archivo, controlador)
% Id e integrantes del equipo con ese controlador en equipos.txt
% (formato: id ; controlador ; integrantes ; grupo). Vacios si no esta.
    id = ''; integrantes = '';
    if ~isfile(archivo), return; end
    lineas = splitlines(string(fileread(archivo)));
    for i = 1:numel(lineas)
        l = strtrim(lineas(i));
        if l == "" || startsWith(l, "#"), continue; end
        c = strtrim(split(l, ";"));
        if numel(c) >= 3 && strcmp(c(2), controlador)
            id = char(c(1)); integrantes = char(c(3));
            de = 'áéíóúüñÁÉÍÓÚÜÑ'; a = 'aeiouunAEIOUUN';
            for j = 1:numel(de), integrantes(integrantes == de(j)) = a(j); end
            return
        end
    end
end
