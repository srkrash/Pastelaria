# Requisitos do produto

## 1. Objetivo e ambiente

**Confirmado em 28/10/2026:** organizar bebidas por categoria e voltar a usar
imagens dos produtos. Mineirinho 200 ml e 250 ml são Guaraná Mineiro. Ver
[bebidas e imagens](BEBIDAS-E-IMAGENS.md).

**Confirmado em 28/10/2026:** incluir tela para alterar preços dos produtos, usada
ocasionalmente, acessível por um botão/menu discreto. Ver
[edição de preços](PRECOS-DOS-PRODUTOS.md).

**Confirmado em 28/10/2026:** incluir BI no aplicativo, com visões diária, semanal,
mensal e por hora, usando o histórico. A cozinha deve destacar o próximo pastel
a montar, recheios e quantidades para reduzir confusão, com apresentação própria
em relação à entrega. Implementação e regras dos indicadores em
[BI e cozinha](BI-E-COZINHA.md).

**Confirmado:** facilitar a criação, a fabricação e a entrega de pedidos em um trailer de feira. A operação usa três tablets, roteador OpenWrt, internet Starlink, sistema de senhas e impressora Tanca TP-650.

**Diretriz da arquitetura escolhida:** a operação ocorre na rede local mesmo sem internet. Queda da Starlink não equivale a queda do Wi-Fi ou do tablet servidor; são falhas diferentes e devem aparecer assim para o operador.

