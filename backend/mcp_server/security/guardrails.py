"""
도구 검증 및 Sandboxing 시스템 (Tool Validation & Guardrails)
Semantic Guardrails, Pydantic 스키마 검증, 도구 제약 조건을 구현합니다.
"""
from typing import Dict, Any, List, Optional, Callable, Set
from enum import Enum
from pydantic import BaseModel, Field, validator, ValidationError
import logging
import inspect

logger = logging.getLogger(__name__)


# ==================== 도구 메타데이터 ====================

class ToolCategory(str, Enum):
    """도구 카테고리"""
    DATA_READ = "data_read"
    DATA_WRITE = "data_write"
    DATA_DELETE = "data_delete"
    ANALYSIS = "analysis"
    RECOMMENDATION = "recommendation"
    EXTERNAL_API = "external_api"
    SYSTEM = "system"


class ToolRiskLevel(str, Enum):
    """도구 위험 수준"""
    SAFE = "safe"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ToolMetadata(BaseModel):
    """도구 메타데이터"""
    name: str
    category: ToolCategory
    risk_level: ToolRiskLevel
    description: str
    
    # 제약 조건
    required_scopes: Set[str]  # 필요한 OAuth 스코프
    max_call_frequency: Optional[int] = None  # 분당 최대 호출 횟수
    data_volume_limit_mb: Optional[float] = None  # 데이터 볼륨 제한
    
    # Sandboxing
    requires_sandbox: bool = False  # 격리 환경 필요 여부
    network_access_allowed: bool = False  # 네트워크 접근 허용 여부
    
    # Human-in-the-Loop
    requires_human_approval: bool = False


# ==================== Semantic Guardrails ====================

class GuardrailViolation(Exception):
    """Guardrail 위반 예외"""
    pass


class SemanticGuardrails:
    """
    의미론적 가드레일
    LLM이 도구를 잘못 이해하거나 오용하지 못하도록 방지합니다.
    """
    
    def __init__(self):
        # 도구별 제약 조건
        self.tool_constraints: Dict[str, List[Callable]] = {}
        
        # 파라미터 유효성 검사 규칙
        self.parameter_rules: Dict[str, Dict[str, Any]] = {}
    
    def add_constraint(
        self,
        tool_name: str,
        constraint_fn: Callable[[Dict[str, Any]], bool],
        error_message: str
    ):
        """
        도구에 제약 조건 추가
        
        Args:
            tool_name: 도구 이름
            constraint_fn: 제약 조건 검사 함수 (parameters -> bool)
            error_message: 위반 시 오류 메시지
        """
        if tool_name not in self.tool_constraints:
            self.tool_constraints[tool_name] = []
        
        self.tool_constraints[tool_name].append({
            "check": constraint_fn,
            "error": error_message
        })
    
    def validate(self, tool_name: str, parameters: Dict[str, Any]) -> bool:
        """
        도구 호출 검증
        
        Args:
            tool_name: 도구 이름
            parameters: 파라미터
        
        Returns:
            검증 통과 여부
        
        Raises:
            GuardrailViolation: 제약 조건 위반
        """
        constraints = self.tool_constraints.get(tool_name, [])
        
        for constraint in constraints:
            try:
                if not constraint["check"](parameters):
                    raise GuardrailViolation(
                        f"Tool '{tool_name}' constraint violated: {constraint['error']}"
                    )
            except Exception as e:
                if isinstance(e, GuardrailViolation):
                    raise
                logger.error(f"Error checking constraint: {str(e)}")
                raise GuardrailViolation(
                    f"Tool '{tool_name}' validation error: {str(e)}"
                )
        
        logger.info(f"Guardrail validation passed for tool: {tool_name}")
        return True
    
    def add_parameter_rule(
        self,
        tool_name: str,
        param_name: str,
        rule: Dict[str, Any]
    ):
        """
        파라미터 규칙 추가
        
        Args:
            tool_name: 도구 이름
            param_name: 파라미터 이름
            rule: 규칙 (예: {"type": "int", "min": 0, "max": 100})
        """
        if tool_name not in self.parameter_rules:
            self.parameter_rules[tool_name] = {}
        
        self.parameter_rules[tool_name][param_name] = rule
    
    def validate_parameters(
        self,
        tool_name: str,
        parameters: Dict[str, Any]
    ) -> bool:
        """
        파라미터 규칙 검증
        
        Raises:
            GuardrailViolation: 규칙 위반
        """
        rules = self.parameter_rules.get(tool_name, {})
        
        for param_name, rule in rules.items():
            if param_name not in parameters:
                if rule.get("required", False):
                    raise GuardrailViolation(
                        f"Required parameter '{param_name}' missing for tool '{tool_name}'"
                    )
                continue
            
            value = parameters[param_name]
            
            # 타입 검사
            expected_type = rule.get("type")
            if expected_type:
                if expected_type == "int" and not isinstance(value, int):
                    raise GuardrailViolation(
                        f"Parameter '{param_name}' must be int, got {type(value).__name__}"
                    )
                elif expected_type == "str" and not isinstance(value, str):
                    raise GuardrailViolation(
                        f"Parameter '{param_name}' must be str, got {type(value).__name__}"
                    )
                elif expected_type == "float" and not isinstance(value, (int, float)):
                    raise GuardrailViolation(
                        f"Parameter '{param_name}' must be float, got {type(value).__name__}"
                    )
            
            # 범위 검사
            if "min" in rule and value < rule["min"]:
                raise GuardrailViolation(
                    f"Parameter '{param_name}' must be >= {rule['min']}, got {value}"
                )
            
            if "max" in rule and value > rule["max"]:
                raise GuardrailViolation(
                    f"Parameter '{param_name}' must be <= {rule['max']}, got {value}"
                )
            
            # 선택지 검사
            if "choices" in rule and value not in rule["choices"]:
                raise GuardrailViolation(
                    f"Parameter '{param_name}' must be one of {rule['choices']}, got {value}"
                )
        
        return True


