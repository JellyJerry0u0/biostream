"""
데이터 보호 계층 (Data Protection Layer)
PII 마스킹, 데이터 최소화, 암호화를 제공합니다.
"""
from typing import Dict, Any, List, Optional, Set
from enum import Enum
import re
import json
import hashlib
from datetime import datetime, timedelta
from pydantic import BaseModel, Field
import logging

logger = logging.getLogger(__name__)


# ==================== PII 카테고리 ====================

class PIICategory(str, Enum):
    """개인식별정보 카테고리"""
    NAME = "name"
    EMAIL = "email"
    PHONE = "phone"
    ADDRESS = "address"
    SSN = "ssn"  # Social Security Number
    CREDIT_CARD = "credit_card"
    IP_ADDRESS = "ip_address"
    DATE_OF_BIRTH = "date_of_birth"
    MEDICAL_RECORD = "medical_record"


class SensitivityLevel(str, Enum):
    """데이터 민감도 수준"""
    PUBLIC = "public"          # 공개 가능
    INTERNAL = "internal"      # 내부 사용
    CONFIDENTIAL = "confidential"  # 기밀
    RESTRICTED = "restricted"  # 고도 기밀


# ==================== PII Masking ====================

class PIIMasker:
    """
    개인식별정보 마스킹 처리
    LLM에게 데이터를 전달하기 전에 PII를 제거/마스킹합니다.
    """
    
    # 정규표현식 패턴
    PATTERNS: Dict[PIICategory, str] = {
        PIICategory.EMAIL: r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        PIICategory.PHONE: r'\b(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3,4}[-.\s]?\d{4}\b',
        PIICategory.SSN: r'\b\d{3}-\d{2}-\d{4}\b',
        PIICategory.CREDIT_CARD: r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
        PIICategory.IP_ADDRESS: r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
        PIICategory.DATE_OF_BIRTH: r'\b\d{4}[-/]\d{2}[-/]\d{2}\b',
    }
    
    def __init__(self, masking_char: str = "*"):
        self.masking_char = masking_char
        self.masked_values: Dict[str, str] = {}  # 원본 -> 마스킹 매핑 (복원용)
    
    def mask_text(
        self,
        text: str,
        categories: Optional[List[PIICategory]] = None
    ) -> str:
        """
        텍스트에서 PII 마스킹
        
        Args:
            text: 마스킹할 텍스트
            categories: 마스킹할 PII 카테고리 (None이면 모두)
        
        Returns:
            마스킹된 텍스트
        """
        if not text:
            return text
        
        masked_text = text
        categories_to_mask = categories or list(self.PATTERNS.keys())
        
        for category in categories_to_mask:
            if category in self.PATTERNS:
                pattern = self.PATTERNS[category]
                matches = re.finditer(pattern, masked_text)
                
                for match in matches:
                    original = match.group()
                    # 부분 마스킹 (처음 몇 글자만 보존)
                    if category == PIICategory.EMAIL:
                        masked = self._mask_email(original)
                    elif category == PIICategory.PHONE:
                        masked = self._mask_phone(original)
                    else:
                        masked = self.masking_char * len(original)
                    
                    self.masked_values[masked] = original
                    masked_text = masked_text.replace(original, masked)
                    
                    logger.debug(f"Masked {category}: {original} -> {masked}")
        
        return masked_text
    
    def mask_dict(
        self,
        data: Dict[str, Any],
        sensitive_keys: Set[str] = None
    ) -> Dict[str, Any]:
        """
        딕셔너리에서 민감한 키의 값 마스킹
        
        Args:
            data: 마스킹할 데이터
            sensitive_keys: 민감한 키 집합
        
        Returns:
            마스킹된 데이터
        """
        if sensitive_keys is None:
            sensitive_keys = {
                "name", "email", "phone", "address", "ssn",
                "password", "credit_card", "date_of_birth"
            }
        
        masked_data = data.copy()
        
        for key, value in masked_data.items():
            if key.lower() in sensitive_keys:
                if isinstance(value, str):
                    masked_data[key] = self.mask_text(value)
                elif isinstance(value, dict):
                    masked_data[key] = self.mask_dict(value, sensitive_keys)
                elif isinstance(value, list):
                    masked_data[key] = [
                        self.mask_dict(item, sensitive_keys) if isinstance(item, dict)
                        else self.mask_text(str(item)) if isinstance(item, str)
                        else item
                        for item in value
                    ]
        
        return masked_data
    
    def _mask_email(self, email: str) -> str:
        """이메일 부분 마스킹 (예: user@example.com -> u***@example.com)"""
        if '@' not in email:
            return self.masking_char * len(email)
        
        local, domain = email.split('@', 1)
        masked_local = local[0] + self.masking_char * (len(local) - 1)
        return f"{masked_local}@{domain}"
    
    def _mask_phone(self, phone: str) -> str:
        """전화번호 부분 마스킹 (예: 010-1234-5678 -> 010-****-5678)"""
        # 숫자만 추출
        digits = re.sub(r'\D', '', phone)
        if len(digits) < 4:
            return self.masking_char * len(phone)
        
        # 마지막 4자리만 보존
        masked_digits = self.masking_char * (len(digits) - 4) + digits[-4:]
        
        # 원본 포맷 유지
        result = phone
        for original, masked in zip(digits, masked_digits):
            result = result.replace(original, masked, 1)
        
        return result


