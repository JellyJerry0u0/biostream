"""
시각자료 생성 도구

리포트 섹션에 대한 차트나 표를 생성합니다.
"""

import json
import base64
from typing import Dict, Any, List, Optional
from datetime import datetime
import matplotlib
matplotlib.use('Agg')  # GUI 백엔드 없이 사용
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import io
import numpy as np

# 한글 폰트 설정 (Linux Docker 환경 고려)
import os
import platform

plt.rcParams['axes.unicode_minus'] = False  # 마이너스 기호 깨짐 방지

# 시스템별 한글 폰트 설정
font_set = False
font_candidates = []

if platform.system() == 'Darwin':  # macOS
    font_candidates = ['AppleGothic', 'Apple SD Gothic Neo', 'Malgun Gothic']
elif platform.system() == 'Linux':  # Linux (Docker)
    # Docker 환경에서는 한글 폰트가 없을 수 있으므로 영어 라벨 사용 권장
    font_candidates = ['DejaVu Sans', 'Liberation Sans', 'sans-serif']
    # 한글 대신 영어로 라벨링하는 것이 안전
else:  # Windows
    font_candidates = ['Malgun Gothic', 'Gulim', 'NanumGothic']

for font in font_candidates:
    try:
        plt.rcParams['font.family'] = font
        # 폰트 테스트
        fig, ax = plt.subplots(figsize=(1, 1))
        ax.text(0.5, 0.5, '테스트', fontsize=10)
        plt.close(fig)
        font_set = True
        print(f"✅ 한글 폰트 설정 성공: {font}")
        break
    except Exception as e:
        continue

if not font_set:
    # 폰트 설정 실패 시 기본 폰트 사용 (한글 깨짐 가능)
    plt.rcParams['font.family'] = 'sans-serif'
    print("⚠️ 한글 폰트 설정 실패. 영어 라벨 사용 권장.")


