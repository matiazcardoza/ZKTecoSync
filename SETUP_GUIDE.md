# ZKTeco Sync - Guía de Configuración

## Requisitos Previos

1. **Python 3.7 o superior** instalado en tu sistema
2. **Visual Studio Code** (ya lo tienes)
3. Dispositivo ZKTeco conectado en la misma red

## Pasos de Instalación

### 1. Preparar el Entorno

Abre una terminal en tu carpeta `ZKTecoSync` y ejecuta:

```bash
# Instalar las dependencias
pip install -r requirements.txt
```

### 2. Estructura del Proyecto

Tu carpeta debería verse así:
```
ZKTecoSync/
├── main.py                 # Aplicación principal
├── requirements.txt        # Dependencias
├── build_exe.bat          # Script para generar .exe
├── SETUP_GUIDE.md         # Esta guía
└── icon.ico               # (opcional) Icono para la app
```

### 3. Configurar el Dispositivo ZKTeco

1. **Conectar el dispositivo** a tu red local
2. **Anotar la IP** del dispositivo (generalmente aparece en la pantalla del dispositivo)
3. **Verificar el puerto** (por defecto es 4370)
4. **Asegurar conectividad** haciendo ping a la IP desde tu PC

### 4. Ejecutar la Aplicación

#### Opción A: Ejecutar directamente con Python
```bash
python main.py
```

#### Opción B: Generar ejecutable .exe
```bash
# En Windows, ejecutar:
build_exe.bat

# O manualmente:
pyinstaller --onefile --windowed --name "ZKTecoSync" main.py
```

El archivo .exe se generará en la carpeta `dist/`

## Uso de la Aplicación

### Panel de Configuración
- **IP del Dispositivo**: Ingresa la IP de tu ZKTeco (ej: 192.168.1.201)
- **Puerto**: Generalmente 4370
- **Timeout**: Tiempo de espera en segundos (recomendado: 5-10)

### Funciones Principales

1. **Probar Conexión**: Verifica si puedes conectarte al dispositivo
2. **Conectar**: Establece conexión persistente
3. **Extraer Usuarios**: Descarga la lista de usuarios registrados
4. **Extraer Asistencias**: Descarga los registros de entrada/salida
5. **Limpiar Datos**: Elimina registros del dispositivo (¡CUIDADO!)

### Archivos de Salida

Los datos se guardan en formato JSON:
- `usuarios_YYYYMMDD_HHMMSS.json`: Lista de usuarios
- `asistencias_YYYYMMDD_HHMMSS.json`: Registros de asistencia

## Solución de Problemas

### Error: "Librería pyzk no encontrada"
```bash
pip install pyzk
```

### Error de conexión
1. Verificar que el dispositivo esté encendido
2. Comprobar la IP y puerto
3. Asegurar que no hay firewall bloqueando
4. Verificar conectividad con: `ping [IP_del_dispositivo]`

### El dispositivo no responde
- Aumentar el timeout a 10-15 segundos
- Verificar que no haya otra aplicación conectada al dispositivo
- Reiniciar el dispositivo ZKTeco

### Generar .exe falla
```bash
# Instalar PyInstaller
pip install pyinstaller

# Ejecutar manualmente
pyinstaller --onefile --windowed main.py
```

## Configuraciones Avanzadas

### Cambiar puerto por defecto
Modifica la línea en `main.py`:
```python
self.port_var = tk.StringVar(value="4370")  # Cambiar aquí
```

### Agregar más campos de extracción
En las funciones `extract_users()` y `extract_attendance()` puedes agregar más campos según tu modelo de ZKTeco.

### Programar extracciones automáticas
Puedes modificar el código para agregar timers que extraigan datos automáticamente.

## Notas Importantes

- **Siempre haz backup** antes de limpiar datos del dispositivo
- La función "Limpiar Datos" es **IRREVERSIBLE**
- Los archivos JSON pueden abrirse con Excel o cualquier editor de texto
- Mantén actualizada la librería `pyzk` para compatibilidad con nuevos modelos

## Soporte

Si tienes problemas:
1. Revisa el log de eventos en la aplicación
2. Verifica la documentación de tu modelo ZKTeco específico
3. Considera usar el software oficial ZKTeco para comparar resultados