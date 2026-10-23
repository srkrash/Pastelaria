import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../models/item_pedido.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';

class PedidosProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService _api;
  PedidosProvider({ApiService? api}) : _api = api ?? ApiService();
  final List<ItemPedido> _draft = [];
  List<ItemPedido> get itensPedidoAtual => List.unmodifiable(_draft);
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> get filaEntrega =>
      _orders.where((p) => p['status'] == 'aberto').toList();
  List<Map<String, dynamic>> get filaProducao => filaEntrega
      .where((p) => (p['itens'] as List).any((i) =>
          i['produto_tipo'] == 'pastel' &&
          i['quantidade_pronta'] < i['quantidade'] - i['quantidade_cancelada']))
      .toList();
  Map<String, dynamic>? ultimoPedidoConfirmado;
  String? error;
  bool loading = false;
  DateTime? lastSync;
  String draftCommandId = newCommandId();
  String draftNotes = '';
  String draftType = 'Consumo';
  WebSocket? _socket;
  Timer? _poll;
  bool _disposed = false;
  bool _refreshAgain = false;
  int _generation = 0;
  int _revision = -1;

  static Future<PedidosProvider> create() async {
    final provider = PedidosProvider();
    WidgetsBinding.instance.addObserver(provider);
    provider._poll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(provider.refresh());
    });
    unawaited(provider.updateConnection());
    return provider;
  }

  void adicionarItem(ItemPedido item) {
    _draft.add(item);
    draftCommandId = newCommandId();
    notifyListeners();
  }

  void removerItem(ItemPedido item) {
    _draft.remove(item);
    draftCommandId = newCommandId();
    notifyListeners();
  }

  void alterarQuantidade(ItemPedido item, int quantity) {
    if (!_draft.contains(item) || quantity < 1 || quantity > 999) return;
    item.quantidade = quantity;
    draftCommandId = newCommandId();
    notifyListeners();
  }

  void inserirItem(int index, ItemPedido item) {
    _draft.insert(index.clamp(0, _draft.length), item);
    draftCommandId = newCommandId();
    notifyListeners();
  }

  void limparPedido() {
    _draft.clear();
    draftNotes = '';
    draftType = 'Consumo';
    draftCommandId = newCommandId();
    notifyListeners();
  }

  void setUltimoPedido(int numero, double total) {
    ultimoPedidoConfirmado = {'numero': numero, 'total': total};
    notifyListeners();
  }

  Future<void> updateConnection() async {
    final generation = ++_generation;
    _revision = -1;
    _orders = [];
    lastSync = null;
    await _socket?.close();
    _socket = null;
    final settings = await AppSettings.load();
    if (generation != _generation || _disposed) return;
    if (!settings.configured) {
      error = 'Abra Configurações para preparar este tablet.';
      notifyListeners();
      return;
    }
    unawaited(refresh());
    try {
      final ws = await WebSocket.connect(
              '${settings.baseUrl.replaceFirst('http:', 'ws:')}/events',
              headers: {'Authorization': 'Bearer ${settings.secret}'})
          .timeout(const Duration(seconds: 5));
      if (generation != _generation || _disposed) {
        await ws.close();
        return;
      }
      _socket = ws;
      ws.listen((_) {
        unawaited(refresh());
      }, onDone: () {
        if (_socket == ws) _socket = null;
      }, onError: (_) {
        if (_socket == ws) _socket = null;
      });
    } catch (_) {/* Snapshots periódicos recuperam eventos perdidos. */}
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (loading) {
      _refreshAgain = true;
      return;
    }
    final generation = _generation;
    loading = true;
    try {
      final snapshot = await _api.snapshot();
      if (_disposed || generation != _generation) return;
      final revision = snapshot['revision'] as int;
      if (revision >= _revision) {
        _orders = (snapshot['pedidos'] as List)
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        _revision = revision;
      }
      error = null;
      lastSync = DateTime.now();
    } catch (e) {
      if (!_disposed && generation == _generation) error = e.toString();
    } finally {
      loading = false;
      if (!_disposed) {
        notifyListeners();
        if (_refreshAgain) {
          _refreshAgain = false;
          unawaited(refresh());
        }
      }
    }
  }

  Future<void> fetchFilaEntrega() => refresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(updateConnection());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _poll?.cancel();
    unawaited(_socket?.close());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
