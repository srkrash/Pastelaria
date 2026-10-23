# Desenvolvimento do sistema da Pastelaria Gaúcha

Documentação inicial em 23/10/2026, preparada para orientar o desenvolvimento por agentes.

## Ordem de leitura

1. [Requisitos e decisões pendentes](REQUISITOS.md): operação do trailer, fluxos, telas e critérios de aceite.
2. [Arquitetura proposta](ARQUITETURA.md): tablet servidor, rede local, sincronização, impressão, backup e migração.
3. [Plano de desenvolvimento](PLANO-DE-DESENVOLVIMENTO.md): tarefas, evidências do legado e validação.
4. [Orientações para agentes](../AGENTS.md): regras aplicáveis às alterações no repositório.
5. [Implementação da versão 2](IMPLEMENTACAO-V2.md): ambiente, funcionalidades implementadas, instalação e limitações reais.

## Como interpretar

- **Confirmado:** informado ou escolhido pelo usuário.
- **Proposta:** recomendação inicial que pode ser ajustada, sem equivaler a uma decisão do usuário.
- **Pendente:** informação necessária antes da implementação dependente.
- **Legado:** comportamento ou implementação observados no código; não necessariamente corretos.

A documentação inicial descreveu o planejamento. O desenvolvimento da versão 2 começou em 23/10/2026, a pedido do usuário; consulte o estado atual em `IMPLEMENTACAO-V2.md`. A versão ainda requer homologação nos dispositivos e na impressora reais.

## Decisões confirmadas

- Uso em trailer para feira, vendendo pastéis de diferentes sabores, salgados específicos e bebidas.
- Três tablets: um para pedidos, um para cozinha e um para entrega.
- Um dos tablets deve hospedar o servidor, conforme a alternativa escolhida na conversa.
- Rede local por roteador OpenWrt; acesso à internet pela Starlink.
- Modelo informado: Samsung SM-T815Y, identificado pela Samsung como Galaxy Tab S2; versão instalada do Android e correspondência dos três aparelhos ainda a verificar.
- Impressora térmica Tanca TP-650, atualmente em USB no computador; o novo sistema deve usar Ethernet pelo roteador, sem computador na operação.
- Sistema de senha numérica de 1 a 99, chamada por voz e ocasionalmente pelo painel de LED; automação do painel não foi solicitada.
- Após a senha 99, a próxima é 1. À meia-noite, reinicia em 1 para o novo dia, em `America/Sao_Paulo`. Não há operação após 23h59; o responsável informa que não há cenário de 99 senhas simultaneamente ativas.
- Produção e entrega devem permitir conclusão parcial por quantidade.
- Substituir a experiência atual da produção por uma tela semelhante à entrega, orientada à produção.
- Investigar e corrigir bugs; prioridade para pedidos ausentes na entrega quando dois tablets usam essa tela.

O backup diário em nuvem deve priorizar uma alternativa gratuita. Google Drive é o candidato proposto; conta, cota disponível e política de retenção permanecem a confirmar.

## Atualização contínua

Registre respostas do usuário em `REQUISITOS.md`, retirando as pendências correspondentes. Registre decisões técnicas em `ARQUITETURA.md`, com motivo e implicações. Mantenha os itens do plano com estado real e evidência de conclusão.
