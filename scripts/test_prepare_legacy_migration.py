import copy
from contextlib import closing
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path
import json
import sqlite3
import tempfile
import unittest

from prepare_legacy_migration import cents, convert


def sample():
    return {
        'produtos': [dict(id=4, nome='Teste', descricao='', tipo='bebida', preco=Decimal('3.25'), ativo=True)],
        'pedidos': [dict(id=7, numero_pedido=99, data_hora_pedido=datetime(2026, 10, 28, 18, tzinfo=timezone.utc),
                         reset_data=date(2026, 10, 28), business_day=date(2026, 10, 28), observacoes='',
                         total_pedido=Decimal('6.50'), status='aberto')],
        'itens_pedido': [dict(id=23, pedido_id=7, produto_id=4, quantidade=2, preco_unitario=Decimal('3.25'),
                             subtotal=Decimal('6.50'), status_item='aguardando', observacoes_item='')],
        'past_ingredientes': [],
    }


class MigrationTest(unittest.TestCase):
    def test_closure_preserves_ids_money_original_and_sequence(self):
        rows = sample()
        original = copy.deepcopy(rows)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'converted.db'
            report = convert(rows, path)
            with closing(sqlite3.connect(path)) as db:
                order = json.loads(db.execute('SELECT data FROM orders').fetchone()[0])
                self.assertEqual(order['id'], 7)
                self.assertEqual(order['itens'][0]['item_id'], 23)
                self.assertEqual(order['total_centavos'], 650)
                self.assertEqual(order['itens'][0]['quantidade_entregue'], 2)
                self.assertEqual(order['legacy']['status'], 'aberto')
                self.assertEqual(order['status'], 'fechado')
                self.assertEqual(db.execute('SELECT count(*) FROM print_jobs').fetchone()[0], 0)
                self.assertEqual(db.execute("SELECT value FROM meta WHERE key='ticket:2026-10-28'").fetchone()[0], '99')
            self.assertEqual(report['open_orders_closed_in_copy'], 1)
            self.assertEqual(rows, original)
            with self.assertRaises(FileExistsError):
                convert(rows, path)

    def test_cancellation_is_preserved(self):
        rows = sample()
        rows['pedidos'][0]['status'] = 'cancelado'
        rows['itens_pedido'][0]['status_item'] = 'cancelado'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'converted.db'
            convert(rows, path)
            with closing(sqlite3.connect(path)) as db:
                order = json.loads(db.execute('SELECT data FROM orders').fetchone()[0])
                self.assertEqual(order['status'], 'cancelado')
                self.assertEqual(order['itens'][0]['quantidade_cancelada'], 2)
                self.assertEqual(order['itens'][0]['quantidade_entregue'], 0)

    def test_mismatched_totals_and_fractional_cents_are_rejected(self):
        rows = sample()
        rows['pedidos'][0]['total_pedido'] = Decimal('0.01')
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                convert(rows, Path(directory) / 'converted.db')
        with self.assertRaises(ValueError):
            cents(Decimal('0.001'))


if __name__ == '__main__':
    unittest.main()