# ==================== Data Minimizer ====================

class DataMinimizationPolicy(BaseModel):
    """데이터 최소화 정책"""
    purpose: str  # 데이터 사용 목적
    allowed_fields: Set[str]  # 허용된 필드 목록
    max_records: Optional[int] = None  # 최대 레코드 수
    time_range_days: Optional[int] = None  # 시간 범위 (일)


class DataMinimizer:
    """
    데이터 최소화 프로세서
    필요한 데이터만 LLM에게 전달하여 프라이버시를 보호합니다.
    """
    
    # 목적별 기본 정책
    DEFAULT_POLICIES: Dict[str, DataMinimizationPolicy] = {
        "sleep_analysis": DataMinimizationPolicy(
            purpose="수면 분석",
            allowed_fields={"sleep_hours", "sleep_quality_score", "bedtime", "wake_time"},
            max_records=7,
            time_range_days=7
        ),
        "nutrition_analysis": DataMinimizationPolicy(
            purpose="영양 분석",
            allowed_fields={"calories", "protein", "carbs", "fat", "meal_type", "date"},
            max_records=14,
            time_range_days=14
        ),
        "activity_analysis": DataMinimizationPolicy(
            purpose="활동 분석",
            allowed_fields={"steps", "distance", "calories_burned", "active_minutes", "date"},
            max_records=7,
            time_range_days=7
        ),
    }
    
    def minimize(
        self,
        data: List[Dict[str, Any]],
        purpose: str,
        custom_policy: Optional[DataMinimizationPolicy] = None
    ) -> List[Dict[str, Any]]:
        """
        데이터 최소화 적용
        
        Args:
            data: 원본 데이터
            purpose: 데이터 사용 목적
            custom_policy: 커스텀 정책 (선택사항)
        
        Returns:
            최소화된 데이터
        """
        policy = custom_policy or self.DEFAULT_POLICIES.get(purpose)
        
        if not policy:
            logger.warning(f"No policy found for purpose: {purpose}, using all data")
            return data
        
        minimized_data = []
        
        for record in data:
            # 1. 필드 필터링
            filtered_record = {
                key: value
                for key, value in record.items()
                if key in policy.allowed_fields
            }
            
            # 2. 시간 범위 필터링
            if policy.time_range_days and "date" in filtered_record:
                record_date = self._parse_date(filtered_record["date"])
                if record_date:
                    cutoff_date = datetime.utcnow() - timedelta(days=policy.time_range_days)
                    if record_date < cutoff_date:
                        continue
            
            minimized_data.append(filtered_record)
        
        # 3. 레코드 수 제한
        if policy.max_records:
            minimized_data = minimized_data[:policy.max_records]
        
        logger.info(
            f"Data minimized: {len(data)} -> {len(minimized_data)} records for purpose '{purpose}'"
        )
        
        return minimized_data
    
    def summarize(
        self,
        data: List[Dict[str, Any]],
        summary_fields: Dict[str, str]  # field_name -> aggregation_type (avg, sum, min, max)
    ) -> Dict[str, Any]:
        """
        데이터를 요약하여 프라이버시 보호
        
        Args:
            data: 원본 데이터
            summary_fields: 요약할 필드와 집계 방식
        
        Returns:
            요약된 데이터
        """
        summary = {}
        
        for field, agg_type in summary_fields.items():
            values = [record.get(field) for record in data if field in record]
            values = [v for v in values if v is not None and isinstance(v, (int, float))]
            
            if not values:
                continue
            
            if agg_type == "avg":
                summary[f"{field}_avg"] = sum(values) / len(values)
            elif agg_type == "sum":
                summary[f"{field}_sum"] = sum(values)
            elif agg_type == "min":
                summary[f"{field}_min"] = min(values)
            elif agg_type == "max":
                summary[f"{field}_max"] = max(values)
            elif agg_type == "count":
                summary[f"{field}_count"] = len(values)
        
        summary["record_count"] = len(data)
        
        logger.info(f"Data summarized: {len(data)} records -> {len(summary)} metrics")
        return summary
    
    def _parse_date(self, date_value: Any) -> Optional[datetime]:
        """날짜 파싱 헬퍼"""
        if isinstance(date_value, datetime):
            return date_value
        if isinstance(date_value, str):
            try:
                return datetime.fromisoformat(date_value.replace('Z', '+00:00'))
            except ValueError:
                pass
        return None


