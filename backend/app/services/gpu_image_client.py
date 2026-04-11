import os
from typing import Any, Dict, Optional, Tuple
from urllib.parse import urlparse
from uuid import uuid4

import httpx


class GPUImageClient:
    """GPU FastAPI 멀티파트 클라이언트 (/skin-edit, /generate)."""

    @staticmethod
    def _normalize_base_url(url: str) -> str:
        """
        .env 에 실수로 엔드포인트까지 넣은 경우 제거 (이중 /generate 방지).
        예: https://pod.../generate → https://pod...
        """
        u = (url or "").strip().rstrip("/")
        if not u:
            return u
        lower = u.lower()
        for suf in (
            "/generate",
            "/skin-edit",
            "/skin_edit",
            "/api/generate",
            "/api/skin-edit",
        ):
            if lower.endswith(suf):
                u = u[: -len(suf)].rstrip("/")
                lower = u.lower()
        return u

    @staticmethod
    def _optional_api_key(raw: Optional[str]) -> Optional[str]:
        """플레이스홀더·빈 값이면 Bearer 를 붙이지 않음 (RunPod 등에서 가짜 키로 404 나는 경우 방지)."""
        if raw is None:
            return None
        k = str(raw).strip()
        if not k:
            return None
        lower = k.lower()
        placeholders = (
            "api_here",
            "none",
            "changeme",
            "replace-me",
            "your-api-key",
            "your_api_key",
        )
        if lower in placeholders or lower.endswith("_here"):
            return None
        return k

    def __init__(
        self,
        base_url: Optional[str] = None,
        api_key: Optional[str] = None,
        timeout_seconds: float = 180.0,
        save_dir: Optional[str] = None,
    ):
        raw_base = (base_url or self._resolve_base_url() or "").strip()
        self.base_url = self._normalize_base_url(raw_base).rstrip("/")
        env_key = os.getenv("IMAGE_GENERATION_API_KEY")
        resolved_key = api_key if api_key is not None else env_key
        self.api_key = self._optional_api_key(resolved_key)
        self.timeout = timeout_seconds
        gp = (os.getenv("IMAGE_GENERATION_PATH_GENERATE") or "/generate").strip()
        sp = (os.getenv("IMAGE_GENERATION_PATH_SKIN_EDIT") or "/skin-edit").strip()
        self.path_generate = gp if gp.startswith("/") else f"/{gp}"
        self.path_skin_edit = sp if sp.startswith("/") else f"/{sp}"
        default_uploads = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../uploads")
        )
        self.save_dir = save_dir or default_uploads
        os.makedirs(self.save_dir, exist_ok=True)
        self._warn_docker_localhost_gpu()

    def _warn_docker_localhost_gpu(self) -> None:
        """Docker 안의 백엔드는 localhost/127.0.0.1 이 호스트의 GPU가 아님 — 흔한 설정 실수."""
        if os.getenv("RUNNING_IN_DOCKER") != "true" or not self.base_url:
            return
        bl = self.base_url.lower()
        if "127.0.0.1" not in bl and "localhost" not in bl:
            return
        print(
            "⚠️ [GPU] IMAGE_GENERATION_BASE_URL이 localhost/127.0.0.1 입니다. "
            "백엔드가 Docker 컨테이너에서 돌면 이 주소는 **컨테이너 자신**을 가리켜 GPU에 닿지 않습니다.\n"
            "   → Mac/Windows Docker Desktop: http://host.docker.internal:<GPU포트>\n"
            "   → Linux compose: extra_hosts 로 host.docker.internal 추가 또는 호스트 LAN IP\n"
            "   → RunPod 등 공인 URL이면 public URL 그대로 사용\n"
            "   → GET /health 성공해도 POST /generate 경로·인증이 다르면 생성은 실패할 수 있음."
        )

    @property
    def enabled(self) -> bool:
        return bool(self.base_url)

    @staticmethod
    def _resolve_base_url() -> Optional[str]:
        direct = os.getenv("IMAGE_GENERATION_BASE_URL")
        if direct:
            return GPUImageClient._normalize_base_url(direct.strip())

        # 하위 호환: 기존에는 IMAGE_GENERATION_API_URL에 전체 URL을 넣어 사용함.
        legacy = os.getenv("IMAGE_GENERATION_API_URL")
        if not legacy:
            return None

        parsed = urlparse(legacy)
        if not parsed.scheme or not parsed.netloc:
            return legacy
        return f"{parsed.scheme}://{parsed.netloc}"

    @staticmethod
    def normalize_gpu_gender(g: Optional[str]) -> str:
        """프로필 값(남성/여성, male/female 등)을 GPU /generate Form용 male|female 로 통일."""
        if g is None or str(g).strip() == "":
            return "female"
        s = str(g).strip().lower()
        if s in ("male", "m", "남성", "남"):
            return "male"
        if s in ("female", "f", "여성", "여"):
            return "female"
        return "female"

    def _build_headers(self) -> Dict[str, str]:
        headers: Dict[str, str] = {}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    @staticmethod
    def _mime_for_image_filename(filename: str) -> str:
        n = (filename or "").lower()
        if n.endswith((".jpg", ".jpeg")):
            return "image/jpeg"
        if n.endswith(".webp"):
            return "image/webp"
        return "image/png"

    def buildRequest(
        self,
        endpoint: str,
        *,
        image_bytes: bytes,
        filename: str,
        fields: Dict[str, Any],
    ) -> Tuple[str, Dict[str, str], Dict[str, Tuple[str, bytes, str]], Dict[str, str]]:
        if not self.base_url:
            raise RuntimeError("IMAGE_GENERATION_BASE_URL (또는 IMAGE_GENERATION_API_URL) not set")

        clean_endpoint = endpoint if endpoint.startswith("/") else f"/{endpoint}"
        url = f"{self.base_url}{clean_endpoint}"
        headers = self._build_headers()
        mime = self._mime_for_image_filename(filename)
        files = {
            "image": (filename, image_bytes, mime),
        }
        data = {k: str(v) for k, v in fields.items() if v is not None}
        return url, headers, files, data

    def _gpu_request_echo(
        self,
        operation: str,
        url: str,
        multipart_form: Dict[str, str],
        image_filename: str,
        image_bytes_len: int,
    ) -> Dict[str, Any]:
        """GPU로 실제로 나가는 multipart form(이미지 제외) + URL — 로그 및 API 응답용."""
        summary: Dict[str, Any] = {
            "operation": operation,
            "post_url": url,
            "multipart_form": dict(multipart_form),
            "image_filename": image_filename,
            "image_bytes": image_bytes_len,
            "bearer_sent": bool(self.api_key),
        }
        print(
            f"[GPU] {operation} → POST {url} | "
            f"form={multipart_form} | file={image_filename} ({image_bytes_len} bytes) | "
            f"Bearer={'yes' if self.api_key else 'no'}"
        )
        return summary

    async def check_health(self) -> Dict[str, Any]:
        if not self.base_url:
            raise RuntimeError("GPU BASE_URL이 비어 있어 health check를 수행할 수 없습니다.")

        url = f"{self.base_url}/health"
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers=self._build_headers())
        try:
            body = response.json()
        except Exception:
            body = {"raw": response.text}
        return {"ok": response.status_code < 400, "status_code": response.status_code, "body": body}

    async def _post_with_retry(
        self,
        *,
        url: str,
        headers: Dict[str, str],
        files: Dict[str, Tuple[str, bytes, str]],
        data: Dict[str, str],
    ) -> bytes:
        last_error: Optional[Exception] = None
        attempts = 2  # 네트워크 실패 시 1회 재시도

        for attempt in range(1, attempts + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(url, headers=headers, files=files, data=data)

                if response.status_code >= 400:
                    msg = self._parse_error_message(response)
                    raise RuntimeError(f"{msg} (POST {url})")
                return response.content
            except (httpx.ConnectError, httpx.ReadTimeout, httpx.WriteError, httpx.NetworkError) as e:
                last_error = e
                if attempt >= attempts:
                    raise RuntimeError(
                        f"GPU 서버 네트워크 오류(재시도 포함) - {type(e).__name__}: {e}"
                    ) from e
            except httpx.RequestError as e:
                last_error = e
                if attempt >= attempts:
                    raise RuntimeError(
                        f"GPU 서버 요청 실패(재시도 포함) - {type(e).__name__}: {e}"
                    ) from e
            except Exception:
                raise

        raise RuntimeError(f"GPU 서버 요청 실패: {last_error}")

    @staticmethod
    def _parse_error_message(response: httpx.Response) -> str:
        message = f"GPU 서버 오류 (status={response.status_code})"
        try:
            payload = response.json()
            detail = payload.get("detail") or payload.get("message") or payload.get("error")
            if isinstance(detail, list):
                detail = "; ".join(str(v) for v in detail)
            if detail:
                message = f"{message}: {detail}"
            else:
                message = f"{message}: {payload}"
        except Exception:
            text = (response.text or "").strip()
            if text:
                message = f"{message}: {text[:600]}"
        return message

    def saveImage(self, image_bytes: bytes, prefix: str = "gpu_result") -> str:
        filename = f"{prefix}_{uuid4().hex[:12]}.png"
        full_path = os.path.join(self.save_dir, filename)
        with open(full_path, "wb") as f:
            f.write(image_bytes)
        return full_path

    async def callSkinEdit(
        self,
        *,
        image_bytes: bytes,
        filename: str = "input.png",
        uv_score: int = 59,
        sleep_score: int = 65,
        exercise_score: int = 45,
        smoking_score: int = 25,
        alcohol_score: int = 20,
        stress_score: int = 55,
        prompt: Optional[str] = None,
        negative_prompt: Optional[str] = None,
        strength: Optional[float] = None,
        guidance_scale: Optional[float] = None,
        num_inference_steps: Optional[int] = None,
        seed: Optional[int] = None,
        max_side: Optional[int] = None,
        return_base64: bool = False,
    ) -> Dict[str, Any]:
        """
        GPU app.py /skin-edit 와 동일한 폼 필드.
        prompt/negative_prompt 가 None 이면 필드를 보내지 않아 서버가 자동 생성한다.
        strength 등이 None 이면 보내지 않아 서버가 -1 로 자동(compute_skin_edit_params) 처리한다.
        """
        fields: Dict[str, Any] = {
            "uv_score": uv_score,
            "sleep_score": sleep_score,
            "exercise_score": exercise_score,
            "smoking_score": smoking_score,
            "alcohol_score": alcohol_score,
            "stress_score": stress_score,
            "return_base64": 1 if return_base64 else 0,
        }
        if max_side is not None:
            fields["max_side"] = max_side
        if prompt is not None:
            fields["prompt"] = prompt
        if negative_prompt is not None:
            fields["negative_prompt"] = negative_prompt
        if strength is not None:
            fields["strength"] = strength
        if guidance_scale is not None:
            fields["guidance_scale"] = guidance_scale
        if num_inference_steps is not None:
            fields["num_inference_steps"] = num_inference_steps
        if seed is not None:
            fields["seed"] = seed

        url, headers, files, data = self.buildRequest(
            self.path_skin_edit,
            image_bytes=image_bytes,
            filename=filename,
            fields=fields,
        )
        gpu_request = self._gpu_request_echo(
            "skin-edit",
            url,
            data,
            filename,
            len(image_bytes),
        )
        result_bytes = await self._post_with_retry(
            url=url,
            headers=headers,
            files=files,
            data=data,
        )
        if return_base64:
            import json

            payload = json.loads(result_bytes.decode("utf-8"))
            b64 = payload.get("image_base64")
            if not b64:
                raise RuntimeError(f"GPU /skin-edit JSON 응답에 image_base64 없음: {payload!r}")
            import base64

            result_bytes = base64.b64decode(b64)
        saved_path = self.saveImage(result_bytes, prefix="gpu_skin_edit")
        return {
            "saved_path": saved_path,
            "endpoint": self.path_skin_edit,
            "gpu_request": gpu_request,
        }

    async def callGenerate(
        self,
        *,
        image_bytes: bytes,
        filename: str = "input.png",
        target_years: int = 3,
        current_age: Optional[int] = None,
        gender: Optional[str] = None,
        seed_base: int = 1000,
    ) -> Dict[str, Any]:
        age_val = int(current_age) if current_age is not None else -1
        gender_val = self.normalize_gpu_gender(gender)
        fields = {
            "target_years": target_years,
            "current_age": age_val,
            "gender": gender_val,
            "seed_base": seed_base,
            "return_base64": 0,
        }
        url, headers, files, data = self.buildRequest(
            self.path_generate,
            image_bytes=image_bytes,
            filename=filename,
            fields=fields,
        )
        gpu_request = self._gpu_request_echo(
            "generate",
            url,
            data,
            filename,
            len(image_bytes),
        )
        result_bytes = await self._post_with_retry(
            url=url,
            headers=headers,
            files=files,
            data=data,
        )
        saved_path = self.saveImage(result_bytes, prefix="gpu_generate")
        return {
            "saved_path": saved_path,
            "endpoint": self.path_generate,
            "gpu_request": gpu_request,
        }
