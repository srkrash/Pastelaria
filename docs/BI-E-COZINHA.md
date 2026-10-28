# Versão 2.2.0+202 — BI e montagem na cozinha

Solicitados pelo responsável em 28/10/2026. O SQLite continua no schema 1; esta
atualização não transforma, encerra ou recria pedidos existentes.

## BI no aplicativo

Abrir pelo ícone de gráfico no cabeçalho principal. Funciona no principal e nos
clientes conectados a um servidor atualizado, sem internet. Consultas autenticadas
em `GET /bi?from=AAAA-MM-DD&to=AAAA-MM-DD`, intervalo inclusivo de até 366 dias.
Há atalhos Hoje, Ontem, 7 dias, 30 dias, Este mês e calendário de período livre.
O calendário do aplicativo está localizado em português brasileiro.

- Indicadores: valor dos pedidos, quantidade de pedidos válidos, ticket médio e
  unidades; comparação percentual com o período imediatamente anterior de igual
  número de dias. Quando a base anterior é zero, informar ausência de base.
- Gráficos de valor, pedidos ou unidades por hora, dia, semana, mês e dia da semana.
  Horas em `America/Sao_Paulo`; dias usam a jornada registrada em `orders.day`.
  Semanas começam na segunda. Bordas semanais e mensais incluem só dias filtrados.
  Horas somam todos os dias do intervalo; dias sem movimento aparecem com zero.
- Ranking dos dez produtos e das dez combinações de recheios com maior quantidade,
  e distribuição por categoria. Cada combinação de pastel é contada uma vez por
  unidade; seus ingredientes não multiplicam seu valor.
- Quantidades e valores de cancelamentos, pedidos em atendimento e encerrados.
  Aviso sobre o histórico encerrado artificialmente durante a migração.

Dinheiro é somado em centavos inteiros a partir dos preços históricos dos itens.
Pedidos cancelados e unidades canceladas são excluídos do valor e dos rankings;
continuam no indicador de cancelamentos. Ticket médio é o valor líquido de
cancelamentos dividido pelo número de pedidos não cancelados, arredondado ao
centavo. Pedidos em atendimento entram na análise. Não há indicador de receita
recebida, lucro, margem ou meio de pagamento: esses dados não existem no domínio
atual. Não inferir pagamento a partir de pronto, entregue ou fechado.

A consulta lê linhas e revisão numa transação consistente e libera a transação
antes da agregação. Usa o índice de jornada existente; não grava comandos, pedidos
ou impressão, e devolve somente agregados ao cliente. Falhas de conexão aparecem
como erro, com nova tentativa; não como gráfico vazio. Atualização manual pelo
botão Atualizar BI. Não há atualização automática, exportação CSV/PDF nem medidas
confiáveis de tempo de montagem, pois o histórico não registra esses eventos.

## Cozinha orientada à montagem

A tela Cozinha agora usa implementação própria em `PastelQueueScreen`, separada
da apresentação da entrega:

- Cartão **MONTAR AGORA** para o próximo item, com número grande de pastéis que
  ainda faltam preparar, recheio em destaque, senha, ID e horário do pedido.
- Observação do pastel e observação do pedido em blocos de atenção separados.
  Personalizações diferentes nunca são juntadas, mesmo com recheios iguais.
- Sequência dos demais itens pendentes com posição, quantidade, recheio, senha e
  observações. Ordem por instante de chegada e ID de pedido para desempate; dentro
  do pedido, ID do item. Senha 01 não passa na frente da 99 por ter valor menor.
- Somente pastéis com saldo a produzir. Bebidas, salgados e itens com preparo
  completo não distraem a montagem. Quantidade restante desconta cancelados e
  prontos, independentemente do que já foi entregue.
- **Registrar unidades prontas** abre confirmação com quantidade inicial 1 e
  atalho para todo o saldo. Produção parcial mantém o saldo no topo; concluir o
  saldo promove o próximo item automaticamente após confirmação do servidor.

“Montar agora” é orientação visual, sem um novo estado persistente. O botão
continua registrando **preparo pronto**, não apenas pastel cru montado; a tela de
confirmação explicita isso. Entrega não é alterada por essa ação. Revisão esperada,
comando idempotente e saldos continuam validados pelo servidor existente. Conflito
ou falha não avança a fila; em erro de sincronização o registro fica desabilitado.

## Validação e instalação

Testes cobrem centavos, cancelamentos totais/parciais, combinação de recheios,
horário de São Paulo, dia bissexto, períodos anterior e atual, API autenticada,
datas inválidas, leitura sem efeitos colaterais, dados reais locais em somente
leitura e layout de BI em tablet retrato/paisagem e 360 px com fonte ampliada.

Na cozinha: layout com fontes ampliadas; chegada 99 antes de 01; exclusão de
itens prontos/bebidas; produção parcial; avanço de item; preservação de entrega;
rejeição de conflito e bloqueio em falha de conexão. Fixtures são sintéticas.
As validações reais opcionais são habilitadas por variáveis de ambiente; não
incluem banco real no repositório, na suíte comum ou no APK.

Antes da atualização, backup protegido do servidor foi exportado para Downloads
e copiado ao PC em `private-migration/tablet-servidor/antes-bi-cozinha.pastelbackup`.
O APK instalado anterior também foi preservado nessa pasta. Nenhuma ação de
preparo ou entrega foi enviada ao tablet como teste desta atualização.

Resultado: 39 testes aprovados (incluindo conciliação do histórico privado e
restauração do backup atual em SQLite em memória); o gerador opcional do pacote
original de migração foi ignorado, pois não era necessário recriar essa entrega.
Análise estática sem apontamentos e `git diff --check` aprovado.

APK final com 56.314.553 bytes, versão 2.2.0+202, minSdk 24, ARM 32/64 bits e
x86_64; assinatura v2 verificada. SHA-256:
`57528B61221D9A3D31A5314C6A3C2EAEA3FDBED9B75FE89024F3E5367710ABFF`.

Atualização instalada por `adb install -r` no tablet servidor SM-T815Y conectado,
preservando configurações, banco e snapshot do pedido ativo. A consulta de todo
o histórico (25/11/2025 a 28/10/2026) respondeu em 2,92 segundos nesse aparelho,
com 9.863 pedidos (9.682 não cancelados e 181 cancelados). Snapshot antes e depois
da atualização e das consultas permaneceu idêntico. Registro sanitizado em
`private-migration/tablet-servidor/validacao-bi-cozinha.json`. Os outros tablets
também precisam receber o APK 2.2.0 para exibir o BI e a nova cozinha; a comunicação
de pedidos com clientes anteriores permanece no mesmo protocolo.

A revisão visual da cozinha usou dados sintéticos e fontes reais, em retrato,
paisagem e fonte ampliada. A validação de usabilidade em um turno real e de dois
montadores usando esta nova apresentação simultaneamente continua pendente.
