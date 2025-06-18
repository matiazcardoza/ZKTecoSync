#!/usr/bin/env python3
"""
ZKTeco Service - Servicio de consola mejorado para instalación silenciosa
Uso: 
    python zkteco_service.py start    - Iniciar servicio
    python zkteco_service.py stop     - Detener servicio
"""

import sys
import time
import signal
import threading
import requests
import socket
import os
import subprocess
import json
from datetime import datetime
from flask import Flask, jsonify, request
from flask_cors import CORS
import argparse
import logging

class ZKTecoService:
    def __init__(self):
        self.flask_app = None
        self.flask_thread = None
        self.running = False
        self.port = 3322
        self.host = "127.0.0.1"
        self.start_time = None
        
        # Variable para control del servicio
        self.shutdown_event = threading.Event()
        
        # Configurar logging mínimo
        self.setup_logging()
        
        # Detectar si estamos en un instalador
        self.is_installer_mode = self.detect_installer_mode()
        
    def detect_installer_mode(self):
        """Detectar si estamos siendo ejecutados desde un instalador"""
        # Verificar variables de entorno del instalador
        installer_vars = ['INNO_SETUP', 'SETUP_RUNNING', 'TEMP']
        
        # Si hay procesos de instalador ejecutándose
        try:
            import psutil
            for proc in psutil.process_iter(['name']):
                proc_name = proc.info['name'].lower()
                if any(installer in proc_name for installer in ['setup', 'install', 'inno']):
                    return True
        except:
            pass
            
        # Verificar si el directorio padre contiene archivos de instalación
        try:
            parent_dir = os.path.dirname(os.path.abspath(__file__))
            files = os.listdir(parent_dir)
            installer_files = [f for f in files if any(ext in f.lower() for ext in ['.iss', 'setup', 'install'])]
            if installer_files:
                return True
        except:
            pass
            
        return False
        
    def setup_logging(self):
        """Configurar logging básico"""
        # Desactivar logs de Flask
        log = logging.getLogger('werkzeug')
        log.setLevel(logging.ERROR)
        
        # Configurar logger principal
        logging.basicConfig(level=logging.ERROR)
        self.logger = logging.getLogger(__name__)
    
    def check_port_available(self, port):
        """Verificar si el puerto está disponible"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind((self.host, port))
                return True
        except:
            return False
    
    def init_flask_server(self):
        """Inicializar servidor Flask básico"""
        self.flask_app = Flask(__name__)
        CORS(self.flask_app)
        
        # Suprimir logs de Flask completamente
        import logging
        log = logging.getLogger('werkzeug')
        log.setLevel(logging.ERROR)
        
        @self.flask_app.route('/estado', methods=['GET'])
        def estado():
            return jsonify({
                'status': 'zkteco servicio activo',
                'instalado': True,
                'version': '1.0',
                'tipo': 'servicio_windows',
                'timestamp': datetime.now().isoformat(),
                'uptime': int(time.time() - self.start_time) if self.start_time else 0,
                'installer_mode': self.is_installer_mode
            })
        
        @self.flask_app.route('/execute-sync', methods=['POST'])
        def execute_sync():
            """Ejecuta la sincronización con parámetros del dispositivo"""
            try:
                # Obtener datos del dispositivo
                device_data = request.get_json()
                if not device_data:
                    return jsonify({'success': False, 'message': 'No se recibieron datos'}), 400

                # Validar campos requeridos
                required_fields = ['id', 'name', 'ip_address', 'port']
                for field in required_fields:
                    if field not in device_data:
                        return jsonify({'success': False, 'message': f'Campo requerido faltante: {field}'}), 400

                # Buscar ejecutable
                app_path = os.path.join(os.path.dirname(__file__), 'ZKTeco-Sync.exe')
                if not os.path.exists(app_path):
                    app_path = 'C:\\Program Files\\ZKTeco Sync\\ZKTeco-Sync.exe'
                if not os.path.exists(app_path):
                    return jsonify({'success': False, 'message': 'ZKTeco-Sync no encontrada'}), 404

                # Ejecutar aplicación con parámetros
                params = json.dumps(device_data, ensure_ascii=False)
                
                # Debug - log de los parámetros enviados (solo si no está en modo instalador)
                if not self.is_installer_mode:
                    print(f"Ejecutando: {app_path}")
                    print(f"Parámetros: {params}")
                
                subprocess.Popen(
                    [app_path, '--params-system', params],
                    shell=False,
                    creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0
                )
                
                return jsonify({
                    'success': True, 
                    'message': 'Sincronización iniciada',
                    'device_info': {
                        'id': device_data['id'],
                        'name': device_data['name'],
                        'ip': device_data['ip_address'],
                        'port': device_data['port']
                    }
                })
                
            except Exception as e:
                error_msg = f'Error ejecutando sincronización: {str(e)}'
                if not self.is_installer_mode:
                    print(error_msg)
                return jsonify({'success': False, 'message': error_msg}), 500
        
        @self.flask_app.route('/shutdown', methods=['POST'])
        def shutdown():
            """Cerrar servicio"""
            self.shutdown_event.set()
            return jsonify({'message': 'Servicio cerrándose...'})
        
        # Agregar ruta de prueba para debug
        @self.flask_app.route('/test', methods=['GET', 'POST'])
        def test():
            """Ruta de prueba para verificar conectividad"""
            if request.method == 'GET':
                return jsonify({'message': 'Servidor funcionando correctamente', 'method': 'GET'})
            else:
                data = request.get_json() if request.is_json else request.form.to_dict()
                return jsonify({'message': 'POST recibido correctamente', 'data': data, 'method': 'POST'})
    
    def start_service(self):
        """Iniciar el servicio"""
        try:
            # Verificar si el puerto está disponible
            if not self.check_port_available(self.port):
                if not self.is_installer_mode:
                    print(f"✗ Puerto {self.port} ya está en uso")
                return False
            
            self.start_time = time.time()
            
            # Solo mostrar mensajes si no estamos en modo instalador
            if not self.is_installer_mode:
                print("ZKTeco Service v1.0 - Iniciando...")
            
            # Inicializar Flask
            self.init_flask_server()
            
            # Iniciar servidor Flask en thread separado
            def run_flask():
                # Suprimir salida de Flask completamente en modo instalador
                if self.is_installer_mode:
                    import sys
                    from io import StringIO
                    old_stdout = sys.stdout
                    old_stderr = sys.stderr
                    sys.stdout = StringIO()
                    sys.stderr = StringIO()
                
                try:
                    self.flask_app.run(
                        host=self.host,
                        port=self.port,
                        debug=False,
                        use_reloader=False,
                        threaded=True
                    )
                except Exception as e:
                    if not self.is_installer_mode:
                        print(f"Error en Flask: {e}")
                finally:
                    if self.is_installer_mode:
                        sys.stdout = old_stdout
                        sys.stderr = old_stderr
            
            self.flask_thread = threading.Thread(target=run_flask, daemon=True)
            self.flask_thread.start()
            
            # Esperar un momento para que Flask se inicie
            time.sleep(1 if not self.is_installer_mode else 2)
            
            self.running = True
            
            if not self.is_installer_mode:
                print(f"✓ Servidor iniciado en http://{self.host}:{self.port}")
                print("Rutas disponibles:")
                print("  GET  /estado - Estado del servicio")
                print("  POST /execute-sync - Ejecutar sincronización")
                print("  GET/POST /test - Ruta de prueba")
                print("  POST /shutdown - Cerrar servicio")
            
            # Comportamiento diferente según el modo
            if self.is_installer_mode:
                # En modo instalador, ejecutar en segundo plano
                self.run_background_service()
            else:
                # En modo normal, esperar comandos del usuario
                self.run_interactive_service()
            
            return True
            
        except Exception as e:
            if not self.is_installer_mode:
                print(f"✗ Error iniciando servicio: {e}")
            return False
    
    def run_interactive_service(self):
        """Ejecutar servicio en modo interactivo"""
        try:
            print("Servicio ejecutándose. Escribe 'stop' para detener:")
            while not self.shutdown_event.is_set():
                try:
                    user_input = input().strip()
                    if user_input == 'stop':
                        print("✓ Deteniendo servicio...")
                        self.shutdown_event.set()
                        break
                except (EOFError, KeyboardInterrupt):
                    self.shutdown_event.set()
                    break
                time.sleep(0.1)
        except:
            pass
    
    def run_background_service(self):
        """Ejecutar servicio en segundo plano (modo instalador)"""
        try:
            # En modo instalador, solo escuchar señales de cierre
            while not self.shutdown_event.is_set():
                time.sleep(1)
        except:
            pass
    
    def stop_service(self):
        """Detener el servicio"""
        try:
            self.shutdown_event.set()
            self.running = False
            return True
        except Exception as e:
            if not self.is_installer_mode:
                print(f"✗ Error deteniendo servicio: {e}")
            return False
    
    def is_running(self):
        """Verificar si el servicio está ejecutándose"""
        try:
            response = requests.get(f'http://{self.host}:{self.port}/estado', timeout=2)
            return response.status_code == 200
        except:
            return False


def signal_handler(signum, frame):
    """Manejar señales del sistema"""
    sys.exit(0)


def main():
    # Configurar manejo de señales
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    if len(sys.argv) != 2 or sys.argv[1] not in ['start', 'stop']:
        print("Uso:")
        print("  python zkteco_service.py start    - Iniciar servicio")
        print("  python zkteco_service.py stop     - Detener servicio")
        sys.exit(1)
    
    action = sys.argv[1]
    service = ZKTecoService()
    
    if action == 'start':
        # Verificar si ya está ejecutándose
        if service.is_running():
            if not service.is_installer_mode:
                print("✗ El servicio ya está ejecutándose")
            sys.exit(1)
        
        # Iniciar servicio
        try:
            if service.start_service():
                if not service.is_installer_mode:
                    print("✓ Servicio detenido")
                sys.exit(0)
            else:
                if not service.is_installer_mode:
                    print("✗ Error iniciando servicio")
                sys.exit(1)
        except KeyboardInterrupt:
            if not service.is_installer_mode:
                print("✓ Servicio interrumpido por usuario")
            sys.exit(0)
        except Exception as e:
            if not service.is_installer_mode:
                print(f"✗ Error: {e}")
            sys.exit(1)
    
    elif action == 'stop':
        # Verificar si está ejecutándose
        if not service.is_running():
            if not service.is_installer_mode:
                print("✗ El servicio no está ejecutándose")
            sys.exit(1)
        
        # Detener servicio
        try:
            response = requests.post(f'http://{service.host}:{service.port}/shutdown', timeout=5)
            if response.status_code == 200:
                if not service.is_installer_mode:
                    print("✓ Servicio detenido correctamente")
                sys.exit(0)
            else:
                if not service.is_installer_mode:
                    print("✗ Error deteniendo servicio")
                sys.exit(1)
        except Exception as e:
            if not service.is_installer_mode:
                print(f"✗ Error deteniendo servicio: {e}")
            sys.exit(1)


if __name__ == "__main__":
    main()