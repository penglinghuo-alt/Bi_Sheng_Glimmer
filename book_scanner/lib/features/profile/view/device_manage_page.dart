import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/hardware_config.dart';
import '../../../../core/providers/device_provider.dart';
import '../../../../shared/widgets/accessible_button.dart';
import '../../../../core/utils/permission_helper.dart';

enum _DeviceMode { mqtt, ble, wifi }

class DeviceManagePage extends ConsumerStatefulWidget {
  const DeviceManagePage({super.key});

  @override
  ConsumerState<DeviceManagePage> createState() => _DeviceManagePageState();
}

class _DeviceManagePageState extends ConsumerState<DeviceManagePage> {
  _DeviceMode _mode = _DeviceMode.mqtt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceState = ref.watch(deviceProvider);
    final isConnected = deviceState.status == DeviceStatus.connected ||
        deviceState.status == DeviceStatus.working ||
        deviceState.status == DeviceStatus.printing ||
        deviceState.status == DeviceStatus.initialized;

    return Scaffold(
      appBar: AppBar(title: const Text('设备管理'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _connectionStatus(theme, deviceState, isConnected),
            const SizedBox(height: 24),
            _modeSwitch(theme),
            const SizedBox(height: 20),
            if (isConnected) ...[
              AccessibleButton(
                label: '断开连接',
                icon: Icons.link_off_rounded,
                onPressed: () => ref.read(deviceProvider.notifier).disconnect(),
                color: AppColors.error,
                fullWidth: true,
              ),
            ] else ...[
              AccessibleButton(
                label: _connectButtonLabel(),
                icon: _connectButtonIcon(),
                onPressed: _handleConnect,
                fullWidth: true,
              ),
            ],
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  String _connectButtonLabel() {
    switch (_mode) {
      case _DeviceMode.mqtt:
        return '连接 MQTT Broker (${HardwareConfig.mqttBrokerHost})';
      case _DeviceMode.ble:
        return '扫描蓝牙设备';
      case _DeviceMode.wifi:
        return '连接 Wi-Fi 设备';
    }
  }

  IconData _connectButtonIcon() {
    switch (_mode) {
      case _DeviceMode.mqtt:
        return Icons.cloud_outlined;
      case _DeviceMode.ble:
        return Icons.bluetooth_rounded;
      case _DeviceMode.wifi:
        return Icons.wifi_rounded;
    }
  }

  Widget _connectionStatus(ThemeData theme, DeviceState deviceState, bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isConnected
                ? AppColors.success.withValues(alpha: 0.12)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 40,
            color: isConnected
                ? AppColors.success
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isConnected ? '已连接' : '未连接',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          isConnected ? (deviceState.connectedDeviceId ?? '') : '点击下方按钮连接设备',
          style: theme.textTheme.bodyMedium,
        ),
        if (isConnected && deviceState.statusMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(deviceState.status, theme).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              deviceState.statusMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusColor(deviceState.status, theme),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Color _statusColor(DeviceStatus status, ThemeData theme) {
    switch (status) {
      case DeviceStatus.connected:
      case DeviceStatus.initialized:
        return AppColors.success;
      case DeviceStatus.connecting:
      case DeviceStatus.initializing:
        return AppColors.warning;
      case DeviceStatus.error:
        return AppColors.error;
      case DeviceStatus.working:
      case DeviceStatus.printing:
        return AppColors.primary;
      case DeviceStatus.paused:
        return AppColors.warning;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  Widget _modeSwitch(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(
          child: _modeOption(
            theme, 'MQTT', Icons.cloud_outlined, _mode == _DeviceMode.mqtt,
            () => setState(() => _mode = _DeviceMode.mqtt),
          ),
        ),
        Expanded(
          child: _modeOption(
            theme, '蓝牙', Icons.bluetooth_rounded, _mode == _DeviceMode.ble,
            () => setState(() => _mode = _DeviceMode.ble),
          ),
        ),
        Expanded(
          child: _modeOption(
            theme, 'Wi-Fi', Icons.wifi_rounded, _mode == _DeviceMode.wifi,
            () => setState(() => _mode = _DeviceMode.wifi),
          ),
        ),
      ]),
    );
  }

  Widget _modeOption(ThemeData theme, String label, IconData icon, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  void _handleConnect() {
    debugPrint('[DevicePage] _handleConnect called, mode=$_mode');
    switch (_mode) {
      case _DeviceMode.mqtt:
        if (mounted) {
          ref.read(deviceProvider.notifier).connect(
            HardwareConfig.mqttBrokerHost,
            useMqtt: true,
          );
        }
        break;
      case _DeviceMode.ble:
        _connectBle();
        break;
      case _DeviceMode.wifi:
        _connectWifi();
        break;
    }
  }

  Future<void> _connectBle() async {
    await PermissionHelper.requestAllForHardware();
    if (mounted) {
      ref.read(deviceProvider.notifier).connect('ELF2-BLE-001');
    }
  }

  Future<void> _connectWifi() async {
    await PermissionHelper.requestAllForHardware();
    if (mounted) {
      ref.read(deviceProvider.notifier).connect('192.168.1.100', useWifi: true);
    }
  }
}
