import 'package:flutter/foundation.dart';
import '../../domain/visita.dart';
import '../../domain/visita_repository.dart';

enum FiltroVisitas { todas, pendentes, concluidas }

class VisitasViewModel extends ChangeNotifier {
  final VisitaRepository _repository;
  List<Visita> _visitas = const [];
  bool _ocupado = false;
  bool _descartado = false;
  String? _erro;
  FiltroVisitas _filtro = FiltroVisitas.todas;

  VisitasViewModel(this._repository);

  bool _modoOffline = false;
  bool get modoOffline => _modoOffline;
  int get alteracoesPendentes => _repository.pendentes;
  bool pendente(int id) => _repository.pendente(id);
  void definirOffline(bool valor) {
    if (_ocupado || _descartado) return;
    _modoOffline = valor;
    notifyListeners();
  }

  Future<bool> sincronizar() async {
    if (_modoOffline) {
      if (!_descartado) {
        _erro = 'Modo offline ativo. Desative-o para sincronizar.';
        notifyListeners();
      }
      return false;
    }
    return _executar(_repository.sincronizar);
  }

  bool get ocupado => _ocupado;
  String? get erro => _erro;
  FiltroVisitas get filtro => _filtro;
  int get total => _visitas.length;
  int get concluidas => _visitas.where((v) => v.concluida).length;
  int get pendentes => total - concluidas;

  List<Visita> get visitas => List<Visita>.unmodifiable(_visitas.where((v) {
        switch (_filtro) {
          case FiltroVisitas.todas:
            return true;
          case FiltroVisitas.pendentes:
            return !v.concluida;
          case FiltroVisitas.concluidas:
            return v.concluida;
        }
      }));

  void filtrar(FiltroVisitas valor) {
    if (_descartado || _ocupado || valor == _filtro) return;
    _filtro = valor;
    notifyListeners();
  }

  Future<bool> carregar() => _executar(_repository.listar);
  Future<bool> salvar(DadosVisita dados, {int? id}) => _executar(() {
        dados.validar();
        return id == null
            ? _repository.criar(dados)
            : _repository.editar(id, dados);
      });
  Future<bool> alternarSituacao(Visita visita) =>
      _executar(() => _repository.alterarSituacao(
          visita.id,
          visita.concluida
              ? SituacaoVisita.pendente
              : SituacaoVisita.concluida));
  Future<bool> excluir(int id) => _executar(() => _repository.excluir(id));

  Future<bool> _executar(Future<List<Visita>> Function() operacao) async {
    if (_ocupado || _descartado) return false;
    _ocupado = true;
    _erro = null;
    notifyListeners();
    try {
      final resultado = await operacao();
      if (_descartado) return false;
      _visitas = List<Visita>.unmodifiable(resultado);
      return true;
    } on ValidacaoVisitaException catch (e) {
      if (!_descartado) _erro = e.mensagem;
      return false;
    } on RepositorioException catch (e) {
      if (!_descartado) _erro = e.mensagem;
      return false;
    } catch (e, stack) {
      debugPrint('Falha inesperada em visitas: $e\n$stack');
      if (!_descartado)
        _erro = 'Não foi possível concluir a operação. Tente novamente.';
      return false;
    } finally {
      _ocupado = false;
      if (!_descartado) notifyListeners();
    }
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
