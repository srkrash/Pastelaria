import win32print # type: ignore
import win32api # type: ignore
import textwrap
import datetime
import os

# Constante de largura máxima para a impressora



class ThermalPrinter:
    """
    Classe otimizada para impressão RAW em impressoras térmicas (48 colunas, ESC/POS).
    """
    # Comandos ESC/POS básicos (em bytes)
    # ----------------------------------------------------------------
    # 1. Comando de Inicialização (limpa buffers, reseta configurações)
    CMD_INIT = b'\x1B\x40'  # ESC @
    # 2. Comando para avanço de 3 linhas (para soltar o papel e cortar)
    CMD_FEED_LINES = b'\x1B\x64\x03' # ESC d 3
    # 3. Comando de Corte Total do Papel (Corte completo, se suportado)
    CMD_CUT = b'\x1D\x56\x00' # GS V 0 
    # 4. Comando para selecionar modo de impressão em negrito
    CMD_BOLD_ON = b'\x1B\x45\x01' # ESC E 1
    CMD_BOLD_OFF = b'\x1B\x45\x00' # ESC E 0
    LARGURA_MAX = 48
    LINHA_DIVISORA = "-" * LARGURA_MAX
    LINHA_DUPLA = "=" * LARGURA_MAX
    # ----------------------------------------------------------------
    
    # Recomenda-se usar 'cp850' ou 'cp437' para compatibilidade com a Elgin/POS
    # Se caracteres especiais estiverem errados, tente 'cp437'
    CODIFICACAO = 'cp850' 

    def __init__(self, impressora_nome):
        """
        Inicializa a classe, exigindo o nome da impressora térmica.

        :param impressora_nome: O nome exato da impressora no Windows.
        """
        self.impressora = impressora_nome
        print(f"Impressora térmica selecionada: {self.impressora}")
        
    def gerar_string_impressao_48col(self, dados_pedido: dict) -> str:
        """
        Gera uma string formatada para impressão em 48 colunas a partir dos dados do pedido.

        :param dados_pedido: Dicionário com a estrutura de dados do pedido.
        :return: String formatada pronta para ser enviada à impressora.
        """
        output = []
        
        # --- 1. CABEÇALHO ---
        
        # Centraliza o título
        titulo = "PEDIDO - PASTELARIA GAUCHA".center(self.LARGURA_MAX)
        output.append(titulo)
        output.append(self.LINHA_DUPLA)
        
        # Informações do Pedido e Data
        output.append(f"{self.CMD_BOLD_ON}PEDIDO: {dados_pedido.get('numero_pedido', 'N/A'):<17}{self.CMD_BOLD_OFF} DATA: {datetime.datetime.now().strftime('%d/%m/%Y %H:%M')}")
        output.append(self.LINHA_DIVISORA)
        
        # --- 2. DETALHES DOS ITENS ---
        
        # Cabeçalho da tabela de itens (Ajuste de colunas: 4 + 32 + 5 + 7 = 48)
        output.append("QTD. ITEM/OBSERVACOES             TOTAL")
        output.append(self.LINHA_DIVISORA)
        
        for item in dados_pedido.get('itens', []):
            quantidade = item.get('quantidade', 1)
            produto_nome = item.get('produto_nome', 'Produto Desconhecido')
            preco_total_item = item.get('quantidade', 0) * item.get('preco', 0)
            
            # Formata o total do item
            preco_formatado = f"{preco_total_item:>.2f}".replace('.', ',')

            # --- Linha Principal do Item (Nome e Preço Total) ---
            # 4 col. (Qtd.) | 37 col. (Nome) | 7 col. (Total) = 48
            
            # Combina QTD e Nome do Produto
            linha_base = f"{quantidade}x {produto_nome}"
            
            # Trunca o nome do item e preenche o espaço
            nome_item_formatado = linha_base.ljust(self.LARGURA_MAX - 7) 
            
            # Junta tudo na linha (Garantindo 48 colunas)
            linha_final = nome_item_formatado[:self.LARGURA_MAX - 7] + preco_formatado.rjust(7)
            output.append(linha_final)

            # --- Observações do Item (Wrap) ---
            observacoes_item = item.get('observacoes_item', '').strip()
            ingredientes_item = item.get('ingredientes', [])
            
            obs_texto = ""
            if ingredientes_item:
                obs_texto += f"Ingredientes: {', '.join(ingredientes_item)}. "
            if observacoes_item:
                obs_texto += f"Obs: {observacoes_item}"

            if obs_texto:
                # Quebra o texto das observações em várias linhas de 48 colunas
                linhas_obs = textwrap.wrap(f"   * {obs_texto}", self.LARGURA_MAX)
                output.extend(linhas_obs)
                
        output.append(self.LINHA_DIVISORA)

        # --- 3. TOTAIS E OBSERVAÇÕES DO PEDIDO ---
        
        total_pedido = dados_pedido.get('total_pedido', 0.0)
        total_formatado = f"{total_pedido:>.2f}".replace('.', ',')

        # Linha Total (Ajuste para 48 colunas)
        texto_total = "TOTAL GERAL:"
        espaco_total = self.LARGURA_MAX - len(texto_total)
        output.append(texto_total.ljust(espaco_total) + total_formatado.rjust(len(texto_total)))
        output.append(self.LINHA_DUPLA)

        # Observações do Pedido (se existirem)
        observacoes_pedido = dados_pedido.get('observacoes', '').strip()
        if observacoes_pedido:
            output.append("OBSERVACOES DO PEDIDO:")
            # Quebra o texto das observações em várias linhas de 48 colunas
            linhas_obs_pedido = textwrap.wrap(observacoes_pedido, self.LARGURA_MAX)
            output.extend(linhas_obs_pedido)
            output.append(self.LINHA_DIVISORA)

        # Rodapé
        output.append("Obrigado pela compra, volte sempre!")
        output.append("\n" * 2) # Duas linhas em branco para espaçamento final

        return "\n".join(output)

    
    def _send_raw_data(self, data_bytes, titulo_documento="Pastelaria Gaucha"):
        """ Função interna para enviar dados brutos para a impressora. """
        hPrinter = None
        
        try:
            # 1. Abre a impressora
            hPrinter = win32print.OpenPrinter(self.impressora)
            
            # 2. Inicia o documento de impressão (formato RAW)
            hJob = win32print.StartDocPrinter(hPrinter, 1, (titulo_documento, None, "RAW"))
            
            try:
                # 3. Escreve os dados
                win32print.StartPagePrinter(hPrinter)
                win32print.WritePrinter(hPrinter, data_bytes)
                win32print.EndPagePrinter(hPrinter)
                
            finally:
                # 4. Finaliza o documento
                win32print.EndDocPrinter(hJob)
                
            return True
            
        except win32api.error as e:
            print(f"Erro da API Win32 ({e.winerror}): {e.strerror}")
            print(f"Falha ao imprimir na impressora: {self.impressora}")
            return False
        except Exception as e:
            print(f"Erro inesperado: {e}")
            return False
        finally:
            if hPrinter:
                win32print.ClosePrinter(hPrinter)


    def print_string(self, texto_string, titulo_documento="Pastelaria Gaucha "):
        """
        Envia uma string formatada (com quebras de linha '\n') e comandos ESC/POS.

        :param texto_string: A string de texto a ser impressa.
        :param titulo_documento: O nome na fila de impressão.
        :return: True se a impressão foi bem-sucedida.
        """
        
        # 1. Formata e codifica a string
        # Adiciona o comando de inicialização no começo
        raw_data = self.CMD_INIT
        
        # Converte a string de texto para bytes
        raw_data += texto_string.encode(self.CODIFICACAO, errors='ignore')
        
        # 2. Adiciona comandos finais (avanço de papel e corte)
        raw_data += self.CMD_FEED_LINES
        raw_data += self.CMD_CUT
        
        # 3. Envia os dados
        sucesso = self._send_raw_data(raw_data, titulo_documento)
        
        if sucesso:
            print(f"Sucesso: O recibo foi enviado para a impressora '{self.impressora}'.")
        return sucesso

