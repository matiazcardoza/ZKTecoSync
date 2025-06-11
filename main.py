import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
from datetime import datetime
import json
import requests
import sys
import argparse
import os
from urllib.parse import urljoin

# Importaciones para Flask
from flask import Flask, jsonify
from flask_cors import CORS

try:
    from zk import ZK
    ZK_AVAILABLE = True
except ImportError:
    ZK_AVAILABLE = False

class ZKTecoApp:
    def __init__(self, root):
        self.root = root
        self.root.title("ZKTeco Sync v1.1 - Solo Asistencias")
        self.root.resizable(True, True)
        self.root.resizable(False, False)
        
        # Variables
        self.connection = None
        self.device = None
        self.is_connected = False
        
        # Variables para el servidor Flask
        self.flask_app = None
        self.flask_thread = None

        # OPTIMIZADO: Parsing rápido de parámetros
        self.system_params = self.parse_system_params_fast()
        
        # Variables para dispositivo (ahora desde parámetros)
        self.device_info = None
        self.current_device_id = None
        
        # Iniciar servidor Flask antes de la UI
        self.init_flask_server()
        
        self.setup_ui()
        
        if not ZK_AVAILABLE:
            self.log_text.insert(tk.END, "ADVERTENCIA: Librería 'pyzk' no encontrada.\n")
            self.log_text.insert(tk.END, "Instalar con: pip install pyzk\n\n")

    def init_flask_server(self):
        """Inicializar servidor Flask para verificación remota"""
        try:
            self.flask_app = Flask(__name__)
            CORS(self.flask_app)  # Permitir CORS para peticiones desde el frontend
            
            # Ruta para verificar estado de la aplicación
            @self.flask_app.route('/estado', methods=['GET'])
            def estado():
                return jsonify({
                    'status': 'zkteco activo',
                    'instalado': True,
                    'version': '1.1',
                    'conectado': self.is_connected,
                    'timestamp': datetime.now().isoformat()
                })
            
            @self.flask_app.route('/info', methods=['GET'])
            def info():
                device_info = {}
                if self.system_params:
                    device_info = {
                        'dispositivo': self.system_params.get('name', 'N/A'),
                        'ip': self.system_params.get('ip_address', 'N/A'),
                        'puerto': self.system_params.get('port', 'N/A')
                    }
                
                return jsonify({
                    'aplicacion': 'ZKTeco Sync',
                    'version': '1.1',
                    'estado': 'activo',
                    'dispositivo_configurado': bool(self.system_params),
                    'dispositivo_conectado': self.is_connected,
                    'device_info': device_info
                })
            
            # Ruta para verificar conectividad con dispositivo
            @self.flask_app.route('/ping-device', methods=['GET'])
            def ping_device():
                return jsonify({
                    'dispositivo_conectado': self.is_connected,
                    'puede_sincronizar': self.is_connected and bool(self.system_params)
                })
            
            def iniciar_servidor():
                try:
                    self.flask_app.run(
                        port=3322, 
                        host='127.0.0.1', 
                        debug=False, 
                        use_reloader=False,
                        threaded=True
                    )
                except Exception as e:
                    print(f"Error iniciando servidor Flask: {e}")
            
            # Iniciar servidor en hilo separado
            self.flask_thread = threading.Thread(target=iniciar_servidor, daemon=True)
            self.flask_thread.start()
            
            print("Servidor Flask iniciado en http://127.0.0.1:3322")
            
        except Exception as e:
            print(f"Error configurando servidor Flask: {e}")

    def parse_system_params_fast(self):
        """Parsing optimizado de parámetros del sistema"""
        try:
            # Método más rápido: buscar directamente en sys.argv
            for i, arg in enumerate(sys.argv):
                if arg == '--params-system' and i + 1 < len(sys.argv):
                    param_value = sys.argv[i + 1]
                    try:
                        return json.loads(param_value)
                    except json.JSONDecodeError:
                        # Intentar limpiar el JSON una sola vez
                        cleaned = param_value.strip().replace(' :', ':').replace(': ', ':')
                        try:
                            return json.loads(cleaned)
                        except:
                            return None
            
            # Fallback: variable de entorno
            env_params = os.environ.get('ZKTECO_PARAMS')
            if env_params:
                return json.loads(env_params)
            
            return None
            
        except Exception:
            # Sin prints de debug para mayor velocidad
            return None
    
    def setup_ui(self):
        # Marco principal
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Configurar device_info una sola vez
        if self.system_params:
            self.device_info = {
                'id': self.system_params.get('id'),
                'name': self.system_params.get('name', ''),
                'ip_address': self.system_params.get('ip_address', ''),
                'port': self.system_params.get('port', 4370)
            }
            self.current_device_id = self.device_info['id']

        # Configuración de conexión (simplificada)
        config_frame = ttk.LabelFrame(main_frame, text="Configuración de Conexión", padding="10")
        config_frame.grid(row=0, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        if self.system_params:
            # Layout más eficiente
            labels_data = [
                ("Dispositivo:", self.device_info['name']),
                ("IP:", self.device_info['ip_address']),
                ("Puerto:", str(self.device_info['port']))
            ]
            
            for i, (label_text, value_text) in enumerate(labels_data):
                ttk.Label(config_frame, text=label_text).grid(row=i, column=0, sticky=tk.W, padx=(0, 10))
                value_label = ttk.Label(config_frame, text=value_text, font=('Arial', 9, 'bold') if i == 0 else None)
                value_label.grid(row=i, column=1, sticky=tk.W)
        else:
            error_label = ttk.Label(config_frame, text="No se puede continuar sin parámetros del dispositivo", foreground='red')
            error_label.grid(row=0, column=0, columnspan=2)

        # Mostrar información del servidor Flask
        server_frame = ttk.LabelFrame(main_frame, text="Servidor de Verificación", padding="10")
        server_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(server_frame, text="Servidor activo en:").grid(row=0, column=0, sticky=tk.W)
        ttk.Label(server_frame, text="http://127.0.0.1:3322/estado", font=('Arial', 9, 'bold')).grid(row=0, column=1, sticky=tk.W, padx=(10, 0))

        # Timeout
        ttk.Label(config_frame, text="Timeout (s):").grid(row=3, column=0, sticky=tk.W, padx=(0, 10), pady=(10, 0))
        self.timeout_var = tk.StringVar(value="5")
        timeout_entry = ttk.Entry(config_frame, textvariable=self.timeout_var, width=10)
        timeout_entry.grid(row=3, column=1, sticky=tk.W, pady=(10, 0))

        # Botones de conexión
        button_frame = ttk.Frame(main_frame)
        button_frame.grid(row=2, column=0, columnspan=2, pady=(0, 10))
        
        # Solo habilitar botones si tenemos parámetros
        button_state = "normal" if self.system_params else "disabled"
        
        self.test_btn = ttk.Button(button_frame, text="Probar Conexión", command=self.test_connection, state=button_state)
        self.test_btn.grid(row=0, column=0, padx=(0, 10))
        
        self.connect_btn = ttk.Button(button_frame, text="Conectar", command=self.connect_device, state=button_state)
        self.connect_btn.grid(row=0, column=1, padx=(0, 10))
        
        self.disconnect_btn = ttk.Button(button_frame, text="Desconectar", command=self.disconnect_device, state="disabled")
        self.disconnect_btn.grid(row=0, column=2)
        
        # Indicador de estado
        status_frame = ttk.Frame(main_frame)
        status_frame.grid(row=3, column=0, columnspan=2, pady=(0, 10))
        
        ttk.Label(status_frame, text="Estado:").grid(row=0, column=0, padx=(0, 10))
        self.status_var = tk.StringVar(value="Desconectado")
        self.status_label = ttk.Label(status_frame, textvariable=self.status_var, foreground="red")
        self.status_label.grid(row=0, column=1)
        
        # Botón de extracción de asistencias únicamente
        data_frame = ttk.LabelFrame(main_frame, text="Extracción y Sincronización", padding="10")
        data_frame.grid(row=4, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.extract_attendance_btn = ttk.Button(data_frame, text="Extraer y Enviar Asistencias", command=self.extract_attendance, state="disabled")
        self.extract_attendance_btn.grid(row=0, column=0)
        
        # Log de eventos
        log_frame = ttk.LabelFrame(main_frame, text="Log de Eventos", padding="10")
        log_frame.grid(row=5, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(0, 10))
        
        # Texto con scrollbar
        log_scroll_frame = ttk.Frame(log_frame)
        log_scroll_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        self.log_text = tk.Text(log_scroll_frame, height=15, width=70)
        scrollbar = ttk.Scrollbar(log_scroll_frame, orient="vertical", command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=scrollbar.set)
        
        self.log_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        scrollbar.grid(row=0, column=1, sticky=(tk.N, tk.S))
        
        # Botón para limpiar log
        ttk.Button(log_frame, text="Limpiar Log", command=self.clear_log).grid(row=1, column=0, pady=(10, 0))
        
        # Configurar weights para redimensionamiento
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(5, weight=1)
        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)
        log_scroll_frame.columnconfigure(0, weight=1)
        log_scroll_frame.rowconfigure(0, weight=1)
        
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        
        # Log inicial - OPTIMIZADO
        self.log("Aplicación iniciada - Solo sincronización de asistencias")
        self.log("Servidor Flask iniciado en puerto 3322")
        if ZK_AVAILABLE:
            self.log("Librería ZK cargada correctamente")
        else:
            self.log("ADVERTENCIA: Instalar con 'pip install pyzk requests flask flask-cors'")
        
        # Log de parámetros - SIMPLIFICADO
        if self.system_params:
            self.log(f"✓ Dispositivo configurado: {self.device_info['name']} ({self.device_info['ip_address']}:{self.device_info['port']})")
        else:
            self.log("✗ No se recibieron parámetros del sistema")

    def log(self, message):
        """Agregar mensaje al log con timestamp"""
        try:
            if hasattr(self, 'log_text') and self.log_text:
                timestamp = datetime.now().strftime("%H:%M:%S")
                self.root.after(0, lambda: self._safe_log_insert(timestamp, message))
            else:
                print(f"[LOG] {message}")
        except Exception as e:
            print(f"[ERROR LOG] {message} - Error: {e}")

    def _safe_log_insert(self, timestamp, message):
        """Insertar mensaje en el log de forma segura"""
        try:
            self.log_text.insert(tk.END, f"[{timestamp}] {message}\n")
            self.log_text.see(tk.END)
            self.root.update_idletasks()
        except Exception as e:
            print(f"[ERROR LOG INSERT] {message} - Error: {e}")
    
    def clear_log(self):
        """Limpiar el log"""
        self.log_text.delete(1.0, tk.END)
    
    def test_connection(self):
        """Probar conexión con el dispositivo - OPTIMIZADO"""
        if not ZK_AVAILABLE:
            messagebox.showerror("Error", "Librería pyzk no está instalada")
            return
            
        if not self.system_params:
            messagebox.showerror("Error", "No hay parámetros de dispositivo disponibles")
            return
            
        def test_conn():
            try:
                self.test_btn.config(state="disabled")
                self.log("Probando conexión...")
                
                ip = self.device_info['ip_address']
                port = int(self.device_info['port'])
                timeout = int(self.timeout_var.get())
                
                # Log reducido para mayor velocidad
                self.log(f"Conectando a {ip}:{port}")
                
                zk = ZK(ip, port=port, timeout=timeout)
                conn = zk.connect()
                
                if conn:
                    # Obtener solo información de asistencias
                    try:
                        attendance_count = len(conn.get_attendance())
                        
                        conn.disconnect()
                        
                        self.log("✓ Conexión exitosa!")
                        self.log(f"  - Registros de asistencia: {attendance_count}")
                        
                        messagebox.showinfo("Éxito", "Conexión establecida correctamente")
                    except Exception as e:
                        conn.disconnect()
                        self.log(f"✓ Conexión establecida (error obteniendo detalles: {str(e)})")
                        messagebox.showinfo("Éxito", "Conexión establecida correctamente")
                else:
                    self.log("✗ Error: No se pudo establecer conexión")
                    messagebox.showerror("Error", "No se pudo conectar al dispositivo")
                    
            except Exception as e:
                self.log(f"✗ Error de conexión: {str(e)}")
                messagebox.showerror("Error", f"Error de conexión: {str(e)}")
            finally:
                self.test_btn.config(state="normal")
        
        # Ejecutar en hilo separado
        threading.Thread(target=test_conn, daemon=True).start()
    
    def connect_device(self):
        """Conectar al dispositivo"""
        if not ZK_AVAILABLE:
            messagebox.showerror("Error", "Librería pyzk no está instalada")
            return
            
        if not self.system_params:
            messagebox.showerror("Error", "No hay parámetros de dispositivo disponibles")
            return
            
        def connect():
            try:
                self.connect_btn.config(state="disabled")
                self.log("Conectando al dispositivo...")
                
                ip = self.device_info['ip_address']
                port = int(self.device_info['port'])
                timeout = int(self.timeout_var.get())
                
                self.device = ZK(ip, port=port, timeout=timeout)
                self.connection = self.device.connect()
                
                if self.connection:
                    self.is_connected = True
                    self.status_var.set("Conectado")
                    self.status_label.config(foreground="green")
                    
                    # Habilitar solo botón de extracción de asistencias
                    self.extract_attendance_btn.config(state="normal")
                    self.disconnect_btn.config(state="normal")
                    
                    self.log("✓ Dispositivo conectado exitosamente")
                    messagebox.showinfo("Éxito", "Dispositivo conectado correctamente")
                else:
                    self.log("✗ Error: No se pudo conectar")
                    messagebox.showerror("Error", "No se pudo conectar al dispositivo")
                    
            except Exception as e:
                self.log(f"✗ Error de conexión: {str(e)}")
                messagebox.showerror("Error", f"Error de conexión: {str(e)}")
            finally:
                if not self.is_connected:
                    self.connect_btn.config(state="normal")
        
        threading.Thread(target=connect, daemon=True).start()
    
    def disconnect_device(self):
        """Desconectar del dispositivo"""
        try:
            if self.connection:
                self.connection.disconnect()
                self.connection = None
                self.device = None
                
            self.is_connected = False
            self.status_var.set("Desconectado")
            self.status_label.config(foreground="red")
            
            # Deshabilitar botón de asistencias
            self.extract_attendance_btn.config(state="disabled")
            self.disconnect_btn.config(state="disabled")
            self.connect_btn.config(state="normal")
            
            self.log("Dispositivo desconectado")
            
        except Exception as e:
            self.log(f"Error al desconectar: {str(e)}")
    
    def extract_attendance(self):
        """Extraer registros de asistencia y enviar a la nube"""
        if not self.connection:
            return
            
        def extract():
            try:
                self.extract_attendance_btn.config(state="disabled")
                self.log("Extrayendo registros de asistencia...")
                
                attendance = self.connection.get_attendance()
                
                if attendance:
                    attendance_data = []
                    for record in attendance:
                        attendance_data.append({
                            'uid': record.uid,
                            'id': record.user_id,
                            'timestamp': record.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
                            'state': record.status,
                            'type': record.punch
                        })
                    
                    self.log(f"✓ {len(attendance)} registros extraídos del dispositivo")
                    
                    # Enviar a la nube
                    cloud_success = self.send_data_to_cloud('attendance', attendance_data, '/api/zkteco/attendance')
                    
                    # Mensaje de resultado
                    if cloud_success:
                        messagebox.showinfo("Éxito", "Asistencias sincronizadas correctamente")
                        self.log("✓ Sincronización completada exitosamente")
                    else:
                        messagebox.showerror("Error", "No se pudo sincronizar las asistencias")
                        
                else:
                    self.log("No se encontraron registros de asistencia")
                    messagebox.showinfo("Información", "No se encontraron registros de asistencia en el dispositivo")
                    
            except Exception as e:
                self.log(f"✗ Error extrayendo asistencias: {str(e)}")
                messagebox.showerror("Error", f"Error extrayendo asistencias: {str(e)}")
            finally:
                self.extract_attendance_btn.config(state="normal")
        
        threading.Thread(target=extract, daemon=True).start()

    def send_data_to_cloud(self, data_type, data, endpoint):
        """Enviar solo los datos a Laravel API"""
        try:
            self.log(f"Enviando {data_type} a la nube...")
            
            # URL base de api Local
            #base_url = "http://localhost:8000/api/zkteco/attendance"
            # URL bade de api producción
            base_url = "https://sistemas.regionpuno.gob.pe/asiss-api/api/zkteco/attendance"

            url = urljoin(base_url, endpoint)
            
            # Payload simplificado - solo los datos
            payload = data  # Directamente el array de datos
            
            # Headers para Laravel
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            }
            
            # Log para debugging
            self.log(f"Enviando a: {url}")
            self.log(f"Cantidad de registros: {len(data)}")
            
            # Hacer la petición POST
            response = requests.post(
                url, 
                json=payload,  # Enviar directamente el array
                headers=headers,
                timeout=60
            )
            
            # Log de respuesta
            self.log(f"Código de respuesta: {response.status_code}")
            
            if response.status_code == 200:
                try:
                    response_data = response.json()
                    self.log(f"✓ {data_type.title()} enviados exitosamente")
                    # Si Laravel devuelve información adicional
                    if isinstance(response_data, dict) and 'message' in response_data:
                        self.log(f"  - Respuesta: {response_data['message']}")
                    return True
                except:
                    # Si Laravel no devuelve JSON, pero el status es 200
                    self.log(f"✓ {data_type.title()} enviados exitosamente")
                    return True
            else:
                try:
                    error_data = response.json()
                    self.log(f"✗ Error HTTP {response.status_code}: {error_data.get('message', 'Error desconocido')}")
                except:
                    self.log(f"✗ Error HTTP {response.status_code}: {response.text[:200]}")
                return False
                
        except requests.exceptions.Timeout:
            self.log(f"✗ Timeout enviando a la nube (60s)")
            return False
        except requests.exceptions.ConnectionError:
            self.log(f"✗ Error de conexión con el servidor")
            return False
        except Exception as e:
            self.log(f"✗ Error enviando a la nube: {str(e)}")
            return False


def main():
    root = tk.Tk()
    app = ZKTecoApp(root)
    
    # Manejo del cierre de ventana
    def on_closing():
        if app.is_connected:
            app.disconnect_device()
        root.destroy()
    
    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()

if __name__ == "__main__":
    main()