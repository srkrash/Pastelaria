# Preparação do APK e dos dados — 28/10/2026

O destino é o SQLite privado do tablet principal, schema 1, aberto pelo servidor
Dart incluído no APK 2.1.0+201. O PostgreSQL do computador continua preservado.

APK gerado em `pastelaria_app/build/app/outputs/flutter-apk/app-release.apk`:
53.692.805 bytes, Android mínimo API 24 (7.0), target API 36, arquiteturas
`armeabi-v7a`, `arm64-v8a` e `x86_64`. Assinatura de desenvolvimento verificada
com `apksigner` (esquema v2). SHA-256:
`7E2FFA6A4584E705874203D7A7D8C306B6EA14A414B63349F933DBAEF1846BFD`.
Compilado neste PC com Flutter 3.38.3, Dart 3.10.1 e JDK 21 do Android Studio.
Análise estática aprovada. A primeira compilação instalou o Build-Tools 35 usando
a licença já reconhecida no SDK; não alterou o código do aplicativo.

## Política autorizada

Importar todo o catálogo e todo o histórico. Encerrar os pedidos antigos na cópia
convertida para começar com as filas vazias. Manter os cancelados como cancelados.
Os itens não cancelados dos pedidos históricos ficam com suas quantidades prontas
e entregues completas; isso representa o encerramento solicitado na conversão,
não uma confirmação física de entrega. Os status originais ficam registrados no
campo `legacy` e na cópia integral do legado. Não gerar trabalhos de impressão.

Preservar IDs de pedidos, itens, produtos e personalizações, datas, observações,
preços unitários, subtotais, totais e quantidades dos ingredientes. Os nomes são
os do catálogo existente no PostgreSQL: o legado não possui um retrato histórico
independente do nome do produto. O contador por jornada é recuperado sem impor
unicidade às senhas; novos pedidos recebem IDs posteriores ao histórico.

## Exportação local preparada

Os arquivos privados ficam em `private-migration/2026-10-28/`, excluído do Git:

- `postgres-original.dump`: backup custom do PostgreSQL, validado por `pg_restore --list`.
- `legacy-original.sqlite`: arquivo de consulta com as quatro tabelas originais;
  valores `numeric` são guardados como texto decimal exato. Não é o banco do app.
- `pastelaria_v2.db`: SQLite no schema do app, com o histórico encerrado.
- `importacao.pastelbackup`: pacote comprimido e protegido com AES-256-GCM,
  compatível com a restauração existente no aplicativo.
- `chave-recuperacao.txt`: chave do pacote; não publicar nem incluir no APK.
- `report.json`: contagens, conciliação, hashes e confirmação do ensaio.

O dump e a exportação usam o mesmo snapshot `REPEATABLE READ`, em sessão somente
leitura. Não foram executados `UPDATE`, `DELETE` ou migrações no PostgreSQL.

Resultado: 50 produtos/ingredientes, 9.862 pedidos, 18.453 itens e 30.605 registros
de ingredientes. Foram encerrados 196 pedidos abertos na cópia; 181 cancelados
foram mantidos. Total original, incluindo cancelados, preservado em centavos:
27.782.200 (R$ 277.822,00). Filas ativas e trabalhos de impressão: zero.

## Colocar os dados no tablet principal

1. Usar o APK em um servidor sem pedidos, com Android 7.0/API 24 ou superior.
   O APK atual usa assinatura de desenvolvimento; conferir a assinatura antes de
   atualizar uma instalação existente e preservar seus dados antes de qualquer
   troca. A homologação no Samsung real permanece necessária.
2. Configurar o principal e a chave de conexão conforme `IMPLEMENTACAO-V2.md`.
3. Transferir `importacao.pastelbackup` ao principal. Não copiar o arquivo SQLite
   diretamente sobre um banco aberto nem instalar dados nos tablets clientes.
4. Nas Configurações, usar a restauração de backup e informar a chave contida em
   `chave-recuperacao.txt`. O app exige um servidor sem pedidos.
5. Conferir catálogo e filas vazias; conectar os clientes ao IP/chave do principal.
   O histórico foi preservado no banco; a tela atual de consulta lista pedidos do
   dia e não oferece navegação completa por datas antigas.
6. Fazer um ensaio em instalação de teste. Antes da troca definitiva entre
   jornadas, repetir a exportação caso o PostgreSQL tenha recebido novos pedidos.
   A cópia preparada não se atualiza automaticamente. Não operar os dois sistemas
   aceitando pedidos reais simultaneamente.
7. Guardar a chave de recuperação fora do tablet e preservar o backup original.

## Repetir o processo

Requisitos: Python com `psycopg2`, ferramentas PostgreSQL 17, Flutter e SDK Android.
`DB_HOST`, `DB_PORT`, `DB_NAME` e `DB_USER` aceitam variáveis de ambiente. A senha é
solicitada sem eco, ou lida de `DB_PASSWORD`; não gravar credenciais no repositório.
Escolher uma **nova pasta de saída** a cada execução; os arquivos anteriores não
são sobrescritos.

```powershell
python scripts/prepare_legacy_migration.py --output private-migration/nova-exportacao --close-history
python -m unittest discover -s scripts -p 'test_*.py'
$env:MIGRATION_DIR = (Resolve-Path private-migration/nova-exportacao).Path
.\scripts\flutter.ps1 test --no-pub test/migration_artifact_test.dart
Remove-Item Env:MIGRATION_DIR
.\scripts\flutter.ps1 analyze --no-pub
.\scripts\flutter.ps1 build apk --release --no-pub
```

O teste opcional cria o pacote e a chave e restaura o histórico através de
`BackupService.restoreEmpty` em um SQLite em memória criado por
`OrderStore.createSchema`. Confere contagens, total, saldos, ausência de filas,
continuidade dos IDs e bloqueio de restauração em servidor com pedidos. O pedido
sintético do ensaio fica somente em memória. Não incluir dados reais em fixtures.

Validação executada: 26 testes Flutter (incluindo restauração integral) e 3 testes
Python aprovados. O APK não inclui o banco real, a senha do PostgreSQL ou a chave.
A cópia nativa do PostgreSQL foi criada e teve seu índice lido; não houve ensaio
de restauração desse dump em outra instância PostgreSQL.

## Instalação no servidor em 28/10/2026

APK 2.1.0+201 instalado por atualização no SM-T815Y/Android 7.0 escolhido como
principal. Hospedagem ativada, função inicial Pedidos/caixa, endereço Wi-Fi
observado `192.168.1.13:5000` (pode mudar por DHCP). Restauração do pacote acima
concluída no aplicativo. Confirmados 50 produtos/ingredientes, filas ativas e de
impressão vazias e quatro registros históricos idênticos à cópia convertida,
incluindo o último ID 9893 e um cancelado. Acesso autenticado confirmado por USB
e Wi-Fi. Ao fechar e reabrir o app, servidor e dados foram recuperados.

Chaves de conexão e dos backups automáticos guardadas fora do aparelho em
`private-migration/tablet-servidor/`, ignorado pelo Git. O registro sanitizado da
instalação fica em `instalacao-servidor.json` nessa pasta. A chave dos novos
backups é diferente da chave usada na importação. O PostgreSQL original permanece
inalterado. Impressora e nuvem não foram configuradas; ensaio com os três tablets
e validação durante um turno real permanecem pendentes.
