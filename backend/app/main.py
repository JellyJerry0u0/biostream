@app.post("/auth/signup")
async def signup(user: UserCreate):
    # 1. 사용자가 이미 존재하는지 확인
    # 2. 비밀번호 해싱: hashed_pw = hash_password(user.password)
    # 3. DB에 저장
    return {"message": "회원가입 성공"}

@app.post("/auth/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    # 1. DB에서 유저 조회
    # 2. 비밀번호 검증: verify_password(form_data.password, user.hashed_pw)
    # 3. JWT 발급
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}