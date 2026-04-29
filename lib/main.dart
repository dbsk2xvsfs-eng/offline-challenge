import 'package:flutter/material.dart';
import 'app.dart';
import 'features/notifications/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalNotificationService.init();

  runApp(const MyApp());
}