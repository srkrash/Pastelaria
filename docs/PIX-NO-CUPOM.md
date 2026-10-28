# PIX no cupom — 28/10/2026

## Comportamento confirmado

O usuário solicitou QR Code PIX no pedido, com o total a pagar, e forneceu os
dados do recebedor para configuração local. O QR é impresso após o total e antes
do corte, preservando uma linha adicional de margem inferior. A geração é local,
sem API bancária ou internet. Não muda estados de pagamento, preparo ou entrega;
o recebimento continua dependendo da conferência no banco.

## Configuração no principal

Em **Configurações → PIX no cupom**, ativar a impressão e preencher chave celular
com DDD, nome do beneficiário (até 25 caracteres) e cidade sem estado (até 15).
Telefone é normalizado para `+55` e DDD; nome/cidade ficam em maiúsculas sem
acentos no BR Code. Dados inválidos impedem salvar a configuração, com mensagem.

A configuração fica nas preferências locais do aparelho, junto à configuração
da impressora. Clientes usam o executor do principal. Os dados reais do usuário
não são incorporados ao código, fixtures ou documentação. Troca de aparelho
requer configurar novamente os dados PIX; a restauração do banco não os restaura.

Sem PIX ativado, o cupom mantém o fluxo anterior. Com PIX ativado e total positivo,
o valor vem de `total_centavos`, usando divisão inteira para a representação
decimal; pedidos de total zero não geram QR de cobrança. A referência `P<ID>` usa
o ID interno estável, não a senha 1–99. Segunda via conserva valor/referência,
sem criar outra cobrança nem inferir pagamento realizado. A configuração é a
vigente no momento da impressão; não há snapshot histórico da chave recebedora.

## Formato e impressora

`pix_payment.dart` implementa o BR Code estático: GUI `br.gov.bcb.pix`, chave,
moeda BRL, valor, recebedor, cidade, referência e CRC-16/CCITT-FALSE, incluindo
`6304` no cálculo. Referência: [Manual de Padrões para Iniciação do Pix, Banco Central](https://www.bcb.gov.br/content/estabilidadefinanceira/pix/Regulamento_Pix/II_ManualdePadroesparaIniciacaodoPix.pdf).

O QR usa `GS ( k`, documentado nas páginas 76–78 do Manual de Comandos TP-650:
modelo 2, módulo de 6 pontos, correção M, armazenamento com comprimento em dois
bytes e impressão nativa. Há espaço em branco acima/abaixo e centralização.
O corte permanece `GS V 66 0`, conforme a [correção de impressão](CORRECAO-IMPRESSAO-TP650.md).

## Teste no computador, sem APK

Criar um JSON **local fora do versionamento**, com campos `phone`, `name`, `city`.
Executar com o Dart instalado:

```powershell
dart --packages=pastelaria_app/.dart_tool/package_config.json scripts/test_printer.dart 10.0.0.20 --pix-file=tools/pix-local.json --send
```

O script usa o encoder do app, imprime teste de R$ 0,10 e não cria pedido no banco.
Sem `--send`, apenas prepara e informa tamanho/valor, sem imprimir ou expor a
chave em logs. `tools/` está no `.gitignore`. Nunca adicionar o JSON a commits.

Foi enviado um único teste de 867 bytes à TP-650 em 28/10/2026, sem erro de
transporte. O usuário confirmou a saída do cupom e a leitura correta da
beneficiária e de R$ 0,10 pelo aplicativo do banco. Isso valida o ensaio físico
do QR e da impressão corrigida, sem afirmar que houve pagamento realizado.

## Layout solicitado em 28/10/2026

Primeira linha com `PASTELARIA GAUCHA` centralizada, seguida de divisor de 48
traços. `PEDIDO: <senha>` em negrito com largura/altura duplicadas; restaurar
fonte normal antes de `Data: dd/MM/yyyy HH:mm`, no fuso America/Sao_Paulo.
Novo divisor antes dos itens. Total preservado em reais com vírgula decimal,
outro divisor e bloco centralizado `Pagamento com PIX`, `Chave: <celular com
DDD, sem +55>` e `Favorecido: <nome configurado>`, seguido do QR centralizado.
O payload PIX continua usando telefone com `+55`; só a apresentação da chave
é nacional. Dados do recebedor continuam configuráveis, sem valores pessoais
fixos no código. Observação geral após o QR, quando preenchida; observações dos
itens continuam junto aos itens. Final centralizado: `Obrigado pela compra,
volte sempre!`, com margem inferior e avanço/corte. Sem PIX, mantém observação
e agradecimento. Sem pastel, imprime `PEDIDO: BALCAO`. Segunda via mantém marca.

O encoder usa a base de fusos já inicializada pelo app. O script de PC inicializa
a mesma base, usando o package_config do aplicativo conforme comando acima.
O ensaio inicial desse ajuste de layout foi feito pelo computador, sem APK.

Após o usuário confirmar o layout no teste físico, foi solicitada a distribuição
em APK 2.4.2 (206), mantendo Android mínimo 24 e instalação por atualização,
sem desinstalar nem limpar dados. Atualizar um tablet por vez, identificando
explicitamente o dispositivo conectado por ADB.

Primeira instalação dessa distribuição concluída em 28/10/2026 no SM-T815Y
conectado (ADB com final `62bf`): `adb install -r` retornou sucesso e o Android
confirmou versão 2.4.2, código 206. Dados/configurações preservados; nenhum teste
funcional ou limpeza de pedidos foi executado nesta instalação.

Regressões do layout: 10 testes de impressão/PIX aprovados, análise estática sem
apontamentos. A primeira tentativa de amostra não conectou à TP-650; após o
usuário ligar a impressora, uma amostra de 1.011 bytes foi enviada com sucesso
a `10.0.0.20:9100`. O usuário confirmou o novo layout como aprovado.

## Validação automatizada

Seis testes PIX cobrem CRC com vetor conhecido e exemplo oficial do Banco
Central, campos EMV/valor/referência, normalização de telefone e acentos,
rejeição de dados inválidos, comprimento de comandos QR acima de 255 bytes,
inclusão condicional no cupom, margem e persistência/compatibilidade das
preferências. Os três testes de impressão também passaram após a integração.

Suíte completa após a integração: 66 testes aprovados e 3 ignorados, por exigirem
dados privados locais de histórico, migração e backup não fornecidos à execução.
