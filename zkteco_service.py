import sys
import os
import time
import json
import socket
import threading
from datetime import datetime

# Importaciones de servicio de Windows
import win32serviceutil
import win32service
import win32event
import servicemanager

# Importaciones para Flask
from flask import Flask, jsonify
from flask_cors import CORS

# Importaciones para ZKTeco
try:
    from zk import ZK
    ZK_AVAILABLE = True
except ImportError:
    ZK_AVAILABLE = False

class ZKTecoService(win32serviceutil.ServiceFramework):
    _svc_name_ = "ZKTecoSync"
    _svc_display_name_ = "ZKTeco Sync Service"
    _svc_description_ = "Servicio de sincronización para dispositivos ZKTeco - API REST en puerto 3322"
    
    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        self.running = True
        
        # Variables del servicio
        self.flask_app = None
        self.flask_thread = None
        self.device_connection = None
        self.system_params = None
        
        # Log del servicio
        self.log_file = os.path.join(os.path.dirname(__file__), 'logs', 'service.log')
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)

    def SvcStop(self):
        """Detener el servicio"""
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)
        self.running = False
        self.log_service("Servicio detenido")

    def SvcDoRun(self):
        """Ejecutar el servicio"""
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, '')
        )
        
        self.log_service("Iniciando servicio ZKTeco Sync...")
        self.main()

    def log_service(self, message):
        """Log del servicio"""
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(f"[{timestamp}] {message}\n")
        except Exception as e:
            print(f"Error escribiendo log: {e}")

    def is_port_in_use(self, port):
        """Verificar si un puerto está en uso"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('127.0.0.1', port)) == 0

    def load_device_params(self):
        """Cargar parámetros del dispositivo desde archivo de configuración"""
        try:
            config_file = os.path.join(os.path.dirname(__file__), 'config', 'device.json')
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    self.system_params = json.load(f)
                    self.log_service(f"Parámetros cargados: {self.system_params.get('name', 'N/A')}")
                    return True
            else:
                self.log_service("No se encontró archivo de configuración")
                return False
        except Exception as e:
            self.log_service(f"Error cargando configuración: {e}")
            return False

    def init_flask_server(self):
        """Inicializar servidor Flask"""
        try:
            self.flask_app = Flask(__name__)
            CORS(self.flask_app)
            
            # Ruta para verificar estado
            @self.flask_app.route('/estado', methods=['GET'])
            def estado():
                return jsonify({
                    'status': 'servicio activo',
                    'instalado': True,
                    'version': '1.1',
                    'tipo': 'servicio_windows',
                    'conectado': self.device_connection is not None,
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
                    'aplicacion': 'ZKTeco Sync Service',
                    'version': '1.1',
                    'estado': 'servicio activo',
                    'tipo': 'servicio_windows',
                    'dispositivo_configurado': bool(self.system_params),
                    'dispositivo_conectado': self.device_connection is not None,
                    'device_info': device_info
                })
            
            @self.flask_app.route('/ping-device', methods=['GET'])
            def ping_device():
                return jsonify({
                    'dispositivo_conectado': self.device_connection is not None,
                    'puede_sincronizar': self.device_connection is not None and bool(self.system_params)
                })

            def run_flask():
                try:
                    self.flask_app.run(
                        port=3322,
                        host='127.0.0.1',
                        debug=False,
                        use_reloader=False,
                        threaded=True
                    )
                except Exception as e:
                    self.log_service(f"Error en servidor Flask: {e}")

            self.flask_thread = threading.Thread(target=run_flask, daemon=True)
            self.flask_thread.start()
            
            self.log_service("Servidor Flask iniciado en puerto 3322")
            return True
            
        except Exception as e:
            self.log_service(f"Error configurando Flask: {e}")
            return False

    def test_device_connection(self):
        """Probar conexión con dispositivo cada 5 minutos"""
        while self.running:
            try:
                if self.system_params and ZK_AVAILABLE:
                    ip = self.system_params.get('ip_address')
                    port = int(self.system_params.get('port', 4370))
                    
                    zk = ZK(ip, port=port, timeout=5)
                    conn = zk.connect()
                    
                    if conn:
                        if not self.device_connection:
                            self.log_service(f"Conectado a dispositivo {ip}:{port}")
                        self.device_connection = conn
                    else:
                        if self.device_connection:
                            self.log_service(f"Perdida conexión con dispositivo {ip}:{port}")
                        self.device_connection = None
                        
                # Esperar 5 minutos antes de la siguiente verificación
                for _ in range(300):  # 5 minutos = 300 segundos
                    if not self.running:
                        break
                    time.sleep(1)
                    
            except Exception as e:
                if self.device_connection:
                    self.log_service(f"Error de conexión: {e}")
                self.device_connection = None
                time.sleep(30)  # Esperar 30 segundos si hay error

    def main(self):
        """Función principal del servicio"""
        try:
            # Verificar si el puerto ya está en uso
            if self.is_port_in_use(3322):
                self.log_service("ERROR: Puerto 3322 ya está en uso. Cerrando servicio.")
                return

            # Cargar configuración del dispositivo
            self.load_device_params()
            
            # Inicializar servidor Flask
            if not self.init_flask_server():
                self.log_service("ERROR: No se pudo iniciar servidor Flask")
                return
            
            # Iniciar monitoreo de dispositivo en hilo separado
            device_thread = threading.Thread(target=self.test_device_connection, daemon=True)
            device_thread.start()
            
            self.log_service("Servicio ZKTeco iniciado correctamente")
            
            # Mantener el servicio ejecutándose
            while self.running:
                # Esperar por señal de parada
                if win32event.WaitForSingleObject(self.hWaitStop, 1000) == win32event.WAIT_OBJECT_0:
                    break
                    
        except Exception as e:
            self.log_service(f"Error en servicio principal: {e}")
        finally:
            if self.device_connection:
                try:
                    self.device_connection.disconnect()
                except:
                    pass
            self.log_service("Servicio finalizado")


def create_default_config():
    """Crear archivo de configuración por defecto"""
    config_dir = os.path.join(os.path.dirname(__file__), 'config')
    os.makedirs(config_dir, exist_ok=True)
    
    config_file = os.path.join(config_dir, 'device.json')
    if not os.path.exists(config_file):
        default_config = {
            "id": "1",
            "name": "Dispositivo ZKTeco",
            "ip_address": "192.168.1.100",
            "port": 4370
        }
        
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(default_config, f, indent=2, ensure_ascii=False)
        
        print(f"Archivo de configuración creado: {config_file}")
        print("IMPORTANTE: Edite este archivo con los datos de su dispositivo")


if __name__ == '__main__':
    if len(sys.argv) == 1:
        # Sin argumentos, crear configuración por defecto
        create_default_config()
        print("\nUso:")
        print("  python zkteco_service.py install    - Instalar servicio")
        print("  python zkteco_service.py remove     - Desinstalar servicio")
        print("  python zkteco_service.py start      - Iniciar servicio")
        print("  python zkteco_service.py stop       - Detener servicio")
        print("  python zkteco_service.py debug      - Ejecutar en modo debug")
    elif 'debug' in sys.argv:
        # Modo debug para pruebas
        print("=== MODO DEBUG ===")
        service = ZKTecoService([])
        service.main()
    else:
        # Comandos de servicio de Windows
        win32serviceutil.HandleCommandLine(ZKTecoService)