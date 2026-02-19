from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
import random

app = FastAPI(title="Mock GPU Server")


class GenerateRequest(BaseModel):
    image_url: str
    aging_strength: float


@app.post("/generate")
async def generate(data: GenerateRequest):

    print("📩 Request received:")
    print("Image URL:", data.image_url)
    print("Aging Strength:", data.aging_strength)

    # 실제 diffusion 대신 가짜 URL 생성
    fake_output_url = f"https://fake-bucket.com/aged_image_{random.randint(1000,9999)}.png"

    return {
        "output_url": fake_output_url
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9000)
