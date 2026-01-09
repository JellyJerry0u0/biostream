from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()

class RegisterRequest(BaseModel):
    email: str
    password: str
    nickname: str

class LoginRequest(BaseModel):
    email: str
    password: str

@router.post("/register")
def register(req: RegisterRequest):
    # TODO: 실제 DB 저장 구현
    return {"message": "registered (placeholder)", "email": req.email}

@router.post("/login")
def login(req: LoginRequest):
    # TODO: 실제 인증 구현
    return {"access_token": "fake-token", "token_type": "bearer"}
