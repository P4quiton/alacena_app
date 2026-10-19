# Alacena App

Aplicación móvil hecha con **Flutter** para gestionar el inventario doméstico (la alacena): controla las existencias por lotes, avisa de los productos caducados, agotados o próximos a caducar, y mantiene la trazabilidad de las compras por tienda. Todos los datos se guardan en el dispositivo con **SQLite** (`sqflite`), así que funciona sin conexión.

Práctica de la materia de desarrollo de aplicaciones móviles, Instituto Tecnológico de Celaya.

## Integrantes

- Gael González Cruz - 21030466
- Abraham Silva Méndez - 20031313

## Capturas de pantalla
### Pantalla de inicio
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/e353bf71-26cf-4985-aec8-8996db0d7f24" />
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/fe9a88db-e34b-43bd-b78b-0269281cb908" />

### Calendario
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/1f2bd276-716a-4c2f-af77-2bbebe8ae9d3" />

### Pantalla que indica los alimentos que caducan el dia hoy
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/c0e0b0de-87bb-40cf-950d-98be5d340c92" />

### Categorias
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/928eea44-db1e-422f-8d5d-55aa48064f47" />

### Tiendas
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/8408b07c-93e7-4af0-8a4c-3fe9ad63a6e4" />

### Pantalla para agregar productos
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/6d7e3409-fb55-4886-8d42-48be162fda40" />

### Los dos widgets Extras
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/0ba03e88-1df0-4a63-929f-b5ac01490b02" />
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/0d7e4e93-eb9e-477f-9407-77bd150fc4be" />

### Funcionalidad extra añadida al carrito para que su uso sea mas redondo
<img width="720" height="1600" alt="image" src="https://github.com/user-attachments/assets/983b5074-12a1-4eba-89e4-af69817f3a53" />


## Funcionalidades

### Pantalla principal

- Lista los productos con alerta (**Alertas**) o todo el inventario (**Todos**) mediante un selector `SegmentedButton`.
- Cada producto muestra su imagen, existencias, próxima caducidad y una etiqueta de color con su estatus:

| Estatus | Cuándo aparece |
|---|---|
| **Caducado** | Tiene al menos un lote con fecha de caducidad vencida |
| **Agotado** | El stock total es 0 o no tiene lotes |
| **Por caducar** | Tiene un lote que caduca hoy o en los próximos 3 días |
| **Por agotarse** | El stock total es menor o igual al stock mínimo del producto |
| **Disponible** | Ninguna de las anteriores |

- Las listas usan **Slivers** (`CustomScrollView`, `SliverAppBar`, `SliverList`, `SliverToBoxAdapter`).

### Calendario de caducidades