# ==================== Tool Validator ====================

class ToolDefinition(BaseModel):
    """도구 정의"""
    name: str
    description: str
    metadata: ToolMetadata
    parameter_schema: type[BaseModel]  # Pydantic 모델
    function: Callable


class ToolValidator:
    """
    도구 검증기
    Pydantic 스키마를 사용하여 엄격한 파라미터 검증을 수행합니다.
    """
    
    def __init__(self):
        self.tools: Dict[str, ToolDefinition] = {}
        self.guardrails = SemanticGuardrails()
    
    def register_tool(
        self,
        name: str,
        description: str,
        metadata: ToolMetadata,
        parameter_schema: type[BaseModel],
        function: Callable
    ):
        """
        도구 등록
        
        Args:
            name: 도구 이름
            description: 도구 설명
            metadata: 메타데이터
            parameter_schema: Pydantic 스키마
            function: 실행 함수
        """
        tool_def = ToolDefinition(
            name=name,
            description=description,
            metadata=metadata,
            parameter_schema=parameter_schema,
            function=function
        )
        
        self.tools[name] = tool_def
        logger.info(f"Tool registered: {name}")
    
    def validate_and_execute(
        self,
        tool_name: str,
        parameters: Dict[str, Any],
        context: Optional[Dict[str, Any]] = None
    ) -> Any:
        """
        도구 검증 및 실행
        
        Args:
            tool_name: 도구 이름
            parameters: 파라미터
            context: 실행 컨텍스트 (사용자 정보 등)
        
        Returns:
            도구 실행 결과
        
        Raises:
            ValueError: 도구가 등록되지 않음
            ValidationError: 파라미터 검증 실패
            GuardrailViolation: Guardrail 위반
        """
        # 1. 도구 존재 확인
        tool = self.tools.get(tool_name)
        if not tool:
            raise ValueError(f"Tool '{tool_name}' not registered")
        
        # 2. Pydantic 스키마 검증
        try:
            validated_params = tool.parameter_schema(**parameters)
        except ValidationError as e:
            logger.error(f"Parameter validation failed for '{tool_name}': {str(e)}")
            raise
        
        # 3. Semantic Guardrails 검증
        self.guardrails.validate(tool_name, parameters)
        self.guardrails.validate_parameters(tool_name, parameters)
        
        # 4. Sandboxing 확인
        if tool.metadata.requires_sandbox:
            logger.warning(f"Tool '{tool_name}' requires sandbox execution (not implemented)")
            # TODO: 실제 샌드박스 환경에서 실행
        
        # 5. 도구 실행
        try:
            logger.info(f"Executing tool: {tool_name}")
            result = tool.function(**validated_params.model_dump())
            logger.info(f"Tool execution completed: {tool_name}")
            return result
        except Exception as e:
            logger.error(f"Tool execution failed: {tool_name}, error: {str(e)}")
            raise
    
    def get_tool_metadata(self, tool_name: str) -> Optional[ToolMetadata]:
        """도구 메타데이터 조회"""
        tool = self.tools.get(tool_name)
        return tool.metadata if tool else None
    
    def list_tools(
        self,
        category: Optional[ToolCategory] = None,
        max_risk_level: Optional[ToolRiskLevel] = None
    ) -> List[str]:
        """
        도구 목록 조회
        
        Args:
            category: 카테고리 필터
            max_risk_level: 최대 위험 수준 필터
        
        Returns:
            도구 이름 리스트
        """
        risk_order = {
            ToolRiskLevel.SAFE: 0,
            ToolRiskLevel.LOW: 1,
            ToolRiskLevel.MEDIUM: 2,
            ToolRiskLevel.HIGH: 3,
            ToolRiskLevel.CRITICAL: 4,
        }
        
        filtered_tools = []
        
        for name, tool in self.tools.items():
            # 카테고리 필터
            if category and tool.metadata.category != category:
                continue
            
            # 위험 수준 필터
            if max_risk_level:
                if risk_order[tool.metadata.risk_level] > risk_order[max_risk_level]:
                    continue
            
            filtered_tools.append(name)
        
        return filtered_tools


