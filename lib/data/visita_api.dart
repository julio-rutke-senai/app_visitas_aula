import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/visita.dart';
import '../domain/visita_repository.dart';

abstract class VisitaRemota {
  Future<void> enviar(Map<String, dynamic> operacao);
  Future<List<Visita>> listar();
}

class VisitaApi implements VisitaRemota {
  final String baseUrl;
  final Duration timeout;
  VisitaApi(String baseUrl, {this.timeout = const Duration(seconds: 8)})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/$'), '');

  Future<http.Response> _request(String path,
      {Map<String, dynamic>? body}) async {
    // Um client por chamada é fechado inclusive após timeout.
    final client = http.Client();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await (body == null
              ? client.get(uri)
              : client.post(uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body)))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RepositorioException('API retornou HTTP ${response.statusCode}. '
            'A fila foi preservada; verifique a API e tente novamente.');
      }
      return response;
    } on TimeoutException {
      throw const RepositorioException('Tempo de resposta esgotado. '
          'O servidor pode ter recebido a operação. Reenvie pela sincronização.');
    } on http.ClientException {
      throw const RepositorioException(
          'API indisponível. Alterações continuam na memória local.');
    } finally {
      client.close();
    }
  }

  @override
  Future<void> enviar(Map<String, dynamic> operacao) async {
    final response = await _request('/sync', body: operacao);
    final ack =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (ack['operationId'] != operacao['operationId'] ||
        ack['applied'] != true) {
      throw const RepositorioException(
          'Confirmação inválida. Operação mantida na fila.');
    }
  }

  @override
  Future<List<Visita>> listar() async {
    final response = await _request('/visitas');
    final lista = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return lista.map((item) {
      final json = item as Map<String, dynamic>;
      final situacao = json['situacao'];
      if (situacao != 'pendente' && situacao != 'concluida') {
        throw const RepositorioException('Situação inválida recebida da API.');
      }
      return Visita(
          id: json['id'] as int,
          cliente: json['cliente'] as String,
          descricao: json['descricao'] as String,
          situacao: situacao == 'concluida'
              ? SituacaoVisita.concluida
              : SituacaoVisita.pendente);
    }).toList();
  }
}
