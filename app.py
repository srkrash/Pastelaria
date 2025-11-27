import eventlet
eventlet.monkey_patch()
import os
import json
from printer import ThermalPrinter
from flask import Flask, jsonify, request, render_template, send_file
import psycopg2
from psycopg2.extras import DictCursor
from dotenv import load_dotenv
from datetime import date
from flask_socketio import SocketIO, emit
from flask_cors import CORS

load_dotenv()

app = Flask(__name__)

socketio = SocketIO(app, cors_allowed_origins="*", async_mode="eventlet")
CORS(app)

connected_clients = set()

printer = ThermalPrinter('TANCA TP-650')

@socketio.on('connect')
def handle_connect():
    sid = request.sid
    print(f"Cliente conectado: {sid}")
    connected_clients.add(sid)

@socketio.on('disconnect')
def handle_disconnect():
    sid = request.sid
    print(f"Cliente desconectado: {sid}")
    connected_clients.remove(sid)
    
def get_db_connection():
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'),
        database=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        port=os.getenv('DB_PORT')
    )
    return conn

def _get_proximo_numero_pedido(tem_pastel=True):
    conn = get_db_connection()
    cur = conn.cursor()

    # Usa o fuso horário correto para a data de reset
    cur.execute("SELECT (NOW() AT TIME ZONE 'America/Sao_Paulo')::DATE;")
    data_reset = cur.fetchone()[0]  # type: ignore

    try:
        if tem_pastel:
            # Sequência Positiva (Com Pastel)
            cur.execute("""
                SELECT numero_pedido 
                FROM pedidos 
                WHERE reset_data = %s AND numero_pedido > 0
                ORDER BY numero_pedido DESC 
                LIMIT 1 FOR UPDATE;
            """, (data_reset,))
            ultimo_numero_row = cur.fetchone()

            if ultimo_numero_row:
                proximo_numero = ultimo_numero_row[0] + 1
            else:
                proximo_numero = 1
                
            if proximo_numero % 100 == 0:
                proximo_numero += 1
        else:
            # Sequência Negativa (Sem Pastel)
            cur.execute("""
                SELECT numero_pedido 
                FROM pedidos 
                WHERE reset_data = %s AND numero_pedido < 0
                ORDER BY numero_pedido ASC 
                LIMIT 1 FOR UPDATE;
            """, (data_reset,))
            ultimo_numero_row = cur.fetchone()

            if ultimo_numero_row:
                proximo_numero = ultimo_numero_row[0] - 1
            else:
                proximo_numero = -1

    finally:
        cur.close()
        conn.close()
    return proximo_numero

def _print_pedido(pedido):
    try:
        printer.print_string(printer.gerar_string_impressao_48col(pedido), f'PEDIDO #{pedido["numero_pedido"]}')
    except Exception as e:
        print(f"Erro ao imprimir pedido: {e}")

@app.route('/')
def home():
    print("Rota / acessada")
    socketio.emit('my_response', {'data': 'Hello, World!'}, namespace='/')
    textEmit = 'Servidor Rodando!<br><br>Clientes atuais: <br>' + '<br>'.join(connected_clients)
    return textEmit

@app.route('/produtos', methods=['GET'])
def get_produtos():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    tipo_filtro = request.args.get('tipo')
    print(f"Buscando produtos. Filtro: {tipo_filtro}")
    query = "SELECT id, nome, preco, tipo FROM produtos WHERE ativo = TRUE"
    params = []

    if tipo_filtro:
        query += " AND tipo = %s"
        params.append(tipo_filtro)

    query += " ORDER BY tipo, nome;"
    cur.execute(query, params)
    produtos = cur.fetchall()
    cur.close()
    conn.close()

    for p in produtos:
        if 'preco' in p and p['preco'] is not None:
            p['preco'] = float(p['preco'])

    return jsonify([dict(p) for p in produtos])

