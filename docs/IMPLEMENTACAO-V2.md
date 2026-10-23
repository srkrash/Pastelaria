# Versão 2 — servidor no APK

Implementação iniciada em 23/10/2026, branch `codex/servidor-tablet`. O Git já existia; não foi reinicializado.

## Cópia de segurança antes das alterações

Cópia completa em `D:\Dev\Sistema Pastelaria - backup antes servidor APK 2026-10-23`, incluindo Git, documentação, arquivos locais, dependências e artefatos legados. Conferidos 11.228 arquivos e 992.985.206 bytes na origem e no destino. A cópia contém os arquivos privados originais e não deve ser publicada.

## Ambiente deste PC

- Flutter 3.38.5 e Dart 3.10.4, instalados em `D:\Dev\Flutter\flutter`.
- O SDK não estava no PATH; os caminhos Android do projeto apontavam para outra instalação antiga.
- Script `scripts/flutter.ps1` resolve o ambiente apenas no processo atual, sem mudar PATH ou configuração global do Git.
- JDK 21 instalado é selecionado para o daemon Gradle. O JDK 25 do Android Studio não era compatível com o Gradle usado.
- Android SDK em `%LOCALAPPDATA%\Android\Sdk`; plataforma 36, NDK 28.2.13676358 e ferramentas de build necessários à compilação foram instalados. Android mínimo do app: API 24 (Android 7.0).
- Gradle 8.13 e Android Gradle Plugin 8.11.1; compilação incremental Kotlin desativada para evitar falha entre o cache em C: e o projeto em D:.
- As ferramentas baixadas para instalação ficam em `tools/`, ignorado pelo Git. Licenças já reconhecidas pelo SDK foram utilizadas pela compilação.

Na raiz do repositório:

```powershell
.\scripts\flutter.ps1 pub get
.\scripts\flutter.ps1 analyze --no-pub
.\scripts\flutter.ps1 test --no-pub
.\scripts\flutter.ps1 build apk --release --no-pub
```

O script aceita `FLUTTER_ROOT` para outro caminho de SDK. Em outra máquina, ajustar SDK/JDK locais e regenerar `android/local.properties`, que não é versionado.

## Implementado

- Servidor HTTP e WebSocket Dart no mesmo APK, ativado explicitamente apenas no principal.
- SQLite privado do aplicativo, schema versionado, transações, IDs internos e sequência diária atômica 1–99/1 em `America/Sao_Paulo`.
- Preservação inicial do catálogo de 47 produtos/ingredientes a partir de `data.sql`, sem dados reais de pedidos. Preços são os do catálogo legado do repositório e precisam ser conferidos pelo responsável antes de usar.
- Regras de preço legado preservadas no servidor: pastel personalizado R$12 com até dois ingredientes pagos; R$3 por ingrediente adicional; Pizza R$15; Misto R$25; cebola/cebolinha/orégano gratuitos.
- Confirmação idempotente de pedidos; comando de criação pendente persiste no tablet para recuperação depois de timeout ou reinício.
- Produção por cartões de pedido, sabores e observações; conclusão parcial por quantidade.
- Entrega parcial com saldos e proteção de concorrência por revisão. Pedido só encerra após entregar todas as unidades não canceladas.
- Filas derivadas do snapshot por ID, sem remoção duplicada por índice nem dependência de animações. Eventos solicitam atualização; consultas a cada 3 segundos e ao retomar recuperam notificações perdidas. Snapshots de revisão anterior são ignorados.
- Consulta de pedidos do dia, cancelamento anterior a preparo/entrega e reimpressão. A antiga finalização passa a encaminhar à entrega, sem marcar itens pendentes como prontos.
- Fila persistente de impressão TCP ESC/POS, IP e porta configuráveis, resultado incerto após reinício/interrupção, segunda via explícita.
- Serviço Android em primeiro plano no principal, notificação e manutenção da tela ligada. Fechar/forçar parada ou reiniciar o aparelho ainda exige reabrir o app; não há início automático após boot.
- Backup local consistente em formato lógico, comprimido e protegido com AES-256-GCM e chave aleatória de recuperação. Na abertura do servidor e a cada hora com app ativo, conserva a última cópia de cada um dos últimos 7 dias com backup.
- Exportação pelo seletor de documentos Android. O operador escolhe o destino disponível e guarda a chave separadamente; selecionar um provedor não equivale a configurar upload automático.
- Restauração em servidor sem pedidos, validação de integridade/chave e dos saldos, sem reimpressão automática de trabalhos históricos pendentes.
- Log em memória limitado a 500 registros.

## Preparar os três tablets

