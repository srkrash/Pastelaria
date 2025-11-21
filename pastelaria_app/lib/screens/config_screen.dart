import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastelaria_app/services/ip_storage.dart';
import 'package:pastelaria_app/providers/pedidos_provider.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final savedIp = await IpStorage.getIp();
    _ipController.text = savedIp ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveIp() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um IP válido')),
      );
      return;
    }

    await IpStorage.saveIp(ip);

    // Atualiza a conexão do WebSocket
    if (mounted) {
      await Provider.of<PedidosProvider>(context, listen: false).updateConnection();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('IP salvo com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context); // Volta para a tela anterior
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Colors.amber,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'IP do Servidor Backend:',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Campo de texto estilizado
                      TextField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          labelText: 'Ex: 192.168.0.100',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                        ),
                        style: const TextStyle(fontSize: 22),
                      ),

                      const SizedBox(height: 32),

                      // Botão seguindo o estilo da tela principal
                      _buildButton(
                        context,
                        text: 'Salvar IP',
                        icon: Icons.save,
                        color: Colors.deepOrange,
                        onPressed: _saveIp,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 36),
      label: Text(
        text,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 8,
      ),
      onPressed: onPressed,
    );
  }
}
