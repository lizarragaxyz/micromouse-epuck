# Micromouse con e-puck en Webots

Proyecto final de **Modelado y Simulación de Sistemas**. Cada equipo programa
un e-puck que debe explorar un laberinto desconocido, llegar al centro y luego
recorrerlo lo más rápido posible, igual que en la competencia **Micromouse
clásica del IEEE**.

Los laberintos ya vienen hechos: el repositorio incluye **10 de 8 × 8** y
**10 de 16 × 16** para desarrollar y probar. **Lo único que entrega cada equipo es
el controlador del robot.** Al final, el profesor carga cada controlador en un
laberinto **sorpresa de 16 × 16** y los equipos compiten uno contra uno.

- **Simulador:** Webots R2025a
- **Lenguaje:** MATLAB (únicamente)
- **Robot:** e-puck estándar de GCtronic (versión 1), con la extensión de sensores de piso

## Documentos

- [Convocatoria](docs/convocatoria/Convocatoria.pdf)
- [Reglamento](docs/reglamento/Reglamento.pdf): es la referencia oficial; este README solo lo resume.
- Reporte técnico: [plantilla LaTeX BitacoraSKv2](docs/bitacora/plantilla/) y su
  [manual de uso](docs/bitacora/Manual_de_Uso_BitacoraSKv2.pdf).

---

## Inicio rápido

1. Abran `worlds/practica_8x8_01.wbt` en Webots y ejecuten la simulación. El e-puck
   sigue la pared derecha celda por celda y el árbitro muestra el marcador en
   pantalla. El seguidor de pared **nunca llega a la meta**: para eso necesitan
   su propio algoritmo.
2. Copien `controllers/epuck_plantilla/` con el nombre de su equipo, por
   ejemplo `controllers/equipo_rojo/equipo_rojo.m`. El nombre de la carpeta y
   el del archivo deben ser iguales, sin espacios ni acentos.
3. Para que el robot use su controlador: en el árbol de la escena de Webots,
   seleccionen `DEF MOUSE E-puck`, luego el campo `controller`, y elijan su
   carpeta. Guarden el mundo. **Es el único cambio permitido a los mundos.**
4. Desarrollen primero en los 8 × 8 y después verifiquen en los 16 × 16.
   Prueben en **todos**: cada laberinto tiene una ruta y unos ciclos distintos.

> Su robot debe funcionar en **cualquier** laberinto que cumpla el estándar,
> no solo en los de práctica. La competencia es en un laberinto que nadie
> conoce.

---

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `worlds/practica_8x8_01.wbt` … `practica_8x8_10.wbt` | 10 laberintos de práctica de 8 × 8 |
| `worlds/practica_16x16_01.wbt` … `practica_16x16_10.wbt` | 10 laberintos de práctica de 16 × 16 (tamaño de competencia) |
| `controllers/epuck_plantilla/` | Plantilla con todos los dispositivos del e-puck inicializados y un seguidor de pared de ejemplo |
| `controllers/referee/` | Árbitro automático (Supervisor). **No modificar** |
| `protos/` | Pared y poste con dimensiones IEEE |
| `results/` | Resultados del árbitro (`resultados.csv` y el detalle de cada concurso) |
| `docs/convocatoria/` | Convocatoria (PDF) |
| `docs/reglamento/` | Reglamento (PDF) |
| `docs/bitacora/` | Plantilla LaTeX del reporte técnico (`plantilla/`) y su manual de uso (PDF) |

---

## Los laberintos

### Dimensiones (estándar IEEE, Micromouse clásico)

| Elemento | Medida |
|---|---|
| Celda | 18 cm × 18 cm |
| Paredes | 5 cm de alto, 1.2 cm de grosor, lados blancos y tapa roja |
| Postes | 1.2 × 1.2 cm, 5 cm de alto |
| Laberinto de competencia | 16 × 16 celdas (2.88 m × 2.88 m) |
| Piso | Negro. La meta (2 × 2 central) es **amarilla** |

### Lo que cumple todo laberinto, incluido el sorpresa

| Regla | Descripción |
|---|---|
| R1 | Cuadrado `N x N`, con `N` par (competencia: 16) |
| R2 | Paredes consistentes entre celdas vecinas |
| R3 | Perímetro completamente cerrado |
| R4 | Inicio en la esquina suroeste, cerrado por 3 lados y abierto solo al norte |
| R5 | Meta: 2 × 2 celdas al centro, sin paredes internas y con **una sola entrada** |
| R6 | Todo poste, salvo el central de la meta, toca al menos una pared |
| R7 | La meta es alcanzable desde el inicio |
| R8 | La meta **no** se alcanza siguiendo la pared derecha ni la izquierda |

Además, el laberinto sorpresa tiene **varias rutas** a la meta: la primera
que encuentre el robot no necesariamente es la más corta.

---

## Reglas de la competencia

### El robot

- El e-puck oficial lo definen los mundos del repositorio: versión 1
  (GCtronic), sensores de piso, paso de simulación de 16 ms y velocidad máxima
  de rueda de 6.28 rad/s.
- Se entrega **únicamente el controlador** en MATLAB: la carpeta
  `controllers/<equipo>/`. No se modifican el robot, el mundo, los PROTO ni el
  árbitro.
- El robot parte de la celda de inicio, viendo al norte. **No conoce el
  laberinto.**
- Se deben usar los dispositivos del e-puck:

