import os
from flask import Flask, jsonify, request
import psycopg2
from psycopg2.extras import DictCursor
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'),
        database=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        port=os.getenv('DB_PORT')
    )
    return conn

def _get_proximo_numero_pedido():
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Usa o fuso horário correto para a data de reset
    cur.execute("SELECT (NOW() AT TIME ZONE 'America/Sao_Paulo')::DATE;")
    data_reset = cur.fetchone()[0]

    try:
        # Usa SELECT FOR UPDATE para evitar que dois clientes peguem o mesmo número
        cur.execute("SELECT numero_pedido FROM pedidos WHERE reset_data = %s ORDER BY numero_pedido DESC LIMIT 1 FOR UPDATE;", (data_reset,))
        ultimo_numero = cur.fetchone()
        
        if ultimo_numero and ultimo_numero[0] < 99:
            proximo_numero = ultimo_numero[0] + 1
        else:
            proximo_numero = 1

    finally:
        cur.close()
        conn.close()

    return proximo_numero


@app.route('/')
def home():
    return "Servidor Rodando!"

@app.route('/produtos', methods=['GET'])
def get_produtos():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    cur.execute("SELECT id, nome, preco, tipo FROM produtos WHERE ativo = TRUE ORDER BY tipo, nome;")
    produtos = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify([dict(p) for p in produtos])

@app.route('/pedidos/<int:pedido_id>', methods=['GET'])
def get_pedido_detalhes(pedido_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    
    pedido_detalhes = {}

    try:
        cur.execute("SELECT numero_pedido, data_hora_pedido, observacoes, total_pedido FROM pedidos WHERE id = %s;", (pedido_id,))
        pedido = cur.fetchone()
        
        if not pedido:
            return jsonify({"erro": "Pedido não encontrado."}), 404
        
        pedido_detalhes = dict(pedido)
        pedido_detalhes['itens'] = []

        # 2. Obter todos os itens para este pedido
        cur.execute("""
            SELECT
                ip.id AS item_id,
                ip.quantidade,
                ip.observacoes_item,
                ip.status_item,
                p.nome AS produto_nome,
                p.tipo AS produto_tipo
            FROM itens_pedido ip
            JOIN produtos p ON ip.produto_id = p.id
            WHERE ip.pedido_id = %s;
        """, (pedido_id,))
        
        itens = cur.fetchall()

        for item in itens:
            item_dict = dict(item)
            
            # Se for um pastel customizado, obtenha os ingredientes
            if item_dict['produto_tipo'] == 'pastel':
                cur.execute("""
                    SELECT p.nome AS ingrediente_nome
                    FROM past_ingredientes pi
                    JOIN produtos p ON pi.ingrediente_id = p.id
                    WHERE pi.item_pedido_id = %s;
                """, (item_dict['item_id'],))
                
                ingredientes = cur.fetchall()
                item_dict['ingredientes'] = [i['ingrediente_nome'] for i in ingredientes]
            
            pedido_detalhes['itens'].append(item_dict)

    except Exception as e:
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()
        conn.close()
    
    return jsonify(pedido_detalhes)

@app.route('/pedidos', methods=['POST'])
def criar_pedido():
    conn = get_db_connection()
    data = request.get_json()

    if not data or 'itens' not in data:
        return jsonify({"erro": "Dados do pedido inválidos."}), 400

    try:
        cur = conn.cursor(cursor_factory=DictCursor)
        conn.autocommit = False # Inicia a transação
        
        # 1. Gerar o próximo número do pedido
        proximo_numero = _get_proximo_numero_pedido()
        
        # 2. Obter os dados principais do pedido
        observacoes_pedido = data.get('observacoes_pedido', '')
        
        # 3. Inserir o pedido principal com o total inicial de 0.00
        cur.execute("""
            INSERT INTO pedidos (numero_pedido, observacoes, total_pedido)
            VALUES (%s, %s, %s) RETURNING id;
        """, (proximo_numero, observacoes_pedido, 0.00))
        pedido_id = cur.fetchone()['id']

        total_pedido = 0.00
        
        # 4. Processar e inserir os itens do pedido
        for item_data in data['itens']:
            produto_nome = item_data['produto_nome']
            quantidade_item = item_data.get('quantidade', 1)
            observacoes_item = item_data.get('observacoes_item', '')
            ingredientes_adicionais = item_data.get('ingredientes_adicionais', [])

            # Obter dados do produto
            cur.execute("SELECT id, preco, tipo FROM produtos WHERE nome = %s;", (produto_nome,))
            produto_info = cur.fetchone()
            
            if not produto_info:
                raise Exception(f"Produto '{produto_nome}' não encontrado.")

            produto_id = produto_info['id']
            preco_base_produto = float(produto_info['preco'])
            tipo_produto = produto_info['tipo']
            
            preco_final_item = preco_base_produto

            # Lógica de precificação para pastéis customizados
            if tipo_produto == 'pastel':
                ingredientes_pagos = [
                    ing for ing in ingredientes_adicionais
                    if ing['nome'].lower() not in ['cebola', 'cebolinha', 'orégano']
                ]
                num_ingredientes = len(ingredientes_pagos)
                if num_ingredientes <= 2:
                    preco_final_item = 12.00
                else:
                    preco_final_item = 12.00 + (num_ingredientes - 2) * 3.00

            subtotal_item = preco_final_item * quantidade_item
            total_pedido += subtotal_item

            # Inserir item do pedido
            cur.execute("""
                INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario, subtotal, observacoes_item)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING id;
            """, (pedido_id, produto_id, quantidade_item, preco_final_item, subtotal_item, observacoes_item))
            item_pedido_id = cur.fetchone()['id']

            # Se for um pastel customizado, inserir os ingredientes
            if tipo_produto == 'pastel':
                for ingrediente_data in ingredientes_adicionais:
                    cur.execute("SELECT id FROM produtos WHERE nome = %s;", (ingrediente_data['nome'],))
                    ingrediente_id = cur.fetchone()['id']
                    cur.execute("""
                        INSERT INTO past_ingredientes (item_pedido_id, ingrediente_id, quantidade)
                        VALUES (%s, %s, %s);
                    """, (item_pedido_id, ingrediente_id, ingrediente_data.get('quantidade', 1)))

        # 5. Atualizar o total_pedido no registro principal
        cur.execute("UPDATE pedidos SET total_pedido = %s WHERE id = %s;", (total_pedido, pedido_id))

        conn.commit() # Confirma todas as inserções
        
    except Exception as e:
        conn.rollback() # Reverte todas as inserções em caso de erro
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify({"mensagem": "Pedido criado com sucesso.", "numero_pedido": proximo_numero, "total_pedido": total_pedido}), 201


if __name__ == '__main__':
    print(_get_proximo_numero_pedido())
    # app.run(host='0.0.0.0', port=5000, debug=True)