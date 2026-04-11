-- BioStream 테스트 설문 데이터 삽입 SQL
-- Docker PostgreSQL에서 실행: docker exec -i biostream_db psql -U myuser -d biostream < tools/insert_test_survey.sql

-- 1. 테스트 사용자 생성 (user_id=1)
INSERT INTO users (id, email, nickname, birthdate, gender, is_pregnant, hashed_password, created_at, updated_at)
VALUES (
    1,
    'test@biostream.com',
    '테스트유저',
    '1995-05-15',
    'female',
    false,
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5Jw5PAiWn/Hwi', -- 비밀번호: test123
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    nickname = EXCLUDED.nickname,
    birthdate = EXCLUDED.birthdate,
    gender = EXCLUDED.gender,
    updated_at = NOW();

-- 2. 테스트 설문 데이터 생성 (lifestyle_id=1)
INSERT INTO lifestyles (
    id,
    user_id,
    outcomes,
    sleep_hours_weekday,
    sleep_hours_weekend,
    sleep_quality_score,
    uv_exposure_10to16,
    sunscreen_frequency,
    sunscreen_reapply,
    outdoor_sports_uv,
    drinking_days_per_week,
    drinking_amount_per_session,
    smoking_status,
    smoking_amount_per_day,
    stress_score,
    aerobic_weekly,
    resistance_weekly,
    height,
    weight,
    skin_type,
    skin_satisfaction,
    target_years,
    created_at
)
VALUES (
    1,
    1,
    '["wrinkle", "elasticity", "pigmentation", "hydration"]'::json,  -- 피부 개선 목표
    6.5,  -- 평일 수면시간
    7.5,  -- 주말 수면시간
    6.0,  -- 수면의 질 (0~10)
    '1~2h',  -- 10~16시 야외 노출
    'most_days',  -- 선크림 사용 빈도
    'sometimes',  -- 선크림 재도포
    'monthly',  -- 야외 스포츠
    '2-3',  -- 주당 음주 일수
    '2-3_glasses',  -- 1회 음주량
    'never',  -- 흡연 상태
    NULL,  -- 하루 흡연량
    7.0,  -- 스트레스 점수 (0~10)
    '3-4',  -- 주당 유산소
    '2',  -- 주당 근력운동
    165.0,  -- 키 (cm)
    55.0,  -- 몸무게 (kg)
    'combination',  -- 피부 타입
    5.0,  -- 피부 만족도 (0~10)
    30,  -- 목표 연도 (고정값)
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    outcomes = EXCLUDED.outcomes,
    sleep_hours_weekday = EXCLUDED.sleep_hours_weekday,
    sleep_hours_weekend = EXCLUDED.sleep_hours_weekend,
    sleep_quality_score = EXCLUDED.sleep_quality_score,
    uv_exposure_10to16 = EXCLUDED.uv_exposure_10to16,
    sunscreen_frequency = EXCLUDED.sunscreen_frequency,
    sunscreen_reapply = EXCLUDED.sunscreen_reapply,
    outdoor_sports_uv = EXCLUDED.outdoor_sports_uv,
    drinking_days_per_week = EXCLUDED.drinking_days_per_week,
    drinking_amount_per_session = EXCLUDED.drinking_amount_per_session,
    smoking_status = EXCLUDED.smoking_status,
    stress_score = EXCLUDED.stress_score,
    aerobic_weekly = EXCLUDED.aerobic_weekly,
    resistance_weekly = EXCLUDED.resistance_weekly,
    height = EXCLUDED.height,
    weight = EXCLUDED.weight,
    skin_type = EXCLUDED.skin_type,
    skin_satisfaction = EXCLUDED.skin_satisfaction,
    target_years = EXCLUDED.target_years;

-- ID 시퀀스 업데이트 (다음 INSERT가 ID 2부터 시작하도록)
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('lifestyles_id_seq', (SELECT MAX(id) FROM lifestyles));

-- 확인
SELECT '✅ 테스트 데이터 삽입 완료!' as status;
SELECT * FROM users WHERE id = 1;
SELECT id, user_id, outcomes, sleep_hours_weekday, skin_type, target_years FROM lifestyles WHERE id = 1;
