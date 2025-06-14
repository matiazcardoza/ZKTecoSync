import threading
import socket
import requests
import sys
from datetime import datetime
from flask import Flask, jsonify, request
from flask_cors import CORS

class ZKTecoServer:
    def __init__(self):
        self.flask_app = None
        self.flask_thread = None
        self.service_running = False
        
        # Verificar si el servicio ya está ejecutándose
        self.check_service_status()
        
        # Solo iniciar servidor Flask si el servicio NO está corriendo
        if not self.service_running:
            self.init_flask_server()
        else:
            print("Servicio ZKTeco ya está ejecutándose en puerto 3322")

    def check_service_status(self):
        """Verificar si el servicio ya está ejecutándose en el puerto 3322"""
        try:
            # Intentar hacer una petición al servicio
            response = requests.get('http://127.0.0.1:3322/estado', timeout=2)
            if response.status_code == 200:
                data = response.json()
                # Verificar si es el servicio (no la aplicación GUI)
                if data.get('tipo') == 'servicio_windows':
                    self.service_running = True
                    print("Servicio ZKTeco detectado ejecutándose")
                    return True
        except:
            pass
        
        # También verificar si el puerto está en uso
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                result = s.connect_ex(('127.0.0.1', 3322))
                if result == 0:
                    self.service_running = True
                    print("Puerto 3322 está en uso (posiblemente por el servicio)")
                    return True
        except:
            pass
        
        self.service_running = False
        return False

    def init_flask_server(self):
        """Inicializar servidor Flask para verificación remota"""
        try:
            self.flask_app = Flask(__name__)
            CORS(self.flask_app)
            
            # Ruta para verificar estado de la aplicación
            @self.flask_app.route('/estado', methods=['GET'])
            def estado():
                return jsonify({
                    'status': 'zkteco activo',
                    'instalado': True,
                    'version': '1.1',
                    'tipo': 'servidor_standalone',
                    'timestamp': datetime.now().isoformat()
                })
            
            @self.flask_app.route('/info', methods=['GET'])
            def info():
                return jsonify({
                    'aplicacion': 'ZKTeco Server',
                    'version': '1.1',
                    'estado': 'activo',
                    'tipo': 'servidor_standalone',
                    'puerto': 3322
                })
            
            # Ruta para cerrar servidor
            @self.flask_app.route('/shutdown', methods=['POST'])
            def shutdown():
                func = request.environ.get('werkzeug.server.shutdown')
                if func is None:
                    raise RuntimeError('Not running with the Werkzeug Server')
                func()
                return jsonify({'message': 'Server shutting down...'})
            
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
            self.flask_thread = threading.Thread(target=iniciar_servidor, daemon=False)
            self.flask_thread.start()
            
            print("Iniciando servidor ZKTeco en puerto 3322...")
            print("✓ Servidor ZKTeco iniciado exitosamente en http://127.0.0.1:3322")
            
        except Exception as e:
            print(f"Error configurando servidor Flask: {e}")

    def mantener_activo(self):
        """Mantener el servidor activo hasta que se ejecute el comando stop"""
        try:
            if self.flask_thread and self.flask_thread.is_alive():
                # Mantener el hilo principal activo sin mostrar mensaje
                self.flask_thread.join()
        except Exception:
            pass

def stop_server():
    """Detener el servidor remotamente"""
    try:
        response = requests.post('http://127.0.0.1:3322/shutdown', timeout=2)
        if response.status_code == 200:
            print("Servidor detenido exitosamente.")
        else:
            print("Error al detener el servidor.")
    except requests.exceptions.ConnectionError:
        print("El servidor no está ejecutándose o ya fue detenido.")
    except Exception as e:
        print(f"Error al intentar detener el servidor: {e}")

def main():
    # Verificar argumentos de línea de comandos
    if len(sys.argv) > 1 and sys.argv[1] == 'stop':
        stop_server()
        return
    
    print("=== Servidor ZKTeco Standalone ===")
    server = ZKTecoServer()
    
    if not server.service_running:
        server.mantener_activo()
    else:
        print("No se puede iniciar: el servicio ya está ejecutándose")

if __name__ == "__main__":
    main()