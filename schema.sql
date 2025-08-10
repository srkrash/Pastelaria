-- Tabela para o catálogo de produtos fixos: pastéis base, ingredientes, bebidas e pastéis completos.
CREATE TABLE produtos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    preco DECIMAL(10, 2) NOT NULL,
    tipo VARCHAR(50) NOT NULL CHECK (tipo IN ('pastel', 'pastel_completo', 'ingrediente', 'bebida', 'salgado')),
    ativo BOOLEAN DEFAULT TRUE
);

-- Tabela para os pedidos dos clientes.
CREATE TABLE pedidos (
    id SERIAL PRIMARY KEY,
    numero_pedido INTEGER NOT NULL,
    data_hora_pedido TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    observacoes TEXT,
    total_pedido DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    reset_data DATE DEFAULT CURRENT_DATE,
    CONSTRAINT unq_numero_pedido_reset_data UNIQUE (numero_pedido, reset_data)
);

-- Tabela para os itens dentro de cada pedido.
CREATE TABLE itens_pedido (
    id SERIAL PRIMARY KEY,
    pedido_id INTEGER NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    produto_id INTEGER NOT NULL REFERENCES produtos(id) ON DELETE RESTRICT,
    quantidade INTEGER NOT NULL DEFAULT 1 CHECK (quantidade > 0),
    preco_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    status_item VARCHAR(50) NOT NULL DEFAULT 'aguardando' CHECK (status_item IN ('aguardando', 'em_preparacao', 'pronto', 'entregue', 'cancelado')),
    observacoes_item TEXT
);

-- Tabela para os ingredientes adicionais de pastéis customizados.
CREATE TABLE past_ingredientes (
    id SERIAL PRIMARY KEY,
    item_pedido_id INTEGER NOT NULL REFERENCES itens_pedido(id) ON DELETE CASCADE,
    ingrediente_id INTEGER NOT NULL REFERENCES produtos(id) ON DELETE RESTRICT,
    quantidade INTEGER NOT NULL DEFAULT 1 CHECK (quantidade > 0)
);