# ==================== Encryption Manager ====================

class EncryptionManager:
    """
    암호화 관리자
    종단간 암호화(E2EE) 및 저장 시 암호화를 제공합니다.
    
    Note: 실제 프로덕션 환경에서는 cryptography 라이브러리 사용 권장
    """
    
    def __init__(self, encryption_key: str):
        self.encryption_key = encryption_key
    
    def encrypt_field(self, value: str) -> str:
        """
        필드 값 암호화 (AES-256 시뮬레이션)
        
        실제 구현에서는 cryptography.fernet 사용:
        from cryptography.fernet import Fernet
        f = Fernet(key)
        encrypted = f.encrypt(value.encode())
        """
        # 간단한 해시 기반 암호화 (데모용)
        import base64
        combined = f"{value}:{self.encryption_key}"
        hashed = hashlib.sha256(combined.encode()).digest()
        encrypted = base64.b64encode(hashed).decode()
        
        logger.debug(f"Encrypted field: {value[:10]}... -> {encrypted[:10]}...")
        return encrypted
    
    def decrypt_field(self, encrypted_value: str) -> str:
        """
        필드 값 복호화
        
        Note: 실제 구현 필요
        """
        # 데모용: 복호화는 실제 키 기반 암호화 구현 필요
        logger.warning("Decryption not implemented in demo")
        return "[ENCRYPTED]"
    
    def hash_identifier(self, identifier: str) -> str:
        """
        식별자 해싱 (일방향, 복호화 불가)
        로깅 및 감사에 사용
        """
        return hashlib.sha256(f"{identifier}:{self.encryption_key}".encode()).hexdigest()[:16]


# ==================== Data Protection Pipeline ====================

class DataProtectionPipeline:
    """
    통합 데이터 보호 파이프라인
    PII 마스킹 -> 데이터 최소화 -> 요약을 순차적으로 적용합니다.
    """
    
    def __init__(
        self,
        pii_masker: PIIMasker,
        data_minimizer: DataMinimizer,
        encryption_manager: EncryptionManager
    ):
        self.pii_masker = pii_masker
        self.data_minimizer = data_minimizer
        self.encryption_manager = encryption_manager
    
    def process_for_llm(
        self,
        data: List[Dict[str, Any]],
        purpose: str,
        sensitive_keys: Optional[Set[str]] = None,
        summarize: bool = False,
        summary_fields: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        LLM에게 전달하기 전 데이터 보호 처리
        
        Args:
            data: 원본 데이터
            purpose: 데이터 사용 목적
            sensitive_keys: 마스킹할 키 집합
            summarize: 요약 여부
            summary_fields: 요약 필드 정의
        
        Returns:
            보호 처리된 데이터
        """
        logger.info(f"Starting data protection pipeline for purpose: {purpose}")
        
        # 1. 데이터 최소화
        minimized_data = self.data_minimizer.minimize(data, purpose)
        
        # 2. PII 마스킹
        masked_data = []
        for record in minimized_data:
            masked_record = self.pii_masker.mask_dict(record, sensitive_keys)
            masked_data.append(masked_record)
        
        # 3. 요약 (선택적)
        if summarize and summary_fields:
            result = self.data_minimizer.summarize(masked_data, summary_fields)
        else:
            result = {"records": masked_data, "count": len(masked_data)}
        
        result["purpose"] = purpose
        result["protection_applied"] = True
        
        logger.info(
            f"Data protection completed: {len(data)} -> {len(masked_data)} records"
        )
        
        return result


# ==================== 사용 예시 ====================

if __name__ == "__main__":
    # 예시 데이터
    sample_data = [
        {
            "user_id": 123,
            "name": "홍길동",
            "email": "hong@example.com",
            "phone": "010-1234-5678",
            "sleep_hours": 7.5,
            "sleep_quality_score": 75,
            "bedtime": "23:30",
            "date": "2026-02-01"
        },
        {
            "user_id": 123,
            "name": "홍길동",
            "email": "hong@example.com",
            "phone": "010-1234-5678",
            "sleep_hours": 6.5,
            "sleep_quality_score": 60,
            "bedtime": "00:15",
            "date": "2026-02-02"
        }
    ]
    
    # 파이프라인 초기화
    pii_masker = PIIMasker()
    data_minimizer = DataMinimizer()
    encryption_manager = EncryptionManager("secret-key")
    
    pipeline = DataProtectionPipeline(pii_masker, data_minimizer, encryption_manager)
    
    # 데이터 보호 처리
    protected_data = pipeline.process_for_llm(
        data=sample_data,
        purpose="sleep_analysis",
        sensitive_keys={"name", "email", "phone"},
        summarize=True,
        summary_fields={"sleep_hours": "avg", "sleep_quality_score": "avg"}
    )
    
    print(json.dumps(protected_data, indent=2, ensure_ascii=False))
