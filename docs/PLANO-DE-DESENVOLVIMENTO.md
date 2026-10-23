# Plano de desenvolvimento e validação

Estado inicial: documentação criada; itens abaixo ainda não implementados ou validados.

**Atualização de implementação em 23/10/2026:** núcleo Dart/SQLite, telas por cartões e parcialidade, sincronização, impressão TCP e backup local criptografado foram implementados; 15 testes aprovados, análise estática sem apontamentos e APK de validação compilado. Isso não conclui as etapas que dependem de hardware real, conta de nuvem ou migração dos dados em uso. Consulte [implementação e limitações](IMPLEMENTACAO-V2.md) para o estado atual; o inventário abaixo preserva as evidências iniciais do legado.

Atualização de requisitos: Samsung SM-T815Y informado (Galaxy Tab S2 segundo fabricante), impressão Ethernet sem computador, produção e entrega parciais, senhas 1–99 com chamada por voz/painel ocasional e preferência por backup gratuito. Senhas voltam a 1 após 99 e à meia-noite; não há operação após 23h59. Android instalado, correspondência dos três modelos, principal e conta de nuvem ainda pendentes.

## 1. Inventário inicial do legado

Inspeção estática em 23/10/2026. Não houve execução nem reprodução nos tablets. As evidências abaixo são pontos de investigação, não prova de todas as causas do relato.

| ID | Tipo | Evidência | Ação e aceite |
|---|---|---|---|
| BUG-01 | Relato confirmado do usuário; causa pendente | Pedidos eventualmente ausentes quando dois tablets usam a entrega | Reproduzir com dois clientes, comparar banco/API/estado/UI e criar regressão |
| RISCO-01 | Hipótese relacionada a BUG-01 | `fila_entrega_screen.dart::_despacharPedido` remove por índice após HTTP; `pedidos_provider.dart::_updatePedidoStatusLocal` também remove por evento | Controlar a ordem HTTP/evento e verificar remoção dupla ou índice obsoleto; corrigir por ID/idempotência |
| RISCO-02 | Fragilidade observada | Provider mantém `GlobalKey<AnimatedListState>` e substitui a fila em `fetchFilaEntrega`; UI usa `AnimatedList.initialItemCount` | Verificar divergência entre lista de dados e animações ao recarregar e receber eventos |
| RISCO-03 | Falta de recuperação observada | `_initWebSocket` registra conexão em log, sem recarregar o snapshot no callback de conexão | Criar pedido durante desconexão; após reconectar deve aparecer automaticamente |
| BUG-02 | Inconsistência estática | Produção consulta `em_producao`; backend e schema usam `em_preparacao` | Padronizar contrato e testar itens em preparo na carga inicial e no evento |
| BUG-03 | Inconsistência estática | Entrega envia `fechado`; backend converte itens pendentes em `pronto` | Separar pronto/entregue e validar com a regra de entrega escolhida |
| BUG-04 | Divergência do checkout; versão implantada a conferir | Usuário confirma ciclo 1–99/1 e reset à meia-noite já funcionando em uso; `_get_proximo_numero_pedido` deste checkout pula múltiplos de 100; schema limita `(numero_pedido, reset_data)` | Conferir diferença de versão; implementar regra confirmada no novo núcleo e testar ciclo, histórico e concorrência |
| RISCO-04 | Concorrência | Número é calculado por conexão distinta da transação que cria o pedido; bloqueio da consulta é liberado antes de inserir | Testar simultaneidade e primeira senha da jornada; gerar número atomicamente |
| RISCO-05 | Fronteira de data | `/fila_entrega` filtra `CURRENT_DATE`; numeração usa explicitamente `America/Sao_Paulo` | Testar fuso/virada e não ocultar pedidos pendentes de outra data |
| RISCO-06 | Contrato | Snapshot da entrega retorna `pedido_id`; eventos usam os dados montados na criação | Comparar payloads e normalizar IDs/campos; testar criação ao vivo versus recarga |
| RISCO-07 | Ciclo de conexão | `updateConnection` desconecta mas não descarta explicitamente o socket antigo antes de criar outro | Testar listeners duplicados, troca de IP e reconexões repetidas |
| MIG-01 | Dependência incompatível com destino | `printer.py` importa Win32; `app.py` instancia impressora Windows | Criar adaptador compatível com hardware real no Android |

Arquivos de referência: `app.py`, `schema.sql`, `printer.py`, `pastelaria_app/lib/providers/pedidos_provider.dart`, `pastelaria_app/lib/screens/fila_entrega_screen.dart` e `pastelaria_app/lib/screens/pastel_queue_screen.dart`.

Não atribuir BUG-01 a um mecanismo de entrega exclusiva no servidor sem evidência: a inspeção mostra emissões gerais de Socket.IO. A remoção dupla é uma hipótese concreta, mas pode haver mais de uma falha.

## 2. Etapas e entregáveis

