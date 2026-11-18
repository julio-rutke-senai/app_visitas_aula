# Visitas técnicas — MVVM, memória offline e API

A aplicação grava TODAS as alterações primeiro em memória, inclusive quando a API está disponível. O botão **Sincronizar** envia a fila por HTTP e depois busca o estado remoto. A sincronização é manual, não é executada automaticamente ao voltar a conexão.

## Iniciar a demonstração (Chrome)

Terminal 1, na pasta do projeto:

```bash
python3 api/server.py
```

No Windows, use `py -3 api/server.py` se `python3` não estiver disponível. Por padrão, o servidor escuta somente em 127.0.0.1:8080. O arquivo visitas.sqlite3 é criado no diretório corrente e preserva dados e chaves de idempotência entre reinícios da API.

Terminal 2, na pasta que contém pubspec.yaml:

```bash
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

Abra http://localhost:8080/visitas no navegador para visualizar os registros remotos. A pasta web já está incluída. Não abra uma versão HTTPS do app apontando para esta API HTTP, pois o navegador pode bloquear conteúdo misto.

## Roteiro para a aula

1. Ative **Simular modo offline**. Cadastre duas visitas, edite uma e conclua outra. As mudanças aparecem imediatamente e as operações pendentes aumentam. A API continua sem receber dados.
2. Desative o modo offline e clique em **Sincronizar**. O contador zera, os cartões mostram “Sincronizada com a API” e GET /visitas exibe as visitas.
3. Encerre a API (Ctrl+C). Crie outra visita e tente sincronizar. A tela informa a falha, a visita continua local e a operação permanece na fila.
4. Reinicie a API com o mesmo banco. Clique em Sincronizar novamente. O envio conclui sem perder a alteração.
5. Crie e exclua uma visita ainda offline. A visita sai da tela, mas a fila mantém o cadastro e a exclusão na ordem correta. Ao sincronizar, ela não permanece no servidor.
6. Para mostrar resultado remoto sem confirmação, reinicie a API com:

```bash
python3 api/server.py --fail-after-commit-once
```

A próxima operação nova é confirmada no SQLite, mas o servidor responde 503 deliberadamente. O app mantém a operação. Confira GET /visitas e sincronize novamente: o mesmo operationId é reconhecido, sem reaplicar o efeito. Essa simulação representa uma falha após gravar, não uma queda de rede literal.

7. Recarregue a página do Flutter depois de sincronizar: a memória começa vazia. Clique em Sincronizar para buscar os registros remotos. Se recarregar ANTES de sincronizar, as alterações pendentes serão perdidas.

O controle offline é uma simulação didática, não um detector de conectividade do sistema. Desligar a API ou a conexão também produz falhas reais de HTTP. A ação de atualizar na barra superior relê apenas a memória local.

## Responsabilidades

| Arquivo | Papel |
|---|---|
| lib/main.dart | Compõe a API, o repositório offline e a aplicação. |
| lib/domain/visita.dart | Modelo imutável e validação. |
| lib/domain/visita_repository.dart | Contrato local + sincronização. |
| lib/data/visita_repository_offline.dart | Fonte local, fila FIFO, exclusões pendentes e sincronização. |
| lib/data/visita_api.dart | HTTP/JSON, timeout e conferência do ACK. |
| lib/presentation/viewmodels/visitas_viewmodel.dart | Estado da tela, ações, filtros e bloqueio de comandos concorrentes. |
| lib/presentation/pages/visitas_page.dart | Página e feedback das ações. |
| lib/presentation/widgets/ | Formulário, cartões, filtros e erros. |
| api/server.py | API REST local e armazenamento SQLite transacional. |

View observa ChangeNotifier por ListenableBuilder. O repository é a fonte de verdade local. Cada alteração gera um snapshot imutável e um operationId novo. Tentativas repetidas da MESMA alteração preservam o operationId. A UI bloqueia alterações durante a sincronização; o repository também impede mutações concorrentes nesse período.

## Protocolo de sincronização

1. Gravar na memória local e acrescentar operação à fila (não faz HTTP).
2. Enviar a primeira operação com POST /sync.
3. Remover da fila SOMENTE após HTTP 2xx, applied=true e operationId correspondente.
4. Repetir em ordem até terminar. Na falha, parar: confirmações anteriores permanecem válidas e as restantes ficam pendentes.
5. Fazer GET /visitas e substituir a visão local apenas quando a resposta estiver completa e válida.

Se o GET final falhar, a memória é preservada. Nesse caso pode haver zero operações pendentes e ainda um erro de atualização: o envio concluiu, mas a leitura não. Clique novamente em Sincronizar para concluir o pull.

Exclusão gera um tombstone: a intenção de excluir permanece na fila embora o cartão não esteja mais na tela. Criar, editar e excluir a mesma visita gera três operações, com IDs diferentes. Esta implementação não compacta a fila para facilitar a explicação em aula.

## API

| Método | Rota | Resultado |
|---|---|---|
| GET | /health | Saúde da API |
| GET | /visitas | Lista remota |
| POST | /sync | Aplica uma operação idempotente |
| OPTIONS | Qualquer rota | Preflight CORS para a demonstração Web |

Exemplo:

```bash
curl -X POST http://localhost:8080/sync \
  -H 'Content-Type: application/json' \
  -d '{"operationId":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","visitaId":123,"action":"upsert","cliente":"Ana","descricao":"Revisar rede","situacao":"pendente"}'
