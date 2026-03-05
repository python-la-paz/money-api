"""
FastAPI application for Bolivian banknote detection and validation.

Endpoints:
  POST   /analyze        -> Analyze bill image, return full detection result
  POST   /analyze/image  -> Analyze bill image, return annotated PNG directly
  GET    /ranges         -> List configured observed ranges
  POST   /ranges         -> Add an observed range for a denomination
  DELETE /ranges/{denom} -> Remove all ranges for a denomination
  GET    /health         -> Health check
"""

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse, Response
import base64

from detector import analyze_bill, OBSERVED_RANGES
from models import AnalysisResponse, RangeInput

app = FastAPI(
    title="Bolivian Banknote Detector API",
    description=(
        "Detects serial numbers, denomination, and verifies whether a bill "
        "falls within an observed range. Supports 10, 20, and 50 Bs bills."
    ),
    version="1.0.0",
)


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(image: UploadFile = File(...)):
    """
    Analyze a Bolivian banknote image.

    - Detects serial numbers (top right + bottom left)
    - Detects denomination (bottom right): 10, 20, or 50
    - If the serial letter is **B**, checks whether the number falls
      within the configured observed range for that denomination.
    - Returns the annotated image (base64), confidence scores, and all details.
    """
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="File must be an image (JPEG, PNG, etc.)",
        )

    image_bytes = await image.read()

    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Image is empty")

    try:
        result = analyze_bill(image_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing the image: {str(e)}",
        )

    return JSONResponse(content=result)


@app.post("/analyze/image")
async def analyze_image(image: UploadFile = File(...)):
    """
    Same as /analyze but returns the annotated PNG image directly
    (no JSON wrapper). Useful for quick previews.
    """
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    image_bytes = await image.read()

    try:
        result = analyze_bill(image_bytes)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    img_bytes = base64.b64decode(result["annotated_image_base64"])
    return Response(content=img_bytes, media_type="image/png")


@app.get("/ranges")
def list_ranges():
    """List all configured observed ranges by denomination."""
    return {
        denom: [{"start": r[0], "end": r[1]} for r in ranges]
        for denom, ranges in OBSERVED_RANGES.items()
    }


@app.post("/ranges")
def add_range(range_input: RangeInput):
    """
    Add an observed range for a denomination.
    Creates the denomination key if it doesn't exist.
    """
    if range_input.range_start >= range_input.range_end:
        raise HTTPException(
            status_code=400,
            detail="range_start must be less than range_end",
        )

    denom = range_input.denomination
    new_range = (range_input.range_start, range_input.range_end)

    if denom not in OBSERVED_RANGES:
        OBSERVED_RANGES[denom] = []

    if new_range not in OBSERVED_RANGES[denom]:
        OBSERVED_RANGES[denom].append(new_range)

    return {
        "message": f"Range {new_range} added for denomination {denom} Bs",
        "current_ranges": OBSERVED_RANGES[denom],
    }


@app.delete("/ranges/{denomination}")
def delete_ranges(denomination: str):
    """Remove all observed ranges for a denomination."""
    if denomination in OBSERVED_RANGES:
        removed = OBSERVED_RANGES[denomination]
        OBSERVED_RANGES[denomination] = []
        return {
            "message": f"Ranges removed for {denomination} Bs",
            "removed": removed,
        }
    raise HTTPException(
        status_code=404,
        detail=f"Denomination {denomination} not found",
    )


@app.get("/health")
def health():
    """Health check."""
    return {
        "status": "ok",
        "configured_ranges": {k: len(v) for k, v in OBSERVED_RANGES.items()},
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
