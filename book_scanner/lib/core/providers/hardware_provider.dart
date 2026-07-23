import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/hardware/hardware_manager.dart';

final hardwareManagerProvider = Provider<HardwareManager>((ref) {
  return HardwareManager();
});