- Usa el paquete [`table_calendar`](https://pub.dev/packages/table_calendar).
- Cada lote activo cuenta como un punto en su fecha de caducidad: si varios productos caducan el mismo día, ese día muestra un punto por cada uno.
- Al tocar un día con productos se abre un **modal a pantalla completa** con el listado de ese día (imagen, nombre, cantidad del lote, fecha y estatus).

### Carrito de compras

- Icono en la esquina superior derecha de la pantalla principal con un contador, usando el paquete [`badges`](https://pub.dev/packages/badges).
- Botón en cada producto para agregarlo al carrito.
- En el carrito se cambia la cantidad con + y −, se desliza un producto para quitarlo y se puede vaciar la lista.
- El carrito se guarda en la base de datos, así que se conserva al cerrar la app.

### Productos, categorías y tiendas (CRUD)

- **Categorías** y **tiendas**: crear, editar y eliminar, con aviso cuando no se pueden eliminar por tener productos o compras asociados.
- **Productos**: crear eligiendo su categoría (con foto desde la cámara o la galería), editar y eliminar.
- Un producto con compras registradas **no se puede eliminar**, para conservar el historial; la app lo avisa con un mensaje claro.

### Lotes y reglas de negocio

- **FEFO** (First Expired, First Out): un producto puede tener varios lotes con distinta caducidad. Al consumir unidades, el sistema descuenta primero del lote que caduca antes y nunca consume lotes caducados.
- **Estado Agotado**: el stock total es la suma de la cantidad de los lotes activos (cantidad mayor que 0).
- **Descartar lote**: un lote se descarta poniendo su cantidad en 0, sin borrarlo, para no romper el historial de compras.

### Trazabilidad de tiendas

- Cada compra se guarda en `historial_compras`, vinculando el producto, la tienda, el lote creado, la cantidad, el precio y la fecha.
- Un **trigger de SQLite** actualiza `productos.ultima_tienda_id` cada vez que se inserta una compra.
- En el detalle de cada producto se ve la última tienda, todas las tiendas donde se ha comprado (como etiquetas `Chip`) y la lista de compras.

### Alarmas locales

- El campo `alerta_activa` de la tabla `lotes` indica si el lote genera aviso.
- La app programa **una notificación a las 8:00 a. m.** por cada día en que caduca algún lote activo con alerta encendida (se programan los próximos 60 días).
- Al tocar la notificación se abre la pantalla **Caducan hoy** con los productos que caducan ese día.
- Las alarmas se reprograman al abrir la app y cada vez que cambian los lotes (compras, consumos y descartes).
- Se usa el paquete [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) en modo no exacto, por lo que la notificación puede llegar con uno o dos minutos de diferencia.

## Funcionalidad extra

**Carrito conectado con las compras.** Cada producto del carrito tiene el botón **"Ya lo compré"**, que abre el formulario de compra con ese producto ya seleccionado. Al guardar la compra se crea el lote, se registra en el historial, se actualiza la última tienda y el producto sale solo del carrito. Así la lista de compras, el registro de compras y el inventario forman un solo flujo.

## Widgets nuevos

Además de los solicitados en la práctica y de los vistos en clase:

| Widget | Dónde se usa |
|---|---|
| `Dismissible` | Carrito: se desliza un producto hacia la izquierda para quitarlo |
| `Chip` | Detalle del producto: una etiqueta por cada tienda donde se ha comprado |

## Base de datos

Base de datos SQLite local (`alacena.db`) con claves foráneas activadas y restricciones de dominio (`CHECK`, `NOT NULL`, `UNIQUE`).

| Tabla | Descripción |
|---|---|
| `categorias` | Categorías de los productos |
| `tiendas` | Establecimientos donde se compra |
| `productos` | Catálogo de productos, con categoría, stock mínimo, imagen y `ultima_tienda_id` |
| `lotes` | Existencias de cada producto con su fecha de caducidad y `alerta_activa` |
| `historial_compras` | Cada compra, ligada a producto, tienda y lote |
| `carrito` | Carrito de compras (estado activo o completado) |
| `carrito_detalles` | Productos y cantidades de cada carrito |

**Integridad referencial:** las claves foráneas usan `ON DELETE RESTRICT`, por lo que no se puede borrar una categoría, tienda o producto con registros asociados. La interfaz revisa esos casos antes y muestra un mensaje en lugar de dejar que la operación falle.

## Paquetes utilizados

| Paquete | Uso |
|---|---|
| `sqflite` | Base de datos local |
| `table_calendar` | Calendario de caducidades |
| `badges` | Contador del icono del carrito |
| `flutter_local_notifications` y `timezone` | Alarmas locales |
| `image_picker` y `path_provider` | Fotos de los productos |
| `intl` | Formato de fechas |

## Estructura del proyecto

```text
lib/
├── main.dart
├── core/
│   ├── database/database_helper.dart
│   └── notifications/notification_service.dart
├── data/
│   ├── models/          # Producto, Lote, Categoria, Tienda, HistorialCompra, Carrito...
│   └── repositories/    # Acceso a datos y reglas de negocio (FEFO, compras)
└── features/
    ├── inventory/screens/   # Inventario, detalle, formulario de producto, categorías
    ├── purchases/screens/   # Formulario de compra y tiendas
    ├── cart/screens/        # Carrito
    ├── calendar/screens/    # Calendario y modal por día
    └── alarms/screens/      # Pantalla "Caducan hoy"
```

## Cómo ejecutar el proyecto

Requisitos: Flutter con Dart `^3.13.1` y un dispositivo o emulador Android.

```bash
git clone https://github.com/P4quiton/alacena_app.git
cd alacena_app
git switch develop
flutter pub get
flutter run
```

Notas:

- En Android 13 o superior, la app pide permiso para mostrar notificaciones.
- En teléfonos Xiaomi (MIUI) conviene activar **Inicio automático** y poner el ahorro de batería en **Sin restricciones** para que las alarmas lleguen con la app cerrada.
- Las alarmas solo se programan para lotes con caducidad desde hoy en adelante.

## Ramas

- `main`: versión estable y entregable.
- `develop`: desarrollo; se fusiona a `main` mediante Pull Request.