```

Repita exatamente a requisição: a resposta terá replayed=true. Alterar o conteúdo mantendo operationId retorna 409. Para editar, envie outro operationId com action=upsert e o mesmo visitaId. Para excluir, envie apenas operationId novo, visitaId e action=delete.

Efeito e chave de idempotência são gravados na mesma transação SQLite. Uma repetição antiga de cadastro, após exclusão, não recria o registro porque a chave já foi processada. As chaves não expiram neste exemplo. Não apague o banco entre a falha e o reenvio se quiser demonstrar a preservação dessa garantia.

Validação: 400; reutilização indevida de chave: 409; falha simulada pós-commit: 503. Erros permanentes preservam a operação e bloqueiam as seguintes: esta versão não tem editor para corrigir ou descartar uma operação inválida na fila.

## Escopo e limites importantes

- Memória offline é VOLÁTIL. Fechar/reiniciar/recarregar o app perde dados e fila não sincronizados. Para sobreviver a reinícios, substitua memória por banco local e persista dados e fila juntos.
- O servidor persiste em SQLite. Não há autenticação, isolamento por usuário ou implantação pública. CORS permissivo é exclusivo da demonstração local. Não exponha esse servidor à internet.
- O cenário é um cliente/aparelho por demonstração. Com múltiplos clientes editando a mesma visita, a última operação aplicada no servidor vence. Não há resolução de conflitos por versão, timestamps ou CRDT.
- IDs locais aleatórios usam 52 bits, compatíveis com inteiros exatos no Web. São adequados à simulação, mas não são UUIDs globais com garantia de unicidade.
- Não há sincronização em segundo plano, detecção automática de rede, backoff, paginação ou limite de crescimento da fila/tabela de operações.
- Em uma aplicação real, erros de validação/conflito precisam de fluxo próprio de resolução. Repetir uma operação 409 com o mesmo conteúdo alterado não resolverá o conflito.

## Android e aparelhos físicos

O fluxo preparado para aula é Flutter Web no Chrome. Para outras plataformas, gere os arquivos com `flutter create --platforms=android,ios --project-name visitas_mvvm_aula .` sem --overwrite e configure o SDK correspondente. Remova o teste de contador gerado, caso apareça, mantendo test/visitas_test.dart.

No emulador Android padrão, use --dart-define=API_URL=http://10.0.2.2:8080. Em aparelho físico, use o IP LAN do computador e inicie a API com --host 0.0.0.0 somente em rede de aula confiável; ajuste o firewall. localhost no aparelho representa o próprio aparelho.

Android exige permissão INTERNET no manifesto. HTTP local pode exigir android:usesCleartextTraffic="true" no application do manifesto de debug; não habilite indiscriminadamente em produção. iOS pode exigir ajustes de transporte/rede local para HTTP de desenvolvimento. Em produção, use HTTPS e controles de acesso.
