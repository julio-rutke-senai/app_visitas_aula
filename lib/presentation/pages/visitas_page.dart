import 'package:flutter/material.dart';
import '../../domain/visita.dart';
import '../viewmodels/visitas_viewmodel.dart';
import '../widgets/filtro_visitas.dart';
import '../widgets/mensagem_erro.dart';
import '../widgets/visita_card.dart';
import '../widgets/visita_form_dialog.dart';

class VisitasPage extends StatelessWidget {
  final VisitasViewModel viewModel;
  const VisitasPage({super.key, required this.viewModel});

  Future<void> _abrirFormulario(BuildContext context, [Visita? visita]) async {
    final salvo = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => VisitaFormDialog(viewModel: viewModel, visita: visita));
    if (context.mounted && salvo == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Visita salva em memória. Sincronize para enviar à API.')));
    }
  }

  Future<void> _excluir(BuildContext context, Visita visita) async {
    final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Excluir visita?'),
              content: Text('A visita de ${visita.cliente} será removida.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Excluir')),
              ],
            ));
    if (confirmado == true && context.mounted)
      await viewModel.excluir(visita.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final itens = viewModel.visitas;
          return Scaffold(
            appBar: AppBar(title: const Text('Visitas técnicas'), actions: [
              IconButton(
                  tooltip: 'Reler memória local',
                  onPressed: viewModel.ocupado
                      ? null
                      : () {
                          viewModel.carregar();
                        },
                  icon: const Icon(Icons.refresh)),
            ]),
            floatingActionButton: FloatingActionButton.extended(
                onPressed:
                    viewModel.ocupado ? null : () => _abrirFormulario(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova visita')),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Simular modo offline'),
                          subtitle: const Text(
                              'Cadastro e alterações continuam disponíveis.'),
                          value: viewModel.modoOffline,
                          onChanged: viewModel.ocupado
                              ? null
                              : viewModel.definirOffline),
                      Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                                '${viewModel.alteracoesPendentes} operações pendentes'),
                            FilledButton.icon(
                                icon: const Icon(Icons.sync),
                                label: const Text('Sincronizar'),
                                onPressed:
                                    viewModel.ocupado || viewModel.modoOffline
                                        ? null
                                        : () async {
                                            final ok =
                                                await viewModel.sincronizar();
                                            if (context.mounted && ok)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Sincronização concluída.')));
                                          }),
                          ]),
                      const SizedBox(height: 12),
                      Text(
                          '${viewModel.total} visitas • ${viewModel.pendentes} pendentes • ${viewModel.concluidas} concluídas'),
                      const SizedBox(height: 12),
                      FiltroVisitasWidget(
                          selecionado: viewModel.filtro,
                          habilitado: !viewModel.ocupado,
                          onChanged: viewModel.filtrar),
                      const SizedBox(height: 8),
                      if (viewModel.ocupado) const LinearProgressIndicator(),
                      if (viewModel.erro != null)
                        MensagemErro(
                            mensagem: viewModel.erro!,
                            onAtualizar: viewModel.ocupado
                                ? null
                                : () {
                                    viewModel.carregar();
                                  }),
                      Expanded(
                          child: itens.isEmpty
                              ? Center(
                                  child: Text(
                                      viewModel.ocupado
                                          ? 'Carregando visitas...'
                                          : viewModel.erro != null
                                              ? 'Confira a mensagem acima e tente novamente.'
                                              : viewModel.total == 0
                                                  ? 'Nenhuma visita cadastrada.\nToque em Nova visita para começar.'
                                                  : 'Nenhuma visita neste filtro.',
                                      textAlign: TextAlign.center))
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 96),
                                  itemCount: itens.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final visita = itens[index];
                                    return VisitaCard(
                                        key: ValueKey(visita.id),
                                        visita: visita,
                                        pendente: viewModel.pendente(visita.id),
                                        habilitado: !viewModel.ocupado,
                                        onEditar: () =>
                                            _abrirFormulario(context, visita),
                                        onExcluir: () =>
                                            _excluir(context, visita),
                                        onAlternar: () {
                                          viewModel.alternarSituacao(visita);
                                        });
                                  })),
                    ],
                  )),
            ))),
          );
        },
      );
}
