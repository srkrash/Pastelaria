import 'package:flutter/material.dart';

// Enum para identificar o tipo de pastel
enum PastelType { none, pizza, misto }

class AddPastelScreen extends StatefulWidget {
  const AddPastelScreen({super.key});

  @override
  State<AddPastelScreen> createState() => _AddPastelScreenState();
}

class _AddPastelScreenState extends State<AddPastelScreen> {
  // Mapa de ingredientes customizáveis com seus estados (selecionado ou não)
  final Map<String, bool> _ingredientesSelecionados = {
    'Carne': false,
    'Frango': false,
    'Presunto': false,
    'Bacon': false,
    'Queijo': false,
    'Catupiry': false,
    'Gueroba': false,
    'Milho': false,
    'Calabresa': false,
    'Tomate': false,
    'Cebola': false,
    'Cebolinha': false,
    'Azeitona': false,
  };

  int _quantidade = 1;
  PastelType _selectedPastelType = PastelType.none;
  // Controlador para o campo de observações
  final TextEditingController _observacoesController = TextEditingController();

  void _aumentarQuantidade() {
    setState(() {
      _quantidade++;
    });
  }

  void _diminuirQuantidade() {
    if (_quantidade > 1) {
      setState(() {
        _quantidade--;
      });
    }
  }

  // Método para descartar o controlador quando a tela for fechada
  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  // Widget auxiliar para os botões de controle de quantidade
  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(24.0),
        shape: const CircleBorder(),
      ),
      child: Icon(icon, size: 36),
    );
  }

  // Widget auxiliar para os botões de ingredientes customizados
  Widget _buildIngredientesColumn(List<String> ingredientes, bool isDisabled) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ingredientes.map((ingrediente) {
          final isSelected = _ingredientesSelecionados[ingrediente]!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ElevatedButton(
              // Desabilita a seleção se um pastel especial estiver selecionado
              onPressed: isDisabled
                  ? null
                  : () {
                      setState(() {
                        _ingredientesSelecionados.update(
                            ingrediente, (value) => !value);
                      });
                    },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                // CORRIGIDO: Cor de seleção em tema âmbar
                backgroundColor: isSelected ? Colors.amber.shade700 : null,
                // CORRIGIDO: Garante que o texto seja escuro (preto) quando selecionado
                foregroundColor: isSelected ? Colors.black : null,
                padding: const EdgeInsets.symmetric(vertical: 35.0),
                textStyle:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              child: Text(ingrediente),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Widget auxiliar para os botões de Pastéis Especiais (Pizza, Misto)
  Widget _buildSpecialPastelButton(String text, PastelType type) {
    final bool isSelected = _selectedPastelType == type;
    final bool otherIsSelected =
        _selectedPastelType != PastelType.none && _selectedPastelType != type;

    return Expanded(
      child: ElevatedButton(
        // Desabilita se outro pastel especial estiver selecionado
        onPressed: otherIsSelected
            ? null
            : () {
                setState(() {
                  _selectedPastelType = isSelected ? PastelType.none : type;
                  // Limpa a seleção de ingredientes se um especial for escolhido
                  if (_selectedPastelType != PastelType.none) {
                    _ingredientesSelecionados.updateAll((key, value) => false);
                  }
                });
              },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          // CORRIGIDO: Cor de seleção em tema âmbar
          backgroundColor: isSelected ? Colors.amber.shade700 : null,
          // CORRIGIDO: Garante que o texto seja escuro (preto) quando selecionado
          foregroundColor: isSelected ? Colors.black : null,
          padding: const EdgeInsets.symmetric(vertical: 35.0),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se um pastel especial estiver selecionado, os botões de ingredientes devem ser desabilitados
    final bool isSpecialPastelSelected = _selectedPastelType != PastelType.none;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Pastel'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Controle de Quantidade
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuantityButton(
                    icon: Icons.remove, onPressed: _diminuirQuantidade),
                const SizedBox(width: 24.0),
                Text(_quantidade.toString(),
                    style: const TextStyle(
                        fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(width: 24.0),
                _buildQuantityButton(
                    icon: Icons.add, onPressed: _aumentarQuantidade),
              ],
            ),
            const SizedBox(height: 24.0),

            // 2. Seleção de Ingredientes
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIngredientesColumn(
                    ['Carne', 'Frango', 'Presunto', 'Bacon'],
                    isSpecialPastelSelected),
                const SizedBox(width: 16.0),
                _buildIngredientesColumn(
                    ['Queijo', 'Catupiry', 'Gueroba', 'Milho'],
                    isSpecialPastelSelected),
                const SizedBox(width: 16.0),
                _buildIngredientesColumn(
                    ['Calabresa', 'Tomate', 'Cebola', 'Cebolinha', 'Azeitona'],
                    isSpecialPastelSelected),
              ],
            ),

            const Divider(thickness: 2, height: 24),

            // 3. Pastéis Especiais
            Row(
              children: [
                _buildSpecialPastelButton('Pastel Pizza', PastelType.pizza),
                const SizedBox(width: 16.0),
                _buildSpecialPastelButton('Pastel Misto', PastelType.misto),
              ],
            ),

            const Divider(thickness: 2, height: 24),

            // 4. Campo de Observação
            TextField(
              controller: _observacoesController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Observações (Ex: Sem cebola, bem passado)',
                // Adiciona um ícone discreto para indicar observações
                suffixIcon:
                    Icon(Icons.note_alt, color: Colors.blueGrey.shade400),
              ),
              maxLines: 2, // Limita a 2 linhas para economizar espaço
              keyboardType: TextInputType.multiline,
            ),

            // Espaço restante antes dos botões de ação
            Expanded(
              child: Container(),
            ),

            // 5. Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Botão Cancelar
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50.0, vertical: 20.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                // Botão Adicionar Pastel
                ElevatedButton(
                  onPressed: () {
                    final List<String> ingredientes;
                    if (_selectedPastelType == PastelType.pizza) {
                      ingredientes = ['Pizza'];
                    } else if (_selectedPastelType == PastelType.misto) {
                      ingredientes = ['Misto'];
                    } else {
                      // Coleta apenas os ingredientes que foram marcados
                      ingredientes = _ingredientesSelecionados.keys
                          .where(
                              (key) => _ingredientesSelecionados[key] == true)
                          .toList();
                    }

                    // Prepara o resultado para retorno
                    final resultado = {
                      'quantidade': _quantidade,
                      'ingredientes': ingredientes,
                      // Passa a observação do controlador, garantindo que seja string vazia se estiver vazia
                      'observacoesItem':
                          (_observacoesController.text.trim().isEmpty)
                              ? ''
                              : _observacoesController.text.trim(),
                    };

                    Navigator.of(context).pop(resultado);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50.0, vertical: 20.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Adicionar Pastel',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
