import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String host, String clientId, int port) {
  return MqttServerClient.withPort(host, clientId, port);
}
