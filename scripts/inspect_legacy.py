"""Read-only PostgreSQL inventory. Never prints credentials or customer data."""
import getpass
import json
import os

import psycopg2


def connect():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=os.getenv('DB_PORT', '5432'),
        dbname=os.getenv('DB_NAME', 'pastelaria_db'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD') or getpass.getpass('Senha PostgreSQL: '),
        connect_timeout=10,
    )


def main():
    with connect() as connection:
        connection.set_session(readonly=True, isolation_level='REPEATABLE READ')
        with connection.cursor() as cursor:
            cursor.execute("SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name, ordinal_position")
            print(json.dumps(cursor.fetchall(), ensure_ascii=False))
            for table in ['produtos', 'pedidos', 'itens_pedido', 'past_ingredientes']:
                cursor.execute('SELECT count(*) FROM ' + table)
                print(table, cursor.fetchone()[0])
            for query in [
                'SELECT status, count(*) FROM pedidos GROUP BY status',
                'SELECT status_item, count(*) FROM itens_pedido GROUP BY status_item',
                'SELECT ativo, tipo, count(*) FROM produtos GROUP BY ativo,tipo',
                'SELECT min(data_hora_pedido),max(data_hora_pedido),sum(total_pedido) FROM pedidos',
                'SELECT count(*) FROM pedidos p WHERE total_pedido != (SELECT coalesce(sum(subtotal),0) FROM itens_pedido i WHERE i.pedido_id=p.id)',
                'SELECT p.status,i.status_item,count(*) FROM pedidos p JOIN itens_pedido i ON i.pedido_id=p.id GROUP BY p.status,i.status_item',
            ]:
                cursor.execute(query)
                print(json.dumps(cursor.fetchall(), default=str, ensure_ascii=False))


if __name__ == '__main__':
    main()
