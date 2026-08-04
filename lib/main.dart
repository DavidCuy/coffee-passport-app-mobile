import 'package:flutter/material.dart';

import 'core/auth/dev_auth_local_datasource.dart';
import 'core/auth/dev_login_screen.dart';
import 'core/network/api_client.dart';
import 'features/diary/data/repositories/diary_repository_impl.dart';
import 'features/diary/domain/repositories/diary_repository.dart';
import 'features/diary/presentation/screens/diary_screen.dart';
import 'features/lab/data/repositories/coffee_repository_impl.dart';
import 'features/lab/data/repositories/recipe_repository_impl.dart';
import 'features/lab/domain/repositories/coffee_repository.dart';
import 'features/lab/domain/repositories/recipe_repository.dart';
import 'features/lab/presentation/screens/lab_screen.dart';
import 'features/passport/data/repositories/passport_repository_impl.dart';
import 'features/passport/domain/repositories/passport_repository.dart';
import 'features/passport/presentation/screens/passport_screen.dart';
import 'features/passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import 'features/scan/data/repositories/scan_repository_impl.dart';
import 'features/scan/domain/repositories/scan_repository.dart';
import 'features/scan/presentation/screens/scan_screen.dart';
import 'features/shop_directory/data/repositories/favorite_repository_impl.dart';
import 'features/shop_directory/data/repositories/shop_repository_impl.dart';
import 'features/shop_directory/data/repositories/shop_review_repository_impl.dart';
import 'features/shop_directory/domain/repositories/favorite_repository.dart';
import 'features/shop_directory/domain/repositories/shop_repository.dart';
import 'features/shop_directory/domain/repositories/shop_review_repository.dart';
import 'features/shop_directory/presentation/screens/shop_directory_screen.dart';

void main() {
  runApp(const CoffeePassportApp());
}

/// Punto de entrada de la app.
///
/// La composición de dependencias sigue siendo manual y explícita (sin
/// get_it/riverpod todavía, ver `ARCHITECTURE.md`): se arma un único
/// [ApiClient] compartido (`core/network`) y se inyecta en los
/// repositorios reales de cada feature (`passport`, `scan`,
/// `shop_directory`).
///
/// Antes de mostrar cualquier pantalla real, hace de gate un "dev
/// login" temporal (ver `core/auth/dev_auth_local_datasource.dart`) —
/// mientras no exista login real, el backend exige un
/// `X-Auth-User-Sub` que hoy sólo puede venir de ahí.
class CoffeePassportApp extends StatelessWidget {
  const CoffeePassportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasaporte Café',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PassportColors.primary,
          primary: PassportColors.primary,
        ),
        scaffoldBackgroundColor: PassportColors.background,
        useMaterial3: true,
      ),
      home: const _AppRoot(),
    );
  }
}

/// Decide si mostrar el dev-login o la app real, según si ya hay un
/// `sub` de prueba guardado.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _authDatasource = DevAuthLocalDatasource();
  late Future<String?> _devSubFuture = _authDatasource.getDevSub();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _devSubFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final sub = snapshot.data;
        if (sub == null) {
          return DevLoginScreen(
            datasource: _authDatasource,
            onLoggedIn: (_) {
              setState(() {
                _devSubFuture = _authDatasource.getDevSub();
              });
            },
          );
        }
        return const _HomeTabs();
      },
    );
  }
}

/// Navegación mínima entre las pantallas reales construidas hasta
/// ahora (Pasaporte, Escanear, Cafeterías, Diario de cata,
/// Laboratorio). No es una feature en sí — es sólo el andamiaje de
/// navegación necesario para poder probarlas todas desde un solo
/// build.
class _HomeTabs extends StatefulWidget {
  const _HomeTabs();

  @override
  State<_HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<_HomeTabs> {
  final ApiClient _apiClient = ApiClient();
  late final PassportRepository _passportRepository = PassportRepositoryImpl(
    apiClient: _apiClient,
  );
  late final ScanRepository _scanRepository = ScanRepositoryImpl(
    apiClient: _apiClient,
  );
  late final ShopRepository _shopRepository = ShopRepositoryImpl(
    apiClient: _apiClient,
  );
  late final FavoriteRepository _favoriteRepository = FavoriteRepositoryImpl(
    apiClient: _apiClient,
  );
  late final ShopReviewRepository _shopReviewRepository =
      ShopReviewRepositoryImpl(apiClient: _apiClient);
  late final DiaryRepository _diaryRepository = DiaryRepositoryImpl(
    apiClient: _apiClient,
  );
  late final CoffeeRepository _coffeeRepository = CoffeeRepositoryImpl(
    apiClient: _apiClient,
  );
  late final RecipeRepository _recipeRepository = RecipeRepositoryImpl(
    apiClient: _apiClient,
  );

  int _index = 0;

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PassportScreen(repository: _passportRepository),
      ScanScreen(repository: _scanRepository),
      ShopDirectoryScreen(
        shopRepository: _shopRepository,
        favoriteRepository: _favoriteRepository,
        shopReviewRepository: _shopReviewRepository,
      ),
      DiaryScreen(
        diaryRepository: _diaryRepository,
        shopRepository: _shopRepository,
      ),
      LabScreen(
        coffeeRepository: _coffeeRepository,
        recipeRepository: _recipeRepository,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: PassportColors.surface,
        // Keys estables para QA (Patrol/integration_test): navegar entre
        // pantallas sin depender del texto/idioma del label.
        destinations: const [
          NavigationDestination(
            key: Key('nav_passport_tab'),
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Pasaporte',
          ),
          NavigationDestination(
            key: Key('nav_scan_tab'),
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Escanear',
          ),
          NavigationDestination(
            key: Key('nav_shops_tab'),
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Cafeterías',
          ),
          NavigationDestination(
            key: Key('nav_diary_tab'),
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Diario',
          ),
          NavigationDestination(
            key: Key('nav_lab_tab'),
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Laboratorio',
          ),
        ],
      ),
    );
  }
}
