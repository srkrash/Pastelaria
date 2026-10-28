"""Export a consistent, read-only legacy snapshot and prepare SQLite v1.

Private output is deliberately excluded from Git. The PostgreSQL source is never
updated. Closing old orders is an explicit conversion policy, not a source edit.
Requires psycopg2 and PostgreSQL's pg_dump/pg_restore executables.
"""
import argparse
from collections import defaultdict
from contextlib import closing
from datetime import date, datetime, timezone
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess

from psycopg2.extras import RealDictCursor
from inspect_legacy import connect

TABLES = ('produtos', 'pedidos', 'itens_pedido', 'past_ingredientes')
SCHEMA = """
PRAGMA foreign_keys=ON;
CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL, data TEXT NOT NULL);
CREATE TABLE orders (id INTEGER PRIMARY KEY AUTOINCREMENT, day TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'aberto', data TEXT NOT NULL);
CREATE INDEX orders_status ON orders(status);
CREATE INDEX orders_day ON orders(day);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE commands (id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, result TEXT NOT NULL);
CREATE TABLE print_jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL REFERENCES orders(id), status TEXT NOT NULL, second_copy INTEGER NOT NULL DEFAULT 0, error TEXT, created_at TEXT NOT NULL);
PRAGMA user_version=1;
"""


