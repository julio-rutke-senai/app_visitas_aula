"""API didática local. Python 3.10+, somente biblioteca padrão."""
import argparse
import hashlib
import json
import re
import sqlite3
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.lock = threading.Lock()
        self.db.executescript('''
          CREATE TABLE IF NOT EXISTS visitas (
            id INTEGER PRIMARY KEY, cliente TEXT NOT NULL,
            descricao TEXT NOT NULL, situacao TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS operacoes (
            id TEXT PRIMARY KEY, hash TEXT NOT NULL);
        ''')
        self.db.commit()

    def listar(self):
        with self.lock:
            return [dict(zip(('id', 'cliente', 'descricao', 'situacao'), row))
                    for row in self.db.execute('SELECT id,cliente,descricao,situacao FROM visitas ORDER BY id')]

    def aplicar(self, op):
        if not isinstance(op, dict):
            raise ValueError('Objeto JSON esperado')
        oid, vid, action = op.get('operationId'), op.get('visitaId'), op.get('action')
        if not isinstance(oid, str) or not re.fullmatch(r'[a-f0-9]{32}', oid):
            raise ValueError('operationId deve conter 32 caracteres hexadecimais')
        if type(vid) is not int or not 0 < vid < 2**53:
            raise ValueError('visitaId inválido')
        if action not in ('upsert', 'delete'):
            raise ValueError('action inválida')
        expected = {'operationId', 'visitaId', 'action'}
        if action == 'upsert':
            expected |= {'cliente', 'descricao', 'situacao'}
            for field, limit in [('cliente', 80), ('descricao', 300)]:
                if not isinstance(op.get(field), str) or not 1 <= len(op[field].strip()) <= limit:
                    raise ValueError(f'{field} inválido')
            if op.get('situacao') not in ('pendente', 'concluida'):
                raise ValueError('situacao inválida')
        if set(op) != expected:
            raise ValueError('Campos inesperados ou ausentes')
        digest = hashlib.sha256(json.dumps(op, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        with self.lock, self.db:
            previous = self.db.execute('SELECT hash FROM operacoes WHERE id=?', (oid,)).fetchone()
            if previous:
                if previous[0] != digest:
                    raise KeyError('operationId reutilizado com conteúdo diferente')
                return {'operationId': oid, 'applied': True, 'replayed': True}
            if action == 'delete':
                self.db.execute('DELETE FROM visitas WHERE id=?', (vid,))
            else:
                self.db.execute('''INSERT INTO visitas(id,cliente,descricao,situacao) VALUES(?,?,?,?)
                    ON CONFLICT(id) DO UPDATE SET cliente=excluded.cliente,
                    descricao=excluded.descricao,situacao=excluded.situacao''',
                    (vid, op['cliente'].strip(), op['descricao'].strip(), op['situacao']))
            # Efeito e chave de idempotência são confirmados na mesma transação.
            self.db.execute('INSERT INTO operacoes(id,hash) VALUES(?,?)', (oid, digest))
            return {'operationId': oid, 'applied': True, 'replayed': False}


class Api(ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, address, store, fail_after_commit=False):
        super().__init__(address, Handler)
        self.store = store
        self.fail_after_commit = fail_after_commit
        self.failure_lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def respond(self, code, data=None):
        body = json.dumps(data, ensure_ascii=False).encode() if data is not None else b''
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        # Para demonstração local no Flutter Web. Não usar assim em produção.
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        if body:
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    def do_OPTIONS(self):
        self.respond(204)

    def do_GET(self):
        if self.path == '/health':
            self.respond(200, {'status': 'ok'})
        elif self.path == '/visitas':
            self.respond(200, self.server.store.listar())
        else:
            self.respond(404, {'error': 'Rota inexistente'})

    def do_POST(self):
        if self.path != '/sync':
            return self.respond(404, {'error': 'Rota inexistente'})
        if self.headers.get_content_type() != 'application/json':
            return self.respond(415, {'error': 'Use application/json'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 16384:
                return self.respond(413, {'error': 'Corpo ausente ou muito grande'})
            op = json.loads(self.rfile.read(size))
            result = self.server.store.aplicar(op)
            with self.server.failure_lock:
                fail = self.server.fail_after_commit and not result['replayed']
                if fail:
                    self.server.fail_after_commit = False
            if fail:
                # O efeito JÁ foi persistido. Retry deverá devolver replayed=true.
                self.respond(503, {'error': 'Falha simulada depois do commit. Reenvie a mesma operação.'})
            else:
                self.respond(200, result)
        except KeyError as exc:
            self.respond(409, {'error': str(exc)})
        except (ValueError, UnicodeDecodeError) as exc:
            self.respond(400, {'error': str(exc)})
        except sqlite3.Error:
            self.respond(500, {'error': 'Falha no banco; operação pode ser reenviada'})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--db', default='visitas.sqlite3')
    parser.add_argument('--fail-after-commit-once', action='store_true')
    args = parser.parse_args()
    store = Store(args.db)
    api = Api((args.host, args.port), store, args.fail_after_commit_once)
    print(f'API local em http://{args.host}:{args.port} (Ctrl+C para encerrar)', flush=True)
    try:
        api.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        api.server_close()
        store.db.close()


if __name__ == '__main__':
    main()