# ==================== Rate Limiter ====================

from collections import defaultdict, deque
from datetime import datetime, timedelta


class RateLimiter:
    """
    도구 호출 속도 제한
    과도한 호출을 방지합니다.
    """
    
    def __init__(self):
        # 사용자별 도구 호출 기록
        self.call_history: Dict[str, Dict[str, deque]] = defaultdict(
            lambda: defaultdict(lambda: deque(maxlen=1000))
        )
    
    def check_rate_limit(
        self,
        user_id: str,
        tool_name: str,
        max_calls: int,
        time_window: timedelta
    ) -> bool:
        """
        속도 제한 확인
        
        Args:
            user_id: 사용자 ID
            tool_name: 도구 이름
            max_calls: 최대 호출 횟수
            time_window: 시간 윈도우
        
        Returns:
            제한 내 여부 (True: 허용, False: 제한 초과)
        """
        now = datetime.utcnow()
        cutoff_time = now - time_window
        
        # 사용자의 해당 도구 호출 기록
        history = self.call_history[user_id][tool_name]
        
        # 시간 윈도우 내 호출 수 계산
        recent_calls = [ts for ts in history if ts >= cutoff_time]
        
        if len(recent_calls) >= max_calls:
            logger.warning(
                f"Rate limit exceeded: user={user_id}, tool={tool_name}, "
                f"calls={len(recent_calls)}, limit={max_calls}"
            )
            return False
        
        # 현재 호출 기록
        history.append(now)
        return True


# ==================== 사용 예시 ====================

if __name__ == "__main__":
    # ========== Pydantic 스키마 정의 ==========
    
    class GetHealthDataParams(BaseModel):
        """건강 데이터 조회 파라미터"""
        user_id: int = Field(..., gt=0, description="사용자 ID")
        days: int = Field(7, ge=1, le=30, description="조회 기간 (일)")
        data_type: str = Field("all", description="데이터 타입")
        
        @validator('data_type')
        def validate_data_type(cls, v):
            allowed = ['all', 'sleep', 'nutrition', 'activity']
            if v not in allowed:
                raise ValueError(f"data_type must be one of {allowed}")
            return v
    
    # ========== 도구 함수 정의 ==========
    
    def get_health_data(user_id: int, days: int, data_type: str) -> Dict[str, Any]:
        """건강 데이터 조회"""
        return {
            "user_id": user_id,
            "days": days,
            "data_type": data_type,
            "data": ["mock_data"]
        }
    
    # ========== ToolValidator 초기화 ==========
    
    validator = ToolValidator()
    
    # 도구 등록
    validator.register_tool(
        name="get_health_data",
        description="사용자의 건강 데이터를 조회합니다.",
        metadata=ToolMetadata(
            name="get_health_data",
            category=ToolCategory.DATA_READ,
            risk_level=ToolRiskLevel.LOW,
            description="건강 데이터 조회",
            required_scopes={"health:read"},
            max_call_frequency=30,
            requires_sandbox=False,
            network_access_allowed=False,
            requires_human_approval=False
        ),
        parameter_schema=GetHealthDataParams,
        function=get_health_data
    )
    
    # Guardrail 추가
    validator.guardrails.add_constraint(
        tool_name="get_health_data",
        constraint_fn=lambda p: p.get("days", 0) <= 30,
        error_message="Cannot query more than 30 days of data"
    )
    
    # 도구 실행
    try:
        result = validator.validate_and_execute(
            tool_name="get_health_data",
            parameters={"user_id": 123, "days": 7, "data_type": "sleep"}
        )
        print(f"Result: {result}")
    except Exception as e:
        print(f"Error: {str(e)}")
