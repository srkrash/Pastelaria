import customtkinter as ctk
import subprocess
import threading
import sys
import os
import signal
import queue
from datetime import datetime

# Configuração do tema
ctk.set_appearance_mode("System")
ctk.set_default_color_theme("dark-blue")

class ServerGUI(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Servidor Pastelaria")
        self.geometry("800x600")
        
        # Configuração do Grid
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        # Variáveis de Estado
        self.process = None
        self.is_running = False
        self.log_queue = queue.Queue()

        # Título
        self.label_title = ctk.CTkLabel(self, text="Controle do Servidor", font=ctk.CTkFont(size=24, weight="bold"))
        self.label_title.grid(row=0, column=0, padx=20, pady=(20, 10))

        # Frame de Controle (Botões e Status)
        self.frame_controls = ctk.CTkFrame(self)
        self.frame_controls.grid(row=1, column=0, padx=20, pady=10, sticky="ew")
        self.frame_controls.grid_columnconfigure((0, 1, 2), weight=1)

        # Botão Iniciar
        self.btn_start = ctk.CTkButton(self.frame_controls, text="Iniciar Servidor", command=self.start_server, fg_color="green", hover_color="darkgreen")
        self.btn_start.grid(row=0, column=0, padx=20, pady=20)

        # Botão Parar
        self.btn_stop = ctk.CTkButton(self.frame_controls, text="Parar Servidor", command=self.stop_server, fg_color="red", hover_color="darkred", state="disabled")
        self.btn_stop.grid(row=0, column=1, padx=20, pady=20)

        # Indicador de Status
        self.lbl_status = ctk.CTkLabel(self.frame_controls, text="Status: Parado", text_color="red", font=ctk.CTkFont(size=16, weight="bold"))
        self.lbl_status.grid(row=0, column=2, padx=20, pady=20)

        # Área de Logs
        self.textbox_logs = ctk.CTkTextbox(self, font=ctk.CTkFont(family="Consolas", size=12))
        self.textbox_logs.grid(row=2, column=0, padx=20, pady=(0, 20), sticky="nsew")
        self.textbox_logs.insert("0.0", "Logs do servidor aparecerão aqui...\n")
        self.textbox_logs.configure(state="disabled")

        # Loop de atualização da UI para logs
        self.after(100, self.update_logs)

    def start_server(self):
        if self.is_running:
            return

        self.log("Iniciando servidor...")
        
        # Caminho para o interpretador Python atual e o script app.py
        python_exe = sys.executable
        script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app.py")
        cmd = [python_exe, script_path]
        cwd = None
        print(f"Iniciando servidor: {script_path}")

        try:
            # Inicia o processo em background, redirecionando stdout e stderr
            # CREATE_NO_WINDOW flag para não abrir janelas extras no Windows
            creationflags = 0
            if os.name == 'nt':
                creationflags = subprocess.CREATE_NO_WINDOW

            # Configura variável de ambiente para não bufferizar saída
            env = os.environ.copy()
            env["PYTHONUNBUFFERED"] = "1"

            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                creationflags=creationflags,
                env=env,
                cwd=cwd
            )

            self.is_running = True
            self.update_ui_state(running=True)

            # Threads para ler stdout e stderr
            threading.Thread(target=self.read_output, args=(self.process.stdout, "STDOUT"), daemon=True).start()
            threading.Thread(target=self.read_output, args=(self.process.stderr, "STDERR"), daemon=True).start()

        except Exception as e:
            self.log(f"Erro ao iniciar servidor: {e}")
            self.is_running = False
            self.update_ui_state(running=False)

    def stop_server(self):
        if not self.is_running or not self.process:
            return

        self.log("Parando servidor...")
        
        # Tenta terminar o processo gentilmente
        self.process.terminate()
        
        # Aguarda um pouco e força se necessário (opcional, aqui simplificado)
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()

        self.process = None
        self.is_running = False
        self.update_ui_state(running=False)
        self.log("Servidor parado.")

    def read_output(self, pipe, source):
        """Lê a saída do processo e coloca na fila de logs."""
        try:
            for line in iter(pipe.readline, ''):
                if line:
                    self.log_queue.put(line)
                else:
                    break
        except Exception:
            pass
        finally:
            pipe.close()

    def update_logs(self):
        """Lê da fila e atualiza a caixa de texto."""
        while not self.log_queue.empty():
            try:
                line = self.log_queue.get_nowait()
                self.textbox_logs.configure(state="normal")
                self.textbox_logs.insert("end", line)
                self.textbox_logs.see("end") # Auto-scroll
                self.textbox_logs.configure(state="disabled")
            except queue.Empty:
                break
        
        # Verifica se o processo morreu inesperadamente
        if self.is_running and self.process and self.process.poll() is not None:
            self.is_running = False
            self.update_ui_state(running=False)
            self.log("Servidor encerrou inesperadamente.")

        self.after(100, self.update_logs)

    def update_ui_state(self, running):
        if running:
            self.btn_start.configure(state="disabled", fg_color="gray")
            self.btn_stop.configure(state="normal", fg_color="red")
            self.lbl_status.configure(text="Status: Rodando", text_color="green")
        else:
            self.btn_start.configure(state="normal", fg_color="green")
            self.btn_stop.configure(state="disabled", fg_color="gray")
            self.lbl_status.configure(text="Status: Parado", text_color="red")

    def log(self, message):
        timestamp = datetime.now().strftime("[%H:%M:%S] ")
        self.log_queue.put(timestamp + message + "\n")

    def on_closing(self):
        if self.is_running:
            self.stop_server()
        self.destroy()

if __name__ == "__main__":
    app = ServerGUI()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()