def _fetch_pedido_details(pedido_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    pedido_detalhes = {}

    try:
        cur.execute("""
            SELECT 
                id, 
                numero_pedido, 
                data_hora_pedido, 
                observacoes, 
                total_pedido, 
                status 
            FROM pedidos WHERE id = %s;
        """, (pedido_id,))
        pedido = cur.fetchone()

        if not pedido:
            return None

        pedido_detalhes = dict(pedido)
        pedido_detalhes['itens'] = []

        # 2. Obter todos os itens para este pedido
        cur.execute("""
            SELECT
                ip.id AS item_id,
                ip.quantidade,
                ip.observacoes_item,
                ip.status_item,
                ip.preco_unitario,
                ip.subtotal,
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
                item_dict['ingredientes'] = [i['ingrediente_nome']
                                             for i in ingredientes]

            pedido_detalhes['itens'].append(item_dict)
            
        return pedido_detalhes

    except Exception as e:
        print(f"Erro em _fetch_pedido_details: {e}")
        raise e
    finally:
        cur.close()
        conn.close()

@app.route('/pedidos/<int:pedido_id>', methods=['GET'])
def get_pedido_detalhes(pedido_id):
    print(f"Buscando detalhes do pedido {pedido_id}")
    try:
        pedido_detalhes = _fetch_pedido_details(pedido_id)
        if not pedido_detalhes:
             return jsonify({"erro": "Pedido não encontrado."}), 404
        return jsonify(pedido_detalhes)
    except Exception as e:
        return jsonify({"erro": str(e)}), 500

@app.route('/reimprimir_pedido/<int:pedido_id>', methods=['POST'])
def reimprimir_pedido(pedido_id):
    print(f"Solicitação de reimpressão para o pedido {pedido_id}")
    try:
        pedido_detalhes = _fetch_pedido_details(pedido_id)
        
        if not pedido_detalhes:
            return jsonify({"erro": "Pedido não encontrado."}), 404
            
        _print_pedido(pedido_detalhes)
        return jsonify({"mensagem": f"Pedido {pedido_id} enviado para reimpressão."}), 200
        
    except Exception as e:
        print(f"Erro ao reimprimir pedido: {e}")
        return jsonify({"erro": str(e)}), 500

@app.route('/pedidos', methods=['POST'])
def criar_pedido():
    print("Recebendo solicitação de novo pedido...")
    conn = get_db_connection()
    data = request.get_json()

    if not data or 'itens' not in data:
        return jsonify({"erro": "Dados do pedido inválidos."}), 400

    try:
        cur = conn.cursor(cursor_factory=DictCursor)
        conn.autocommit = False  # Inicia a transação

        # 1. VERIFICAÇÃO DE PASTEL (Antes de gerar o número)
        # Verifica se existe pelo menos um item do tipo 'pastel'
        tem_pastel = False
        for item_data in data['itens']:
            produto_nome = item_data['produto_nome']
            cur.execute("SELECT tipo FROM produtos WHERE nome = %s", (produto_nome,))
            res = cur.fetchone()
            if res and res['tipo'] == 'pastel':
                tem_pastel = True
                break

        # 2. Gerar o próximo número do pedido com base no tipo
        proximo_numero = _get_proximo_numero_pedido(tem_pastel)

        # 3. Obter os dados principais do pedido
        observacoes_pedido = data.get('observacoes_pedido', '')
        # 4. Inserir o pedido principal com o total inicial de 0.00
        cur.execute("""
            INSERT INTO pedidos (numero_pedido, observacoes, total_pedido)
            VALUES (%s, %s, %s) RETURNING id;
        """, (proximo_numero, observacoes_pedido, 0.00))
        pedido_dados = cur.fetchone()
        pedido_id = pedido_dados['id']  # type: ignore

        novo_pedido_detalhes = {
            'pedido_id': pedido_id,
            'numero_pedido': proximo_numero,
            'observacoes': observacoes_pedido,
            'itens': []
        }

        total_pedido = 0.00

        # 4. Processar e inserir os itens do pedido
        for item_data in data['itens']:
            produto_nome = item_data['produto_nome']
            quantidade_item = item_data.get('quantidade', 1)
            observacoes_item = item_data.get('observacoes_item', '')
            ingredientes = item_data.get('ingredientes', [])

            # Obter dados do produto
            cur.execute(
                "SELECT id, preco, tipo FROM produtos WHERE nome = %s;", (produto_nome,))
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
                    ing for ing in ingredientes
                    if ing['nome'].lower() not in ['cebola', 'cebolinha', 'orégano']
                ]
                is_special = False
                for ing in ingredientes_pagos:
                    if ing['nome'].lower() == 'misto':
                        preco_final_item = 25.00
                        is_special = True
                        break
                    elif ing['nome'].lower() == 'pizza':
                        preco_final_item = 15.00
                        is_special = True
                        break

                # Se não for um pastel especial, aplica a lógica de precificação por ingredientes
                if not is_special:
                    num_ingredientes = len(ingredientes_pagos)
                    if num_ingredientes <= 2:
                        preco_final_item = 12.00
                    else:
                        preco_final_item = 12.00 + \
                            (num_ingredientes - 2) * 3.00

            subtotal_item = preco_final_item * quantidade_item
            total_pedido += subtotal_item
            # Inserir item do pedido
            cur.execute("""
                INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario, subtotal, observacoes_item)
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING id, status_item;
            """, (pedido_id, produto_id, quantidade_item, preco_final_item, subtotal_item, observacoes_item))

            item_info = cur.fetchone()
            item_pedido_id = item_info['id']  # type: ignore
            status_item = item_info['status_item']  # type: ignore

            item_para_ws = {
                'item_id': item_pedido_id,
                'pedido_id': pedido_id, # Adiciona o ID do pedido
                'numero_pedido': proximo_numero, # Adiciona o número do pedido
                'produto_nome': produto_nome,
                'produto_tipo': tipo_produto,
                'quantidade': quantidade_item,
                'status_item': status_item,
                'preco': subtotal_item,
                'observacoes_item': observacoes_item,
                'ingredientes': []  # Inicializa a lista de ingredientes
            }

            # Se for um pastel customizado, inserir os ingredientes
            if tipo_produto == 'pastel':
                for ingrediente_data in ingredientes:
                    cur.execute(
                        "SELECT id FROM produtos WHERE nome = %s;", (ingrediente_data['nome'],))
                    ingrediente_info = cur.fetchone()
                    ingrediente_id = ingrediente_info['id']  # type: ignore

                    cur.execute("""
                        INSERT INTO past_ingredientes (item_pedido_id, ingrediente_id, quantidade)
                        VALUES (%s, %s, %s);
                    """, (item_pedido_id, ingrediente_id, ingrediente_data.get('quantidade', 1)))

                    item_para_ws['ingredientes'].append(
                        ingrediente_data['nome'])

            novo_pedido_detalhes['itens'].append(item_para_ws)

        # 5. Atualizar o total_pedido no registro principal
        cur.execute("UPDATE pedidos SET total_pedido = %s WHERE id = %s;",
                    (total_pedido, pedido_id))
        novo_pedido_detalhes['total_pedido'] = total_pedido

        conn.commit()  # Confirma todas as inserções

        json.dumps(novo_pedido_detalhes)

        print(f"Pedido criado com sucesso: #{proximo_numero}")
        socketio.emit('novo_pedido', novo_pedido_detalhes, namespace='/')

        _print_pedido(novo_pedido_detalhes)



    except Exception as e:
        conn.rollback()  # Reverte todas as inserções em caso de erro
        print(f"Erro ao criar pedido: {e}")
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()  # type: ignore
        conn.close()

    return jsonify({"mensagem": "Pedido criado com sucesso.", "numero_pedido": proximo_numero, "total_pedido": total_pedido}), 201

@app.route('/pedidos/itens', methods=['GET'])
def get_itens_pedido():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)

    # Parâmetros de filtro da URL
    status_filtro = request.args.getlist('status_item')
    print(f"Buscando itens do pedido. Filtro status: {status_filtro}")

    # Lógica para construir a query SQL com base no filtro
    query = """
        SELECT
            ip.id AS item_id,
            ip.pedido_id,
            ip.quantidade,
            ip.observacoes_item,
            ip.status_item,
            p.nome AS produto_nome,
            p.tipo AS produto_tipo,
            pe.numero_pedido,
            pe.observacoes
        FROM itens_pedido ip
        JOIN produtos p ON ip.produto_id = p.id
        JOIN pedidos pe ON ip.pedido_id = pe.id
    """

    params = ()
    if status_filtro:
        # Cria placeholders para o IN clause (ex: %s, %s)
        placeholders = ', '.join(['%s'] * len(status_filtro))
        query += f" WHERE ip.status_item IN ({placeholders})"
        params = tuple(status_filtro)

    query += " ORDER BY pe.data_hora_pedido, ip.id;"

    try:
        cur.execute(query, params)
        itens = cur.fetchall()

        lista_final = []
        for item in itens:
            item_dict = dict(item)

            if item_dict['produto_tipo'] == 'pastel':
                cur_ingredientes = conn.cursor(cursor_factory=DictCursor)
                cur_ingredientes.execute("""
                    SELECT p.nome AS ingrediente_nome
                    FROM past_ingredientes pi
                    JOIN produtos p ON pi.ingrediente_id = p.id
                    WHERE pi.item_pedido_id = %s;
                """, (item_dict['item_id'],))

                ingredientes = cur_ingredientes.fetchall()
                item_dict['ingredientes'] = [i['ingrediente_nome']
                                             for i in ingredientes]
                cur_ingredientes.close()
            else:
                # Garante que a chave 'ingredientes' exista
                item_dict['ingredientes'] = []

            lista_final.append(item_dict)

    except Exception as e:
        print(f"Erro em get_itens_pedido: {e}")
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()
        conn.close()

    return jsonify(lista_final)

@app.route('/pedidos/hoje', methods=['GET'])
def get_pedidos_hoje():
    """
    Retorna a lista de todos os pedidos criados na data atual.
    """
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    print("Buscando pedidos de hoje...")

    query = """
        SELECT 
            id,
            numero_pedido,
            status, 
            total_pedido,
            data_hora_pedido,
            observacoes
        FROM 
            pedidos
        WHERE
            reset_data = CURRENT_DATE
        ORDER BY
            data_hora_pedido DESC;
    """

    try:
        cur.execute(query)
        pedidos = cur.fetchall()

        return jsonify([dict(p) for p in pedidos])

    except Exception as e:
        print(f"Erro em get_pedidos_hoje: {e}")
        return jsonify({"error": "Erro interno do servidor"}), 500

    finally:
        cur.close()
        conn.close()

STATUS_POSSIVEIS = ['aguardando', 'em_preparacao',
                    'pronto', 'entregue', 'cancelado']

@app.route('/itens-pedido/<int:item_id>/status', methods=['PUT'])
def atualizar_status_item(item_id):
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.get_json()
    novo_status = data.get('status')
    print(f"Atualizando status do item {item_id} para {novo_status}")

    if not novo_status:
        return jsonify({"erro": "O novo status não foi fornecido."}), 400

    if novo_status not in STATUS_POSSIVEIS:
        return jsonify({"erro": "Status inválido."}), 400

    try:
        # 1. Atualiza o status do item no banco de dados
        cur.execute("""
            UPDATE itens_pedido
            SET status_item = %s
            WHERE id = %s RETURNING pedido_id;
        """, (novo_status, item_id))

        resultado = cur.fetchone()

        if not resultado:
            conn.rollback()
            return jsonify({"erro": "Item do pedido não encontrado."}), 404

        pedido_id = resultado[0]

        conn.commit()

        # 2. Emite o evento de WebSocket para notificar os clientes
        socketio.emit('status_atualizado', {
            'item_id': item_id,
            'novo_status': novo_status,
            'pedido_id': pedido_id
        }, namespace='/')

    except Exception as e:
        conn.rollback()
        print(f"Erro em atualizar_status_item: {e}")
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()
        conn.close()

    # 3. Retorna a resposta HTTP de sucesso para o cliente que fez a requisição
    return jsonify({
        "mensagem": f"Status do item {item_id} atualizado para '{novo_status}'.",
        "pedido_id": pedido_id
    }), 200

@app.route('/pedidos/<int:pedido_id>/status', methods=['PATCH'])
def update_pedido_status(pedido_id):

    # 1. Conexão e Dados
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.get_json()
    new_status = data.get('status')
    print(f"Atualizando status do pedido {pedido_id} para {new_status}")

    # 2. Validação
    if not new_status or new_status not in ['fechado', 'cancelado']:
        return jsonify({"erro": "Status inválido. Deve ser 'fechado' ou 'cancelado'."}), 400

    try:
        # 3. Atualização no Banco de Dados
        cur.execute("""
            UPDATE pedidos
            SET status = %s
            WHERE id = %s;
        """, (new_status, pedido_id))

        if cur.rowcount == 0:
            conn.rollback()
            return jsonify({"erro": "Pedido não encontrado ou status inalterado."}), 404

        # Se o pedido for cancelado, cancela também todos os itens associados
        if new_status == 'cancelado':
            print(f"Cancelando todos os itens do pedido {pedido_id}...")
            cur.execute("""
                UPDATE itens_pedido
                SET status_item = 'cancelado'
                WHERE pedido_id = %s;
            """, (pedido_id,))
        
        # Se o pedido for fechado, marca todos os itens como 'pronto' (se ainda não estiverem entregues/cancelados)
        elif new_status == 'fechado':
             print(f"Finalizando todos os itens do pedido {pedido_id}...")
             cur.execute("""
                UPDATE itens_pedido
                SET status_item = 'pronto'
                WHERE pedido_id = %s AND status_item NOT IN ('entregue', 'cancelado', 'pronto');
            """, (pedido_id,))

        conn.commit()

        # Notifica clientes sobre a atualização do pedido
        socketio.emit('pedido_atualizado', {
            'pedido_id': pedido_id,
            'novo_status': new_status
        }, namespace='/')

        return jsonify({"mensagem": f"Status do pedido {pedido_id} atualizado para {new_status}."}), 200

    except Exception as e:
        conn.rollback()
        # Loga o erro, se necessário
        print(f"Erro em update_pedido_status: {e}")
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()
        conn.close()

@app.route('/pedidos/<int:pedido_id>', methods=['PUT'])
def update_pedido_observacoes(pedido_id):
    conn = get_db_connection()
    cur = conn.cursor()
    data = request.get_json()
    observacoes = data.get('observacoes')

    print(f"Atualizando observacoes do pedido {pedido_id}")

    try:
        cur.execute("""
            UPDATE pedidos
            SET observacoes = %s
            WHERE id = %s;
        """, (observacoes, pedido_id))

        if cur.rowcount == 0:
            conn.rollback()
            return jsonify({"erro": "Pedido não encontrado."}), 404

        conn.commit()

        return jsonify({"mensagem": f"Observações do pedido {pedido_id} atualizadas."}), 200

    except Exception as e:
        conn.rollback()
        print(f"Erro em update_pedido_observacoes: {e}")
        return jsonify({"erro": str(e)}), 500
    finally:
        cur.close()
        conn.close()

@app.route('/fila_entrega', methods=['GET'])
def get_fila_entrega():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=DictCursor)
    print("Buscando fila de entrega...")
    SQL_FILA_ENTREGA = """
        SELECT
            p.id AS pedido_id,
            p.numero_pedido,
            p.data_hora_pedido,
            p.observacoes,
            p.total_pedido,
            p.status,
            COALESCE(
                json_agg(
                    json_build_object(
                        'item_id', ip.id,
                        'quantidade', ip.quantidade,
                        'preco_unitario', ip.preco_unitario,
                        'subtotal', ip.subtotal,
                        'status_item', ip.status_item,
                        'observacoes_item', ip.observacoes_item,
                        'produto_nome', prod.nome,
                        -- NOVO: Agregação dos ingredientes para este item, usando 'past_ingredientes'
                        'ingredientes', (
                            SELECT 
                                COALESCE(json_agg(ing.nome), '[]'::json)
                            FROM 
                                past_ingredientes pi -- Tabela AGORA correta
                            INNER JOIN 
                                produtos ing ON pi.ingrediente_id = ing.id
                            WHERE 
                                pi.item_pedido_id = ip.id -- Chave de ligação correta
                        )
                    )
                ) FILTER (WHERE ip.id IS NOT NULL),
                '[]'::json
            ) AS itens
        FROM
            pedidos p
        LEFT JOIN
            itens_pedido ip ON p.id = ip.pedido_id
        LEFT JOIN
            produtos prod ON ip.produto_id = prod.id
        WHERE
            p.status = 'aberto'
            and p.reset_data = CURRENT_DATE
            and p.numero_pedido > 0 -- FILTRA PEDIDOS SEM PASTEL (NEGATIVOS)
        GROUP BY
            p.id
        ORDER BY
            p.data_hora_pedido ASC;
    """
    try:
        cur.execute(SQL_FILA_ENTREGA)
        pedidos_fila = cur.fetchall()
        return jsonify([dict(p) for p in pedidos_fila])

    except Exception as e:
        # Lógica de tratamento de erro de DB
        print(f"Erro em get_fila_entrega: {e}")
        return jsonify({"erro": "Falha interna ao carregar a fila de entrega."}), 500
    finally:
        cur.close()
        conn.close()

def print_pedidos(pedido_data):
    pass

def get_app_version():
    try:
        with open('pastelaria_app/pubspec.yaml', 'r') as f:
            for line in f:
                if line.strip().startswith('version:'):
                    return line.split(':')[1].strip()
    except Exception as e:
        print(f"Erro ao ler versão: {e}")
        return "1.0.0"
    return "1.0.0"

@app.route('/download-apk', methods=['GET'])
def download_apk():
    apk_path = 'pastelaria_app/build/app/outputs/flutter-apk/app-release.apk'
    version = get_app_version()
    today = date.today().strftime('%Y-%m-%d')
    filename = f"PastelariaAPK-ver{version}-{today}.apk"
    
    try:
        return send_file(apk_path, as_attachment=True, download_name=filename)
    except Exception as e:
        print(f"Erro ao baixar APK: {e}")
        return jsonify({"erro": "Arquivo não encontrado ou erro no servidor."}), 404

if __name__ == '__main__':
    print("Iniciando servidor Flask...")
    socketio.run(app, host='0.0.0.0', port=5000)
