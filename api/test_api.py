import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from server import Api, Store


def op(oid='a', action='upsert', vid=1):
    body = {'operationId': oid * 32, 'visitaId': vid, 'action': action}
    if action == 'upsert':
        body.update(cliente='Ana', descricao='Revisar rede', situacao='pendente')
    return body


class ApiTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = str(Path(self.temp.name) / 'test.sqlite3')
        self.store = Store(self.path)
        self.api = Api(('127.0.0.1', 0), self.store)
        self.thread = threading.Thread(target=self.api.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.api.server_port}'

    def tearDown(self):
        self.api.shutdown()
        self.api.server_close()
        self.thread.join()
        self.store.db.close()
        self.temp.cleanup()

    def request(self, path='/sync', body=None, method=None):
        request = urllib.request.Request(self.url + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Content-Type': 'application/json'}, method=method)
        try:
            response = urllib.request.urlopen(request, timeout=3)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            data = response.read()
            return response.status, json.loads(data) if data else None

    def test_crud_and_replay(self):
        self.assertEqual(self.request(body=op())[0], 200)
        self.assertTrue(self.request(body=op())[1]['replayed'])
        changed = op('b'); changed['situacao'] = 'concluida'
        self.request(body=changed)
        self.assertEqual(self.request('/visitas')[1][0]['situacao'], 'concluida')
        self.request(body=op('c', 'delete'))
        self.assertEqual(self.request('/visitas')[1], [])
        # Repetição atrasada do cadastro não ressuscita registro excluído.
        self.request(body=op())
        self.assertEqual(self.request('/visitas')[1], [])

    def test_lost_ack_after_commit(self):
        self.api.fail_after_commit = True
        self.assertEqual(self.request(body=op())[0], 503)
        self.assertEqual(len(self.request('/visitas')[1]), 1)
        self.assertTrue(self.request(body=op())[1]['replayed'])
        self.assertEqual(len(self.request('/visitas')[1]), 1)

    def test_validation_and_key_conflict(self):
        invalid = op(); invalid['cliente'] = ' '
        self.assertEqual(self.request(body=invalid)[0], 400)
        self.assertEqual(self.request('/visitas')[1], [])
        self.request(body=op())
        changed = op(); changed['descricao'] = 'Outro conteúdo'
        self.assertEqual(self.request(body=changed)[0], 409)
        self.assertEqual(self.request('/visitas')[1][0]['descricao'], 'Revisar rede')

    def test_persistence_including_idempotency(self):
        self.request(body=op())
        another = Store(self.path)
        try:
            self.assertEqual(len(another.listar()), 1)
            self.assertTrue(another.aplicar(op())['replayed'])
        finally:
            another.db.close()

    def test_cors_health_and_unknown_route(self):
        self.assertEqual(self.request('/health')[0], 200)
        self.assertEqual(self.request('/unknown')[0], 404)
        self.assertEqual(self.request('/sync', method='OPTIONS')[0], 204)
        with urllib.request.urlopen(self.url + '/health') as res:
            self.assertEqual(res.headers['Access-Control-Allow-Origin'], '*')


if __name__ == '__main__':
    unittest.main()
