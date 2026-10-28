# Recheio adicional escrito na montagem — 2.4.4 (208)

Requisito confirmado em 28/10/2026: botão para escrever o recheio adicional e
cobrar por pastel. O campo de valor começa com o preço do adicional do cadastro
(`PricingRules.extra`), informado pelo catálogo carregado na comanda, e permite
ajuste pelo atendente. Exemplo: base R$ 12,00 + adicional R$ 3,00 = R$ 15,00 por
pastel; duas unidades custam R$ 30,00.

## Montagem e preços

Em Escolher recheios → Resumo do recheio, “Recheio adicional” abre nome e valor
por pastel. É possível adicionar mais de um ou remover um antes de concluir a
montagem. O resumo, o valor unitário e o total acompanham os adicionais e a
quantidade. Não basta escrever uma observação para gerar cobrança.

Adicionais livres ficam separados dos ingredientes do catálogo e não entram na
contagem dos dois recheios pagos incluídos. A regra de preço do terceiro recheio
comum continua funcionando. Pizza e Misto mantêm o preço especial e também podem
receber o adicional livre. Continua sendo necessário escolher um recheio base.

Cada adicional tem nome de 1 a 80 caracteres, sem comandos de controle, e valor
de R$ 0,00 a R$ 9.999,99, em centavos inteiros. Aceita vírgula ou ponto e até duas
casas decimais. Zero é permitido, como no cadastro existente. O formulário não
arredonda entradas inválidas silenciosamente.

## Autoridade e histórico

O payload do item usa `adicionais: [{nome, preco_centavos}]`, com preço por unidade.
O servidor valida nomes e valores, permite esses campos somente em pastéis,
recalcula a base pelo catálogo e soma os adicionais cotados. Exige preço unitário
conferido no cliente quando houver adicional; divergência retorna 422 antes de
salvar pedido, senha ou impressão. O valor livre é uma cotação manual autorizada
na montagem, não uma alteração do preço geral do catálogo.

O item vendido preserva adicionais, preço base, preço unitário total e quantidade.
Uma alteração posterior do cadastro não muda o adicional já cotado na comanda
nem o pedido histórico; a base continua sendo reconferida antes de confirmar.
Os adicionais fazem parte do fingerprint de idempotência. Não há tabela nova nem
migração estrutural: são campos adicionais no JSON do item, compatíveis com itens
antigos sem esse campo. O backup existente conserva o JSON integral.

## Produção, entrega e impressão

O recheio escrito aparece no destaque e na sequência da cozinha, no cartão da
entrega, nos detalhes do pedido e no cupom, identificado como adicional. Comanda,
entrega, detalhes e cupom mostram também o valor por pastel. Itens continuam
separados por ID mesmo quando têm os mesmos recheios base. Preparo/entrega parcial
e “Entregar tudo” preservam os adicionais. O PIX usa o total já acrescido; não
há alteração no gerador ou confirmação automática de pagamento. O BI conserva
o valor histórico e diferencia combinações com adicionais pelo nome.

## Validação e implantação

Testes sintéticos cobrem cobrança por quantidade, valor padrão do cadastro,
alteração e remoção na montagem, validação monetária, dados inválidos, proteção do
total, Pizza, vários adicionais, idempotência, histórico após mudança de preço,
restauração em memória, BI, cupom e payload da comanda. Widgets exercitam retrato
e paisagem com fonte ampliada. Dois clientes HTTP independentes confirmam a
persistência/transmissão dos campos, junto à regressão de entrega concorrente.

Resultado: suíte completa com 85 testes aprovados e 3 ignorados por exigirem
dados privados locais de histórico, migração e backup. Análise estática sem
apontamentos; diff sem erros de whitespace. Os ensaios usaram apenas dados
sintéticos e não criaram pedidos ou alteraram preços nos tablets.

Atualizar primeiro o servidor e depois todos os clientes: versões antigas não
conhecem os campos de adicionais e podem omiti-los na produção/entrega. Preservar
dados com `adb install -r`, Android mínimo 24 e ABI ARM 32 dos tablets confirmados.
Não usar pedidos em operação para testar cobranças ou entregas.

Instalação concluída em 28/10/2026 nos três SM-T815Y pelo ADB sobre Wi-Fi:
servidor 10.0.0.11 primeiro, depois 10.0.0.12 e 10.0.0.200. Todas as instalações
retornaram sucesso, Android confirmou 2.4.4 (208), e os apps foram reabertos.
Dados/configurações preservados. Porta 5000 do servidor acessível após a troca.
Não foram feitos pedidos, cobranças ou entregas nos tablets para testar a função.
