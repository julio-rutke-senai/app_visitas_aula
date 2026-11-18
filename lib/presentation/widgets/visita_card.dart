import 'package:flutter/material.dart';
import '../../domain/visita.dart';

class VisitaCard extends StatelessWidget {
  final Visita visita;
  final bool habilitado;
  final bool pendente;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onAlternar;

  const VisitaCard(
      {super.key,
      required this.visita,
      required this.habilitado,
      required this.pendente,
      required this.onEditar,
      required this.onExcluir,
      required this.onAlternar});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(visita.cliente, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(pendente ? 'Alteração local pendente' : 'Sincronizada com a API'),
        Text(visita.descricao),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                  avatar: Icon(
                      visita.concluida ? Icons.check_circle : Icons.schedule,
                      size: 18),
                  label: Text(visita.concluida ? 'Concluída' : 'Pendente')),
              TextButton.icon(
                  onPressed: habilitado ? onAlternar : null,
                  icon: Icon(visita.concluida ? Icons.undo : Icons.check),
                  label: Text(visita.concluida ? 'Reabrir' : 'Concluir')),
              IconButton(
                  tooltip: 'Editar visita',
                  onPressed: habilitado ? onEditar : null,
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                  tooltip: 'Excluir visita',
                  onPressed: habilitado ? onExcluir : null,
                  icon: const Icon(Icons.delete_outline)),
            ]),
      ]),
    ));
  }
}
