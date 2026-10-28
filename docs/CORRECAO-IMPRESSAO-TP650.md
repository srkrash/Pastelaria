# Corte incompleto na TP-650 — 28/10/2026

## Relato e limites da reprodução

Após configurar Ethernet com DHCP/reserva no OpenWrt, o usuário relatou que o
cupom terminou na descrição do primeiro pastel, cortando a linha ao meio.
Não houve reprodução física pelo agente nem captura do tráfego do tablet.
Não atribuir o relato definitivamente ao transporte TCP ou à guilhotina.

## Evidência e correção

O `PrinterWorker` da versão Dart enviava o texto completo seguido de três LFs e
`1D 56 00` (`GS V 0`). Não há altura fixa de página ou limite de itens nesse
caminho. O manual **Manual de Comandos TP-650.pdf**, incluído no pacote
`Driver_Utilitarios_TP-650.zip` disponibilizado pelo usuário, página impressa 42,
documenta somente `m=1/49` para corte parcial e `m=66` para avanço e corte.
Especifica que `n=0` avança até a posição de corte. O modo de corte total `m=0`
usado pelo app não está documentado para esse modelo.

O novo `receipt_encoder.dart` separa a montagem dos bytes do executor e usa
`1D 56 42 00` (`GS V 66 0`) após a quebra de linha final: avanço até a guilhotina
e corte parcial, conforme o modelo. A margem deixa de depender de três LFs.
Também impede que caracteres de controle em nomes, ingredientes e observações
sejam interpretados como comandos ESC/POS; não há evidência de que esses
caracteres estivessem presentes no pedido relatado. Mantém transliteração ASCII,
todos os itens, observações, total e identificação da segunda via.

A referência geral [ESC/POS GS V da Epson](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/gs_cv.html)
explica a diferença entre corte imediato e avanço até a posição de corte;
os modos disponíveis foram escolhidos pelo manual específico da Tanca.

O encerramento TCP foi investigado, mas permaneceu sem alteração: a recepção
local completa não reproduziu truncamento. `flush`/`close` e o estado `enviado`
continuam sem comprovar saída física do papel. Não houve reenvio de trabalhos
reais, alterações de banco em uso ou mudanças no roteador nesta correção.

## Regressão automatizada

`pastelaria_app/test/printer_test.dart` verifica:

- Pedido sintético de 100 itens, preservando último item, observação e total
  antes do único comando de avanço/corte documentado.
- Caracteres ESC, GS e NUL em todos os campos textuais não geram comandos;
  quebras de linha, transliteração e indicação de segunda via são preservadas.
- Executor real com SQLite em memória e receptor TCP independente em loopback:
  mais de 60 KB recebidos integralmente, uma conexão, um pedido preservado e
  trabalho marcado `enviado` somente após o envio.

Esse receptor valida o fluxo de bytes, não emula a mecânica/firmware da TP-650.

Resultados: `flutter test --no-pub test/printer_test.dart test/server_test.dart`
aprovou 17 testes (3 de impressão e 14 do servidor). `flutter analyze --no-pub`
terminou sem apontamentos. `git diff --check` não encontrou erros de whitespace.

## Validação física pendente

Não é necessário compilar ou instalar APK para testar a impressora pelo PC.
`scripts/test_printer.dart` importa o mesmo encoder do app e envia um cupom
sintético identificado como teste, sem banco, fila ou pedido real. Por padrão
somente mostra a prévia; `--send` habilita o envio explícito:

```powershell
dart --packages=pastelaria_app/.dart_tool/package_config.json scripts/test_printer.dart 10.0.0.20 --send
```

Em 28/10/2026, a porta TCP 9100 respondeu em `10.0.0.20`; a tabela de vizinhos
confirmou MAC `A8:01:57:4B:50:71`, igual ao selecionado pelo usuário na reserva.
Um cupom de teste com três itens, descrição longa e total final foi enviado pelo
PC: 621 bytes, encerrados por `GS V 66 0`, sem erro de transporte. O usuário
confirmou que saiu tudo certo e pediu uma linha extra de margem inferior.
Essa linha foi acrescentada ao encoder; o ensaio posterior de margem e PIX
está descrito em [PIX no cupom](PIX-NO-CUPOM.md).

Conferir o cupom enviado e imprimir também um pedido sintético curto e outro com vários pastéis, ingredientes e
observações longas. Conferir primeiro e último itens, total e linha final inteira
antes do corte parcial. Se houver corte novamente no primeiro item, registrar
foto do cupom, composição sintética, versão instalada e resultado do autoteste;
investigar firmware/transporte com essa evidência, sem reimpressão automática.

A correção no código não altera um APK já instalado. A atualização será
necessária para levar a mudança ao tablet, mas não para o teste pelo PC.
As tentativas de build encontraram falhas de intermediários Gradle e CMake
x86_64; a tentativa ARM/ARM64 foi interrompida a pedido do usuário para priorizar
o ensaio direto. Nenhum APK novo foi entregue nesta investigação.
