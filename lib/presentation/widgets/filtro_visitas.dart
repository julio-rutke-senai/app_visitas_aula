import 'package:flutter/material.dart';
import '../viewmodels/visitas_viewmodel.dart';

class FiltroVisitasWidget extends StatelessWidget {
  final FiltroVisitas selecionado;
  final bool habilitado;
  final ValueChanged<FiltroVisitas> onChanged;
  const FiltroVisitasWidget(
      {super.key,
      required this.selecionado,
      required this.habilitado,
      required this.onChanged});

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item in FiltroVisitas.values)
          ChoiceChip(
              label: Text(switch (item) {
                FiltroVisitas.todas => 'Todas',
                FiltroVisitas.pendentes => 'Pendentes',
                FiltroVisitas.concluidas => 'Concluídas',
              }),
              selected: item == selecionado,
              onSelected: habilitado ? (_) => onChanged(item) : null),
      ]);
}
