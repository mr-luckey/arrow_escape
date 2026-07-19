import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/game/data/datasources/level_asset_datasource.dart';
import '../../features/game/data/datasources/progress_local_datasource.dart';
import '../../features/game/data/repositories/repositories_impl.dart';
import '../../features/game/domain/repositories/repositories.dart';
import '../../features/game/domain/usecases/game_usecases.dart';
import '../../features/levels/presentation/bloc/progress_cubit.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../ads/ads_service.dart';
import '../audio/audio_service.dart';
import '../haptics/haptics_service.dart';
import '../store/app_store_service.dart';
import '../theme/theme_cubit.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  sl.registerLazySingleton(() => AudioService());
  sl.registerLazySingleton(() => HapticsService());
  sl.registerLazySingleton(() => AdsService(sl()));
  sl.registerLazySingleton(() => AppStoreService(sl()));
  sl.registerLazySingleton(() => LevelAssetDataSource());
  sl.registerLazySingleton(() => ProgressLocalDataSource(sl()));

  sl.registerLazySingleton<LevelRepository>(
    () => LevelRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProgressRepository>(
    () => ProgressRepositoryImpl(sl()),
  );

  sl.registerLazySingleton(() => const CanEscapeUseCase());
  sl.registerLazySingleton(() => ApplyMoveUseCase(canEscape: sl()));
  sl.registerLazySingleton(() => GetHintUseCase(canEscape: sl()));

  sl.registerFactory(() => ThemeCubit(sl()));
  sl.registerFactory(() => SettingsCubit(sl(), sl(), sl()));
  sl.registerFactory(() => ProgressCubit(sl(), sl()));
}
