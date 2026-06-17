import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_enums.dart';

class HomeState {
  final PrintMode selectedMode;
  final PrintStep currentStep;
  final bool showPaperDialog;
  final double progress;

  const HomeState({
    this.selectedMode = PrintMode.scanAndPrint,
    this.currentStep = PrintStep.idle,
    this.showPaperDialog = false,
    this.progress = 0.0,
  });

  HomeState copyWith({
    PrintMode? selectedMode,
    PrintStep? currentStep,
    bool? showPaperDialog,
    double? progress,
  }) {
    return HomeState(
      selectedMode: selectedMode ?? this.selectedMode,
      currentStep: currentStep ?? this.currentStep,
      showPaperDialog: showPaperDialog ?? this.showPaperDialog,
      progress: progress ?? this.progress,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode);
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