if __name__ == "__main__":
    # --- EXEMPLO DE USO ---

    # ATENÇÃO: SUBSTITUA PELO NOME EXATO DA SUA ELGIN i9 NO WINDOWS
    NOME_IMPRESSORA_ELGIN = "Elgin i9" 

    # Crie uma instância da impressora
    elgin_printer = ThermalPrinter(NOME_IMPRESSORA_ELGIN)

    # Adicionando negrito manualmente (pode não funcionar dependendo do driver)
    TEXTO_RECIBO = (
        elgin_printer.CMD_BOLD_ON.decode(elgin_printer.CODIFICACAO, errors='ignore') + 
        "       LOJA DE TESTES\n" + 
        elgin_printer.CMD_BOLD_OFF.decode(elgin_printer.CODIFICACAO, errors='ignore') +
        "--------------------------------------\n"
        "ITEM | DESCRIÇÃO        | QTD | VALOR\n"
        "--------------------------------------\n"
        "01   | Cerveja Artesanal| 2   | 15,00\n"
        "02   | Salgadinho P     | 1   |  5,50\n"
        "--------------------------------------\n"
        "TOTAL: R$ 35,50\n\n"
        "     OBRIGADO E VOLTE SEMPRE!\n"
    )

    elgin_printer.print_string(TEXTO_RECIBO)