| Dispositivo | Nombre en Webots |
|---|---|
| Sensores IR de proximidad | `ps0` … `ps7` |
| Sensores de luz | `ls0` … `ls7` |
| Sensores de piso | `gs0` … `gs2` |
| Encoders | `left wheel sensor`, `right wheel sensor` |
| Acelerómetro y giroscopio | `accelerometer`, `gyro` |
| Cámara | `camera` |
| LEDs | `led0` … `led9` |
| Emisor y receptor | `emitter`, `receiver` |

### Prohibido

- Usar funciones de Supervisor (`wb_supervisor_*`) en el controlador del robot.
- Leer archivos de laberinto, mundos (`.wbt`) o cualquier archivo de datos.
- Incluir en el controlador laberintos guardados o precalculados, incluidos los
  de ejemplo.
- Usar GPS, posición absoluta o cualquier dato que no venga de los sensores del
  e-puck.
- Modificar los archivos oficiales.

Violar estas reglas descalifica al equipo.

### Cómo se mide (árbitro automático)

Todo se mide en **tiempo de simulación**, así que el resultado no depende de la
computadora.

1. Una **corrida** inicia cuando el centro del robot **sale** de la celda de
   inicio y termina cuando **entra** a la meta.
2. Para iniciar otra corrida, el robot debe regresar **por sí solo** a la celda
   de inicio. Puede conservar en memoria el mapa que construyó.
3. Si en una corrida el robot vuelve al inicio sin llegar a la meta, la corrida
   se anula.
4. El puntaje de cada corrida es

   **P = t_corrida + t_salida / 30**

   donde `t_salida` es el instante (contado desde `t = 0`) en que inició esa
   corrida. Explorar rápido también cuenta. El puntaje del robot es el **menor
   P** de sus corridas completas. Una corrida completa nunca pasa de 600.
   Si el robot **no completa ninguna corrida**, su puntaje es

   **P = 600 + 30·d + t_d / 30**

   donde `d` es la distancia a la meta, en celdas por los pasillos, de la celda
   más cercana a la meta que visitó, y `t_d` el instante en que llegó a ella.
   Así, llegar a la meta siempre es mejor que no llegar, y entre los que no
   llegan gana el que quedó más cerca.
5. El concurso de cada robot termina con lo que ocurra primero:
   - **10 minutos** de simulación;
   - el robot no cambia de celda en **60 s** (se considera atorado);
   - el robot se queda **30 s** en la celda de inicio después de haber
     completado al menos una corrida (así puede terminar su turno antes).

### Torneo

- Equipos de **máximo 3 integrantes**.
- Clasificación en un laberinto sorpresa de 16 × 16.
- Después, eliminatoria uno contra uno por posiciones (1.° contra último, …),
  Cada llave tiene su propio laberinto sorpresa, distinto de todos los demás;
  los dos robots de la llave corren en él, primero el mejor clasificado.
- Gana el menor puntaje. En un empate exacto: mayor número de celdas distintas
  visitadas (lo registra el árbitro) y luego la mejor posición en la clasificación.

---

## Entregas (evaluación secuencial)

> **Cada entrega solo se evalúa si se entregaron todas las anteriores.** Si un
> equipo no entrega un hito, ninguna de las entregas siguientes se evalúa: por
> ejemplo, sin el H2 no se evalúan el H3, el H4, llegada, regreso, corrida rápida ni el reporte.
>
> **Todo se entrega en las semanas 14 y 15.** Los hitos H1–H4 se entregan junto
> con el controlador final, el **martes 17 de noviembre**.

> [!IMPORTANT]
> **El controlador se entrega el martes 17 de noviembre (semana 14)**, una semana
> antes del torneo, para resolver a tiempo cualquier percance: errores de
> MATLAB, nombres de carpeta o problemas de compatibilidad. Después del 17 de
> noviembre **no se recibe ningún controlador**. Hasta el viernes 20 solo se
> aceptan correcciones de compatibilidad sobre el controlador ya entregado.

- [ ] **Inscripción**: nombre del equipo e integrantes (semana 14, en el salón de clases)
- [ ] **H1, sensores y modelo**: calibración de sensores IR, modelo cinemático y odometría (martes 17 de noviembre)
- [ ] **H2, movimiento celda por celda** en el 8 × 8: avanzar, girar y centrarse (martes 17 de noviembre)
- [ ] **H3, mapeo y flood fill**: llegar a la meta en el 8 × 8 y en el 16 × 16 (martes 17 de noviembre)
- [ ] **H4, robot completo**: regreso, corridas rápidas y uso de todos los dispositivos (martes 17 de noviembre)
- [ ] **Entrega del controlador final**: **martes 17 de noviembre (semana 14)**. Esa semana se revisa que funcione en el equipo del profesor; las correcciones de compatibilidad se aceptan hasta el viernes 20 de noviembre.
- [ ] **Torneo**: **semana 15, del 23 al 27 de noviembre**
- [ ] **Reporte técnico y video**: semana 15, del 23 al 27 de noviembre. El reporte
  se hace con la plantilla LaTeX **BitacoraSKv2**, que ya viene en
  [`docs/bitacora/plantilla/`](docs/bitacora/plantilla/): trabajen sobre `main.tex`.
  El [manual de uso](docs/bitacora/Manual_de_Uso_BitacoraSKv2.pdf) explica cómo usarla.

---

## Licencia

Este repositorio se distribuye bajo la [licencia MIT](LICENSE).

El logotipo del ITESO (`docs/bitacora/plantilla/figures/logoiteso.png`) es
propiedad del ITESO y no está cubierto por esta licencia. El modelo del e-puck
y los fondos de los mundos son de Cyberbotics: los mundos solo los referencian
(no se incluyen aquí) y se rigen por la licencia de Webots.
