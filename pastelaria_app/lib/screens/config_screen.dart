import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pedidos_provider.dart';
import '../services/app_settings.dart';
import '../services/api_service.dart';
import '../server/server_runtime.dart';
import '../server/backup_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _address = TextEditingController();
  final _secret = TextEditingController();
  final _printer = TextEditingController();
  final _port = TextEditingController(text: '9100');
  bool _host = false, _busy = true, _showSecret = false;
  String _role = 'pedido';
  String _ips = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppSettings.load();
    String ips = '';
    try {
      ips = (await NetworkInterface.list(type: InternetAddressType.IPv4))
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .join(', ');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _host = s.host;
      _role = s.role;
      _address.text = s.address;
      _secret.text = s.secret;
      _printer.text = s.printerAddress;
      _port.text = '${s.printerPort}';
      _ips = ips;
      _busy = false;
    });
  }

  Future<void> _save() async {
    final secret = _secret.text.trim();
    final port = int.tryParse(_port.text);
    if (secret.length < 16 ||
        !_host && InternetAddress.tryParse(_address.text.trim()) == null ||
        _printer.text.isNotEmpty &&
            InternetAddress.tryParse(_printer.text.trim()) == null ||
        port == null ||
        port < 1 ||
        port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Confira IPs, porta e chave (mínimo 16 caracteres).')));
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<PedidosProvider>();
    final old = await AppSettings.load();
    final s = AppSettings(
        host: _host,
        address: _address.text.trim(),
        secret: secret,
        printerAddress: _printer.text.trim(),
        printerPort: port,
        role: _role);
    try {
      await ServerRuntime.instance.configure(s);
      await s.save();
      await provider.updateConnection();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      try {
        await ServerRuntime.instance.configure(old);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível aplicar: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _jobs() async {
    try {
      final jobs = await ApiService().printJobs();
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Fila de impressão'),
                content: SizedBox(
                    width: 600,
                    child: jobs.isEmpty
                        ? const Text('Nenhum trabalho.')
                        : ListView(
                            shrinkWrap: true,
                            children: jobs
                                .map((j) => ListTile(
                                      title: Text(
                                          'Pedido interno ${j['order_id']} · ${j['status']}'),
                                      subtitle: Text(j['error']?.toString() ??
                                          'Enviado significa envio de dados, sem confirmação física.'),
                                      trailing: j['status'] == 'pendente' ||
                                              j['status'] == 'enviando'
                                          ? null
                                          : IconButton(
                                              tooltip:
                                                  'Segunda via após conferir o papel',
                                              icon: const Icon(Icons.print),
                                              onPressed: () async {
                                                Navigator.pop(dialogContext);
                                                final confirm = await showDialog<
                                                        bool>(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                            title: const Text(
                                                                'Conferiu o papel?'),
                                                            content: const Text(
                                                                'Uma segunda via pode duplicar um cupom já impresso.'),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          c,
                                                                          false),
                                                                  child: const Text(
                                                                      'Cancelar')),
                                                              FilledButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          c,
                                                                          true),
                                                                  child: const Text(
                                                                      'Solicitar segunda via'))
                                                            ]));
                                                if (confirm != true) return;
                                                try {
                                                  await ApiService()
                                                      .reimprimirPedido(
                                                          j['order_id'] as int);
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content:
                                                                Text('$e')));
                                                  }
                                                }
                                              }),
                                    ))
                                .toList())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Fechar'))
                ],
              ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _backup({bool restore = false}) async {
    final runtime = ServerRuntime.instance;
    if (runtime.store == null) return;
    final provider = context.read<PedidosProvider>();
    final keyController =
        TextEditingController(text: restore ? '' : await runtime.recoveryKey());
    if (!mounted) {
      keyController.dispose();
      return;
    }
    final key = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(restore
                  ? 'Restaurar em servidor sem pedidos'
                  : 'Guardar chave de recuperação'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(restore
                    ? 'O tablet principal anterior deve estar desligado. A restauração só é aceita se este servidor não tiver pedidos.'
                    : 'Copie esta chave e guarde fora do tablet. Sem ela, o backup não pode ser recuperado. O envio automático à nuvem ainda não está configurado.'),
                const SizedBox(height: 16),
                TextField(
                    controller: keyController,
                    readOnly: !restore,
                    decoration: const InputDecoration(
                        labelText: 'Chave de recuperação'),
                    maxLines: 2),
                if (!restore)
                  TextButton(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: keyController.text)),
                      child: const Text('Copiar chave')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(c, keyController.text.trim()),
                    child:
                        Text(restore ? 'Escolher backup' : 'Exportar backup'))
              ],
            ));
    keyController.dispose();
    if (key == null || !mounted) return;
    setState(() => _busy = true);
    try {
      const channel = MethodChannel('pastelaria/server');
      if (restore) {
        final bytes = await channel.invokeMethod<Uint8List>('readBackup');
        if (bytes == null) return;
        await BackupService.restoreEmpty(runtime.store!, bytes, key);
        await provider.refresh();
      } else {
        final file = await runtime.backupNow();
        final exported = await channel.invokeMethod<bool>('saveBackup', {
          'bytes': await file.readAsBytes(),
          'name': file.uri.pathSegments.last
        });
        if (exported != true) return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(restore
                ? 'Backup restaurado. Confira pedidos e senhas antes de atender.'
                : 'Backup exportado. Guarde também a chave de recuperação.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível concluir. Confira arquivo, chave e se o servidor de destino está sem pedidos.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recoverOrder() async {
    try {
      final api = ApiService();
      final pending = await api.pendingOrder();
      if (!mounted) return;
      if (pending == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma confirmação pendente.')));
        return;
      }
      final items = (pending['payload']['itens'] as List)
          .map((i) => '${i['quantidade']}× ${i['produto_nome']}')
          .join('\n');
      final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Resolver confirmação pendente'),
                  content: Text(
                      '$items\n\nConsultar/reenviar o pedido original? Se já foi salvo, o servidor devolve o mesmo pedido sem duplicar.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Voltar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Resolver pedido'))
                  ]));
      if (confirm != true) return;
      final result = await api.recoverPending();
      if (!mounted) return;
      final provider = context.read<PedidosProvider>();
      provider.limparPedido();
      provider.setUltimoPedido(result['numero_pedido'] as int,
          (result['total_pedido'] as num).toDouble());
      await provider.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Pedido confirmado: senha ${result['numero_pedido']}.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_address, _secret, _printer, _port]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Configuração dos tablets')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    const Text('Servidor e rede local',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                    SwitchListTile(
                        title: const Text('Este é o tablet principal'),
                        subtitle: const Text(
                            'Ative em apenas um aparelho. Mantenha o aplicativo aberto e o tablet ligado durante o atendimento.'),
                        value: _host,
                        onChanged: (v) => setState(() {
                              _host = v;
                              if (v && _secret.text.isEmpty) {
                                _secret.text = newCommandId();
                              }
                            })),
                    if (_host)
                      SelectableText(
                          'IP deste aparelho: ${_ips.isEmpty ? 'não identificado' : _ips}\nPorta do servidor: 5000'),
                    if (!_host)
                      TextField(
                          controller: _address,
                          decoration: const InputDecoration(
                              labelText: 'IP do tablet principal',
                              hintText: '192.168.1.10')),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _secret,
                        obscureText: !_showSecret,
                        decoration: InputDecoration(
                            labelText:
                                'Chave de conexão (igual nos três tablets)',
                            suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _showSecret = !_showSecret),
                                icon: const Icon(Icons.visibility)))),
                    if (_host)
                      TextButton.icon(
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: _secret.text)),
                          icon: const Icon(Icons.copy),
                          label: const Text(
                              'Copiar chave para configurar os outros tablets')),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                            labelText: 'Tela inicial deste tablet'),
                        items: const [
                          DropdownMenuItem(
                              value: 'pedido', child: Text('Pedidos / caixa')),
                          DropdownMenuItem(
                              value: 'cozinha', child: Text('Cozinha')),
                          DropdownMenuItem(
                              value: 'entrega', child: Text('Entrega'))
                        ],
                        onChanged: (v) => setState(() => _role = v!)),
                    if (_host) ...[
                      const SizedBox(height: 24),
                      const Text('Impressora Tanca por cabo de rede',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      TextField(
                          controller: _printer,
                          decoration: const InputDecoration(
                              labelText:
                                  'IP da impressora (opcional durante configuração)')),
                      TextField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText:
                                  'Porta TCP (confirmar; sugestão 9100)')),
                      const Text(
                          'Sem IP de impressora, os pedidos ficam com impressão pendente.'),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar e conectar')),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: _jobs,
                        icon: const Icon(Icons.print),
                        label: const Text('Fila de impressão / segunda via')),
                    OutlinedButton.icon(
                        onPressed: _recoverOrder,
                        icon: const Icon(Icons.sync_problem),
                        label: const Text(
                            'Resolver confirmação de pedido pendente')),
                    if (ServerRuntime.instance.store != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () => _backup(),
                          icon: const Icon(Icons.backup),
                          label: const Text('Exportar backup protegido')),
                      OutlinedButton.icon(
                          onPressed: () => _backup(restore: true),
                          icon: const Icon(Icons.restore),
                          label: const Text(
                              'Restaurar backup em servidor sem pedidos')),
                      Text(ServerRuntime.instance.backupError ??
                          'Backup local na abertura e a cada hora com servidor ativo; guarda os últimos 7 dias.'),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                        'Versão 2 em validação: use a rede privada da operação. Backup em nuvem e homologação no SM-T815Y ainda pendentes.'),
                  ]))));
}
