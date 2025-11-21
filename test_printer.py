from printer import ThermalPrinter
import datetime

def test_formatting():
    printer = ThermalPrinter("Dummy Printer")
    
    dados_pedido = {
        'numero_pedido': '12345',
        'total_pedido': 50.00,
        'itens': [
            {'quantidade': 2, 'produto_nome': 'Pastel Carne', 'preco': 10.00},
            {'quantidade': 1, 'produto_nome': 'Coca Cola', 'preco': 5.00}
        ]
    }
    
    output = printer.gerar_string_impressao_48col(dados_pedido)
    
    print("--- Output Repr ---")
    print(repr(output))
    print("--- Output Print ---")
    print(output)

if __name__ == "__main__":
    test_formatting()
