# Revisão das telas — versão 2.1.0

Revisão em 23/10/2026, voltada ao atendimento em trailer: pouco espaço, leitura rápida, operação por toque e tablets antigos. A análise usou o código das telas e renderizações Flutter com dados sintéticos; ainda não houve observação de uso na feira.

## Problemas identificados e melhorias aplicadas

| Área | Problema observado no código anterior | Implementação |
|---|---|---|
| Navegação | Scaffold principal e telas filhas tinham barras de título simultâneas; troca de papel escondida no menu | Um cabeçalho por tela; navegação lateral em paisagem e inferior em retrato; acesso direto às configurações e estado de conexão |
| Atendimento | Botões muito altos ocupavam a área central sem mostrar a operação atual | Ação principal para iniciar/retomar comanda, contadores das filas e última senha confirmada |
| Montagem | Categorias, observações e rodapés disputavam espaço com os itens; quantidade só podia ser alterada removendo/refazendo seleção | Comanda e painel lateral em telas largas, adaptação vertical, total e confirmação fixos; controles de quantidade por item; remoção com desfazer |
| Tipo de pedido | Consumo/viagem exigia um diálogo adicional na confirmação | Escolha visível na comanda, enviada no mesmo formato legado; padrão inicial No local; escolha preservada enquanto o rascunho está em memória |
| Pastéis | Seleção em colunas fixas, sem preço durante a montagem, sem bloqueio de recheio vazio e sem acesso ao orégano gratuito | Seleção visual com marca de confirmação, altura natural conforme fonte/texto, preço unitário/total, atalho Personalizado/Pizza/Misto e validação antes de adicionar |
| Bebidas e salgados | Lista longa sem busca, quantidade e subtotal pouco evidentes | Busca sem distinção de acentos, cartões com preço/quantidade e total da seleção; produtos selecionados continuam marcados ao mudar o filtro |
| Cozinha e entrega | Quantidades prontas acumuladas podiam ser confundidas com o saldo ainda disponível | Indicadores separados A produzir/Disponíveis/Entregues; senha, tipo e observação destacados; filtros visíveis e busca por senha; diálogo de parcialidade inclui identificação e recheios |
| Consulta diária | Filtro escondido em dropdown e pouca distinção entre senha de chamada e ID interno | Filtros por status, busca por senha/ID, pedidos recentes primeiro e detalhes dos saldos |
| Cancelamento/segunda via | A tela de detalhes permitia disparar operações diretamente | Confirmação explícita, descrição da consequência e bloqueio de ações durante o envio; regras do servidor preservadas |
| Configurações | Credenciais, impressora e recuperação apareciam em uma lista sem agrupamento claro | Seções por assunto, ação Salvar fixa, chave oculta com rótulos acessíveis e restauração em seção recolhida |
| Aparência | Cores, tamanhos, espaçamentos e botões variavam entre telas | Tema compartilhado com fundo claro, texto escuro, terracota para ações de pedido/preparo e verde para entrega; controles com área de toque mínima de 48 pixels lógicos |

## Comportamentos preservados

- Sem alteração de schema, API de comandos, regras de senhas, preços no servidor ou backup.
- O servidor continua validando preço, estado e quantidade. A prévia de preço da interface não substitui essa validação.
- Alterações na comanda atual não modificam pedidos já enviados.
- Filas continuam usando IDs e revisões, e a ordem de chegada é mantida.
- Filtros são locais e começam em Todos. Não reservam, consomem ou removem pedidos no servidor.
- O filtro e a busca podem ser limpos quando não há resultados; o texto da busca também é limpo para evitar discrepância entre campo e lista.
- Rascunho, observações e escolha No local/Viagem são mantidos em memória ao sair e voltar à montagem. Persistência após encerramento do processo continua pendente.
- Cancelamento depois de preparo/entrega continua bloqueado pelo servidor; não foi criada uma regra de estorno ou reabertura.

## Validação

`flutter analyze` concluído sem apontamentos. APK release 2.1.0 (código 201) gerado em `pastelaria_app/build/app/outputs/flutter-apk/app-release.apk`, 58.868.655 bytes; Android mínimo API 24, arquiteturas ARM de 32/64 bits e x86_64. SHA-256: `6B5DCE79765CDA2166E8D506014A1333287528E11225B5F59EB4B6CF3D6BB72A`.

25 testes aprovados: os 15 testes anteriores e 10 novos testes de interação/layout. Cenários adicionais incluem:

- Recheio vazio bloqueado e preço atualizado ao selecionar ingredientes/quantidades.
- Fonte em escala 1,3, retrato 600×960 e teclado ocupando 300 pixels lógicos.
- Busca por `agua` encontra `Água`, sem perder seleções fora do filtro.
- Ajuste de quantidade, desfazer remoção e preservação de observações.
- Envio de Consumo/Viagem e observações conforme a escolha na comanda.
- Somente um AppBar na navegação principal e troca entre os papéis.
- Busca/filtro das filas e retorno a Todos sem ocultação involuntária.
- Cancelamento não é enviado quando o operador volta na confirmação.

As prévias de montagem, ingredientes, bebidas e entrega são geradas por `test/ui_flow_test.dart` com `UI_PREVIEW=1`, em `tools/ui-previews/`. A geração opcional usa fontes locais do Windows; os testes normais não dependem desses arquivos. As imagens são renderizações sintéticas para revisão visual, não capturas dos tablets reais.

Comandos de validação na raiz:

```powershell
.\scripts\flutter.ps1 test --no-pub
.\scripts\flutter.ps1 analyze --no-pub
.\scripts\flutter.ps1 build apk --release --no-pub
```

## O que observar no teste com a equipe

Conferir legibilidade sob a luz da feira e distância real da cozinha; tempo para montar um pedido misto; erros na identificação do saldo parcial; uso em retrato/paisagem; tamanho da fonte configurado nos Samsung. Ajustes de densidade e organização por sabor/lote dependem desse retorno da operação e não foram assumidos como regra nesta revisão.
