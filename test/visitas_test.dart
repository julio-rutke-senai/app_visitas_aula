import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitas_mvvm_aula/app.dart';
import 'package:visitas_mvvm_aula/data/visita_api.dart';
import 'package:visitas_mvvm_aula/data/visita_repository_offline.dart';
import 'package:visitas_mvvm_aula/domain/visita.dart';
import 'package:visitas_mvvm_aula/domain/visita_repository.dart';
import 'package:visitas_mvvm_aula/presentation/viewmodels/visitas_viewmodel.dart';

class ApiFake implements VisitaRemota {
  final dados = <int, Visita>{};
  final recebidas = <String>[];
  final aplicadas = <String>{};
  bool offline = false;
  bool perderConfirmacao = false;
  bool falharLeitura = false;
  int? falharNaChamada;
  int chamadas = 0;
  @override
  Future<void> enviar(Map<String, dynamic> op) async {
    chamadas++;
    if (offline || chamadas == falharNaChamada) throw const RepositorioException('Offline');
    final oid = op['operationId'] as String;
    recebidas.add(oid);
    if (aplicadas.add(oid)) {
      final id = op['visitaId'] as int;
      if (op['action'] == 'delete') {
        dados.remove(id);
      } else {
        dados[id] = Visita(id: id, cliente: op['cliente'] as String,
          descricao: op['descricao'] as String,
          situacao: op['situacao'] == 'concluida' ? SituacaoVisita.concluida : SituacaoVisita.pendente);
      }
    }
    if (perderConfirmacao) {
      perderConfirmacao = false;
      throw const RepositorioException('Confirmação perdida');
    }
  }
  @override
  Future<List<Visita>> listar() async {
    if (offline || falharLeitura) throw const RepositorioException('Falha de leitura');
    return dados.values.toList();
  }
}

DadosVisita entrada(String cliente) => DadosVisita(cliente: cliente, descricao: 'Revisar rede');
void main() {
  test('grava offline e valida fora da UI', () async {
    final api = ApiFake()..offline = true;
    final repo = VisitaRepositoryOffline(api);
    await repo.criar(entrada('Ana'));
    expect((await repo.listar()).length, 1);
    expect(repo.pendentes, 1);
    expect(api.chamadas, 0);
    await expectLater(repo.criar(entrada(' ')), throwsA(isA<ValidacaoVisitaException>()));
    await expectLater(repo.sincronizar(), throwsA(isA<RepositorioException>()));
    expect(repo.pendentes, 1);
    api.offline = false;
    await repo.sincronizar();
    expect(repo.pendentes, 0);
    expect(api.dados.length, 1);
  });
  test('ACK perdido repete mesmo ID sem duplicar', () async {
    final api = ApiFake()..perderConfirmacao = true;
    final repo = VisitaRepositoryOffline(api);
    await repo.criar(entrada('Ana'));
    await expectLater(repo.sincronizar(), throwsA(isA<RepositorioException>()));
    expect(api.dados.length, 1);
    expect(repo.pendentes, 1);
    await repo.sincronizar();
    expect(api.recebidas[0], api.recebidas[1]);
    expect(api.dados.length, 1);
    expect(repo.pendentes, 0);
  });
  test('falha parcial confirma só operações já aceitas', () async {
    final api = ApiFake()..falharNaChamada = 2;
    final repo = VisitaRepositoryOffline(api);
    await repo.criar(entrada('Ana')); await repo.criar(entrada('Bia'));
    await expectLater(repo.sincronizar(), throwsA(isA<RepositorioException>()));
    expect(repo.pendentes, 1);
    expect((await repo.listar()).length, 2);
    await repo.sincronizar();
    expect(api.dados.length, 2);
  });
  test('criar editar excluir offline envia tombstone em ordem', () async {
    final api = ApiFake(); final repo = VisitaRepositoryOffline(api);
    final visita = (await repo.criar(entrada('Ana'))).single;
    await repo.editar(visita.id, entrada('Ana Maria'));
    await repo.excluir(visita.id);
    expect(await repo.listar(), isEmpty);
    expect(repo.pendentes, 3);
    await repo.sincronizar();
    expect(api.dados, isEmpty);
    expect(repo.pendentes, 0);
  });
  test('pull falha sem apagar memória; nova sync recupera', () async {
    final api = ApiFake()..falharLeitura = true;
    final repo = VisitaRepositoryOffline(api);
    await repo.criar(entrada('Ana'));
    await expectLater(repo.sincronizar(), throwsA(isA<RepositorioException>()));
    expect(repo.pendentes, 0);
    expect((await repo.listar()).length, 1);
    api.falharLeitura = false;
    expect((await repo.sincronizar()).length, 1);
  });
  test('VM bloqueia sync offline mas permite cadastro', () async {
    final api = ApiFake(); final vm = VisitasViewModel(VisitaRepositoryOffline(api));
    addTearDown(vm.dispose);
    vm.definirOffline(true);
    expect(await vm.salvar(entrada('Ana')), isTrue);
    expect(await vm.sincronizar(), isFalse);
    expect(api.chamadas, 0);
    vm.definirOffline(false);
    expect(await vm.sincronizar(), isTrue);
    expect(vm.alteracoesPendentes, 0);
  });
  testWidgets('cadastro local aparece e sincroniza pela tela', (tester) async {
    final api = ApiFake();
    await tester.pumpWidget(VisitasApp(repository: VisitaRepositoryOffline(api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova visita')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Cliente da aula');
    await tester.enterText(find.byType(TextFormField).at(1), 'Configurar impressora');
    await tester.tap(find.text('Salvar')); await tester.pumpAndSettle();
    expect(find.text('Alteração local pendente'), findsOneWidget);
    expect(api.dados, isEmpty);
    await tester.tap(find.text('Sincronizar')); await tester.pumpAndSettle();
    expect(api.dados.length, 1);
    expect(find.text('Sincronizada com a API'), findsOneWidget);
  });
}
