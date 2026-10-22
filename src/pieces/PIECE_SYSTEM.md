# Sistema de Piezas (Piece System)

Documentación técnica sobre la arquitectura, funcionamiento, cinemática y uso de la escena unificada de piezas (`Piece.tscn`) en el juego de Parqués.

---

## 1. Filosofía de Diseño y Arquitectura

El sistema implementa el principio de **Composición sobre Herencia** y una estricta separación de responsabilidades entre **Lógica/Física** y **Presentación/Visual**:

```
				  ┌───────────────────────────────────────────────┐
				  │            MainGame / GameController          │
				  └───────────────────────┬───────────────────────┘
										  │ Órdenes de juego (await move_steps_to, etc.)
										  ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Piece.tscn (Area3D) - Entidad Física y Lógica (Piece.gd)                       │
│  - Identidad: team, slot, piece_color                                           │
│  - Detección de interacción: CollisionShape3D (input_event, piece_selected)     │
│  - Control de interpolación y tweens de movimiento                              │
│  - Señales: moved_to, step_reached, movement_finished, piece_selected           │
│                                                                                 │
│      ┌───────────────────────────────────────────────────────────────────┐      │
│      │  Visual (Node3D) - Componente Gráfico y Cinemático (PieceVisual)  │      │
│      │  - Generación de mallas procedurales (SurfaceTool, prismas, etc.) │      │
│      │  - Cinemática de articulaciones, gimbals y alas en _process()     │      │
│      │  - Previsualización en vivo en el Editor de Godot (@tool)         │      │
│      │  - AnimatedRig (Esqueleto y partes acopladas)                     │      │
│      └───────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Ventaja clave:
Si en el futuro se sustituyen las mallas procedurales por modelos 3D exportados de Blender (`.gltf` o `.fbx`), **la lógica del juego (`GameController`), las reglas (`ParquesRules`) y la física de la pieza (`Piece.gd`) no se modifican en absoluto**; solo se actualiza el nodo `Visual`.

---

## 2. Estructura de la Escena (`Piece.tscn`)

El archivo [`Piece.tscn`](./Piece.tscn) contiene los siguientes nodos:

```text
Piece (Area3D - Script: src/pieces/Piece.gd)
├── CollisionShape3D (CylinderShape3D: radio 0.55m, altura 1.6m)
└── Visual (Node3D - Script: src/pieces/PieceVisual.gd)
	└── AnimatedRig (Generado proceduralmente en tiempo de ejecución)
