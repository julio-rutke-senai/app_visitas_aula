import 'package:flutter/material.dart';
import 'app.dart';
import 'data/visita_api.dart';
import 'data/visita_repository_offline.dart';

void main() {
  const baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
  final repository = VisitaRepositoryOffline(VisitaApi(baseUrl));
  runApp(VisitasApp(repository: repository));
}
