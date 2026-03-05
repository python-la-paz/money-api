# Money API - Detector de Billetes Bolivianos

API FastAPI para detectar y validar billetes bolivianos.

## Instalación

```bash
# Crear entorno virtual
python -m venv venv

# Activar entorno virtual (Windows)
venv\Scripts\activate

# Instalar dependencias
pip install -r app/requirements.txt
```

## Uso

```bash
# Ejecutar API
cd app
python main.py
```

La API estará disponible en: http://localhost:8000

## Documentación

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Endpoints

- `GET /health` - Health check
- `POST /analyze` - Analizar imagen de billete
- `POST /analyze/image` - Analizar y retornar imagen anotada
- `GET /ranges` - Obtener rangos configurados
- `POST /ranges` - Agregar rango
- `DELETE /ranges/{denomination}` - Eliminar rangos

## Ejemplo de uso

```bash
curl -X POST "http://localhost:8000/analyze" -F "image=@billete.jpg"
```