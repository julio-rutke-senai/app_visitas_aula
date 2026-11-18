import 'visita.dart';

abstract class VisitaRepository {
  int get pendentes;
  bool pendente(int id);
  Future<List<Visita>> sincronizar();
  Future<List<Visita>> listar();
  Future<List<Visita>> criar(DadosVisita dados);
  Future<List<Visita>> editar(int id, DadosVisita dados);
  Future<List<Visita>> alterarSituacao(int id, SituacaoVisita situacao);
  Future<List<Visita>> excluir(int id);
}

class RepositorioException implements Exception {
  final String mensagem;
  const RepositorioException(this.mensagem);
}
