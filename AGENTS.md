# Orientações para os agentes

## Antes de desenvolver

Leia `docs/README.md`, `docs/REQUISITOS.md`, `docs/ARQUITETURA.md` e `docs/PLANO-DE-DESENVOLVIMENTO.md`.
As decisões confirmadas pelo usuário prevalecem sobre propostas e sobre o comportamento legado.
Consulte a seção de pendências antes de implementar regras ainda não definidas. Avance nas tarefas independentes e peça apenas a informação necessária para a tarefa bloqueada.

## Contexto e limites

- Sistema de um trailer de feira: pedido, produção de pastéis e entrega em três tablets.
- Arquitetura escolhida: um tablet principal hospeda o servidor local. A internet não é necessária para atender, produzir ou entregar.
- Flutter é a base do aplicativo. Dart embarcado e SQLite são a proposta técnica para o servidor; validar hardware e ciclo de vida Android antes da migração completa.
- Não introduza servidor remoto obrigatório, dependência de Windows ou uma nova stack sem justificar e registrar a decisão.
- O repositório atual usa Flutter, Flask/Socket.IO, PostgreSQL e impressão Win32; essa é a implementação legada, não a arquitetura final.
- Nunca exponha segredos de `.env`, credenciais de nuvem, cópias reais do banco ou dados de clientes em código, logs, fixtures ou commits.
- Não alterar o roteador, publicar serviços na internet, conectar contas de nuvem ou substituir dados de produção como parte de uma tarefa de código sem autorização específica.

## Invariantes de implementação

- O servidor principal é a autoridade das operações. Confirmar sucesso apenas depois da persistência.
- Toda alteração usa IDs estáveis; índices de listas e senha de chamada não identificam entidades.
- Comandos sujeitos a reenvio devem ser idempotentes. Tratar concorrência e eventos repetidos ou fora de ordem.
- Recarregar e reconciliar as filas ao conectar, reconectar e retomar o aplicativo. Uma conexão WebSocket não substitui a leitura do estado persistido.
- A camada de domínio não depende de `GlobalKey`, animações ou widgets.
- Impressão e upload não podem desfazer ou impedir um pedido já salvo.
- Dinheiro em centavos inteiros; conservar nomes e preços históricos dos itens vendidos.
- Mudanças de schema têm versão e migração; migrações destrutivas exigem cópia verificável dos dados.
- Pronto, entregue, cancelado e pago são conceitos diferentes; não converter um no outro implicitamente.
- Produção e entrega parciais são requisitos confirmados: controlar quantidades por item e não concluir o restante implicitamente.
- Tablets Samsung antigos exigem validação de Android mínimo, memória e desempenho; não elevar requisitos de versão sem verificar o hardware.
- Modelo informado SM-T815Y (Galaxy Tab S2 segundo a Samsung); conferir Android instalado e se os três aparelhos são iguais.
- Senhas seguem 1–99, depois 1, e reset diário à meia-noite em `America/Sao_Paulo`, inclusive se o servidor estiver desligado nesse horário (verificar a data no próximo pedido). Não introduzir seleção de senha livre ou limite de 99 pedidos por dia. A operação termina até 23h59.
- A impressão final deve funcionar por Ethernet sem computador; USB/Win32 representa apenas o legado.

## Conclusão de tarefas

- Trabalhe em incrementos revisáveis; não reescreva tudo em uma única etapa.
- Para bugs, registre reprodução, evidência, correção e teste de regressão. Não anuncie uma hipótese como causa comprovada.
- Teste sincronização com clientes independentes; duas telas dentro do mesmo processo não substituem dois clientes.
- Execute análise e testes pertinentes ao código alterado. Para tarefas somente documentais, confira links, consistência e diff; não é necessário executar a aplicação.
- Atualize a documentação afetada e relate os testes executados, resultados e limitações reais.
- Não declare “todos os bugs corrigidos” sem delimitar o inventário e a matriz de validação.
