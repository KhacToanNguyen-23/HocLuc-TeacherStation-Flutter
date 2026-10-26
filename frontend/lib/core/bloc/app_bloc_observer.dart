import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teaching_companion/core/utils/frontend_logger.dart';

/// Application-wide [BlocObserver] for tracking state transitions and errors.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    FrontendLogger.write('[Bloc] ${bloc.runtimeType} state changed: ${change.nextState}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    FrontendLogger.write('[Bloc Error] ${bloc.runtimeType} caught: $error');
  }
}