1. Instalar o APK de validação. A versão mantém o application ID legado e usa assinatura de desenvolvimento; não desinstalar uma versão em uso nem tentar substituir dados reais sem conferir assinatura e fazer cópia dos dados.
2. No tablet principal, abrir Configurações e ativar “Este é o tablet principal”. Uma chave de conexão é gerada. Conferir IP local exibido; guardar chave e IP para os outros tablets.
3. Selecionar a tela inicial (normalmente Pedidos/caixa). Salvar e conectar. O servidor escuta na porta 5000; o próprio tablet acessa por loopback.
4. Nos outros dois, deixar principal desativado, informar o IP do principal e a mesma chave; selecionar Cozinha ou Entrega e salvar.
5. Confirmar que o OpenWrt permite tráfego entre os equipamentos da operação. Nenhuma alteração foi feita no roteador por esta tarefa.
6. Após configurar Ethernet da TP-650, informar IP e porta TCP no principal. O valor inicial 9100 é uma sugestão a conferir no equipamento, não uma porta homologada. Sem IP, trabalhos ficam pendentes.
7. Fazer um pedido sintético, concluir parte dos pastéis, entregar parte, conferir saldos nos três aparelhos e depois concluir o restante. Repetir com dois aparelhos na entrega.
8. No principal, usar “Exportar backup protegido”, copiar a chave e guardar fora do aparelho. Testar restauração em instalação vazia antes de confiar no procedimento.

Para uma confirmação de pedido sem resposta, usar “Resolver confirmação de pedido pendente”. O sistema consulta/reenvia o comando original com o mesmo ID; não criar outro pedido manualmente antes de conferir o resultado.

## Validação automatizada

Suite inicial de 15 testes cobre SQLite real via FFI, dois clientes HTTP e WebSockets independentes, idempotência, concorrência sobre a última unidade, produção/entrega parciais, sequência 98/99/1, data de São Paulo, rollback, pronta entrega e backup/restauração, chave errada e corrupção. Testes de widgets verificam as filas em 1024×768, saldos e rejeição de snapshots antigos.

Esses testes não homologam comportamento de bateria no Samsung nem o protocolo/resultado físico da Tanca. O diagnóstico do PC encontrou dispositivos Quest conectados, não os tablets da operação; nenhum aplicativo foi instalado nesses dispositivos.

Resultado desta execução: 15 testes aprovados e `flutter analyze` sem apontamentos. APK release gerado em `pastelaria_app/build/app/outputs/flutter-apk/app-release.apk`, versão 2.0.0 (código 200), 57.752.259 bytes, minSdk 24, targetSdk 36, arquiteturas `armeabi-v7a`, `arm64-v8a` e `x86_64`. SHA-256: `8F60C25C20F42213F7181530E6D599E23347D48E0AB218528BF75243CFE12E32`.

## Limitações e próximos passos

- **Homologação real:** provar estabilidade do servidor durante um turno no SM-T815Y/Android instalado, suspensão, Wi-Fi e reinício. E1 da documentação segue pendente dessa evidência, apesar do núcleo já implementado.
- **Impressão:** validar porta, largura, layout e corte. Nesta versão o texto é transliterado para ASCII até a página de códigos da unidade ser testada. “Enviado” confirma envio dos dados, não saída física do papel. Falhas/estados incertos exigem conferência e segunda via, sem retry cego.
- **Nuvem:** backup automático no Google Drive ainda não implementado/configurado. Depende da conta e da configuração OAuth para o aplicativo. Nenhuma credencial foi solicitada ou incluída; não há alegação de backup remoto concluído.
- **Rede:** autenticação por chave compartilhada, em HTTP na rede privada. HTTPS/provisionamento de certificados e credenciais individuais por dispositivo continuam pendentes antes de homologação definitiva. Não expor a porta 5000 na internet.
- **Migração:** catálogo inicial vem do SQL versionado; histórico do PostgreSQL não foi importado. O banco legado e seus arquivos foram preservados. O banco novo tem outro formato e outro arquivo.
- **Regras em aberto:** cancelamento após preparo/entrega, estorno/reabertura e pagamento continuam aguardando definição; o app bloqueia cancelamento que apagaria quantidades já produzidas/entregues.
- **Distribuição:** configurar chave de assinatura de produção e processo de atualização após homologação. O APK gerado é para validação.
- **Rascunho:** confirmação pendente sobrevive ao reinício; rascunho ainda não enviado continua em memória e pode ser perdido ao encerrar o processo.
- **Backup:** agendamento local depende do app/servidor ativo; não há WorkManager nem execução garantida com o app fechado. Restauração exige servidor sem pedidos e chave de recuperação externa.

Não declarar todos os bugs eliminados: as classes de falha identificadas foram tratadas no novo fluxo, mas o relato original de pedidos ausentes precisa ser validado na operação real.