def json_value(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    raise TypeError(type(value).__name__)


def encode(value):
    return json.dumps(value, ensure_ascii=False, default=json_value, separators=(',', ':'))


def file_hash(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def cents(value):
    scaled = Decimal(str(value)) * 100
    if scaled != scaled.to_integral_value():
        raise ValueError('Valor monetário com fração de centavo.')
    return int(scaled)


def convert(rows, destination):
    """Pure offline conversion; all historical non-cancelled orders are closed."""
    products = {p['id']: p for p in rows['produtos']}
    items = defaultdict(list)
    ingredients = defaultdict(list)
    for ingredient in rows['past_ingredientes']:
        if ingredient['ingrediente_id'] not in products:
            raise ValueError('Ingrediente sem produto correspondente.')
        ingredients[ingredient['item_pedido_id']].append(ingredient)
    item_ids = {i['id'] for i in rows['itens_pedido']}
    if any(i not in item_ids for i in ingredients):
        raise ValueError('Ingrediente sem item correspondente.')
    order_ids = {o['id'] for o in rows['pedidos']}
    for item in rows['itens_pedido']:
        if item['pedido_id'] not in order_ids or item['produto_id'] not in products:
            raise ValueError('Referência de item inválida.')
        if item['quantidade'] <= 0 or cents(item['subtotal']) != cents(item['preco_unitario']) * item['quantidade']:
            raise ValueError('Quantidade ou subtotal inconsistente; conversão interrompida.')
        items[item['pedido_id']].append(item)
    total = 0
    closed = 0
    sequences = {}
    # Exclusive creation avoids replacing a previous conversion accidentally.
    with destination.open('xb'):
        pass
    with closing(sqlite3.connect(destination)) as target, target:
        target.executescript(SCHEMA)
        for product in products.values():
            value = dict(product, preco_centavos=cents(product['preco']), preco=cents(product['preco']) / 100)
            target.execute('INSERT INTO products VALUES(?,?,?)', (product['id'], product['nome'], encode(value)))
        for revision, source in enumerate(sorted(rows['pedidos'], key=lambda o: o['id']), 1):
            if source['status'] not in ('aberto', 'fechado', 'cancelado'):
                raise ValueError('Status de pedido desconhecido.')
            source_items = items[source['id']]
            if not source_items or sum(cents(i['subtotal']) for i in source_items) != cents(source['total_pedido']):
                raise ValueError('Total do pedido não confere com os itens.')
            day = str(source['reset_data'] or source['business_day'])
            status = 'cancelado' if source['status'] == 'cancelado' else 'fechado'
            converted_items = []
            for item in source_items:
                if item['status_item'] not in ('aguardando', 'em_preparacao', 'pronto', 'entregue', 'cancelado'):
                    raise ValueError('Status de item desconhecido.')
                product = products[item['produto_id']]
                cancelled = status == 'cancelado' or item['status_item'] == 'cancelado'
                quantity = item['quantidade']
                unit = cents(item['preco_unitario'])
                converted_items.append({
                    'item_id': item['id'], 'pedido_id': source['id'], 'numero_pedido': source['numero_pedido'],
                    'produto_id': product['id'], 'produto_nome': product['nome'], 'produto_tipo': product['tipo'],
                    'quantidade': quantity, 'quantidade_pronta': 0 if cancelled else quantity,
                    'quantidade_entregue': 0 if cancelled else quantity,
                    'quantidade_cancelada': quantity if cancelled else 0,
                    'preco_unitario_centavos': unit, 'preco_unitario': unit / 100,
                    'subtotal': cents(item['subtotal']) / 100, 'preco': cents(item['subtotal']) / 100,
                    'ingredientes': [products[i['ingrediente_id']]['nome'] for i in ingredients[item['id']]],
                    'observacoes_item': item['observacoes_item'] or '',
                    'status_item': 'cancelado' if cancelled else 'entregue',
                    'legacy': {'status_item': item['status_item'], 'ingredientes': ingredients[item['id']]},
                })
            amount = cents(source['total_pedido'])
            value = {
                'id': source['id'], 'pedido_id': source['id'], 'numero_pedido': source['numero_pedido'],
                'data_hora_pedido': source['data_hora_pedido'].astimezone(timezone.utc).isoformat(),
                'reset_data': day, 'observacoes': source['observacoes'] or '',
                'total_centavos': amount, 'total_pedido': amount / 100,
                'status': status, 'revision': revision, 'itens': converted_items,
                'legacy': {'status': source['status'], 'conversion': 'close-history-no-reprint'},
            }
            target.execute('INSERT INTO orders VALUES(?,?,?,?)', (source['id'], day, status, encode(value)))
            total += amount
            closed += source['status'] == 'aberto'
            ticket = source['numero_pedido']
            if ticket > 0:
                sequences['ticket:' + day] = (ticket - 1) % 99 + 1
            else:
                sequences['counter:' + day] = min(ticket, sequences.get('counter:' + day, 0))
        sequences['revision'] = len(rows['pedidos'])
        target.executemany('INSERT INTO meta VALUES(?,?)', [(k, str(v)) for k, v in sequences.items()])
        if target.execute('PRAGMA integrity_check').fetchone()[0] != 'ok' or target.execute('PRAGMA foreign_key_check').fetchall():
            raise ValueError('Falha de integridade do SQLite convertido.')
    return {'products': len(products), 'orders': len(rows['pedidos']), 'items': len(item_ids),
            'ingredients': len(rows['past_ingredientes']), 'total_centavos': total,
            'open_orders_closed_in_copy': closed, 'active_orders': 0, 'print_jobs': 0}


def archive(rows, destination):
    with closing(sqlite3.connect(destination)) as db, db:
        for table in TABLES:
            data = rows[table]
            if not data:
                raise ValueError('Tabela vazia exige conferência de schema: ' + table)
            columns = list(data[0])
            # Numeric values are stored as decimal text to preserve exact values.
            types = ['INTEGER' if isinstance(data[0][c], (int, bool)) else 'TEXT' for c in columns]
            definition = ','.join('"' + c + '" ' + t for c, t in zip(columns, types))
            db.execute('CREATE TABLE "' + table + '" (' + definition + ')')
            values = [[v if v is None or isinstance(v, (str, int, float, bytes)) else json_value(v)
                       for v in row.values()] for row in data]
            db.executemany('INSERT INTO "' + table + '" VALUES (' + ','.join('?' for _ in columns) + ')', values)
        if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Arquivo legado inválido.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--close-history', action='store_true', required=True,
                        help='Explicitly close old orders only in the converted copy.')
    parser.add_argument('--pg-bin', type=Path, default=Path(r'C:\Program Files\PostgreSQL\17\bin'))
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    created = datetime.now(timezone.utc).isoformat()
    connection = connect()
    try:
        connection.set_session(readonly=True, isolation_level='REPEATABLE READ')
        with connection.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute('SELECT pg_export_snapshot() AS snapshot')
            snapshot = cursor.fetchone()['snapshot']
            params = connection.get_dsn_parameters()
            environment = dict(os.environ, PGPASSWORD=connection.info.password)
            dump = output / 'postgres-original.dump'
            command = [str(args.pg_bin / 'pg_dump.exe'), '--format=custom', '--no-owner', '--no-privileges',
                       '--snapshot=' + snapshot, '--host=' + params['host'], '--port=' + params['port'],
                       '--username=' + params['user'], '--dbname=' + params['dbname'], '--file=' + str(dump)]
            subprocess.run(command, env=environment, check=True, capture_output=True)
            subprocess.run([str(args.pg_bin / 'pg_restore.exe'), '--list', str(dump)],
                           check=True, capture_output=True)
            rows = {}
            for table in TABLES:
                cursor.execute('SELECT * FROM ' + table + ' ORDER BY id')
                rows[table] = [dict(row) for row in cursor.fetchall()]
            cursor.execute("SELECT id,(data_hora_pedido AT TIME ZONE 'America/Sao_Paulo')::date AS business_day FROM pedidos")
            days = {row['id']: row['business_day'] for row in cursor.fetchall()}
    finally:
        connection.rollback()
        connection.close()
    archive(rows, output / 'legacy-original.sqlite')
    for order in rows['pedidos']:
        order['business_day'] = days[order['id']]
    report = convert(rows, output / 'pastelaria_v2.db')
    report.update({'created_at': created, 'source_readonly': True, 'schema': 1,
                   'policy': 'Close non-cancelled history in the copy; preserve cancellations, original statuses and monetary values; no automatic printing.',
                   'note': 'Snapshot for rehearsal. Export again between shifts before the final cutover.',
                   'sha256': {file.name: file_hash(file)
                              for file in output.iterdir() if file.is_file()}})
    (output / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
