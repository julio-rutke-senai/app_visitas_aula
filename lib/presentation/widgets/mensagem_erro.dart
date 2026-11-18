import 'package:flutter/material.dart';

class MensagemErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onAtualizar;
  const MensagemErro({super.key, required this.mensagem, this.onAtualizar});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              liveRegion: true,
              child: Text(mensagem,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
          if (onAtualizar != null)
            TextButton.icon(
                onPressed: onAtualizar,
                icon: const Icon(Icons.refresh),
                label: const Text('Recarregar lista')),
        ]),
      );
}
