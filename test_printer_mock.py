import datetime
import textwrap

class ThermalPrinterMock:
    CMD_INIT = b'\x1B\x40'
    CMD_FEED_LINES = b'\x1B\x64\x03'
    CMD_CUT = b'\x1D\x56\x00'
    CMD_BOLD_ON = b'\x1B\x45\x01'
    CMD_BOLD_OFF = b'\x1B\x45\x00'
    CMD_SIZE_2X = b'\x1D\x21\x11'
    CMD_SIZE_NORMAL = b'\x1D\x21\x00'

    LARGURA_MAX = 48
    LINHA_DIVISORA = "-" * LARGURA_MAX
    LINHA_DUPLA = "=" * LARGURA_MAX
    CODIFICACAO = 'cp850' 

    def gerar_string_impressao_48col(self, dados_pedido: dict) -> str:
        output = []
        
        # Decodifica comandos para string para concatenar corretamente
        bold_on = self.CMD_BOLD_ON.decode(self.CODIFICACAO)
        bold_off = self.CMD_BOLD_OFF.decode(self.CODIFICACAO)
        size_2x = self.CMD_SIZE_2X.decode(self.CODIFICACAO)
        size_normal = self.CMD_SIZE_NORMAL.decode(self.CODIFICACAO)
        
        # --- 1. CABEÇALHO ---
        titulo = "PEDIDO - PASTELARIA GAUCHA".center(self.LARGURA_MAX)
        output.append(f"{bold_on}{titulo}{bold_off}")
        output.append(self.LINHA_DUPLA)
        
        # Informações do Pedido e Data
        num_pedido = dados_pedido.get('numero_pedido', 'N/A')
        output.append(f"{size_2x}{bold_on}PEDIDO: {num_pedido}{bold_off}{size_normal}")
        
        output.append(f"DATA: {datetime.datetime.now().strftime('%d/%m/%Y %H:%M')}")
        output.append(self.LINHA_DIVISORA)
        
        # ... (rest of the logic is less relevant for this test, but let's include a bit)
        output.append("QTD. ITEM/OBSERVACOES             TOTAL")
        output.append(self.LINHA_DIVISORA)
        
        return "\n".join(output)

def test_formatting():
    printer = ThermalPrinterMock()
    
    dados_pedido = {
        'numero_pedido': '12345',
        'total_pedido': 50.00,
        'itens': []
    }
    
    output = printer.gerar_string_impressao_48col(dados_pedido)
    
    print("--- Output Repr ---")
    print(repr(output))
    
    # Check if the correct escape sequences are present
    expected_bold_on = '\x1bE\x01'
    expected_size_2x = '\x1d!\x11'
    
    if expected_bold_on in output:
        print("SUCCESS: Bold ON command found.")
    else:
        print("FAILURE: Bold ON command NOT found.")
        
    if expected_size_2x in output:
        print("SUCCESS: Size 2X command found.")
    else:
        print("FAILURE: Size 2X command NOT found.")

if __name__ == "__main__":
    test_formatting()
