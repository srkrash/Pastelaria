# Versão 2.3.0+203 — edição ocasional de preços

Solicitada em 28/10/2026. Acesso discreto pelo menu de três pontos no cabeçalho:
**Mais opções → Preços dos produtos**. Não acrescenta botões ao atendimento ou à
cozinha. Busca, filtros por categoria e confirmação mostrando valores anteriores
e novos antes de salvar. Aceita vírgula ou ponto decimal, até duas casas, de
R$ 0,00 a R$ 9.999,99; valores inválidos não são arredondados silenciosamente.

Na versão 2.4.4, o valor cadastrado de adicional também sugere o preço inicial
do [recheio adicional escrito na montagem](RECHEIO-ADICIONAL.md). Esse preço pode
ser ajustado pelo atendente para o item, sem mudar o cadastro geral.

Pode alterar preços de bebidas e salgados, pastel personalizado com até dois
recheios pagos, adicional a partir do terceiro recheio pago, Pizza e Misto.
Cebola, cebolinha e orégano continuam gratuitos; não houve mudança na composição
ou no número de recheios incluídos. Ingredientes comuns não têm preço de venda
individual, pois o pastel continua calculado pela regra de quantidade de recheios.
Preços iniciais permanecem os já usados: base R$ 12, adicional R$ 3, Pizza R$ 15,
Misto R$ 25, bebidas e salgados conforme o catálogo existente.

## Persistência e concorrência

O servidor principal é a autoridade. `GET /catalogo/precos` retorna catálogo,
regras e revisão. A alteração usa `POST /commands`, ação `update_prices`, com ID
de comando e revisão esperada do catálogo. Produtos são identificados pelo ID.
Uma transação grava o lote completo, as regras e o registro de comando; erro
reverte todo o lote. Uma segunda edição da mesma revisão recebe conflito 409,
mantendo a edição local para conferência/recarregamento. Reenvio do mesmo comando
retorna o resultado original. Há auditoria dos preços anteriores e novos e das
regras anteriores no resultado persistido em `commands`.

As regras ficam em `meta.pricing_rules_v1` e a revisão em `meta.catalog_revision`,
sem alteração estrutural do SQLite (schema 1). Backups e restauração existentes
incluem esses registros. Nome, composição, preço histórico e totais dos pedidos
já confirmados permanecem intactos. A consulta do BI continua usando preços dos
itens vendidos, sem recalcular o histórico com o catálogo atual.

## Comandas abertas e atualização dos tablets

A montagem carrega o catálogo atual para calcular o total e os preços dos pastéis.
Antes de confirmar, consulta novamente o servidor. Se o valor de algum item mudou,
atualiza a comanda e pede conferência e nova confirmação. Cada item enviado informa
o preço esperado em centavos; o servidor recalcula e rejeita uma divergência com
422 antes de gerar pedido, senha ou impressão. Essa recusa definitiva limpa a
confirmação pendente, permitindo corrigir a comanda. Uma confirmação já persistida
continua idempotente mesmo se o catálogo mudar antes de uma recuperação da resposta.

**Atualizar primeiro o principal e depois todos os tablets de pedidos para 2.3.0.**
Clientes 2.3.0 precisam do endpoint de catálogo novo. Clientes antigos continuam
com o protocolo de filas, mas, depois da primeira alteração de preços, não podem
criar pedidos sem informar o valor conferido; o servidor bloqueia a cobrança
potencialmente divergente. Atualizar todos antes de editar preços reais.

O acesso usa a chave compartilhada já existente no aplicativo. O menu discreto
não constitui um perfil de administrador ou PIN de autorização adicional.

## Validação

Regressão completa anterior: 51 testes aprovados, incluindo a nova edição e a
conciliação do BI; mais um teste HTTP com dois clientes e notificação WebSocket
aprovado separadamente (52 casos únicos). Cobertura: moeda exata, limites e dados
inválidos, lote com rollback, idempotência, histórico preservado, revisão antiga,
preço desatualizado na comanda, limpeza da confirmação pendente, persistência das
regras em backup/restauração e telas em retrato/paisagem/360 px com fonte ampliada.
Análise estática final sem apontamentos. Nenhum preço real
foi alterado para testar a instalação.

Antes da atualização no tablet, exportada cópia atual para
`private-migration/tablet-servidor/antes-precos.pastelbackup`, autenticada e restaurada
em SQLite em memória; o APK anterior 2.2.0 foi preservado na mesma pasta. Esses
arquivos, as chaves e os snapshots reais continuam fora do Git.

APK 2.3.0+203, Android mínimo 7.0/API 24, arquiteturas ARM 32/64 e x86_64,
assinatura de desenvolvimento v2 verificada. SHA-256:
`4097ED8F82DE1AE37FDC857A35B3016B96FFF5DA45B5F076928C61E805475C2E`.

## Instalação no servidor

Instalado no SM-T815Y principal por atualização (`adb install -r`) em 28/10/2026.
Aplicativo reaberto; servidor respondeu com o novo catálogo de 50 registros.
Snapshots de pedidos ativos e lista completa de produtos comparados antes/depois
e idênticos. Regras iniciais mantidas e revisão de catálogo zero: não houve edição
de preço real durante a validação. Registro sanitizado em
`private-migration/tablet-servidor/validacao-precos.json`. Os tablets de pedidos
restantes ainda precisam da atualização antes de alterar preços na operação.
