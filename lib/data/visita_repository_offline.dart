import 'dart:math';
import '../domain/visita.dart';
import '../domain/visita_repository.dart';
import 'visita_api.dart';

class VisitaRepositoryOffline implements VisitaRepository {
  final VisitaRemota _api;
  final Random _random = Random.secure();
  final Map<int, Visita> _local = {};
  final List<Map<String, dynamic>> _fila = [];
  bool _sincronizando = false;
  VisitaRepositoryOffline(this._api);

  @override
  int get pendentes => _fila.length;
  @override
  bool pendente(int id) => _fila.any((o) => o['visitaId'] == id);
  List<Visita> _snapshot() =>
      List<Visita>.unmodifiable(_local.values.toList().reversed);
  String _operationId() => List.generate(
      16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  int _visitaId() {
    // 52 bits: representação exata também no JavaScript/Flutter Web.
    int id;
    do {
      id = _random.nextInt(1 << 26) * (1 << 26) + _random.nextInt(1 << 26);
    } while (id == 0 || _local.containsKey(id) || pendente(id));
    return id;
  }

  void _verificarLivre() {
    if (_sincronizando)
      throw const RepositorioException('Aguarde a sincronização terminar.');
  }

  Visita _buscar(int id) {
    final visita = _local[id];
    if (visita == null)
      throw const RepositorioException('Visita não encontrada.');
    return visita;
  }

  void _enfileirar(Visita visita) {
    _fila.add(Map<String, dynamic>.unmodifiable({
      'operationId': _operationId(),
      'visitaId': visita.id,
      'action': 'upsert',
      'cliente': visita.cliente,
      'descricao': visita.descricao,
      'situacao': visita.situacao.name,
    }));
  }

  @override
  Future<List<Visita>> listar() async => _snapshot();
  @override
  Future<List<Visita>> criar(DadosVisita dados) async {
    _verificarLivre();
    dados.validar();
    final visita = Visita(
        id: _visitaId(), cliente: dados.cliente, descricao: dados.descricao);
    _local[visita.id] = visita;
    _enfileirar(visita);
    return _snapshot();
  }

  @override
  Future<List<Visita>> editar(int id, DadosVisita dados) async {
    _verificarLivre();
    dados.validar();
    final visita = _buscar(id)
        .copyWith(cliente: dados.cliente, descricao: dados.descricao);
    _local[id] = visita;
    _enfileirar(visita);
    return _snapshot();
  }

  @override
  Future<List<Visita>> alterarSituacao(int id, SituacaoVisita situacao) async {
    _verificarLivre();
    final visita = _buscar(id).copyWith(situacao: situacao);
    _local[id] = visita;
    _enfileirar(visita);
    return _snapshot();
  }

  @override
  Future<List<Visita>> excluir(int id) async {
    _verificarLivre();
    _buscar(id);
    _local.remove(id);
    // Tombstone: remover da tela não pode apagar a intenção de excluir na API.
    _fila.add(Map<String, dynamic>.unmodifiable({
      'operationId': _operationId(),
      'visitaId': id,
      'action': 'delete',
    }));
    return _snapshot();
  }

  @override
  Future<List<Visita>> sincronizar() async {
    _verificarLivre();
    _sincronizando = true;
    try {
      // FIFO: não enviar a operação seguinte antes de confirmar a atual.
      while (_fila.isNotEmpty) {
        final operacao = _fila.first;
        await _api.enviar(operacao);
        _fila.removeAt(
            0); // Só depois de ACK válido. Retry usa o MESMO operationId.
      }
      // Pull somente depois de enviar tudo, para não sobrescrever mudanças locais.
      final remotas = await _api.listar();
      _local.clear();
      for (final visita in remotas) {
        _local[visita.id] = visita;
      }
      return _snapshot();
    } finally {
      _sincronizando = false;
    }
  }
}