**Confirmado sobre hardware:** tablets Samsung antigos; modelo informado SM-T815Y, chamado de “Galaxy Tab A2” na conversa. A Samsung identifica esse código como **Galaxy Tab S2**; usar o código como referência para homologação. Versão instalada do Android e confirmação de que os três aparelhos são iguais ainda pendentes. [Identificação oficial Samsung](https://doc.samsungmobile.com/SM-T815Y/016502210109/eng.html)

A TP-650 está hoje em USB no computador; o destino escolhido é impressão por cabo de rede no OpenWrt, sem computador na operação.

**Pesquisa de compatibilidade em 23/10/2026:** última versão oficial identificada para o SM-T815Y: **Android 7.0 Nougat**. O histórico oficial da Samsung registra, por exemplo, build `T815YDVS2CTK8`, publicada em 14/01/2021, ainda em Android 7.0. Build, data e patch variam conforme região/operadora. Usar Android 7.0 (API 24) como referência inicial de homologação, sem presumir que já esteja instalado nem que todas as dependências atuais sejam compatíveis. [Histórico oficial Samsung](https://doc.samsungmobile.com/SM-T815Y/016568210115/eng.html)

**Pendente:** conferir modelos dos demais aparelhos, memória, armazenamento e versões instaladas do Android; qual será o principal; conferir interface Ethernet da unidade e firmware/configuração da impressora; volume de pedidos no pico; duração do turno; alimentação elétrica e autonomia. A implementação deve priorizar interface leve e validar compatibilidade antes de escolher versões mínimas e dependências. Não inferir Android instalado a partir do modelo ou de atualizações publicadas.

## 2. Papéis dos tablets

| Papel | Responsabilidade |
|---|---|
| Pedido/caixa | Montar pedido, conferir valores, confirmar, informar senha e solicitar impressão |
| Cozinha | Consultar pastéis pendentes, ingredientes, observações e registrar avanço do preparo |
| Entrega | Conferir itens, acompanhar preparo, chamar senha e registrar entrega |

O papel de interface não deve ficar preso ao IP do equipamento. É necessário suportar dois clientes independentes na entrega, inclusive para reproduzir e validar o bug relatado. A troca de papel e a autorização necessária são pendentes.

**Proposta:** o tablet do caixa também é o servidor. Validar essa escolha no hardware; o servidor não deve parar ao trocar de tela.

## 3. Pedido e catálogo

### REQ-01 — Montagem do pedido

**Confirmado em 28/10/2026:** incluir botão “Recheio adicional” na montagem do
pastel, com nome livre e valor por pastel. O valor inicial do campo é o adicional
já configurado no cadastro; o atendente pode ajustá-lo nessa montagem. Multiplicar
pela quantidade do item e preservar nome/valor histórico. Não substituir a regra
dos recheios comuns incluídos. Ver [recheio adicional](RECHEIO-ADICIONAL.md).

- Selecionar pastéis por sabor, salgados e bebidas, com quantidades.
- Preservar as personalizações e regras de adicionais do legado que forem confirmadas com o responsável.
- Distinguir observação do pedido e observação do item.
- Mostrar valores antes de confirmar; servidor recalcula e valida preço, disponibilidade e quantidade.
- Não exibir sucesso se o pedido não estiver persistido no servidor.
- Reenvio do mesmo comando após timeout não cria outro pedido nem outra senha.

**Pendências:** sabores e produtos atuais, regras exatas de recheios/adicionais, tamanhos, descontos, indisponibilidade e possibilidade de editar após iniciar o preparo. Validar consumo local/viagem, já existente no legado.

### REQ-02 — Identidade e senha

- Pedido tem ID interno único e independente da senha exibida.
- Senhas não identificam eventos, cartões ou operações de banco.
- Atribuição de senha deve ser atômica, inclusive com pedidos simultâneos.
- Definir a jornada operacional em `America/Sao_Paulo`; mudança de data não pode fazer pedidos pendentes desaparecerem.

**Confirmado:** senha numérica de 1 a 99; chamada por voz e, às vezes, pelo painel de LED existente. Não há requisito confirmado de acionar esse painel automaticamente.

**Regra confirmada de reinício:** a sequência é `1, 2, ..., 98, 99, 1, 2, ...`. À meia-noite em `America/Sao_Paulo`, a sequência do novo dia reinicia em 1. Não há operação após 23h59. O responsável informa que não ocorre cenário de 99 senhas simultaneamente ativas. Não implementar seleção de próxima senha livre, esgotamento de senhas ou limite de 99 pedidos no dia como requisito desta versão.

O reinício diário deve funcionar mesmo com tablet desligado à meia-noite: no próximo comando de criação, comparar a data local da jornada e atribuir 1 ao primeiro pedido elegível do novo dia. A troca de dia e a alocação da senha são atômicas. Não reiniciar por simples reabertura do app no mesmo dia.

**Legado:** o responsável informa que o sistema em uso já implementa esse ciclo. O trecho presente neste checkout e a restrição do schema aparentam divergir; conferir a versão implantada antes de atribuir um defeito à operação atual. Histórico deve permitir várias ocorrências da mesma senha no mesmo dia, identificadas por IDs internos distintos.

**Pendência:** regra dos pedidos só de bebida/salgado, que no legado não recebem senha positiva. Integração eletrônica com o letreiro permanece fora do escopo até solicitação específica.

## 4. Produção de pastéis

### REQ-03 — Nova tela da cozinha

**Confirmado em 28/10/2026:** o botão principal “Definir como pronto” conclui
todo o saldo do item exibido em um toque, sem confirmação. Preservar as unidades
já prontas/entregues; outros itens não são concluídos implicitamente. A produção
parcial continua disponível por uma ação secundária de quantidade.

**Confirmado:** a tela atual não é usada porque a experiência não ficou boa. Criar uma tela parecida com a entrega, adaptada à produção.

**Confirmado:** permitir produção parcial. Proposta de interação: em cada item/sabor, escolher quantas unidades ficaram prontas, com atalho para concluir o saldo. Mostrar total solicitado, pronto acumulado e saldo a produzir, sem juntar itens com personalizações diferentes.

**Proposta de interface a validar em protótipo:**

- Cartões por pedido, com senha em destaque, horário e tempo de espera.
- Quantidades, sabores, ingredientes e observações legíveis sem abrir várias telas.
- Diferenciar aguardando, em preparo e pronto usando texto e indicadores visuais, sem depender somente de cor.
- Ordenação inicial por chegada; preparo de pedidos distintos pode ocorrer em paralelo.
- Botões grandes e poucas ações para o trabalho no trailer.
- Mostrar conexão/sincronização e estado de carregamento; não apresentar fila vazia quando houve falha de consulta.
- Bebidas e salgados só aparecem como contexto quando necessário; não gerar tarefa de pastel a partir deles.
- Cancelamento ou alteração após início deve ter destaque para evitar fabricação incorreta.

**Pendências essenciais:** interação exata do controle por quantidade; necessidade de etapa “em preparo”; agrupamento por sabor/lote; som para novo pedido; ordenação e prioridade manual; destino do cartão após ficar pronto. Produção parcial já é requisito e não depende dessas escolhas de interface.

Critério de aceite: um pedido com sabores distintos e observações deve ser compreensível no tablet real, e a ação de conclusão deve aparecer nos outros clientes sem marcar itens não preparados.

## 5. Entrega

### REQ-04 — Fila compartilhada e confiável

**Confirmado em 28/10/2026:** incluir “Entregar tudo” à direita da senha no
cabeçalho do pedido. Habilitar somente quando todos os pastéis estiverem prontos.
A ação entrega todos os saldos do pedido (inclusive bebidas/salgados), sem
confirmação por item, em uma transação idempotente validada pelo servidor.
Preservar a entrega parcial e não converter unidades pendentes em prontas.

- Todos os clientes com a mesma configuração de filtro devem representar o mesmo estado persistido.
- Um cliente abrir a fila não consome, reserva ou oculta pedidos para outro.
- A entrega de um pedido remove/atualiza somente esse pedido em todos os clientes.
- Ação simultânea no mesmo pedido é idempotente; resposta repetida ou evento repetido não remove um segundo cartão.
- Reconectar, reabrir ou retomar a tela recupera as alterações perdidas.
- Identificação e mutação por ID, nunca por índice da lista.

**Proposta:** mostrar pedidos aguardando preparo e prontos, com estados claros. Confirmar se a fila deve mostrar somente prontos.

**Confirmado:** permitir entrega parcial. Selecionar item e quantidade entregue, mostrar saldo e manter o pedido visível até que todas as unidades não canceladas sejam entregues. Dois dispositivos não podem entregar a mesma quantidade disponível por concorrência.

**Pendências:** retirada antecipada de bebidas; conferência de todos os itens; desfazer entrega; chamar novamente uma senha; pedidos que não contêm pastel.

## 6. Estados e regras de consistência

**Proposta inicial:** item passa por `aguardando → em_preparacao → pronto → entregue`, com cancelamento conforme regra autorizada. Transições devem ser validadas no servidor. Itens de pronta entrega podem começar como prontos, conforme regra do produto.

Pedido guarda situação própria e resumo derivado dos itens. Pronto não é entregue. Pagamento não é preparo. Um clique de entrega não deve marcar silenciosamente itens pendentes como preparados.

**Requisito confirmado de parcialidade:** manter, por item, quantidades solicitada, cancelada, pronta acumulada e entregue acumulada. Garantir `0 <= entregue <= pronto <= solicitada - cancelada`. Quantidade pronta inclui o que já foi entregue; disponível para entregar é `pronto - entregue`; saldo a produzir é `solicitada - cancelada - pronto`. Etapa em preparo, se adotada, precisa de contador próprio consistente. Itens de pronta entrega podem iniciar com quantidade pronta igual à quantidade solicitada, conforme regra validada.

Exemplo de aceite: pedido de 5 pastéis; cozinha conclui 2; entrega retira 1. Exibir 3 a produzir, 1 pronto disponível e 1 entregue. Concluir a produção dos 3 restantes não encerra a entrega: ainda faltam 4 unidades a entregar. Os três tablets devem concordar após reconexão.

Comandos de incremento/conclusão devem ser atômicos e idempotentes, com histórico. Dois clientes tentando entregar a última unidade não podem registrar duas entregas. Cancelamento de unidades prontas/entregues e estornos exigem regras explícitas; não reduzir contadores arbitrariamente para satisfazer a invariável.

**Pendências:** pagamento no pedido ou na retirada; dinheiro/PIX/cartão; troco; fechamento de caixa; confirmação manual ou integração; perfis de acesso para cancelamento, reabertura, preços e reimpressão. Não incluir integração fiscal, adquirente ou PIX automático sem decisão específica.

## 7. Impressão

### REQ-05 — Tanca TP-650

**Confirmado em 28/10/2026:** incluir QR Code PIX no cupom, com o total do pedido,
chave celular e dados do beneficiário configurados localmente. Imprimir após o
total e manter uma linha extra de margem inferior. Não implica confirmação
automática de pagamento. Ver [PIX no cupom](PIX-NO-CUPOM.md).

- Preservar pedido e produção mesmo se a impressão falhar.
- Manter fila persistente com tentativas e erro visível.
- Distinguir pendente, envio em andamento, enviado, falha e resultado incerto quando aplicável.
- Reimpressão explícita, identificada como segunda via e auditável.
- Restaurar banco em outro tablet não pode reenviar automaticamente todos os trabalhos antigos.

**Confirmado:** substituir USB no computador por Ethernet no roteador, sem computador na operação. A ficha oficial da TP-650 informa Ethernet, Serial, VCom e USB; verificar a unidade real e a configuração antes de homologar. [Ficha técnica Tanca](https://tanca.com.br/assets/conteudo/uploads/tp650v060421compressed6526ffe300879.pdf)

**Pendências:** protocolo/porta de impressão, IP/configuração, largura do papel, acentos/corte, quantidade e destino das vias, impressão automática ou manual. Não assumir porta TCP 9100 sem conferir a documentação e testar.

## 8. Backup e recuperação

### REQ-06 — Backup diário em nuvem (planejado)

**Proposta:** cópia consistente do SQLite ao fechar o caixa; verificação diária e ao abrir o aplicativo; upload pendente quando sem internet; Google Drive como primeiro candidato.

**Preferência confirmada:** usar opção gratuita de armazenamento, se viável. Google Drive é a proposta inicial, usando a cota gratuita da conta: a documentação informa até 15 GB compartilhados com Gmail e Google Fotos. Conferir cota e espaço realmente disponíveis na conta escolhida; não prometer armazenamento ilimitado nem compra automática de espaço. [Armazenamento Google](https://support.google.com/googleone/answer/9004014?hl=en)

- Incluir banco, versão do schema/aplicativo e configurações necessárias à recuperação, sem exportar tokens diretamente.
- Criptografar, validar integridade e confirmar o upload antes de registrar sucesso remoto.
- Retenção proposta: 7 cópias diárias locais, 30 diárias e 12 mensais na nuvem.
- Guardar meio de recuperação da chave fora do tablet; perda do aparelho não pode tornar o backup inutilizável.
- Exibir última cópia local, último envio confirmado e pendências.
- Monitorar uso de espaço e falhas de cota. Dimensionar retenção pelo tamanho medido dos backups; não apagar a última cópia remota válida para tentar abrir espaço para um upload ainda não confirmado.
- Testar restauração em outro aparelho, com controle de qual é o servidor ativo.

**Pendências:** provedor/conta, retenção, responsável pela chave, perda de dados aceitável e tempo de recuperação desejado. Backup diário pode perder todo o trabalho posterior à última cópia; confirmar necessidade de cópias durante o expediente.

## 9. Operação e qualidade

**Confirmado em 28/10/2026 para a migração:** importar todo o catálogo e histórico
do PostgreSQL; encerrar os pedidos antigos na cópia destinada ao SQLite do tablet,
mantendo cancelados e o registro dos status originais. O PostgreSQL de origem fica
preservado. Procedimento e validação em [migração](MIGRACAO-POSTGRESQL.md).

- Diferenciar internet indisponível, servidor inacessível, dados desatualizados e impressora indisponível.
- Sem servidor, preservar rascunho e informar indisponibilidade; não confirmar pedidos localmente como se estivessem na cozinha.
- Persistir pedidos em reinício do aplicativo/tablet; preservar rascunho é proposta a validar.
- Registrar erros com IDs de comando, pedido e dispositivo, sem credenciais ou dados desnecessários.
- Disponibilizar diagnóstico e exportação de logs sanitizados.
- Proposta de desempenho: atualizações em até 2 segundos em rede saudável; reconciliar em até 5 segundos após conexão restabelecida. Validar metas com carga e hardware reais.
- Atualização de APK deve preservar dados e identidade do servidor; instalação e migração exigem roteiro de recuperação.

## 10. Perguntas para fechar o escopo

1. Os três tablets são SM-T815Y? Quais versões do Android estão instaladas? Qual será o servidor? Ficam ligados na energia durante todo o turno?
2. Validar Ethernet/configuração da TP-650; qual largura, vias e momento da impressão?
3. Como deve ser a interação para registrar quantidades parciais? Precisa da etapa em preparo e de produção por lote?
4. Qual tratamento para pedidos sem pastel? Ciclo após 99 e reinício à meia-noite já estão definidos.
5. Quais sabores, personalizações e preços? Pode editar ou cancelar depois de iniciar o preparo?
6. Quando acontece o pagamento e o que o caixa precisa registrar? Há consumo local/viagem?
7. Google Drive gratuito atende à preferência? Qual conta será usada? Quanto trabalho pode ser perdido e quanto tempo pode levar a restauração?
8. Qual volume no pico, tamanho do turno e condições de alimentação/rede? Quais outros bugs e passos de reprodução já são conhecidos?
