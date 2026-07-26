import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String host, String clientId, int port) {
  const wsPort = 8083;
  final client = MqttBrowserClient('ws://$host:$wsPort/mqtt', clientId);
  client.port = wsPort;
  client.websocketProtocols = ['mqtt'];
  return client;
}
