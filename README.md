# Sistema de Pastelaria - Pastelaria Gaúcha

Este projeto foi desenvolvido sob medida para a **Pastelaria Gaúcha**, focando na otimização do atendimento e na flexibilidade para a escolha de recheios personalizados oferecidos pelo estabelecimento. O sistema integra um backend em Flask e um frontend em Flutter para criar uma solução completa de KDS (Kitchen Display System) e PDV.

## 🚀 Funcionalidades e Regras de Negócio

### 1. Sistema de Numeração Inteligente (Integração com Letreiro Digital)
A lógica de numeração dos pedidos foi projetada especificamente para operar em conjunto com um **letreiro digital de 2 dígitos**:
- **Reset Diário e Ciclico**: A numeração inicia no **01** todos os dias. Além disso, ao atingir o pedido **99**, o contador reinicia automaticamente para **01**, garantindo compatibilidade contínua com o display limitado a dois dígitos.
- **Pedidos com Pastel (Sequência Positiva)**: Apenas pedidos que contêm pastéis recebem a numeração sequencial positiva (01, 02...), pois são estes que devem ser chamados no letreiro digital quando prontos.
- **Pedidos sem Pastel (Sequência Negativa)**: Pedidos exclusivos de bebidas ou itens de pronta entrega recebem numeração negativa oculta (ex: -1, -2). Isso impede que eles avancem o contador do letreiro digital desnecessariamente, mantendo a sequência visual para os clientes que aguardam os pratos principais.

### 2. Gestão Visual de Pedidos (KDS)
- **Consumo no Local vs. Viagem**: O sistema permite classificar cada pedido como "Para Consumo" ou "Para Viagem". No painel de produção, cartões de pedidos recebem **cores distintas** para essa finalidade, facilitando a identificação rápida pela equipe da cozinha e embalagem.
- **Painel em Tempo Real**: Atualizações instantâneas via WebSockets garantem que a fila de produção esteja sempre sincronizada entre todos os dispositivos.
- **Cancelamento Inteligente**: O cancelamento de um pedido remove automaticamente seus itens da produção.

### 3. Automação de Impressão
- **Impressão Térmica**: Geração automática de comandas detalhadas na impressora térmica (ex: Tanca TP-650).
- **Detalhamento de Recheios**: A comanda destaca claramente os ingredientes e personalizações, essencial para a operação da Pastelaria Gaúcha onde a customização é frequente.

### 4. Gestão Financeira
- **Precificação Automática**: O servidor calcula o total do pedido considerando regras complexas, como preços base diferentes e custos adicionais por ingrediente extra.
- **Relatório Diário**: Visualização rápida dos totais vendidos no dia.

### 5. Distribuição Facilitada
- **Atualização via APK**: O sistema hospeda a versão mais recente do aplicativo, permitindo que os dispositivos Android baixem e instalem atualizações diretamente pelo endpoint `/download-apk`.

## 🛠️ Stack Tecnológica

- **Backend**: Python (Flask) + Eventlet + PostgreSQL.
- **Frontend**: Flutter (Android).
- **Hardware**: Integração com impressoras térmicas via protocolo ESC/POS.