def generate_visualization(
    section_type: str,
    section_content: str,
    lifestyle_data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    리포트 섹션에 대한 시각자료를 생성합니다.
    
    Args:
        section_type: 섹션 타입 (goals, sleep, uv, lifestyle, activity)
        section_content: 섹션 내용
        lifestyle_data: 사용자 생활습관 데이터
    
    Returns:
        시각자료 정보 (base64 인코딩된 이미지 또는 차트 데이터)
    """
    try:
        visualization_data = None
        chart_type = None
        
        if section_type == "sleep":
            visualization_data = generate_sleep_chart(lifestyle_data)
            chart_type = "bar"
            
        elif section_type == "uv":
            visualization_data = generate_uv_chart(lifestyle_data)
            chart_type = "radar"
            
        elif section_type == "lifestyle":
            visualization_data = generate_lifestyle_chart(lifestyle_data)
            chart_type = "pie"
            
        elif section_type == "activity":
            visualization_data = generate_activity_chart(lifestyle_data)
            chart_type = "bar"
            
        elif section_type == "goals":
            visualization_data = generate_goals_chart(lifestyle_data, section_content)
            chart_type = "progress"
        
        if visualization_data:
            return {
                "success": True,
                "chart_type": chart_type,
                "image_base64": visualization_data["image_base64"],
                "description": visualization_data.get("description", ""),
                "metadata": visualization_data.get("metadata", {})
            }
        else:
            return {
                "success": False,
                "message": f"{section_type} 섹션에 대한 시각자료를 생성할 수 없습니다."
            }
            
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


def generate_sleep_chart(lifestyle_data: Dict[str, Any]) -> Dict[str, Any]:
    """수면 패턴 차트 생성 (영어 라벨 사용 - 한글 폰트 호환성 문제 방지)"""
    fig, ax = plt.subplots(figsize=(8, 5), facecolor='#1A2C16')
    ax.set_facecolor('#1A2C16')
    
    weekday = lifestyle_data.get("sleep_hours_weekday", 0)
    weekend = lifestyle_data.get("sleep_hours_weekend", 0)
    quality = lifestyle_data.get("sleep_quality_score", 0)
    
    # 영어 라벨 사용 (한글 폰트 문제 방지)
    categories = ["Weekday\nSleep", "Weekend\nSleep", "Sleep\nQuality"]
    values = [weekday, weekend, quality * 10]  # 질은 0-10 스케일을 0-100으로
    colors = ['#37EC13', '#2ECC71', '#27AE60']
    
    bars = ax.bar(categories, values, color=colors, alpha=0.7)
    
    # 권장 수면시간 라인 표시
    ax.axhline(y=7, color='r', linestyle='--', alpha=0.5, label='Recommended (7h)')
    ax.axhline(y=8, color='orange', linestyle='--', alpha=0.5, label='Ideal (8h)')
    
    ax.set_ylabel('Hours / Score', fontsize=12, color='white')
    ax.set_title('Sleep Pattern Analysis', fontsize=14, fontweight='bold', color='white')
    ax.legend(facecolor='#1A2C16', edgecolor='white', labelcolor='white')
    ax.grid(axis='y', alpha=0.3, color='white')
    ax.tick_params(axis='x', colors='white')
    ax.tick_params(axis='y', colors='white')
    
    # 값 표시
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}',
                ha='center', va='bottom')
    
    plt.tight_layout()
    
    # 이미지를 base64로 변환
    img_buffer = io.BytesIO()
    plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
    img_buffer.seek(0)
    img_base64 = base64.b64encode(img_buffer.read()).decode('utf-8')
    plt.close()
    
    return {
        "image_base64": img_base64,
        "description": "수면 패턴을 시각화한 차트입니다.",
        "metadata": {
            "weekday_hours": weekday,
            "weekend_hours": weekend,
            "quality_score": quality
        }
    }


def generate_uv_chart(lifestyle_data: Dict[str, Any]) -> Dict[str, Any]:
    """자외선 노출 차트 생성 (영어 라벨 사용)"""
    fig = plt.figure(figsize=(8, 6), facecolor='#1A2C16')
    ax = plt.subplot(111, projection='polar', facecolor='#1A2C16')
    
    # 자외선 노출 지수 (0-5 스케일)
    uv_exposure_map = {"<30m": 1, "30~60": 2, "1~2h": 3, ">2h": 5}
    sunscreen_map = {"never": 5, "sometimes": 3, "most_days": 2, "daily_with_reapply": 1}
    
    uv_exposure = lifestyle_data.get("uv_exposure_10to16", "<30m")
    sunscreen_freq = lifestyle_data.get("sunscreen_frequency", "never")
    
    # 영어 라벨 사용
    categories = ['UV Exposure\n(10-16h)', 'Sunscreen\nFrequency', 'Reapply\nFrequency', 'Outdoor\nSports']
    values = [
        uv_exposure_map.get(uv_exposure, 3),
        6 - sunscreen_map.get(sunscreen_freq, 3),  # 역순 (낮을수록 좋음)
        3,  # 재도포는 기본값
        2 if lifestyle_data.get("outdoor_sports_uv") == "weekly" else 1
    ]
    
    angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist()
    values += values[:1]  # 닫기
    angles += angles[:1]
    
    ax.plot(angles, values, 'o-', linewidth=2, color='#37EC13')
    ax.fill(angles, values, alpha=0.25, color='#37EC13')
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories, color='white')
    ax.set_ylim(0, 5)
    ax.set_title('UV Exposure Assessment', fontsize=14, fontweight='bold', pad=20, color='white')
    ax.grid(True, color='white', alpha=0.3)
    ax.tick_params(colors='white')
    
    plt.tight_layout()
    
    img_buffer = io.BytesIO()
    plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
    img_buffer.seek(0)
    img_base64 = base64.b64encode(img_buffer.read()).decode('utf-8')
    plt.close()
    
    return {
        "image_base64": img_base64,
        "description": "자외선 노출 패턴을 시각화한 레이더 차트입니다.",
        "metadata": {
            "uv_exposure": uv_exposure,
            "sunscreen_frequency": sunscreen_freq
        }
    }


def generate_lifestyle_chart(lifestyle_data: Dict[str, Any]) -> Dict[str, Any]:
    """생활습관 파이 차트 생성 (영어 라벨 사용)"""
    fig, ax = plt.subplots(figsize=(8, 6), facecolor='#1A2C16')
    ax.set_facecolor('#1A2C16')
    
    # 건강 점수 계산 (각 요소별 점수)
    stress = lifestyle_data.get("stress_score", 5)
    stress_score = 10 - stress  # 스트레스는 낮을수록 좋음
    
    drinking_days_map = {"0": 10, "1": 8, "2-3": 6, "4-5": 4, "6-7": 2}
    drinking_days = lifestyle_data.get("drinking_days_per_week", "0")
    drinking_score = drinking_days_map.get(drinking_days, 5)
    
    smoking_map = {"never": 10, "former": 7, "current": 3}
    smoking = lifestyle_data.get("smoking_status", "never")
    smoking_score = smoking_map.get(smoking, 5)
    
    # 영어 라벨 사용
    categories = ['Stress\nManagement', 'Alcohol\nHabits', 'Smoking\nStatus']
    scores = [stress_score, drinking_score, smoking_score]
    colors = ['#37EC13', '#2ECC71', '#27AE60']
    
    wedges, texts, autotexts = ax.pie(scores, labels=categories, colors=colors, autopct='%1.0f',
                                       startangle=90, textprops={'fontsize': 11, 'color': 'white'})
    
    ax.set_title('Lifestyle Assessment', fontsize=14, fontweight='bold', color='white')
    for text in texts:
        text.set_color('white')
    
    plt.tight_layout()
    
    img_buffer = io.BytesIO()
    plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
    img_buffer.seek(0)
    img_base64 = base64.b64encode(img_buffer.read()).decode('utf-8')
    plt.close()
    
    return {
        "image_base64": img_base64,
        "description": "생활습관 요소별 건강 점수를 시각화한 파이 차트입니다.",
        "metadata": {
            "stress_score": stress_score,
            "drinking_score": drinking_score,
            "smoking_score": smoking_score
        }
    }


def generate_activity_chart(lifestyle_data: Dict[str, Any]) -> Dict[str, Any]:
    """활동 패턴 차트 생성 (영어 라벨 사용)"""
    fig, ax = plt.subplots(figsize=(8, 5), facecolor='#1A2C16')
    ax.set_facecolor('#1A2C16')
    
    aerobic_map = {"0": 0, "1-2": 1.5, "3-4": 3.5, "5+": 5}
    resistance_map = {"0": 0, "1": 1, "2": 2, "3+": 3}
    
    aerobic = lifestyle_data.get("aerobic_weekly", "0")
    resistance = lifestyle_data.get("resistance_weekly", "0")
    
    # 영어 라벨 사용
    categories = ["Aerobic\nExercise", "Resistance\nExercise"]
    values = [
        aerobic_map.get(aerobic, 0),
        resistance_map.get(resistance, 0)
    ]
    colors = ['#37EC13', '#2ECC71']
    
    bars = ax.bar(categories, values, color=colors, alpha=0.7)
    
    # 권장 라인
    ax.axhline(y=3, color='orange', linestyle='--', alpha=0.5, label='Recommended (3x/week)')
    
    ax.set_ylabel('Times per Week', fontsize=12, color='white')
    ax.set_title('Exercise Pattern Analysis', fontsize=14, fontweight='bold', color='white')
    ax.legend(facecolor='#1A2C16', edgecolor='white', labelcolor='white')
    ax.grid(axis='y', alpha=0.3, color='white')
    ax.tick_params(axis='x', colors='white')
    ax.tick_params(axis='y', colors='white')
    
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}',
                ha='center', va='bottom')
    
    plt.tight_layout()
    
    img_buffer = io.BytesIO()
    plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
    img_buffer.seek(0)
    img_base64 = base64.b64encode(img_buffer.read()).decode('utf-8')
    plt.close()
    
    return {
        "image_base64": img_base64,
        "description": "운동 패턴을 시각화한 차트입니다.",
        "metadata": {
            "aerobic_weekly": aerobic,
            "resistance_weekly": resistance
        }
    }


def generate_goals_chart(lifestyle_data: Dict[str, Any], section_content: str) -> Dict[str, Any]:
    """목표 달성 진행도 차트 생성 (영어 라벨 사용)"""
    fig, ax = plt.subplots(figsize=(8, 6), facecolor='#1A2C16')
    ax.set_facecolor('#1A2C16')
    
    outcomes = lifestyle_data.get("outcomes", [])
    # 영어 라벨 사용
    outcome_labels = {
        "wrinkle": "Wrinkle",
        "pigmentation": "Pigmentation",
        "hydration": "Hydration",
        "acne": "Acne",
        "redness": "Redness",
        "general_aging": "General Aging"
    }
    
    if not outcomes:
        return None
    
    labels = [outcome_labels.get(o, o.title()) for o in outcomes]
    
    # 현재 상태 점수 (임시로 기본값, 실제로는 섹션 내용 분석 필요)
    current_scores = [50] * len(outcomes)  # 기본 50점
    target_scores = [80] * len(outcomes)  # 목표 80점
    
    x = np.arange(len(labels))
    width = 0.35
    
    bars1 = ax.bar(x - width/2, current_scores, width, label='Current', color='#95A5A6', alpha=0.7)
    bars2 = ax.bar(x + width/2, target_scores, width, label='Target', color='#37EC13', alpha=0.7)
    
    ax.set_ylabel('Score', fontsize=12, color='white')
    ax.set_title('Goals Achievement Status', fontsize=14, fontweight='bold', color='white')
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=45, ha='right', color='white')
    ax.legend(facecolor='#1A2C16', edgecolor='white', labelcolor='white')
    ax.grid(axis='y', alpha=0.3, color='white')
    ax.tick_params(axis='y', colors='white')
    ax.set_ylim(0, 100)
    
    plt.tight_layout()
    
    img_buffer = io.BytesIO()
    plt.savefig(img_buffer, format='png', dpi=150, bbox_inches='tight')
    img_buffer.seek(0)
    img_base64 = base64.b64encode(img_buffer.read()).decode('utf-8')
    plt.close()
    
    return {
        "image_base64": img_base64,
        "description": "주요 목표별 달성 현황을 시각화한 차트입니다.",
        "metadata": {
            "outcomes": outcomes,
            "current_scores": current_scores,
            "target_scores": target_scores
        }
    }
