enum SituacaoVisita { pendente, concluida }

class Visita {
  final int id;
  final String cliente;
  final String descricao;
  final SituacaoVisita situacao;

  const Visita({
    required this.id,
    required this.cliente,
    required this.descricao,
    this.situacao = SituacaoVisita.pendente,
  });

  bool get concluida => situacao == SituacaoVisita.concluida;

  Visita copyWith({String? cliente, String? descricao, SituacaoVisita? situacao}) {
    return Visita(
      id: id,
      cliente: cliente ?? this.cliente,
      descricao: descricao ?? this.descricao,
      situacao: situacao ?? this.situacao,
    );
  }
}

// A mesma regra atende o formulário e a fronteira de gravação.
class DadosVisita {
  final String cliente;
  final String descricao;

  DadosVisita({required String cliente, required String descricao})
      : cliente = cliente.trim(), descricao = descricao.trim();

  static String? validarCliente(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe o nome do cliente.';
    if (texto.length > 80) return 'Use até 80 caracteres no nome.';
    return null;
  }

  static String? validarDescricao(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe a descrição da visita.';
    if (texto.length > 300) return 'Use até 300 caracteres na descrição.';
    return null;
  }

  void validar() {
    final mensagem = validarCliente(cliente) ?? validarDescricao(descricao);
    if (mensagem != null) throw ValidacaoVisitaException(mensagem);
  }
}

class ValidacaoVisitaException implements Exception {
  final String mensagem;
  const ValidacaoVisitaException(this.mensagem);
}
