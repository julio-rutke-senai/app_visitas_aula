import 'package:flutter/material.dart';
import '../../domain/visita.dart';
import '../viewmodels/visitas_viewmodel.dart';
import 'mensagem_erro.dart';

class VisitaFormDialog extends StatefulWidget {
  final VisitasViewModel viewModel;
  final Visita? visita;
  const VisitaFormDialog({super.key, required this.viewModel, this.visita});
  @override
  State<VisitaFormDialog> createState() => _VisitaFormDialogState();
}

class _VisitaFormDialogState extends State<VisitaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cliente;
  late final TextEditingController _descricao;
  bool _tentouSalvar = false;

  @override
  void initState() {
    super.initState();
    _cliente = TextEditingController(text: widget.visita?.cliente ?? '');
    _descricao = TextEditingController(text: widget.visita?.descricao ?? '');
  }

  @override
  void dispose() {
    _cliente.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (widget.viewModel.ocupado || !_formKey.currentState!.validate()) return;
    setState(() => _tentouSalvar = true);
    final sucesso = await widget.viewModel.salvar(
      DadosVisita(cliente: _cliente.text, descricao: _descricao.text),
      id: widget.visita?.id,
    );
    if (mounted && sucesso) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          return PopScope(
              canPop: !vm.ocupado,
              child: AlertDialog(
                scrollable: true,
                title: Text(
                    widget.visita == null ? 'Nova visita' : 'Editar visita'),
                content: SizedBox(
                    width: 440,
                    child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              controller: _cliente,
                              enabled: !vm.ocupado,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                  labelText: 'Cliente',
                                  border: OutlineInputBorder()),
                              validator: DadosVisita.validarCliente),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _descricao,
                              enabled: !vm.ocupado,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                  labelText: 'Descrição da visita',
                                  border: OutlineInputBorder()),
                              validator: DadosVisita.validarDescricao),
                          if (vm.ocupado)
                            const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: LinearProgressIndicator()),
                          if (_tentouSalvar && vm.erro != null)
                            MensagemErro(mensagem: vm.erro!),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: vm.ocupado
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: vm.ocupado ? null : _salvar,
                      child: Text(vm.ocupado ? 'Salvando...' : 'Salvar')),
                ],
              ));
        },
      );
}
