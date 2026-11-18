import 'package:flutter/material.dart';
import 'domain/visita_repository.dart';
import 'presentation/pages/visitas_page.dart';
import 'presentation/viewmodels/visitas_viewmodel.dart';

class VisitasApp extends StatefulWidget {
  final VisitaRepository repository;
  const VisitasApp({super.key, required this.repository});
  @override
  State<VisitasApp> createState() => _VisitasAppState();
}

class _VisitasAppState extends State<VisitasApp> {
  late final VisitasViewModel _viewModel;
  @override
  void initState() {
    super.initState();
    _viewModel = VisitasViewModel(widget.repository);
    _viewModel.carregar();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Visitas técnicas',
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF17448C))),
        home: VisitasPage(viewModel: _viewModel),
      );
}
