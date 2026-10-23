import '../ui/app_ui.dart';
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

  Widget _section(String title, IconData icon, List<Widget> children) =>
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: brand),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w800)))
        ]),
        const SizedBox(height: 18),
        ...children,
      ]));
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          _section(
                              'Este tablet', Icons.tablet_android_outlined, [
                            DropdownButtonFormField<String>(
                                initialValue: _role,
                                decoration: const InputDecoration(
                                    labelText: 'Abrir sempre em'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'pedido',
                                      child: Text('Pedidos / caixa')),
                                  DropdownMenuItem(
                                      value: 'cozinha', child: Text('Cozinha')),
                                  DropdownMenuItem(
                                      value: 'entrega', child: Text('Entrega'))
                                ],
                                onChanged: (v) => setState(() => _role = v!)),
                            const SizedBox(height: 12),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                    'Hospedar os pedidos neste aparelho',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: const Text(
                                    'Ative em apenas um tablet. Ele precisa permanecer ligado durante o atendimento.'),
                                value: _host,
                                onChanged: (v) => setState(() {
                                      _host = v;
                                      if (v && _secret.text.isEmpty) {
                                        _secret.text = newCommandId();
                                      }
                                    })),
                          ]),
                          const SizedBox(height: 18),
                          _section(
                              'Conexão entre os tablets', Icons.wifi_outlined, [
                            if (_host) ...[
                              SelectableText(
                                  'IP deste tablet: ${_ips.isEmpty ? 'não identificado' : _ips}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              const Text(
                                  'Informe este IP e a chave abaixo nos outros dois aparelhos.',
                                  style: TextStyle(color: mutedInk)),
                              const SizedBox(height: 16)
                            ],
                            if (!_host) ...[
                              TextField(
                                  controller: _address,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'IP do tablet principal',
                                      hintText: '192.168.1.10')),
                              const SizedBox(height: 16)
                            ],
                            TextField(
                                controller: _secret,
                                obscureText: !_showSecret,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                    labelText: 'Chave de conexão',
                                    helperText:
                                        'Use a mesma chave nos três tablets.',
                                    suffixIcon: IconButton(
                                        tooltip: _showSecret
                                            ? 'Ocultar chave'
                                            : 'Mostrar chave',
                                        onPressed: () => setState(
                                            () => _showSecret = !_showSecret),
                                        icon: Icon(_showSecret
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined)))),
                            if (_host)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: _secret.text));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('Chave copiada.')));
                                        }
                                      },
                                      icon: const Icon(Icons.copy),
                                      label: const Text('Copiar chave'))),
                          ]),
                          if (_host) ...[
                            const SizedBox(height: 18),
                            _section('Impressora Tanca', Icons.print_outlined, [
                              const Text(
                                  'Conecte a impressora ao roteador por cabo de rede.',
                                  style: TextStyle(color: mutedInk)),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _printer,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'IP da impressora',
                                      hintText: '192.168.1.20')),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _port,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Porta da impressora',
                                      helperText:
                                          'Confirme a porta na configuração da Tanca.')),
                              const SizedBox(height: 12),
                              const Text(
                                  'Sem impressora configurada, os pedidos ficam salvos e a impressão aguarda.',
                                  style: TextStyle(color: mutedInk)),
                            ]),
                          ],
                          const SizedBox(height: 18),
                          _section('Acompanhamento e recuperação',
                              Icons.health_and_safety_outlined, [
                            OutlinedButton.icon(
                                onPressed: _jobs,
                                icon: const Icon(Icons.print_outlined),
                                label: const Text(
                                    'Fila de impressão e segunda via')),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                                onPressed: _recoverOrder,
                                icon: const Icon(Icons.sync_problem_outlined),
                                label: const Text(
                                    'Resolver pedido com confirmação pendente')),
                            if (ServerRuntime.instance.store != null) ...[
                              const SizedBox(height: 18),
                              const Divider(),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                  onPressed: () => _backup(),
                                  icon: const Icon(Icons.backup_outlined),
                                  label:
                                      const Text('Exportar backup protegido')),
                              const SizedBox(height: 10),
                              Text(
                                  ServerRuntime.instance.backupError ??
                                      'Cópias locais na abertura e a cada hora com o servidor ativo. Histórico dos últimos 7 dias.',
                                  style: const TextStyle(color: mutedInk)),
                              const SizedBox(height: 10),
                              const StatusPill(
                                  'Backup na nuvem não configurado',
                                  color: mutedInk,
                                  icon: Icons.cloud_off_outlined),
                              const SizedBox(height: 12),
                              ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title:
                                      const Text('Restaurar em outro tablet'),
                                  children: [
                                    const Text(
                                        'Use apenas em um servidor sem pedidos, com o aparelho principal anterior desligado.',
                                        style: TextStyle(color: mutedInk)),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                        onPressed: () => _backup(restore: true),
                                        icon: const Icon(Icons.restore),
                                        label: const Text(
                                            'Escolher arquivo de backup'))
                                  ]),
                            ],
                          ]),
                        ]))),
        bottomNavigationBar: _busy
            ? null
            : SafeArea(
                top: false,
                child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                        heightFactor: 1,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    onPressed: _save,
                                    icon: const Icon(Icons.check),
                                    label:
                                        const Text('Salvar e conectar'))))))),
      );
}
