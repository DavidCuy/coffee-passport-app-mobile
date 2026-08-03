# Arquitectura — Coffee Passport App (Mobile)

Fecha de la decisión: 2026-07-29.

## Decisión: Clean Architecture, organización **feature-first**

Se eligió **feature-first** sobre capas globales (`lib/domain`,
`lib/data`, `lib/presentation` a nivel raíz).

```
lib/
├── core/                          # (reservado, aún vacío) utilidades
│                                  # transversales: DI, manejo de errores,
│                                  # cliente HTTP, theming compartido.
│                                  # Se puebla cuando una 2da feature
│                                  # necesite compartir código con la 1ra
│                                  # — evita abstraer antes de tiempo.
├── features/
│   └── <feature>/
│       ├── domain/
│       │   ├── entities/
│       │   └── repositories/     # interfaces (contratos)
│       ├── data/
│       │   ├── datasources/      # (a futuro) REST/Firestore/local
│       │   └── repositories/     # implementaciones de las interfaces
│       └── presentation/
│           ├── widgets/
│           ├── screens/          # (a futuro)
│           └── controllers/      # (a futuro, según state mgmt elegido)
└── main.dart
```

### Por qué feature-first y no capas globales

La Fase 1 (`coffee-passport-obsidian-vault/10 - Proyectos/Pasaporte Café/
Fase 1 - Funcionalidades.md`) define secciones de producto muy
independientes entre sí: **Pasaporte** (perfil/sellos), **Mapa &
Directorio**, **Escáner QR**, **Diario de Cata** y **Laboratorio**
(fichas técnicas + recetas + calculadora). Cada una tiene su propio
modelo de datos, sus propios endpoints (pendientes, ver
`API endpoints` en el vault) y probablemente ritmos de desarrollo
distintos.

Con capas globales, un solo `lib/domain/entities` terminaría
mezclando `Shop`, `Stamp`, `TastingNote`, `CoffeeProfile`, `Recipe`,
etc., y cualquier cambio en una feature obliga a navegar por carpetas
compartidas con todo lo demás. Con feature-first, cada carpeta bajo
`lib/features/` es autocontenida (su propio `domain`/`data`/
`presentation`), se puede desarrollar, testear y hasta eliminar de
forma aislada, y el acoplamiento cruzado queda explícito porque
requiere un import entre features (o pasar por `core/`).

`lib/core/` queda reservado para cuando de verdad haga falta compartir
algo entre dos o más features (p. ej. un cliente HTTP común, manejo de
errores, o el contenedor de inyección de dependencias). Hoy está vacío
a propósito — no se creó código especulativo ahí.

### Regla de dependencia (Clean Architecture)

`presentation` → depende de → `domain` ← depende de ← `data`

- `domain` no importa nada de `data` ni de Flutter. Sólo entidades y
  contratos (interfaces de repositorio).
- `data` implementa los contratos de `domain`.
- `presentation` sólo conoce entidades y contratos de `domain`, nunca
  las implementaciones concretas de `data` (la composición/inyección
  ocurre en `main.dart` por ahora).

## Esqueleto ilustrativo incluido

Se agregó una única feature de ejemplo, `shop_directory`, para
demostrar el cableado de las 3 capas de punta a punta. **No es una
implementación real de ninguna pantalla del mock** — sólo ilustra el
patrón que las features reales (pasaporte, mapa, laboratorio, etc.)
deben seguir:

- `lib/features/shop_directory/domain/entities/shop.dart` — entidad
  `Shop` (id, nombre, dirección, lat/lng, `isStamped`).
- `lib/features/shop_directory/domain/repositories/shop_repository.dart`
  — interfaz `ShopRepository` (`getShops`, `getShopById`).
- `lib/features/shop_directory/data/repositories/shop_repository_impl.dart`
  — `ShopRepositoryImpl`, stub con datos en memoria (marcado con
  `TODO(fase-1)` para reemplazar por una fuente de datos real).
- `lib/features/shop_directory/presentation/widgets/shop_card.dart` —
  `ShopCard`, widget de presentación puro que sólo pinta una `Shop`.
- `lib/main.dart` — arma manualmente `ShopRepositoryImpl` y lo pasa a
  un `ShopDirectoryScaffold` mínimo que lista las cafeterías mock.

## Pendientes explícitos (no resueltos en este bootstrap)

- **State management**: no se eligió todavía (Provider/Riverpod/Bloc/
  etc.). `main.dart` usa composición manual + `FutureBuilder` sólo
  para el ejemplo.
- **Dependency injection**: no se agregó `get_it` ni similar. La
  composición es manual en `main.dart`.
- **`google_maps_flutter` / `geolocator`**: agregados a `pubspec.yaml`
  (2026-08-02, ver `lib/features/shop_directory/presentation/widgets/shop_map_view.dart`
  y `lib/features/scan/data/datasources/geolocation_datasource.dart`).
  `GeolocationDatasource` sigue viviendo bajo `features/scan/` (no se
  subió a `core/` a pesar de que ahora 2 features la usan, para no
  romper el import literal ya usado por
  `integration_test/common/mock_location.dart` del Agente QA Mobile)
  — `shop_directory` la importa cruzado explícitamente, caso
  contemplado por la regla de dependencias de más abajo.
- **Pantallas reales** (pasaporte, mapa, escáner QR, diario de cata,
  laboratorio): fuera de alcance de este bootstrap, son trabajo
  aparte.
- **Modelo de datos y endpoints**: pendientes de definir en el vault
  (`Base de datos`, `API endpoints`), como ya estaba anotado en
  `Fase 1 - Funcionalidades.md`.

## Referencias

- Producto/UX: `coffee-passport-obsidian-vault/10 - Proyectos/
  Pasaporte Café/Fase 1 - Funcionalidades.md`
- Mock UI: `mock-ui/pasaporte-cafe-mock.html`
