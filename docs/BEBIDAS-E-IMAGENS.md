# Versão 2.4.0+204 — bebidas por categoria e imagens offline

Solicitado em 28/10/2026. A seleção de bebidas abre num painel de categorias,
em vez de uma grade com todo o catálogo. Categorias disponíveis apenas quando
contêm produtos: Refrigerantes em lata, Cervejas, Refrigerantes 600 ml, 1 litro,
2 litros, pequenos, Águas, Sucos, Energéticos e Outras bebidas.

Classificação visual por nome/marca/volume, sem alterar o banco. Cervejas são
separadas antes de detectar “lata”; Guaraná Antarctica não vira cerveja. Bebidas
desconhecidas continuam acessíveis em Outras bebidas. A busca ignora acentos e
hífens e pesquisa em todas as bebidas. Atalhos permitem voltar às categorias,
trocar de grupo e ver somente os produtos selecionados. Quantidades e total
atravessam filtros/categorias; a confirmação retorna uma única linha por ID.

Os cartões usam mais colunas no tablet (largura mínima aproximada de 220 px),
foto, nome, preço atual e controle de quantidade. Layout com uma coluna quando
necessário em tela pequena; rodapé se adapta para não apertar os controles.
Não houve mudança nas regras de preço, nos IDs ou no histórico dos pedidos.

## Biblioteca de fotos

Foram pesquisadas `C:\Sistema Pastelaria` e `C:\Sistema Pastelaria v1`, incluindo
arquivos ignorados, assets de build e APKs disponíveis, além das branches
baixadas. Nenhuma biblioteca de fotos de bebidas foi encontrada nesses locais.

Incluídas 21 fotos em `pastelaria_app/assets/bebidas/`, aproximadamente 2,3 MB.
Fontes: catálogos públicos do [Bretas](https://www.bretas.com.br),
[loja oficial Heineken](https://express.heineken.com.br/collections/cervejas) e
[Guaraná Mineiro](https://www.guaranamineiro.ind.br/guarana-mineiro).
Origem individual, URL da imagem, produto de referência e SHA-256 registrados
em `assets/bebidas/sources.json`.

O responsável confirmou que Mineirinho 200 ml e 250 ml são Guaraná Mineiro;
ambos têm foto correspondente, incluindo a garrafa de vidro de 200 ml do fabricante.
Os demais produtos de referência são Coca-Cola normal/zero, Fanta Laranja, Sprite,
Guaraná Mineiro, Amstel, Skol, Brahma, Antarctica, Heineken e Extra Power.
Os volumes e nomes do catálogo continuam identificando o item vendido; a foto
serve de referência visual e pode divergir de mudanças de rótulo/embalagem.

Águas e sucos naturais sem marca/sabor especificado usam ícones, evitando atribuir
uma embalagem ou sabor não informado. Novos produtos não reconhecidos e falhas
de leitura da foto também usam ícone. Fotos próprias desses itens podem substituir
essa representação em uma atualização da biblioteca.

As fotos são assets do APK, não URLs consultadas durante o atendimento. A única
consulta de rede é a de produtos/preços ao servidor local, como antes. Imagens
são decodificadas com largura limitada para reduzir memória nos tablets antigos.
Há ícone durante o carregamento e em falha, evitando um cartão sem referência.

## Validação

Suíte completa com 62 testes aprovada; o gerador opcional da exportação original
de migração foi ignorado. Sete testes específicos de bebidas aprovados novamente
após a revisão visual. Verificação de todas as fotos no bundle do Flutter e dos
hashes, distinção normal/zero, cervejas/refrigerantes, embalagens pequenas,
categoria de produto novo, catálogo vazio e seleção por ID sem duplicação.

Layout verificado em 768×1024, 1024×768 e 360×800, fonte ampliada e teclado aberto.
Prévia com fontes reais e fotos efetivamente decodificadas; os dados dessas
prévias são sintéticos. A biblioteca não acrescenta dependências de imagem ou
modificações ao schema SQLite.

## Build e instalação

A primeira compilação falhou com intermediários ausentes em `minifyReleaseWithR8`
e no modelo de lint do Gradle. Foi encerrado o daemon Gradle que mantinha arquivos
abertos, limpos apenas os arquivos gerados e regeneradas as dependências. Nova
compilação concluída com sucesso, sem alterações adicionais no código do produto.

APK 2.4.0+204, 59.140.990 bytes, minSdk 24, ARM 32/64 bits e x86_64. Assinatura v2
verificada e hash de cada uma das 21 fotos conferido diretamente dentro do APK.
SHA-256: `7129F0AB2970801E392305B1DC5378104D7FA34FB3A10F2185E5653E168E1230`.
Cópia de distribuição em `tools/releases/pastelaria-2.4.0.apk`.

Antes da instalação, backup atual exportado no tablet e copiado para
`private-migration/tablet-servidor/antes-bebidas.pastelbackup`. Autenticação e
restauração desse arquivo em SQLite em memória aprovadas. APK 2.3.0 anterior
preservado. Atualização instalada no tablet servidor SM-T815Y, Android 7.0,
sem desinstalar ou substituir o banco. Confirmados versão 2.4.0+204, quatro pedidos
ativos preservados e catálogo completo de 50 produtos/regras de preço idêntico ao
estado anterior. Registro sanitizado em
`private-migration/tablet-servidor/validacao-bebidas.json`.