```

1. **`Piece` (`Area3D`)**: Raíz de la escena. Representa la posición lógica y física de la ficha en el tablero 3D.
2. **`CollisionShape3D`**: Cilindro de colisión para detección de clics del ratón vía raycast y eventos de entrada (`input_event`).
3. **`Visual` (`Node3D`)**: Contenedor del rig paramétrico y animaciones.

---

## 3. Entidad Física y Lógica (`Piece.gd`)

El script [`Piece.gd`](./Piece.gd) gestiona el estado de juego y proporciona una API declarativa de alto nivel para mover la ficha en el tablero.

### 3.1. Señales
* `moved_to(destination: Vector3)`: Emitida al completar cualquier movimiento hacia una posición final.
* `step_reached(step_position: Vector3)`: Emitida cada vez que la pieza pisa una casilla intermedia durante su recorrido.
* `movement_finished()`: Emitida cuando cesan todos los tweens de animación activos.
* `piece_selected()`: Emitida cuando el jugador hace clic izquierdo sobre el `CollisionShape3D` de la pieza.

### 3.2. Métodos de Movimiento (API para MainGame)

Todos los métodos devuelven una señal compatible con `await`, lo que permite secuenciar el audio, turnos y efectos especiales en `GameController`:

#### `move_release_to(destination: Vector3) -> Signal`
Mueve la pieza desde la base de salida de la cárcel hacia la casilla de inicio (*salida*).
* Calcula un arco parabólico con un punto ápice a $+2.5\text{ m}$ de altura.
* Orienta la pieza hacia el destino (`face_destination`).
* Activa la cinemática de despegue (`play_launch`) y al tocar tierra activa el impulso de asentamiento (`play_arrival`).

#### `move_steps_to(waypoints: Array[Vector3], final_target: Vector3) -> Signal`
Recorre paso a paso la secuencia de casillas del tablero.
* Por cada casilla en `waypoints`, rota progresivamente la pieza mirando al siguiente punto.
* Utiliza el ritmo de paso propio de la facción (`step_duration()`).
* Emite `step_reached` en cada pisada para sincronizar partículas o sonidos de pisadas.
* Concluye con un asentamiento suave en `final_target`.

#### `move_bonus_to(goal_position: Vector3) -> Signal`
Ejecuta la animación especial cuando el jugador saca tres dobles seguidos:
* Salto propulsado verticalmente hacia el centro del tablero a $3\text{ m}$ de altura en $0.6\text{ s}$.
* Descenso triunfal hacia el núcleo de llegada en $0.3\text{ s}$.

#### `move_smooth_to(target_pos: Vector3, duration: float = 0.3) -> Signal`
Interpola suavemente la pieza hacia una posición concreta mediante una curva cúbica (`TRANS_CUBIC`, `EASE_OUT`). Empleado durante sincronizaciones de tablero o tras una captura enemiga.

#### `kill_movement() -> void`
Cancela de forma segura cualquier tween activo en la pieza y detiene la cinemática de marcha en el componente visual.

---

## 4. Componente Gráfico y Cinemático (`PieceVisual.gd`)

El script [`PieceVisual.gd`](./PieceVisual.gd) genera toda la geometría mediante `SurfaceTool` sin necesidad de texturas externas o dependencias binarias pesadas.

### 4.1. Facciones Soportadas
Cada facción posee una silueta, distribución de extremidades y cinemática propia:

| Facción | Nombre | Estructura | Cinemática en `_process()` |
| :---: | :--- | :--- | :--- |
| **0** | **Crimson Sentinel** | Bípedo pesado acorazado con pelvis, hombreras, rodillas articuladas, cuello y faldones/mantos. | Zancada firme (`gait = phase * 12`), flexión de rodillas opuestas y oscilación de manto. |
| **1** | **Viridian Warden** | Guardián botánico bípedo con tronco de corteza, capa de 7 hojas articuladas y semilla mística en las manos. | Paso cadencioso (`gait = phase * 8`), ondulación de pétalos y respiración de la semilla. |
| **2** | **Azure Drone** | Unidad orbital levitante con núcleo cristalino, gimbals ópticos, anillo meridiano y 3 satélites triangulares. | Precesión giroscópica, inclinación lateral al girar (`bank`) y rotación orbital continua de satélites. |
| **3** | **Solar Skimmer** | Planeador aeroespacial con piloto articulado al descubierto, estabilizadores alares, bufanda y dos propulsores de plasma. | Balanceo aerodinámico, bufanda al viento (`phase * 9`) y modulación de la llama del reactor según la velocidad. |

### 4.2. Variantes de Tripulación (Slots 0 a 3)
Cada equipo dispone de 4 tripulantes con nombres de llamada (*callsigns*), siluetas y accesorios únicos:
* **Sentinel**: *Bulwark*, *Pathfinder*, *Standard*, *Veteran*.
* **Warden**: *Rootkeeper*, *Bloomtender*, *Wayfarer*, *Elder*.
* **Drone**: *Surveyor*, *Cartographer*, *Relay*, *Archivist*.
* **Skimmer**: *Hotshot*, *Longwing*, *Courier*, *Old Glory*.

---

## 5. Inspección en Vivo en el Editor de Godot (`@tool`)

Al abrir [`Piece.tscn`](./Piece.tscn) en el editor de Godot, el nodo `Visual` reconstruye el modelo procedural en el viewport 3D. El panel **Inspector** expone:

### Grupo `Faction & Crew`
* **`preview_faction`**: Desplegable para alternar entre Sentinel, Warden, Drone y Skimmer.
* **`preview_slot`**: Selector (0–3) para revisar cada uno de los 4 tripulantes.
* **`callsign`**: Muestra en tiempo real el nombre de llamada oficial correspondiente.
* **`auto_faction_color`**: Si está activado, asigna automáticamente la paleta de color oficial de la facción.
* **`preview_color`**: Selector de color personalizado para iluminación y armaduras.

### Grupo `Editor Animation Preview`
* **`animate_in_editor`**: Activa la cinemática en vivo en el viewport de Godot (respiración, flotación y giros).
* **`preview_moving`**: Simula el estado de marcha para calibrar la zancada o el empuje de turbinas.
* **`preview_attention`**: Dispara la animación de atención/selección.

---

## 6. Pruebas Automatizadas Relacionadas

* [`tests/unit/test_unit_visuals.gd`](../tests/unit/test_unit_visuals.gd): Verifica orientación de ruta, blending de marcha, impulsos de asentamiento, firmas geométricas de tripulantes y rebuilds dinámicos.
* [`tests/integration/test_arena.gd`](../tests/integration/test_arena.gd): Comprueba la colocación de las 16 fichas en sus bases de lanzamiento.
* [`tests/integration/test_game_flow.gd`](../tests/integration/test_game_flow.gd): Valida los movimientos en tiempo real durante una partida completa.