| Etapa | Dependências | Entregável | Validação para concluir |
|---|---|---|---|
| E0 — Regras e inventário | Respostas sobre hardware e operação | Pendências essenciais respondidas, catálogo/regras inventariados e reprodução de BUG-01 | Regras consistentes; evidências sanitizadas e cenário reproduzível |
| E1 — Viabilidade no Android | Hardware, impressora e principal definidos | App experimental com servidor local, SQLite, dois clientes e impressão | Teste nos equipamentos reais, incluindo segundo plano/reinício e Starlink desligada |
| E2 — Núcleo e protocolo | E1; estados e senhas definidos | Domínio, migrações, API, idempotência, revisão e reconciliação | Transações, concorrência, limite de senha, contratos e recuperação sem perda |
| E3 — Pedido e entrega | E2 | Clientes usando contrato único; correção da classe de defeitos de BUG-01 | Dois clientes na entrega com HTTP/eventos em ordens diferentes, reconexão e recarga |
| E4 — Nova produção | Interação por quantidade validada; E2 | Protótipo e tela por cartões com produção e entrega parciais | Saldos corretos, concorrência protegida e exemplo de 5 unidades validado |
| E5 — Impressão confiável | Interface e layout confirmados; E2 | Fila persistente, diagnóstico e segunda via | Testes reais: sem papel, desligamento, reinício, reimpressão e resultado incerto |
| E6 — Backup e recuperação | Provedor/conta/chave definidos; E2 | Snapshot, criptografia, upload, retenção e restauração | Sem internet, tentativa posterior, corrupção detectada e restauração em outro tablet |
| E7 — Migração e operação | E3–E6 | Importador se necessário, APKs, instalação e roteiro de recuperação | Ensaio de turno, conciliação de dados e checklist de implantação aprovado pelo responsável |

Cada tarefa futura deve indicar arquivos previstos, dependências, critérios de aceite e evidências. Agentes podem trabalhar em frentes independentes se solicitado, mas devem acordar contratos e evitar alterações concorrentes no mesmo arquivo.

## 3. Regressão obrigatória do bug da entrega

Usar clientes A e B independentes na entrega, além do cliente que cria pedidos. Pode-se trocar o papel do tablet da cozinha durante o ensaio; repetir também com clientes automatizados.

1. Criar vários pedidos de composição diferente. Comparar IDs do banco, snapshot da API e cartões de A/B.
2. Entregar o primeiro, um intermediário e o último pedido. Somente o ID escolhido deve sair das duas filas.
3. Forçar evento chegar antes da resposta HTTP, depois dela e repetido.
4. Entregar simultaneamente o mesmo pedido em A e B; depois entregar pedidos diferentes ao mesmo tempo.
5. Enquanto um pedido é entregue, criar outro e recarregar uma das filas.
6. Desconectar B, criar/alterar/cancelar/entregar pedidos em A e reconectar B.
7. Reabrir a tela e retomar o aplicativo após segundo plano.
8. Se houver falha, registrar comando, pedido, revisão e ordem de mensagens; não depender somente de vídeo.

Aceite: filas convergem para os mesmos IDs e estados do servidor; nenhum pedido indevido desaparece ou duplica; estado se recupera automaticamente. Registrar resultados reais e limites do teste.

## 4. Matriz mínima do produto

| Cenário | Resultado esperado |
|---|---|
| Somente pastel; somente bebida; somente salgado; pedido misto | Fluxos e senha conforme regras confirmadas; totais corretos |
| Vários sabores e observações; quantidades maiores que 1 | Nenhuma perda de personalização; preparo conforme granularidade escolhida |
| 5 pastéis, 2 produzidos e 1 entregue | 3 a produzir, 1 pronto disponível, 1 entregue; pedido continua ativo em todos os clientes |
| Dois clientes entregam a última unidade simultaneamente | Somente uma entrega efetiva; nenhum saldo negativo ou duplicação |
| Reenvio de comando de produção/entrega parcial | Contador incrementa uma única vez; histórico e clientes convergem |
| Reenvio após timeout | Um pedido, uma senha e impressão automática sem duplicação lógica |
| Alteração ou cancelamento durante preparo | Política explícita e atualização de cozinha/entrega |
| Desligar somente Starlink | Pedir, produzir e entregar continuam na LAN; upload fica pendente |
| Perder Wi-Fi ou desligar principal | Erro claro; sem falso sucesso; recuperação após retorno |
| Reiniciar principal com pedidos pendentes | Estado persistido; clientes reconciliam sem recriação de pedidos |
| Virada do dia e fim da faixa de senha | Pedidos ativos continuam visíveis; sem colisão de identidade |
| Senhas 98, 99 e próximo pedido no mesmo dia | Próxima senha 1; IDs diferentes e histórico preservado, inclusive repetição da senha 1 na mesma data |
| Tablet desligado à meia-noite e ligado no dia seguinte | Primeiro pedido elegível recebe senha 1 em `America/Sao_Paulo` |
| Reinício do servidor durante o mesmo dia | Próxima senha continua a sequência persistida; não reinicia indevidamente em 1 |
| Impressora indisponível | Pedido preservado; fila/erro visíveis; reimpressão controlada |
| TP-650 por cabo no OpenWrt, computador desligado | Impressão do tablet principal com acentos/corte conforme layout homologado |
| Restaurar backup em outro tablet | Totais e pedidos conferidos; um principal ativo; sem impressão histórica automática |
| Backup atrasado, credencial revogada ou armazenamento cheio | Falha visível; nova tentativa apropriada; sem sucesso remoto fictício |
| Cota gratuita próxima do limite | Aviso e retenção conforme configuração, sem compra automática e sem perda da última cópia válida |
| Samsung antigo em turno prolongado | Medições de memória/desempenho e disponibilidade do servidor; compatibilidade Android comprovada |
| Instalar APK com migração de schema | Dados preservados e recuperação ensaiada |

## 5. O que significa corrigir os bugs

O objetivo solicitado é corrigir os bugs do sistema. A entrega deve demonstrar inventário atualizado, correções prioritárias, regressões automatizadas pertinentes e ensaio real dos três papéis. Novos defeitos encontrados entram no inventário com severidade e reprodução. Não prometer ausência absoluta de bugs com base apenas em análise estática ou testes unitários.

Problemas de perda/duplicação de pedidos, valores incorretos, dados corrompidos, indisponibilidade do servidor no turno e filas divergentes impedem implantação até resolução e validação.
