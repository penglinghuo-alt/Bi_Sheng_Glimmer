import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_enums.dart';

class HomeState {
  final PrintMode selectedMode;
  final PrintStep currentStep;
  final bool showPaperDialog;
  final double progress;
  final bool isInitializing;
  final bool isInitialized;

  const HomeState({
    this.selectedMode = PrintMode.scanAndPrint,
    this.currentStep = PrintStep.idle,
    this.showPaperDialog = false,
    this.progress = 0.0,
    this.isInitializing = false,
    this.isInitialized = false,
  });

  HomeState copyWith({
    PrintMode? selectedMode,
    PrintStep? currentStep,
    bool? showPaperDialog,
    double? progress,
    bool? isInitializing,
    bool? isInitialized,
  }) {
    return HomeState(
      selectedMode: selectedMode ?? this.selectedMode,
      currentStep: currentStep ?? this.currentStep,
      showPaperDialog: showPaperDialog ?? this.showPaperDialog,
      progress: progress ?? this.progress,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  void startInitialization() {
    state = state.copyWith(isInitializing: true);
  }

  void completeInitialization() {
    state = state.copyWith(isInitializing: false, isInitialized: true);
  }

  void cancelInitialization() {
    state = state.copyWith(isInitializing: false, isInitialized: false);
  }

  void startPrintJob() {
    state = state.copyWith(currentStep: PrintStep.turningPage, progress: 0.0);
  }

  void updateStep(PrintStep step, double progress) {
    state = state.copyWith(currentStep: step, progress: progress);
  }

  void showPaperDialog() {
    state = state.copyWith(showPaperDialog: true, currentStep: PrintStep.completed);
  }

  void dismissPaperDialog() {
    state = state.copyWith(showPaperDialog: false);
  }

  void confirmPaperReady() {
    state = state.copyWith(showPaperDialog: false, currentStep: PrintStep.printing, progress: 0.8);
  }

  void reset() {
    state = const HomeState();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier());
