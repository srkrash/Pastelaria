import 'package:flutter/material.dart';

enum PastelType { none, Pizza, Misto }

class AddPastelScreen extends StatefulWidget {
  const AddPastelScreen({super.key});

  @override
  State<AddPastelScreen> createState() => _AddPastelScreenState();
}

class _AddPastelScreenState extends State<AddPastelScreen> {
  // ... (variáveis de estado e métodos existentes) ...
  final Map<String, bool> _ingredientesSelecionados = {
    'Carne': false, 'Frango': false, 'Presunto': false, 'Bacon': false,
    'Queijo': false, 'Catupiry': false, 'Gueroba': false, 'Milho': false,
    'Calabresa': false, 'Tomate': false, 'Cebola': false, 'Cebolinha': false,
    'Azeitona': false,
  };

  int _quantidade = 1;
  PastelType _selectedPastelType = PastelType.none;
  // NOVO: Controlador para o campo de observações
  final TextEditingController _observacoesController = TextEditingController();

  void _aumentarQuantidade() {
    setState(() { _quantidade++; });
  }

  void _diminuirQuantidade() {
    if (_quantidade > 1) {
      setState(() { _quantidade--; });
    }
  }

  // NOVO: Método para descartar o controlador quando a tela for fechada
  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSpecialPastelSelected = _selectedPastelType != PastelType.none;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Pastel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuantityButton(icon: Icons.remove, onPressed: _diminuirQuantidade),
                const SizedBox(width: 24.0),
                Text(_quantidade.toString(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(width: 24.0),
                _buildQuantityButton(icon: Icons.add, onPressed: _aumentarQuantidade),
              ],
            ),
            const SizedBox(height: 24.0),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIngredientesColumn(['Carne', 'Frango', 'Presunto', 'Bacon'], isSpecialPastelSelected),
                const SizedBox(width: 16.0),
                _buildIngredientesColumn(['Queijo', 'Catupiry', 'Gueroba', 'Milho'], isSpecialPastelSelected),
                const SizedBox(width: 16.0),
                _buildIngredientesColumn(['Calabresa', 'Tomate', 'Cebola', 'Cebolinha', 'Azeitona'], isSpecialPastelSelected),
              ],
            ),
            
            const Divider(thickness: 2),
            
            Row(
              children: [
                _buildSpecialPastelButton('Pastel Pizza', PastelType.Pizza),
                const SizedBox(width: 16.0),
                _buildSpecialPastelButton('Pastel Misto', PastelType.Misto),
              ],
            ),
            
            const Divider(thickness: 2),
            
            // NOVO: Campo de observação
            TextField(
              controller: _observacoesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Observações (Ex: Sem cebola, bem passado)',
              ),
              maxLines: null, // Permite múltiplas linhas
              keyboardType: TextInputType.multiline,
            ),

            // Este Expanded agora pegará o espaço restante.
            Expanded(
              child: Container(),
            ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () { Navigator.of(context).pop(); },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 20.0),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final List<String> ingredientes;
                    if (_selectedPastelType == PastelType.Pizza) {
                      ingredientes = ['Pizza'];
                    } else if (_selectedPastelType == PastelType.Misto) {
                      ingredientes = ['Misto'];
                    } else {
                      ingredientes = _ingredientesSelecionados.keys.where((key) => _ingredientesSelecionados[key] == true).toList();
                    }

                    // NOVO: Adiciona a observação ao mapa de resultado
                    final resultado = {
                      'quantidade': _quantidade,
                      'ingredientes': ingredientes,
                      'tipo_pastel': 'none',
                      'observacoesItem': (_observacoesController.text.isEmpty) ? '' : _observacoesController.text,
                    };
                    print(resultado);
                    Navigator.of(context).pop(resultado);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 20.0),
                  ),
                  child: const Text('Adicionar Pastel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (outros métodos _build existentes) ...
  Widget _buildQuantityButton({required IconData icon, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(24.0),
        shape: const CircleBorder(),
      ),
      child: Icon(icon, size: 36),
    );
  }

  Widget _buildIngredientesColumn(List<String> ingredientes, bool isDisabled) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ingredientes.map((ingrediente) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ElevatedButton(
              onPressed: isDisabled ? null : () {
                setState(() {
                  _ingredientesSelecionados.update(ingrediente, (value) => !value);
                });
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                backgroundColor: _ingredientesSelecionados[ingrediente]! ? const Color.fromARGB(255, 105, 226, 109) : null,
                padding: const EdgeInsets.symmetric(vertical: 35.0),
                textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              child: Text(ingrediente),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpecialPastelButton(String text, PastelType type) {
    final bool isSelected = _selectedPastelType == type;
    final bool otherIsSelected = _selectedPastelType != PastelType.none && _selectedPastelType != type;

    return Expanded(
      child: ElevatedButton(
        onPressed: otherIsSelected ? null : () {
          setState(() {
            _selectedPastelType = isSelected ? PastelType.none : type;
            if (_selectedPastelType != PastelType.none) {
                _ingredientesSelecionados.updateAll((key, value) => false);
            }
          });
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          backgroundColor: isSelected ? const Color.fromARGB(255, 105, 226, 109) : null,
          padding: const EdgeInsets.symmetric(vertical: 35.0),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        child: Text(text),
      ),
    );
  }
}