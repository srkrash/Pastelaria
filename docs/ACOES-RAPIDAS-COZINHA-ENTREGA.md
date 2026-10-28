# Ações rápidas na cozinha e entrega — 2.4.3 (207)

Solicitadas em 28/10/2026, após a distribuição 2.4.2. Não há mudança de schema,
Android mínimo ou arquitetura.

## Cozinha

“Definir como pronto” envia imediatamente a quantidade ainda a produzir do
item destacado: solicitada menos cancelada menos pronta acumulada. Não abre
diálogo e não muda unidades entregues ou outros recheios. O item seguinte só
avança após sucesso persistido e reconciliação. “Informar quantidade” mantém
o registro parcial com seletor e confirmação. Ambos ficam bloqueados durante
envio ou quando a fila está sem conexão confirmada. O servidor mantém controle
por ID, revisão e ID de comando para rejeitar conflitos e reenvios duplicados.

## Entrega

“Entregar tudo” fica à direita da senha no cabeçalho, acima das informações de
consumo/horário. Só habilita quando o pedido está aberto, todas as quantidades
ativas estão prontas e há saldo a entregar. Bebidas/salgados já começam prontos;
um pedido de balcão também pode usar a ação. A entrega por item continua disponível.

Um único comando `deliver_all`, com ID do pedido e revisão capturada, faz o
servidor conferir todos os saldos e registrar a entrega numa transação. Cada
quantidade entregue passa à solicitada menos cancelada; quantidade pronta não
é alterada. Pedido é encerrado pelo resumo dos itens, sem marcar pagamento.
Reenvio com o mesmo ID devolve o resultado anterior; comandos concorrentes com
revisão antiga são rejeitados, sem duplicar entregas. Não são enviados comandos
separados por item. Duplo toque e ações simultâneas do mesmo cartão ficam
bloqueados enquanto o envio está em andamento; erro mantém o pedido e reconcilia.

## Validação e implantação

Testes de widgets cobrem o preparo total sem diálogo, preservação da produção
parcial, bloqueio de entrega com pastel pendente, entrega mista após conclusão,
falha, duplo toque e layouts retrato/paisagem com fonte ampliada. Testes SQLite
cobrem preparo obrigatório, saldo já parcialmente entregue, cancelados, balcão
e idempotência. Dois clientes HTTP e dois WebSockets independentes exercitam
entrega completa concorrente: uma resposta 200, outra 409, snapshots convergentes
e pedido vizinho preservado.

Resultado da suíte completa: 76 testes aprovados e 3 ignorados por dependerem
de dados privados locais de histórico, backup e migração. Análise estática sem
apontamentos. Os testes alteram apenas bancos sintéticos e não operam os pedidos
dos tablets conectados.

Atualizar o servidor antes dos demais tablets, pois `deliver_all` é uma operação
nova. Instalar por `adb install -r`, preservando dados. Não criar pedidos reais
ou marcar entregas no banco em uso para testar a instalação. O ensaio dos botões
nos aparelhos reais continua sendo uma validação operacional separada.

Instalação concluída em 28/10/2026 pelo ADB sobre Wi-Fi, sem desinstalar ou limpar
dados. O Android confirmou versão 2.4.3 (207) nos três SM-T815Y: servidor em
10.0.0.11, seguido dos clientes 10.0.0.12 e 10.0.0.200. Apps reabertos após a
instalação; a porta 5000 do servidor voltou a responder. Não foram criados pedidos
nem acionados preparo/entrega no banco dos tablets para validar a implantação.
