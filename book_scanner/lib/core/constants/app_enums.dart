enum DeviceStatus {
  disconnected,
  connecting,
  connected,
  working,
  printing,
  error,
}

enum PrintMode { scanAndPrint, localFile }

enum PrintStep {
  idle,
  turningPage,
  capturing,
  recognizing,
  converting,
  printing,
  completed,
  stopped,
}
