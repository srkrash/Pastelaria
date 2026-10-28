# Atualização 2.4.1 — 28/10/2026

Inclui a [correção da TP-650](CORRECAO-IMPRESSAO-TP650.md), margem inferior extra,
[PIX no cupom](PIX-NO-CUPOM.md) e limpeza explícita de pedidos de teste do dia.

## Limpeza autorizada de testes

O usuário informou que todos os pedidos de 28/10/2026 foram testes e autorizou
sua remoção, sem cópia de segurança. O tablet conectado por ADB foi identificado
como servidor SM-T815Y, com ABI `armeabi-v7a` e aplicativo 2.4.0 (204).

O Android bloqueou `run-as`; não foi copiado nem alterado diretamente o banco
privado. A ação foi implementada no app, em Configurações → Acompanhamento e
recuperação → Limpar pedidos de teste de hoje, disponível no principal.

A confirmação mostra data e quantidade. O executor de impressão é pausado até
terminar qualquer envio ativo. A transação valida data em America/Sao_Paulo,
revisão e quantidade; remove somente os pedidos dessa data e os trabalhos de
impressão correspondentes. Conflito de revisão exige nova conferência. Não há
backup disparado por essa ação; ela é destrutiva e serve exclusivamente para um
dia em que TODOS os pedidos são testes.

O catálogo, preços, pedidos anteriores, sequência de senha e IDs permanecem.
Comandos associados aos testes ficam como marcadores de remoção: o reenvio do
mesmo comando devolve 410, sem recriar pedido nem devolver confirmação obsoleta.
O cliente remove a confirmação pendente ao receber esse resultado definitivo.
A própria limpeza é idempotente pelo ID de comando. A API rejeita essa ação se
a conexão não for local ao principal; continua exigindo a chave de conexão.
Os clientes conectados recebem a notificação normal de atualização das filas.

## Validação

26 testes de servidor, manutenção, PIX e impressão aprovados. As três novas
regressões verificam exclusão limitada ao dia, preservação de catálogo/histórico,
reenvio idempotente, IDs/sequência sem reinício, rejeição de confirmação/data/
revisão/contagem incorretas e bloqueio de limpeza durante envio. Análise estática
sem apontamentos. Não houve migração de schema.

O APK de atualização deve ser instalado por `adb install -r`, sem desinstalar o
app ou apagar seus dados. Gerar para `android-arm` após conferir a ABI real;
versão 2.4.1, código 205, Android mínimo 24.
